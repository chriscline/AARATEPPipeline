function h = c_plot_cortex(varargin)

persistent PathModified;
if isempty(PathModified)
	mfilepath=fileparts(which(mfilename));
	%addpath(fullfile(mfilepath,'../MeshFunctions'));
	addpath(fullfile(mfilepath,'../ThirdParty/FromBrainstorm/anatomy'));
% 	addpath(fullfile(mfilepath,'../ThirdParty/Arrow'));
	PathModified = true;
end

if nargin==0
	testfn();
	return;
end

p = inputParser();
p.addRequired('mesh_cortex',@(x) ischar(x) || isstruct(x));  % path to load, or raw struct
p.addParameter('meshScalar',1,@isscalar); % for converting distance units
p.addParameter('meshFaceColor', [0.7 0.7 0.9], @isvector);
p.addParameter('ROIs',[],@(x) isstruct(x) || isempty(x));
p.addParameter('ROIAlpha',0.4,@isscalar);
p.addParameter('view',[-90 90],@isvector);
p.addParameter('doInflate',false,@islogical);
p.addParameter('doShadeSulci',true,@islogical);
p.addParameter('doCenter',false,@islogical);
p.addParameter('data',[],@isvector);
p.addParameter('sliderData',[],@ismatrix); % e.g. time-varying data
p.addParameter('sliderInitialIndex',1,@isscalar);
p.addParameter('sliderIndexToString',@(x) sprintf('%d',x),@(x) isa(x,'function_handle'));
p.addParameter('sliderExistingHandle',[],@isscalar);
p.addParameter('dataLimits',0.5,@isvector);
p.addParameter('colorLimits',1,@isvector);
p.addParameter('doSymmetricLimits',true,@islogical);
p.addParameter('dataAlpha',1,@isscalar);
p.addParameter('plotTitle','',@ischar);
p.addParameter('axis',[],@ishandle);
p.addParameter('inputUnit','uA-m'); % assuming imaging kernel that converts A-m to V was applied to uV signal
p.addParameter('dispUnit','pA-m');
p.addParameter('doPlotVertexNormals',false,@islogical);
p.addParameter('doInvertVertexNormals',true,@islogical);
p.addParameter('doLabelROIs',false,@islogical);
p.addParameter('ROILabelOrigin', [], @isvector);  % if empty, will use center of mesh
p.addParameter('doUseROISeedsForLabeling',true,@islogical);
p.addParameter('doDoublePlot',false,@islogical); % inflated and non-inflated
p.addParameter('doublePlotParent',[],@isgraphics);
p.addParameter('doShowColorbar',false,@islogical);
% If a scalar, defines a relative minimum. If a tuple, defines absolute min/max limits.
p.parse(varargin{:});
s = p.Results;

if ismember('inputUnit', p.UsingDefaults) && ~isempty(s.data)
	warning('Input units unspecified, assuming %s', s.inputUnit);
end

if ismember('dispUnit', p.UsingDefaults) && ~isempty(s.data)
	warning('Display units unspecified, assuming %s', s.dispUnit);
end

if s.doDoublePlot
	if isempty(s.doublePlotParent)
		s.doublePlotParent = gcf;
	end
	if s.doShowColorbar
		ha(1) = c_subplot('position',[0 0 0.45 1],'parent',s.doublePlotParent);
	else
		ha(1) = c_subplot(1,2,'parent',s.doublePlotParent);
	end
	h(1) = c_plot_cortex(varargin{:},'doDoublePlot',false,'doInflate',s.doInflate,'doShowColorbar',false);
	extraArgs = {};
	if c_isFieldAndNonEmpty(h(1),'slider'),
		extraArgs = {'sliderExistingHandle',h(1).slider};
	end
	if s.doShowColorbar
		ha(2) = c_subplot('position',[0.45 0 0.45 1],'parent',s.doublePlotParent);
	else
		ha(2) = c_subplot(2,2,'parent',s.doublePlotParent);
	end
	h(2) = c_plot_cortex(varargin{:},'doDoublePlot',false,'doInflate',~s.doInflate,'doShowColorbar',false,extraArgs{:});

	if s.doShowColorbar
		ha(3) = c_subplot('position',[0.9 0 0.1 1]);
		ha(3).Visible = 'off';
		caxis(ha(3),[-1 1]*eps);
		hc = colorbar(ha(3));
		hc.Position = [0.925 0.1 0.05 0.8];
		c_plot_setEqualAxes('axisHandles',flipud(ha),'axesToSet','c','doForceSymmetric',s.doSymmetricLimits);
	end
	
	if 0
		hlink = linkprop(flipud(ha(1:2)),{'CameraPosition','CameraUpVector','CameraTarget','CameraViewAngle'});
		axes(ha(1));
		ud = get(gcf,'UserData');
		ud.LinkPropertiesHandle = hlink;
		set(gcf,'UserData',ud);
	else
		c_plot_linkViews(flipud(ha(1:2)));
	end
	return
