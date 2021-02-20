function h = c_fig_arrange(varargin)
% c_fig_arrange - arrange one or more figures
% Makes it easier to quickly visualize data spread across multiple figures with options such as tiling
%  sets of figures across specified monitors, etc.
%
% Possible general actions include: 'maximize','tile','show','close','link'.
% Can also move figures to a specific region of a screen with specific actions: 
%  'left-half','top-left','left-third',etc.
%
% Syntax:
%	 c_fig_arrange(action,figHandles,...)
%
% Examples:
% 	h1 = figure('name','Example figure 1');
% 	h2 = figure('name','Example figure 2');
% 	h3 = figure('name','Other figure');
% 	c_fig_arrange('maximize'); % maximize active figure
% 	c_fig_arrange('tile',[h1 h2]); % tile multiple figures on same monitor
% 	c_fig_arrange('tile',[h1 h2],'monitors',[1 2]); % tile multiple figures across multiple monitors
% 	c_fig_arrange('show',h1); % bring a figure to the foreground
% 	c_fig_arrange('tile',[],'figNumFilter',[1 3]); % arrange figures by figure number
% 	c_fig_arrange('left-half',h1,'monitor',2); % move figure to left half of second monitor
% 	c_fig_arrange('tile','^Example*'); % include certain figures matching a regex string
% 	c_fig_arrange('tile',[],'notFigHandles','^Other*'); % exclude certain figures matching a regex string

if nargin == 0; testfn(); return; end;

p = inputParser();
p.addRequired('action',@ischar); % valid: maximum, tile, show
p.addOptional('figHandles',[],@(x) isempty(x) || all(ishandle(x(:))) || ischar(x) || iscellstr(x));
p.addParameter('notFigHandles',[],@(x) isempty(x) || all(ishandle(x(:))) || ischar(x) || iscellstr(x));
p.addParameter('monitors',[1],@isvector); % single or multiple monitors to use
p.addParameter('doHideMenuBar','auto',@islogical);
p.addParameter('doHideToolBar','auto',@islogical);
p.addParameter('doBringToFront',true,@islogical);
p.addParameter('tileOrder',{'col','row','mon'},@iscellstr);
p.addParameter('tileDims','auto',@ismatrix); % vector or matrix describing number of rows and columns to tile on each monitor
p.addParameter('figNumFilter',[],@isvector);
p.addParameter('multiRegexOperation','or',@ischar);
p.addParameter('linkArgs',{},@iscell);
p.parse(varargin{:});
s = p.Results;

singleFigActions = {'maximize',...
	'left-half','right-half','top-half','bottom-half',...
	'top-left','top-right','bottom-left','bottom-right',...
	'top-left-top','top-left-bottom','top-right-top','top-right-bottom',...
	'bottom-left-top','bottom-left-bottom','bottom-right-top','bottom-right-bottom',...
	'top-third',...
	'top-twothirds','bottom-twothirds','left-twothirds','right-twothirds',...
	'copy-nocrop-1','copy-nocrop-2',...
};
multiFigActions = {'tile','show','close','link','setEqualAxes','get','getTiler'};

nonArrangeActions = {'copy-nocrop-1','copy-nocrop-2','show','close','link','setEqualAxes','get','getTiler'};

allActions = [singleFigActions, multiFigActions];
assert(ismember(s.action,allActions));

if isempty(s.figHandles)
	if ismember(s.action,singleFigActions) && isempty(s.figNumFilter)
		s.figHandles = gcf;
	else
		s.figHandles = '.*';
	end
else
	if ~ischar(s.figHandles) && ~iscell(s.figHandles)
		s.figHandles = s.figHandles(:); % force to be a vector
	end
end

if ischar(s.figHandles) || iscellstr(s.figHandles)
	% assume that figHandles is a regex string matching figure names to arrange
	regexStr = s.figHandles;
	figs = get(0,'Children'); % get all open figures (not included those with hidden handles)
	if isempty(figs)
		return;
	end
	figNames = {figs.Name};
	indicesToKeep = c_str_matchRegex(figNames,regexStr,'multiRegexOperation',s.multiRegexOperation);
	s.figHandles = figs(indicesToKeep);
	% sort by figure number
	[~,I] = sort(cell2mat({s.figHandles.Number}));
	s.figHandles = s.figHandles(I);
end

if ~isempty(s.figNumFilter)
	figNums = c_struct_mapToArray(s.figHandles,{'Number'});
	figsToKeep = ismember(figNums,s.figNumFilter);
	s.figHandles = s.figHandles(figsToKeep);
end

