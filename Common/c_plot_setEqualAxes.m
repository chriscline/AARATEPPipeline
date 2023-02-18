function c_plot_setEqualAxes(varargin)
% c_plot_setEqualAxes - set axis limits equal across multiple plots
% By default, this included color scales, and also links the axes so that changes to one plot
%  affect all linked plots
%
% Example:
% 	figure;
% 	h1 = c_subplot(1,2);
% 	plot(rand(10,2));
% 	h2 = c_subplot(2,2);
% 	plot(rand(20,2)*2);
% 	c_plot_setEqualAxes([h1 h2]);

p = inputParser();
p.addOptional('axisHandles',[],@(x) all(ishandle(x(:))));
p.addParameter('xlim',[nan, nan],@isvector);
p.addParameter('ylim',[nan, nan],@isvector);
p.addParameter('zlim',[nan, nan],@isvector);
p.addParameter('clim',[nan, nan],@isvector);
p.addParameter('axesToSet','xyzc',@(x) ischar(x) || iscellstr(x)); % if cell, one char per axisHandle in each element
p.addParameter('doForceSymmetric',false,@islogical);
p.addParameter('doForceEqualAspect',false,@islogical);
p.addParameter('doLink',true,@islogical);
p.parse(varargin{:});
s = p.Results;

if isempty(s.axisHandles)
	% no handles given, assume we should grab all axes from current figure
	s.axisHandles = gcf;
else
	s.axisHandles = s.axisHandles(:); % reshape any higher dimensions into vector
end

axisHandles = [];
for i=1:length(s.axisHandles)
	if isgraphics(s.axisHandles(i),'Figure')
		% figure handle given, assume we should grab all axes from the figure
		childHandles = findobj(s.axisHandles(i),'Type','axes');
		axisHandles = [axisHandles; childHandles];
	elseif isgraphics(s.axisHandles(i),'axes')
		axisHandles = [axisHandles;s.axisHandles(i)];
	else
		error('invalid handle');
	end
end
s.axisHandles = axisHandles;

if s.doForceEqualAspect
	set(s.axisHandles,'DataAspectRatio',[1 1 1]);
end

for j=1:length(s.axesToSet)
	if length(s.doForceSymmetric)==1 % one doForceSymmetric value for all axes
		doForceSymmetric = s.doForceSymmetric;
	else % one doForceSymmetric value for each axis
		assert(length(s.doForceSymmetric)==length(s.axesToSet)); 
		doForceSymmetric = s.doForceSymmetric(j);
	end
	if ~iscell(s.axesToSet)
		limfield = [lower(s.axesToSet(j)) 'lim'];
		lim = s.(limfield);
		setEqualAxis(s.axisHandles,s.axesToSet(j),lim,doForceSymmetric,s.doLink);
	else
		assert(length(s.axisHandles)==length(s.axesToSet{j}));
		lim = s.([lower(s.axesToSet{j}(1)) 'lim']);
		setEqualAxis(s.axisHandles,s.axesToSet{j},lim,doForceSymmetric,s.doLink);
	end
end

end


function setEqualAxis(axisHandles,axesToSet,lim,doSymmetry, doLink)
	if length(axesToSet)==1
		assert(ischar(axesToSet));
		axesToSet = repmat(axesToSet,1,length(axisHandles));
	end
	assert(length(axesToSet)==length(axisHandles));
	fieldsOfInterest = cell(1,length(axisHandles));
	for i=1:length(axisHandles)
		fieldsOfInterest{i} = [upper(axesToSet(i)) 'Lim'];
	end
	i=1;
	currentLim = get(axisHandles(i),fieldsOfInterest{i});
	if isdatetime(currentLim)
		% handle special case of datetime axis values
		assert(all(arrayfun(@(i) isdatetime(get(axisHandles(i),fieldsOfInterest{i})), 1:length(axisHandles))));
		if all(isnan(lim))
			i=1;
			[minVal,maxVal] = c_mat_deal(get(axisHandles(i),fieldsOfInterest{i}));
			for i=2:length(axisHandles)
				newLim = get(axisHandles(i),fieldsOfInterest{i});
				minVal = min(minVal,newLim(1));
				maxVal = max(maxVal,newLim(2));
			end
			lim = [minVal, maxVal];
		elseif any(isnan(lim))
			error('Partially specified datetime limits not currently supported');
		end
	else
		isnat_ = @(t) isa(t, 'datetim') && isnat(t);
		if isnan(lim(1)) || isnat_(lim(1)) % need to autodetect min
			minVal = inf;
			for i=1:length(axisHandles)
				newVal = paren(get(axisHandles(i),fieldsOfInterest{i}),1);
				minVal = min(newVal,minVal);
			end
			lim(1) = minVal;
		end
		if isnan(lim(2)) || isnat_(lim(2)) % need to autodetect max
			maxVal = -inf;
			for i=1:length(axisHandles)
				newVal = paren(get(axisHandles(i),fieldsOfInterest{i}),2);
				maxVal = max(newVal,maxVal);
			end
			lim(2) = maxVal;
		end
	end
	
	if doSymmetry
		lim = [-1 1]*max(abs(lim));
	end
	
	% set limits
	for i=1:length(axisHandles)
		set(axisHandles(i),fieldsOfInterest{i},lim);
	end
	
	if doLink
		if c_allEqual(axesToSet)
			fieldOfInterest = fieldsOfInterest{1};
			hlink = linkprop(axisHandles,fieldOfInterest);
			ud = get(axisHandles(1),'UserData');
			if iscell(ud) && ~isempty(ud)
				ud{end+1} = ['Link' fieldOfInterest 'Handle'];
				ud{end+1} = hlink;
			else
				ud.(['Link' fieldOfInterest 'Handle']) = hlink;
			end
			set(axisHandles(1),'UserData',ud);
		else
			% linking not currently supported for linking between different axes
		end
	end
end