end


if isempty(s.axis)
	s.axis = gca;
end

%% import / parse cortex mesh

mesh_cortex = s.mesh_cortex;

% load from file if needed
if ischar(mesh_cortex)
	assert(exist(mesh_cortex,'file')>0);
	mesh_cortex = load(mesh_cortex);
	tmpFields = fieldnames(mesh_cortex);
	if length(tmpFields)==1
		% original mesh was saved as a struct, pull out
		mesh_cortex = mesh_cortex.(tmpFields{1}); 
	end % else we assume separate variables representing mesh are already in variable
end
	
% convert from different struct formats to common format
if ~c_isFieldAndNonEmpty(mesh_cortex,'Vertices') || ~c_isFieldAndNonEmpty(mesh_cortex,'Faces');
	error('Unexpected mesh format');
	%TODO: add any necessary conversion code
end

% assume format is now mesh.Vertices, mesh.Faces

mesh_cortex.Vertices = mesh_cortex.Vertices * s.meshScalar;

if s.doShadeSulci
	if ~c_isFieldAndNonEmpty(mesh_cortex,'SulciMap')
		mesh_cortex.VertConn = tess_vertconn(mesh_cortex.Vertices,mesh_cortex.Faces);
		mesh_cortex.SulciMap = tess_sulcimap(mesh_cortex);
	end
else
	if isfield(mesh_cortex,'SulciMap')
		mesh_cortex = rmfield(mesh_cortex,'SulciMap');
	end
end

if s.doInflate
	mesh_cortex = c_smooth_surf(mesh_cortex);
end

if s.doCenter
	bounds = extrema(mesh_cortex.Vertices,[],1);
	origCenter = mean(bounds,2)';
	mesh_cortex.Vertices = bsxfun(@minus,mesh_cortex.Vertices,origCenter);
end

%keyboard

%% ROIs
% format: 
%	ROIs.nodeIndices: 1xN cell array, with each element being a variable length vector of indices into cortex mesh nodes describing ROI membership
%	ROIs.centers: (optional) Nx3 coordinates of ROI centers (auto-calculated if not specified)
%	ROIs.centerIndices (optional), as above, but indices into mesh nodes instead of coordinates
%	ROIs.labels: (optional) cell array of strings
%	ROIs.colors: (optional) Nx3 one color for each ROI

ROIs = s.ROIs;

if ~isempty(ROIs)

	ROIs = c_convertROIs(ROIs,'toFormat','eConnectome');
		
	numROIs = length(ROIs.nodeIndices);

	if ~c_isFieldAndNonEmpty(ROIs,'labels')
		for r=1:numROIs
			ROIs.labels{r} = num2str(r);
		end
	else
		assert(length(ROIs.labels)==numROIs);
	end
end

%% Plotting

prevHold = ishold(s.axis);
hold(s.axis,'on');

plotSurfaceArgs = {...
	'edgeColor','none',...
	'faceAlpha',1,...
	'view',[],...
	'axis',s.axis,...
	'renderingMode',1};

% cortex mesh

if c_isFieldAndNonEmpty(mesh_cortex,'SulciMap')
	h.meshSurf = c_plotSurface(mesh_cortex.Vertices,mesh_cortex.Faces,...
		'nodeData',bsxfun(@times,(2-mesh_cortex.SulciMap)/2, s.meshFaceColor),...
		plotSurfaceArgs{:});
else
	h.meshSurf = c_plotSurface(mesh_cortex.Vertices,mesh_cortex.Faces,...
		'faceColor', s.meshFaceColor,...
		plotSurfaceArgs{:});
end


