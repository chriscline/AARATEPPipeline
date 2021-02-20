function [axisHandles, extra] = c_plot_stacked(varargin)

if nargin == 0, testfn(); return; end

p = inputParser();
p.addRequired('x',@isvector);
p.addRequired('y',@ismatrix);
p.addParameter('existingHandles',[],@(x) all(ishandle(x)));
p.addParameter('doAddToExisting',false,@islogical);
p.addParameter('xlabel','',@ischar);
p.addParameter('ylabel','',@ischar);
p.addParameter('ylabels',{},@iscell);
p.addParameter('plotArgs_common',{},@iscell);
p.addParameter('plotArgs_per_names',{},@iscell);
p.addParameter('plotArgs_per_values',{},@iscell);
p.addParameter('plotFn',@plot,@(x) isa(x,'function_handle')); % inputs: (handle, x, y, plotArgs{:})
p.addParameter('warnLimit',100,@isscalar); % warn and pause if number of plots will exceed this limit
p.addParameter('doShowYTicks',false,@islogical);
p.addParameter('parent',[],@isgraphics);
p.addParameter('position',[0 0.05 1 1-0.075],@(x) isvector(x) && length(x)==4); % in normalized units
p.parse(varargin{:});
s = p.Results;

x = s.x;
y = s.y;

extra = struct();


if isempty(s.parent)
	if ~isempty(s.existingHandles)
		s.parent = s.existingHandles(1).Parent;
	else
		s.parent = gcf;
	end
end

numPts = length(x);
secondDim = find(size(y)==numPts,1,'first');
if isempty(secondDim)
	error('No matching dimension in y');
end
y = shiftdim(y,secondDim-1);
y = reshape(y,size(y,1),[]);
y = y.';

numPlots = size(y,1);
if numPlots > s.warnLimit
	warning('Will plot %d plots, continue?',numPlots);
	pause
end

assert(length(s.plotArgs_per_names)==length(s.plotArgs_per_values));

if ~isempty(s.existingHandles)
	assert(length(s.existingHandles)==numPlots);
end

prevWarnState = warning('off','MATLAB:hg:ColorSpec_None');

% in normalized units
left = s.position(1);
width = s.position(3);
bottom = s.position(2);
totalHeight = s.position(4);
top = 1-totalHeight-bottom;
singleHeight = totalHeight/numPlots;

prevParentUnits = get(s.parent,'units');
set(s.parent,'units','normalized');

ylabels = s.ylabels;
if isempty(ylabels)
	if ~s.doAddToExisting
		for i=1:numPlots
			ylabels{i} = num2str(i);
		end
	else
		ylabels = cell(1,numPlots);
	end
end

if ~isempty(s.existingHandles)
	handles = s.existingHandles;
else
	handles = gobjects(1,numPlots);
end
extra.plotFnVarargout = cell(1,numPlots);

for i=1:numPlots
	if isempty(s.existingHandles)
		singleBottom = 1-top-singleHeight*i;
		handles(i) = c_subplot('position',[left singleBottom width singleHeight],'Number',i,'parent',s.parent);
	end
	
	args = s.plotArgs_common;
	if ~isempty(s.plotArgs_per_names)
		for j=1:length(s.plotArgs_per_names)
			args = [args, s.plotArgs_per_names{j},s.plotArgs_per_values{j}{i}];
		end
	end
	
	if s.doAddToExisting
		prevHold = ishold(handles(i));
		hold(handles(i),'on');
	end
	[extra.plotFnVarargout{i}{1:nargout(s.plotFn)}] = s.plotFn(handles(i),x,y(i,:),args{:});
	if s.doAddToExisting
		if ~prevHold
			hold(handles(i),'off');
		end
	end
	
	if isempty(s.existingHandles)
		set(handles(i),'box','off');
		outerPos = get(handles(i),'OuterPosition');
		innerPos = get(handles(i),'Position');
		newPos = [innerPos(1) outerPos(2) innerPos(3) outerPos(4)];
		set(handles(i),'Position',newPos);
	end
	set(get(handles(i),'Children'),'Clipping','off');
	%axis off
	if ~isempty(ylabels{i})
		ylabelStr = c_str_wrap(ylabels{i},'toLength',30);
		fontSize = max(8,8/max(sum(ylabelStr==sprintf('\n'))-1,1));
		if s.doAddToExisting && ~isempty(handles(i).YLabel.String) && ~isequal(ylabelStr,handles(i).YLabel.String)
			warning('Overwriting previous ylabel. To avoid this warning, only specify ylabels once or repeated labels are identical');
		end
		h = ylabel(handles(i),ylabelStr,'Rotation',0,'HorizontalAlignment','right','VerticalAlignment','middle','FontSize',fontSize);
	end
	
	if i~=numPlots
		if isempty(s.existingHandles)
			% disable other plot components?
			set(handles(i),'XTickLabel',{});
			set(handles(i),'XTick',[]);
			set(handles(i),'XColor',[0.5 0.5 0.5]);
		end
	else
		if ~isempty(s.xlabel)
			if s.doAddToExisting && ~isempty(handles(i).XLabel.String) && ~isequal(s.xlabel,handles(i).XLabel.String)
				warning('Overwriting previous xlabel. To avoid this warning, only specify xlabels once or repeated labels are identical');
			end
			xlabel(handles(i),s.xlabel);
		end
	end
end

if ~s.doShowYTicks
	set(handles,'YTickLabel',{});
	set(handles,'YTick',[]);
end

set(handles,'color','none');

linkaxes(flipud(handles));
ylims = extrema(y(:));
if any(isnan(ylims))
	ylim(handles(end),[0 1]);
else
	ylim(handles(end),extrema(y(:)));
end

if ~isempty(s.ylabel)
	rightBound = max(paren(get(handles(1),'Position'),1)-...
		paren(get(handles(1),'TightInset'),1),0);
	hp = uipanel(...
		'Units','normalized',...
		...%'BackgroundColor','none',...
		'BorderType','none',...
		'Parent',s.parent,...
		'Position',[rightBound/8, 0, rightBound*3/4,1]);
	ha = axes('Parent',hp,'Visible','off');
	ht = text('Parent',ha, ...
		'Units','normalized',...
		'HorizontalAlignment','center',...
		'Position',[0.5 0.5],...
		'String',s.ylabel, ...
		'Rotation',90);
end

%axes(handles(end));

warning(prevWarnState.state,'MATLAB:hg:ColorSpec_None');

set(s.parent,'units',prevParentUnits);

axisHandles = handles;


end


function testfn()
N = 1000;
M = 20;

x = linspace(0,10,1000);

y = cumsum(randn(M,N),2);

hf = figure;
hf.Visible = 'off';
c_plot_stacked(x,y,...
	'xlabel','time',...
	'ylabel','magnitude');

pause
hf.Visible = 'on'; 

keyboard


end