if ischar(s.notFigHandles) || iscellstr(s.notFigHandles)
	regexStr = s.notFigHandles;
	figs = get(0,'Children'); % get all open figures (not included those with hidden handles)
	if isempty(figs)
		s.notFigHandles = [];
	else
		figNames = {figs.Name};
		indicesToKeep = c_str_matchRegex(figNames,regexStr,'multiRegexOperation',s.multiRegexOperation);
		s.notFigHandles = figs(indicesToKeep);
	end
end

if ~isempty(s.notFigHandles)
	s.figHandles = s.figHandles(~ismember(s.figHandles,s.notFigHandles));
end

numFigs = numel(s.figHandles);

persistent mps;
if isempty(mps)
	prevUnits = get(0,'Units');
	set(0,'Units','pixels');
	mps = get(0,'MonitorPositions');
	set(0,'Units',prevUnits);
end
s.monitors = mod(s.monitors-1,size(mps,1))+1;

if ischar(s.doHideMenuBar) && strcmpi(s.doHideMenuBar,'auto') 
	if ~ismember(s.action,nonArrangeActions)
		s.doHideMenuBar = numFigs > 4;
	else
		s.doHideMenuBar = false;
	end
end

if ischar(s.doHideToolBar) && strcmpi(s.doHideToolBar,'auto')
	if ~ismember(s.action,nonArrangeActions)
		s.doHideToolBar = numFigs > 8;
	else
		s.doHideToolBar = false;
	end
end

if s.doHideMenuBar
	set(s.figHandles,'MenuBar','none');
end

if s.doHideToolBar
	set(s.figHandles,'ToolBar','none');
elseif s.doHideMenuBar
	set(s.figHandles,'ToolBar','figure');
end

drawnow;

set(s.figHandles,'Units','pixels');