if ~isempty(ROIs)
	% overlay ROIs

	if ~c_isFieldAndNonEmpty(ROIs,'colors')
		ROIs.colors = ROIColors(numROIs);
	end
	
	colorIsScalar = size(ROIs.colors,2)==1;
	if colorIsScalar
		defaultColor = NaN;
	else
		defaultColor = [0.7 0.7 0.9];
	end

	roiCData = repmat(defaultColor,size(mesh_cortex.Vertices,1),1);
	roiAlpha = zeros(size(mesh_cortex.Vertices,1),1);
	% assume that no one node belongs to more than 1 ROI
	for r=1:numROIs
		roiNodeIndices = ROIs.nodeIndices{r};
		roiCData(roiNodeIndices,:) = repmat(ROIs.colors(r,:),length(roiNodeIndices),1);
		roiAlpha(roiNodeIndices) = s.ROIAlpha;
	end
	
	h.ROIsSurf = c_plotSurface(mesh_cortex.Vertices,mesh_cortex.Faces,...
		'nodeData',roiCData,...
		plotSurfaceArgs{:},...
		...'faceAlpha',roiAlpha,...
		'faceoffsetbias',-0.0002);
	h.ROIsSurf.FaceAlpha = s.ROIAlpha;
	
	if s.doLabelROIs
		%TODO: save ROI label handles in h output struct
		if s.doUseROISeedsForLabeling && c_isFieldAndNonEmpty(ROIs,'centerIndices')
			coords = mesh_cortex.Vertices(ROIs.centerIndices,:);
		else
			coords = nan(numROIs,3);
			for r=1:numROIs
				roiVertices = mesh_cortex.Vertices(ROIs.nodeIndices{r},:);
				[~,index] = min(c_norm(bsxfun(@minus,roiVertices,mean(roiVertices,1)),2,2));
				coords(r,:) = roiVertices(index,:);
			end
		end
		if isempty(s.ROILabelOrigin)
			globalCenter = mean(extrema(mesh_cortex.Vertices),2)';
			s.ROILabelOrigin = globalCenter;
		end
		
		maxDist = max(c_norm(bsxfun(@minus,mesh_cortex.Vertices, s.ROILabelOrigin),2,2));
		centeredCoords = bsxfun(@minus,coords, s.ROILabelOrigin);
		scatter3(s.axis,coords(:,1),coords(:,2),coords(:,3));
		
		for r=1:numROIs
			
			labelCoord = centeredCoords(r,:) / c_norm(centeredCoords(r,:),2); % unit vector
			dist = max(c_norm(bsxfun(@minus,mesh_cortex.Vertices(ROIs.nodeIndices{r},:),s.ROILabelOrigin),2,2));
			labelCoord = labelCoord * (dist + 0.3*maxDist);
			labelCoord = labelCoord + s.ROILabelOrigin;
			
			hl = line(...
				[labelCoord(1) coords(r,1)],...
				[labelCoord(2) coords(r,2)],...
				[labelCoord(3) coords(r,3)],...
				'LineWidth',2,...
				'Parent',s.axis,...
				'Color',[0 0 0 0.5]);
% 			arrow(...
% 				'Start',labelCoords(:),...
% 				'Stop',coords(r,:));
			ht = text(labelCoord(1),labelCoord(2),labelCoord(3),...
				strrep(ROIs.labels{r},'_','\_'),... % with underscores escaped
				'BackgroundColor',[1 1 1 0.6]*0.9,...
				'Parent',s.axis,...
				'HorizontalAlignment','center');
		end
	end
end

%%
if ~isempty(s.data) && ~isempty(s.sliderData)
	error('Should only specify one of data or sliderData');
end

dataMultiplier = c_convertValuesFromUnitToUnit(1,s.inputUnit,s.dispUnit); % note this doesn't work for nonlinear unit conversions (e.g. dB)

if ~isempty(s.sliderData)
	s.sliderData = dataMultiplier*s.sliderData;
	s.data = s.sliderData(:,s.sliderInitialIndex);
else
	s.data = dataMultiplier*s.data;
end

if ~isempty(s.data)
	if isscalar(s.dataLimits)
		if isvector(s.colorLimits) && length(s.colorLimits) == 2
			dataLimits = [min(s.colorLimits) + diff(s.colorLimits)*s.dataLimits inf] * dataMultiplier;
		else
			if all(s.data(:) >= 0)
				dataLimits = [max(s.data(:))*s.dataLimits inf];
			else
				lims = extrema(s.data(:));
				if true
					dataLimits = [max(abs(lims)*s.dataLimits), inf];
				else
					dataLimits = [mean(lims) inf];
				end
			end
		end
	else
		dataLimits = s.dataLimits*dataMultiplier;
	end
	if s.doSymmetricLimits
		dataLimits(3:4) = flip(dataLimits(1:2))*-1;
	end
	if isscalar(s.colorLimits)
		if s.doSymmetricLimits
			colorLimits = [-1 1]*s.colorLimits*max(abs(s.data(:)));
		else
			if max(s.data(:)) < 0
				warning('Not currently set up to handle all negative values');
			end
			colorLimits = [0 1]*s.colorLimits*max(abs(s.data(:)));
		end
	else
		colorLimits = s.colorLimits*dataMultiplier;
	end
	
	%TODO: add code to detect if data is specified per-face and plot that instead
	
	dataAlpha = zeros(size(mesh_cortex.Vertices,1),1);
	indices = isWithinLimits(s.data,dataLimits);
	dataAlpha(indices) = s.dataAlpha;
	
	if all(dataAlpha)
		dataAlpha(end)=0.999; % not sure why this is necessary...
	end
	
	if ~any(dataAlpha)
		dataAlpha(end)=0.0001; % not sure why this is necessary...
	end
	
	dataHandle = c_plotSurface(mesh_cortex.Vertices,mesh_cortex.Faces,...
		'nodeData',s.data,...
		plotSurfaceArgs{:},...
		'faceoffsetbias',-0.0002,...
		'faceAlpha',dataAlpha);
	
	h.dataSurf = dataHandle;
	
	if ~any(isnan(colorLimits))
		caxis(s.axis,colorLimits);
	end
