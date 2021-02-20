function c_plot_colorSwatches(varargin)
if nargin == 0, testfn(); return; end
p = inputParser();
p.addRequired('colors',@ismatrix);
p.addParameter('labels',{},@iscellstr);
p.addParameter('parent',[],@c_ishandle);
p.addParameter('maxNumRows',10,@isscalar);
p.addParameter('swatchSize',15,@isscalar);
p.addParameter('fontWeight','normal',@ischar);
p.addParameter('orientation','vertical',@ischar);
p.addParameter('rowHeight', -1, @isscalar);
p.addParameter('labelsMayHaveSubscripts', [], @islogical);
p.parse(varargin{:});
s = p.Results;

persistent p_pathModified
if isempty(p_pathModified)
	c_GUI_initializeGUILayoutToolbox();
	p_pathModified = true;
end

assert(size(s.colors,2)==3);
numColors = size(s.colors,1);

if isempty(s.labels)
	s.labels = cell(1,numColors);
	for iC = 1:numColors
		s.labels{iC} = sprintf('%d: %s',iC,c_toString(s.colors(iC,:),'precision',2));
	end
else
	assert(length(s.labels)==size(s.colors,1));
end

if isempty(s.parent)
	s.parent = figure('name','Color swatches');
end

if 1
	hb = uix.Grid('Parent',s.parent);
	for iC = 1:numColors
		container = uix.HBox('Parent', hb);
		uix.Empty('Parent', container);
		c_GUI_ColorIndicator(...
			'Parent',container,...
			'Color',s.colors(iC,:),...
			'IndicatorSize',[1 1]*s.swatchSize,...
			'LabelFontWeight',s.fontWeight,...
			'LabelMayHaveSubscripts',c_if(isempty(s.labelsMayHaveSubscripts), any(c_str_matchRegex(s.labels,'_')), s.labelsMayHaveSubscripts),...
			'Label',s.labels{iC});
		uix.Empty('Parent', container);
		set(container, 'Widths', [-0.1 -1 -0.1]);
	end
	numRows = min(numColors,s.maxNumRows);
	numCols = ceil(numColors / numRows);
	numRows = ceil(numColors / numCols);
	set(hb,'Heights',repmat(s.rowHeight,1,numRows),'Widths',repmat(-1,1,numCols));
else
	ha = axes('parent',s.parent);
	for iC = 1:numColors
		patch(ha,[0 1 1 0],[0 0 1 1],s.colors(iC,:));
		hold on;
	end
	legend(ha,s.labels,...
		'location','westoutside',...
		'Orientation',s.orientation,...
		'FontSize',s.swatchSize/2)
	legend(ha,'boxoff');
		
	axis(ha,'off');
	xlim(ha,[3 4]);
end
	

end

function testfn()
colors = c_getColors(12);

c_plot_colorSwatches(colors);

end