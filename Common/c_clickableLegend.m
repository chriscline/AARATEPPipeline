function varargout = c_clickableLegend(varargin)
% inspired by clickableLegend, implementation based on https://www.mathworks.com/help/releases/R2017a/matlab/creating_plots/create-callbacks-for-interacting-with-legend-items.html

if nargin == 0, testfn(); return; end

p = inputParser();
p.KeepUnmatched = true;
p.addParameter('axis',[],@isgraphics);
p.addParameter('labels',{},@iscellstr);
p.addParameter('obj',{},@iscell); % cell array of handles to include in legend, where only first element of each is passed to legend
try
	p.parse(varargin{:});
	s = p.Results;
	
	legendArgs = {};
	if ~isempty(s.axis)
		legendArgs{end+1} = s.axis;
	end
	if ~isempty(s.obj)
		obj = gobjects(1,length(s.obj));
		for iG = 1:length(s.obj)
			obj(iG) = s.obj{iG}(1);
			if length(s.obj{iG}) > 1
				setUserData(obj(iG),'clickableLegend_othersInGroup',s.obj{iG}(2:end));
			end
		end
		legendArgs{end+1} = obj;
	end
	
	assert(~isempty(s.labels));
	legendArgs{end+1} = s.labels;
	
	legendArgs = [legendArgs, c_structToCell(p.Unmatched)];
catch e
	% if error above, just assume all args are meant to be passed to legend
	rethrow(e)
	warning(e.message)
	legendArgs = varargin;
end

assert(nargout <= 1,'Legacy syntax with > 1 output from legend not supported');

lh = legend(legendArgs{:});

if verLessThan('matlab','R2016a')
	warning('ItemHitFcn not supported in MATLAB < R2016a. Legend will not be interactive');
else
	lh.ItemHitFcn = @callback_itemHit;
end

varargout{1} = lh;

end

function callback_itemHit(src,event)
	hp = event.Peer;
	if ismember(event.SelectionType,{'open','normal'})
		toggleHighlight(hp);
	elseif strcmpi(event.SelectionType,'extend')
		toggleHighlight(hp); % assuming open was triggered by double click, undo previous toggle width that preceded this
		toggleVisible(hp);
	else
		warning('Unexpected selection type: %s',event.SelectionType);
	end
end

function toggleHighlight(h)
	if c_isFieldAndNonEmpty(h.UserData,'clickableLegend_isHighlighted')
		isHighlighted = h.UserData.clickableLegend_isHighlighted;
	else
		isHighlighted = false;
	end
	
	hg = h;
	if c_isFieldAndNonEmpty(h.UserData,'clickableLegend_othersInGroup')
		hg = [hg; h.UserData.clickableLegend_othersInGroup];
	end
	
	fields = {'LineWidth','MarkerWidth'};
	for iF = 1:length(fields)
		hl = findobj(hg,'-property',fields{iF});
		vals = get(hl,fields(iF));
		set(hl,fields(iF),cellfun(@(x) x*c_if(isHighlighted,1/3,3),vals,'UniformOutput',false));
	end
	
	setUserData(h,'clickableLegend_isHighlighted',~isHighlighted);
end

function toggleVisible(h)
	if c_isFieldAndNonEmpty(h.UserData,'clickableLegend_isHidden')
		isHidden = h.UserData.clickableLegend_isHidden;
	else
		isHidden = false;
	end
	
	hg = h;
	if c_isFieldAndNonEmpty(h.UserData,'clickableLegend_othersInGroup')
		hg = [hg; h.UserData.clickableLegend_othersInGroup];
	end
	
	hl = findobj(hg,'-property','Visible');
	vals = get(hl,{'Visible'});
	set(hl,{'Visible'},cellfun(@(x) c_if(isHidden,'on','off'),vals,'UniformOutput',false));
	
	setUserData(h,'clickableLegend_isHidden',~isHidden);
end

function setUserData(h,field,val)
	if ~isstruct(h.UserData)
		if ~isempty(h.UserData)
			warning('Overwriting user data');
		end
		h.UserData = struct();
	end
	h.UserData = c_setField(h.UserData,field,val);
end


function testfn()
figure;
plot(1:10,rand(2,10));
c_clickableLegend({'a','b'});

hf = figure;
ha = c_subplot(1,1,'parent',uipanel(hf));
numGroups = 3;
groupLabels = arrayfun(@(iG) sprintf('Group %d',iG),1:numGroups,'UniformOutput',false);
colors = c_getColors(numGroups);
hg = {};
for iG=1:numGroups
	hg{iG} = plot(ha,1:10,rand(3,10)+iG,'Color',colors(iG,:));
	hold(ha,'on');
end
c_clickableLegend('axis',ha,'obj',hg,'labels',groupLabels,'location','east');
end