end

if ~isempty(s.sliderData)
	
	h.slider = c_plot_addSlider(...
		'callback',@(v,h) sliderCallback(v,h,s,dataHandle),...
		'InitialValue',1,...
		'MinValue',1,...
		'MaxValue',size(s.sliderData,2),...
		'SliderStep',1/size(s.sliderData,2),...
		'ExistingSliderHandle',s.sliderExistingHandle,...
		'ValueToString',s.sliderIndexToString);
		
end

if s.doPlotVertexNormals && isfield(mesh_cortex,'VertNormals')
	if s.doInflate
		warning('Normals not recomputed to match inflated surface');
	end
	c_mesh_plotVertexNormals(mesh_cortex,s.doInvertVertexNormals);
end

h.axis = s.axis;

if ~isempty(s.plotTitle)
	% use uicontrol() instead of title() to avoid moving title during zoom/pan	
	ha2 = axes(...
		'OuterPosition',get(h.axis,'OuterPosition'),...
		'Position',get(h.axis,'Position'),...
		'HitTest','off');
	title(ha2,s.plotTitle);
	axis(ha2,'off');
	%axes(h.axis);
end

if ~isempty(s.view)
	set(s.axis,'cameraviewanglemode','manual'); % disable zooming before rotating, to minimize unecessary zoom out due to non-orthogonal view
	view(s.axis,s.view);
end

if ~prevHold
	hold(s.axis,'off');
end

end

function sliderCallback(sliderValue,axisHandle,s,dataHandle)

	data = s.sliderData(:,round(sliderValue));
	
	if isscalar(s.dataLimits)
		dataLimits = [max(data(:))*s.dataLimits inf];
	else
		dataLimits = s.dataLimits;
	end
	if s.doSymmetricLimits
		dataLimits(3:4) = flip(dataLimits(1:2))*-1;
	end
	if isscalar(s.colorLimits)
		if s.doSymmetricLimits
			colorLimits = [-1 1]*s.colorLimits*max(data(:));
		else
			colorLimits = [0 1]*s.colorLimits*max(data(:));
		end
	else
		colorLimits = s.colorLimits;
	end
	
	dataAlpha = get(dataHandle(1),'FaceVertexAlphaData');
	indices = isWithinLimits(data,dataLimits);
	dataAlpha(indices) = s.dataAlpha;
	dataAlpha(~indices) = 0;

	set(dataHandle,...
		'FaceVertexCData',data,...
		'FaceVertexAlphaData',dataAlpha);
	
	caxis(axisHandle,colorLimits);
	
end


function indices = isWithinLimits(data,limits)
	% limits specified in pairs of (lower bound, upper bound)
	indices = false(size(data));
	for i=2:2:length(limits)
		indices = indices | (data >= limits(i-1) & data <= limits(i));
	end
end


function cmap = ROIColors(num)
	%adapted from eConnectome 
	if num < 1
		return;
	end
	basecolors = zeros(7,3);
	basecolors(1,:) = [0.0, 0.5, 0.0];
	basecolors(2,:) = [0, 0.6, 0.9];
	basecolors(3,:) = [0.6, 0.42, 0.56];
	basecolors(4,:) = [0.7, 0.5, 0.2];
	basecolors(5,:) = [0.5, 0.5, 1.0];
	basecolors(6,:) = [0.1, 0.9, 0.1];
	basecolors(7,:) = [0.9, 0.4, 0.2];

	% repeat the 7 colors
	cmap = zeros(num,3);
	for i = 1:num
		j = mod(i,7);
		if j == 0
			j = 7;
		end
		cmap(i,:) = basecolors(j,:);
	end
end