switch(s.action)
	case 'maximize'
		pos = [0 0 1 1];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'left-half'
		pos = [0 0 0.5 1];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'right-half'
		pos = [0.5 0 0.5 1];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'top-half'
		pos = [0 0 1 0.5];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'bottom-half'
		pos = [0 0.5 1 0.5];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'top-left'
		pos = [0 0 0.5 0.5];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'top-right'
		pos = [0.5 0 0.5 0.5];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'bottom-left'
		pos = [0 0.5 0.5 0.5];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'bottom-right'
		pos = [0.5 0.5 0.5 0.5];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'top-left-top'
		pos = [0 0 0.5 0.25];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'top-left-bottom'
		pos = [0 0.25 0.5 0.25];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'top-right-top'
		pos = [0.5 0 0.5 0.25];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'top-right-bottom'
		pos = [0.5 0.25 0.5 0.25];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'bottom-left-top'
		pos = [0 0.5 0.5 0.25];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'bottom-left-bottom'
		pos = [0 0.75 0.5 0.25];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'bottom-right-top'
		pos = [0.5 0.5 0.5 0.25];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'bottom-right-bottom'
		pos = [0.5 0.75 0.5 0.25];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'top-third'
		pos = [0 0 1 1/3];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'top-twothirds'
		pos = [0 0 1 2/3];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'bottom-twothirds'
		pos = [0 1/3 1 2/3];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'left-twothirds'
		pos = [0 0 2/3 1];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'right-twothirds'
		pos = [1/3 0 2/3 1];
		set(s.figHandles,'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors));
	case 'tile'
		
		if ischar(s.tileDims) && strcmpi(s.tileDims,'auto')
			if numFigs == 3
				numCols = numFigs;
				numRows = 1;
			elseif numFigs == 6 && length(s.monitors)==1
				numCols = 3;
				numRows = 2;
			elseif numFigs == 6 && length(s.monitors)==2
				numRows = 1;
				numCols = 6;
			elseif numFigs == 8 && length(s.monitors)==1
				numCols = 4;
				numRows = 2;
			elseif numFigs == 8 && length(s.monitors)==2
				numRows = 2;
				numCols = 4;
			else
				numCols = min(ceil(sqrt(numFigs/length(s.monitors))*length(s.monitors)),numFigs);
				numRows = ceil(numFigs/numCols);
			end
		else
			numRows = s.tileDims(1);
			numCols = s.tileDims(2);
			if isnan(numRows)
				assert(~isnan(numCols));
				numRows = ceil(numFigs / numCols);
			elseif isnan(numCols)
				numCols = ceil(numFigs / numRows);
			end
		end
		if length(s.monitors)==1
			isLandscape = mps(s.monitors,3) > mps(s.monitors,4);
			if ~isLandscape
				% swap numbers of rows and columns
				tmp = numCols;
				numCols = numRows;
				numRows = tmp;
			end
		end
		% in multi-monitor case, assume (for now) that all monitors are landscape
		
		colsPerMon = ceil(numCols / length(s.monitors));
		
		assert(all(ismember(s.tileOrder,{'row','col','mon'})));
		assert(length(s.tileOrder)==3);
		assert(length(unique(s.tileOrder))==3);
		
		rowColMonMapping = cellfun(@(x) find(ismember(s.tileOrder,x),1,'first'),{'row','col','mon'});
		
		limits = nan(1,3);
		limits(rowColMonMapping) = [numRows, colsPerMon, length(s.monitors)];
		
		locIndex = [0,1,1];
		
		for iF = 1:numFigs
			locIndex(1) = locIndex(1) + 1;
			if locIndex(1) > limits(1)
				locIndex(1) = 1;
				locIndex(2) = locIndex(2) + 1;
			end
			if locIndex(2) > limits(2)
				locIndex(2) = 1;
				locIndex(3) = locIndex(3) + 1;
			end
			if locIndex(3) > limits(3)
				error('Tile dimensions too small for number of figures: %dx%dx%d<%d',limits(rowColMonMapping),numFigs);
			end
			
			[rowNum, colNum, monNum] = c_mat_deal(locIndex(rowColMonMapping));
			pos = [(colNum-1)/colsPerMon, (rowNum-1)/numRows, 1/colsPerMon, 1/numRows];
			set(s.figHandles(iF),'OuterPosition',convertRelativePosToPixelPos(pos,s.monitors(monNum)));
		end
		
	case 'show'
		% just bring all figures to the front
		s.doBringToFront = true;
		
	case 'close'
		s.doBringToFront = false;
		close(s.figHandles);
		
	case 'link'
		ah = [];
		for iF = 1:length(s.figHandles)
			ah = cat(1,ah,findall(s.figHandles(iF),'type','axes'));
		end
		c_plot_linkViews(ah, s.linkArgs{:});
		
	case 'setEqualAxes'
		ah = [];
		for iF = 1:length(s.figHandles)
			ah = cat(1,ah,findall(s.figHandles(iF),'type','axes'));
		end
		c_plot_setEqualAxes(ah);
		
	case 'copy-nocrop-1'
		c_FigurePrinter.copyMultipleToClipboard(s.figHandles,1,false);
	case 'copy-nocrop-2'
		c_FigurePrinter.copyMultipleToClipboard(s.figHandles,2,false);
		
	case 'get'
		% do nothing (used for getting handles)
		s.doBringToFront = false;
	
	case 'getTiler'
		s.doBringToFront = false;
		
		h_vb = findobj(s.figHandles,'-depth',1,'Type','uicontainer');
		
		h = [];
		for i = 1:length(h_vb)
			if c_isFieldAndNonEmpty(h_vb(i),'UserData.c_GUI_Tiler')
				if isempty(h)
					h = h_vb(i).UserData.c_GUI_Tiler;
				else
					h(end+1) = h_vb(i).UserData.c_GUI_Tiler;
				end
			end
		end
		
	otherwise
		error('Unsupported action: %s',s.action);
end

if s.doBringToFront
	for iF = 1:numFigs
		figure(s.figHandles(iF));
	end
end

if ~ismember(s.action,{'getTiler'})
	h = s.figHandles;
end

drawnow;

end


function pos = convertRelativePosToPixelPos(pos,mon)
	if nargin < 2
		mon = 1;
	end
	
	% get monitor position(s)
	persistent mps;
	if isempty(mps)
		prevUnits = get(0,'Units');
		set(0,'Units','pixels');
		mps = get(0,'MonitorPositions');
		set(0,'Units',prevUnits);
	end
	
	assert(isscalar(mon));
	mon = mod(mon-1,size(mps,1))+1;
	mp = mps(mon,:);
	
	bottomOffset = 0;
	isWindows10 = ispc; %TODO: dynamically set
	if mon==1 || isWindows10
		if ispc
			bottomOffset = 40; % assume taskbar is 40 pixels in height
		else
			bottomOffset = 33; %TODO: update offset for non windows platforms
		end
	end
	
	if isWindows10
		insets = [8 8 8 0];
	else
		insets = [0 0 0 0];
	end
	
	leftStart = mp(1) + pos(1)*mp(3) - insets(1);
	width = pos(3)*mp(3) + insets(1) + insets(3);
	height = pos(4)*(mp(4)-bottomOffset) + insets(2) + insets(4);
	bottomStart = mp(2) + mp(4) - height - pos(2)*(mp(4)-bottomOffset) - insets(4);
	
	pos = [leftStart, bottomStart, width, height];
	

end

function testfn()

h = [];
for i=1:3
	h(i) = figure('name',sprintf('Figure %d',i));
	plot(rand(10,3));
end

c_fig_arrange('tile',h,'tileDims',[3,2]);


end