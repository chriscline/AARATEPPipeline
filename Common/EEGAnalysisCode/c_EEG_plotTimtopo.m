function varargout = c_EEG_plotTimtopo(varargin)
persistent pathModified;
if isempty(pathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'../GUI'));
	addpath(fullfile(mfilepath,'../MeshFunctions'));
	c_EEG_openEEGLabIfNeeded();
	pathModified = true;
end

defaultTraceColors = [0 0 1; 0 1 0; 1 0 0];

p = inputParser();
p.addRequired('EEG',@isstruct);
p.addParameter('TPOI',[],@(x) isvector(x) || ismatrix(x)); % if ismatrix, height should be num trials; units in sec
p.addParameter('TPOIData',[],@isnumeric);
p.addParameter('TPOILabels',{},@iscellstr);
p.addParameter('numMapRows',1,@isscalar); % for many TPOIs, may want to stagger in multiple rows
p.addParameter('xlim',[],@isvector); % in ms
p.addParameter('ylim',[],@isvector);
p.addParameter('doSymmetricYLim', false, @islogical); % can be overridden by custom ylim
p.addParameter('trialAggFn', 'nanmean', @(x) ischar(x) || isa(x, 'function_handle')); % of form @(x, dim)
p.addParameter('doPlotGMFA', false, @islogical);
p.addParameter('doPlotSensorSpace',true,@islogical);
p.addParameter('doPlotSourceSpace','auto',@(x) islogical(x) || (ischar(x) && strcmpi(x,'auto')));
p.addParameter('srcData', [], @isnumeric); % provide as matrix of size [numDipoles, numTimes, numTrials] to use instead of EEG.src.kernel*EEG.data
p.addParameter('srcTPOIData', [], @isnumeric);
p.addParameter('srcKernel', [], @ismatrix); % if not specified, will try to use EEG.src.kernel
p.addParameter('srcSurf', [], @c_mesh_isValid); % if not specified, will try to use EEG.src.meshCortex
p.addParameter('plotButterflyWithSrcROIs', [], @isstruct); % provide as list of ROIs to convert srcData to ROIs, with one line in butterfly plot per ROI
p.addParameter('srcROIData', [], @isnumeric); % only used if plotButterflyWithSrcROIs is nonempty; % assumed to be in units of uA-m
p.addParameter('doPlotInflated',[false true],@(x) islogical(x) && length(x) <= 2);
p.addParameter('doClickToPlotTopoAtTime', true, @islogical);
p.addParameter('topoplotKwargs', {}, @iscell);  % optional extra args to provide to topoplot, e.g. for custom styling
p.addParameter('epochIndices',[],@islogical);
p.addParameter('parent',[],@c_ishandle);
p.addParameter('traceColors',defaultTraceColors,@ismatrix);
p.addParameter('doPlotLineAtTimeZero',true,@islogical);
p.addParameter('doNormalizeMaps',true,@islogical);
p.addParameter('sourceMapDataLimits', 0.25, @isvector);
p.addParameter('doShowColorbars',true,@islogical);
p.addParameter('doInsetButterflyLegend', 'auto', @islogical);
p.addParameter('videoFilename','',@ischar);
p.addParameter('videoFramerate',30,@isscalar); % in fps
p.addParameter('videoDuration',18,@isscalar); % in s
p.addParameter('videoDoInvert',false,@islogical);
p.addParameter('title','',@ischar);
p.parse(varargin{:});
s = p.Results;

EEG = s.EEG;

structOut = struct();

s.doVideo = ~isempty(s.videoFilename);

if isequal(s.doInsetButterflyLegend, 'auto')
	if isempty(s.plotButterflyWithSrcROIs)
		s.doInsetButterflyLegend = ~isempty(EEG.chanlocs);
	else
		s.doInsetButterflyLegend = ~isempty(s.srcSurf) || c_isFieldAndNonEmpty(EEG, 'src.meshCortex');
	end
end

if isempty(s.parent)
	s.parent = gcf;
end

ht = c_GUI_Tiler('parent',s.parent,'title',s.title);
ht.pauseAutoRetiling(); 
ht.numCols = 1;

structOut.ht = ht;

if isempty(s.epochIndices)
	s.epochIndices = true(1,EEG.trials);
end

if isempty(s.srcKernel)
	if c_isFieldAndNonEmpty(EEG, 'src.kernel')
		s.srcKernel = EEG.src.kernel;
	end
end
if isempty(s.srcSurf)
	if c_isFieldAndNonEmpty(EEG, 'src.meshCortex')
		s.srcSurf = EEG.src.meshCortex;
	end
end

if ~islogical(s.doPlotSourceSpace)
	assert(ischar(s.doPlotSourceSpace) && strcmpi(s.doPlotSourceSpace,'auto'));
	% plot source topos if necessary info is available
	if ~isempty(s.srcSurf) && (~isempty(s.srcData) || ~isempty(s.srcKernel))
		s.doPlotSourceSpace = true;
	else
		s.doPlotSourceSpace = false;
	end
else
	if s.doPlotSourceSpace
		if isempty(s.srcSurf) || (isempty(s.srcData) && isempty(s.srcKernel))
			error('Necessary source info not available');
		end
	end
end

if ~isempty(s.plotButterflyWithSrcROIs)
	if isempty(s.srcSurf) || (isempty(s.srcData) && isempty(s.srcKernel))
		error('Necessary source info not available');
	end
	assert(~s.doPlotSensorSpace); % TODO: add support for plotting butterfly as src ROIs but topos in sensor space by separating respective axis labels
	amplitudeAxisLabel = 'Amplitude (pA-m)';
else
	amplitudeAxisLabel = 'Amplitude (\mu{V})';
end

% normalizedAmplitudeAxisLabel = 'Normalized amplitude';
normalizedAmplitudeAxisLabel = 'Normalized ampl';

if ischar(s.trialAggFn)
	switch(s.trialAggFn)
		case {'mean', 'nanmean'}
			s.trialAggFn = @(x,dim) nanmean(x,dim);
		case 'median'
			s.trialAggFn = @(x,dim) nanmedian(x,dim);
		case 'std'
			s.trialAggFn = @(x,dim) nanstd(x,0,dim);
		case 'SNR'
			s.trialAggFn = @(x,dim) abs(nanmean(x,dim)) ./ nanstd(x,0,dim);
			amplitudeAxisLabel = 'SNR';
			normalizedAmplitudeAxisLabel = 'Normalized SNR';
		case 'SNRdB'
			s.trialAggFn = @(x,dim) 20*log10(abs(nanmean(x,dim)) ./ nanstd(x,0,dim));
			amplitudeAxisLabel = 'SNR (dB)';
			normalizedAmplitudeAxisLabel = 'Normalized SNRdB';
		otherwise
			error('Unrecognized trial agg fn: %s',s.trialAggFn);
	end
end

if isempty(s.doPlotInflated) && s.doPlotSourceSpace
	s.doPlotInflated = false;
end

if ~s.doVideo
	doPlotTopos = ~isempty(s.TPOI);
else
	assert(isempty(s.TPOI),'TPOIs not supported with video');
end
if ~doPlotTopos
	assert(isempty(s.TPOIData),'Specified TPOIData without TPOIs');
end

if doPlotTopos
	assert(~isempty(s.TPOI)); %TODO: eventually add code to automatically select a few TPOI if none are specified
	if isvector(s.TPOI)
		s.TPOI = c_vec_makeRowVec(s.TPOI);
	end
	numTimes = size(s.TPOI,2);
	numTrials = EEG.trials;
	if size(s.TPOI,1)==1
		TPOIsWereReplicated = true;
		s.TPOI = repmat(s.TPOI,numTrials,1);
		% would be more efficient to do index finding (below) before repmat...
	else
		TPOIsWereReplicated = false;
		assert(size(s.TPOI,1)==numTrials);
	end
	if isempty(s.TPOIData)
		timeIndices = nan(numTrials,numTimes);
		% could be more efficient if only finding indices for unique times
		for iT = 1:numel(s.TPOI)
			[difft, timeIndices(iT)] = min(abs(EEG.times/1e3-s.TPOI(iT)));
			if difft > 1/EEG.srate*2
				error('No samples found near TPOI %s ms',c_toString(s.TPOI(iT)*1e3));
			end
		end
		s.TPOIData = nan(EEG.nbchan,numTimes,numTrials);
		for iTr = 1:numTrials
			s.TPOIData(:,:,iTr) = EEG.data(:,timeIndices(iTr,:),iTr);
		end
		if isempty(s.srcTPOIData) && s.doPlotSourceSpace && ~isempty(s.srcData)
			s.srcTPOIData = nan(size(s.srcData, 1), numTimes, numTrials);
			for iTr = 1:numTrials
				s.srcTPOIData(:, :, iTr) = s.srcData(:, timeIndices(iTr, :), iTr);
			end
		end
	else
		assert(size(s.TPOIData,1)==EEG.nbchan);
		assert(size(s.TPOIData,2)==numTimes);
		assert(size(s.TPOIData,3)==EEG.trials);
		assert(~isempty(s.srcTPOIData) || isempty(s.srcData) || ~s.doPlotSourceSpace,...
			'Specifying both TPOIData and srcData not currently supported'); % would cause inconsistent behavior in TPOI plotting below
	end
	if isempty(s.TPOILabels)
		s.TPOILabels = arrayfun(@(TPOI) sprintf('%s ms',c_toString(round(TPOI*1e3))),mean(s.TPOI,1),'UniformOutput',false);
	else
		assert(length(s.TPOILabels)==numTimes);
	end
end

latencyTitlesNeedToBePlotted = true;

if ~isempty(s.plotButterflyWithSrcROIs)
	if ~isempty(s.srcData)
		numBTraces = size(s.srcData, 1);
	else
		numBTraces = size(s.srcKernel, 1);
	end
else
	numBTraces = EEG.nbchan;
end

if size(s.traceColors,1) <= 3
	if 1
		if ~isempty(s.plotButterflyWithSrcROIs)
			% base trace colors on ROI seed locations
			args = {[], 'XYZ', s.srcSurf.Vertices([s.plotButterflyWithSrcROIs.Seed],:)};
		else
			% base trace colors on channel locations
			args = {EEG};
		end
		if ~isempty(s.traceColors)
			s.traceColors = c_EEG_getButterflyTraceColors(args{:},'seedColor',s.traceColors);
		else
			s.traceColors = c_EEG_getButterflyTraceColors(args{:});
		end
	else
		s.traceColors = c_getColors(numBTraces);
	end
else
	assert(size(s.traceColors,2)==EEG.nbchan); % could mod repmat here if needed
end

%% plot epochs
if doPlotTopos
	relHeight = 0.5+max(s.doPlotSensorSpace/2+length(s.doPlotInflated)*s.doPlotSourceSpace/3,1);
else
	relHeight = 1;
end

function keepInsetSizeUpdated(h, callbackInfo, ha_ep, ha_epInset, insetShape)
	insetShape(1) = insetShape(1) ...
		* ha_ep.Parent.Position(4)/ha_ep.Parent.Position(3);  % correct for aspect ratio
	% (assumes parent is in non-relative units)
	
	% assume we want legend to always be before time zero
	availX = min(-min(min(ha_ep.XLim), 0) / diff(ha_ep.XLim) * 0.9, 1);
	if insetShape(1) > availX
		insetShape = insetShape / insetShape(1) * availX;
	end
	
	% assume we want legend to always be above y=0
	availY = min(max(max(ha_ep.YLim), 0) / diff(ha_ep.YLim) * 0.7, 1);
	if insetShape(2) > availY
		insetShape = insetShape / insetShape(2) * availY;
	end
	
	anyChildrenVisible = any(arrayfun(@(child) isequal(child.Visible, 'on'), ha_epInset.Children));
	
	if any(insetShape==0)
		if anyChildrenVisible
			if isempty(ha_epInset.UserData)
				ha_epInset.UserData = struct();
			end
			ha_epInset.UserData.hiddenBySize = true;
			set(ha_epInset.Children, 'Visible', 'off'); 
		end
		return;
	elseif ~anyChildrenVisible && c_isFieldAndTrue(ha_epInset, 'UserData.hiddenBySize')
		set(ha_epInset.Children, 'Visible', 'on'); % note this restores all children, not preserving what were already hidden
		ha_epInset.UserData.hiddenBySize = false;
	end
	
	ha_epInset.Position = [ha_ep.Position(1) sum(ha_ep.Position([2 4]))-insetShape(2) insetShape];
end

if s.doInsetButterflyLegend
	hp = ht.add('relHeight', relHeight);
	ha_ep = axes('Parent', hp);
	insetShape = [0.3 0.3];
	ha_epInset = axes('Parent', hp);
	structOut.ha_epInset = ha_epInset;
	hp.SizeChangedFcn = {@keepInsetSizeUpdated, ha_ep, ha_epInset, insetShape};
	ha_ep.addlistener({'XLim', 'YLim'}, 'PostSet', @(varargin) keepInsetSizeUpdated([], [], ha_ep, ha_epInset, insetShape));
	keepInsetSizeUpdated([], [], ha_ep, ha_epInset, insetShape);
	axes(ha_ep);
	uistack(ha_epInset, 'top'); % bring above ha_ep without changing the active axes
	
	% allow caller to manually trigger an update later
	structOut.refreshInsetButterflyLegendSize = @() keepInsetSizeUpdated([], [], ha_ep, ha_epInset, insetShape); 
else
	ha_ep = ht.addAxes('relHeight',relHeight);
end
structOut.ha_ep = ha_ep;

if ~isempty(s.plotButterflyWithSrcROIs)
	numROIs = length(s.plotButterflyWithSrcROIs);
	if isempty(s.srcROIData)
		c_say('Calculating ROI time courses');
		roiData = c_EEG_calculateROIData(EEG,...
			'srcKernel', s.srcKernel,...
			'srcSurf', s.srcSurf,...
			'srcData', s.srcData,...
			'ROIs', s.plotButterflyWithSrcROIs);
		c_sayDone();
	else
		roiData = s.srcROIData;
		assert(size(roiData,1)==numROIs);
		assert(size(roiData,2)==EEG.pnts);
		assert(size(roiData,3)==EEG.trials);
	end
	roiData = c_convertValuesFromUnitToUnit(roiData, 'uA-m', 'pA-m');
	
	if s.doPlotGMFA
		c_EEG_plotEpochs(EEG,...
			'doPlotGMFA', true,...
			'data', roiData,...
			'dataColors', s.traceColors,...
			'dataAlpha', c_if(numROIs < 100, 0.5, 0.2),...
			'reduceOperation', s.trialAggFn,...
			'yLabel', amplitudeAxisLabel,...
			'lineWidth', 1.5,...
			'axis', ha_ep);
		hold(ha_ep, 'on');
		legend(ha_ep, 'GMFA', 'location', 'northeast', 'AutoUpdate', 'off');
	end
	
	traceAlpha = c_if(numROIs < 100, 0.5, 0.3);
	
	c_EEG_plotEpochs(EEG,...
		'data', roiData,...
		'dataColors', s.traceColors,...
		'dataAlpha', traceAlpha,...
		'reduceOperation', s.trialAggFn,...
		'doShowLegend', false,...
		'yLabel', amplitudeAxisLabel,...
		'lineWidth', 1,...
		'axis', ha_ep);
	
	if s.doPlotGMFA
		% move GMFA line above other traces
		ha_ep.Children = [ha_ep.Children(end); ha_ep.Children(1:end-1)]; 
	end
	
	if s.doInsetButterflyLegend
		axes(ha_epInset);
		ROIs = s.plotButterflyWithSrcROIs;
		for iR = 1:length(ROIs)
			ROIs(iR).Color = s.traceColors(iR,:);
		end
		c_plot_cortex(s.srcSurf,...
			'ROIs', ROIs,...
			'ROIAlpha', 1-(1-traceAlpha)/2,...
			'meshFaceColor', [1 1 1],...
			'doShadeSulci', false,...
			'doInflate', s.doPlotInflated(1),...
			'axis', ha_epInset);
	end
else
	if s.doPlotGMFA
		c_EEG_plotEpochs(EEG,...
			'doPlotGMFA', true,...
			'data', EEG.data(:, :, s.epochIndices),...
			'dataColors', s.traceColors,...
			'dataAlpha', 0.5,...
			'reduceOperation', s.trialAggFn,...
			'yLabel', amplitudeAxisLabel,...
			'lineWidth', 1.5,...
			'axis', ha_ep);
		hold(ha_ep, 'on');
		legend(ha_ep, 'GMFA', 'location', 'northeast', 'AutoUpdate', 'off');
	end
	
	c_EEG_plotEpochs(EEG,...
		'data',EEG.data(:,:,s.epochIndices),...
		'dataColors',s.traceColors,...
		'dataAlpha',0.5,...
		'reduceOperation', s.trialAggFn,...
		'doShowLegend', false,...
		'yLabel',amplitudeAxisLabel,... 
		'lineWidth',1,...
		'axis',ha_ep);
	
	if s.doPlotGMFA
		% move GMFA line above other traces
		ha_ep.Children = [ha_ep.Children(end); ha_ep.Children(1:end-1)]; 
	end
	
	if s.doInsetButterflyLegend
		axes(ha_epInset);
		topoplot(1:EEG.nbchan, EEG.chanlocs,...
			'style', 'blank',...
			'emarkercolors', c_mat_sliceToCell(s.traceColors, 1),...
			'plotdisk', 'off');
	end
end


if s.doClickToPlotTopoAtTime && isempty(s.plotButterflyWithSrcROIs)
	ha_ep.ButtonDownFcn = @(obj, evtData) axisButtonDownFcn(obj,evtData, s,EEG,structOut);
end

if ~isempty(s.xlim)
	xlim(ha_ep,s.xlim);
end
if ~isempty(s.ylim)
	ylim(ha_ep,s.ylim);
end

%%
if isempty(s.ylim)
	if ~isempty(s.plotButterflyWithSrcROIs)
		globalYLim = [-1 1]*max(abs(extrema(roiData(:))));
	else
		globalYLim = [-1 1]*max(abs(extrema(EEG.data(:))));
	end
	if s.doSymmetricYLim
		ylim(ha_ep, max(abs(ha_ep.YLim))*[-1 1]);
	end
else
	globalYLim = s.ylim;
end
globalYLim = c_limits_multiply(globalYLim,10);

%% add vertical line at t=0
if s.doPlotLineAtTimeZero
	hold(ha_ep,'on');
	hl = line(ha_ep,[0 0],globalYLim,...
		'LineStyle','-',...
		'LineWidth',1.5,...
		'Color',[0 0 0 0.6]);
	set(get(get(hl(end),'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
	set(hl,'YLimInclude','off');
	ha_ep.Children = [ha_ep.Children(2:end); ha_ep.Children(1)]; % move line below everything else
end


%% add vertical lines at TPOIs
if doPlotTopos
	hold(ha_ep,'on');
	%TODO: add option to scale TPOI indicator height to match extreme values at that time
	
	hl = gobjects(0);

	if TPOIsWereReplicated
		TPOI = s.TPOI(1,:);
	% 	TPOI = TPOI(s.epochIndices,:);
		timesToPlot = unique(TPOI,'rows');
		for iT = 1:length(timesToPlot)
			hl(end+1) = line(ha_ep,[1 1]*timesToPlot(iT)*1e3,globalYLim,...
				'LineWidth',1.5,...
				'Color',[[1 1 1]*0.6 0.5]);
			set(get(get(hl(end),'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
		end

		set(hl,'YLimInclude','off');
		ha_ep.Children = [ha_ep.Children((length(timesToPlot)+1):end); ha_ep.Children(1:length(timesToPlot))]; % move lines below everything else
		ha_TPOI = [];
	else
		ht.ChildrenRelHeights(end) = ht.ChildrenRelHeights(end) - 0.8;
		ha_TPOI = ht.addAxes('relHeight',0.8);

		TPOI = s.TPOI;
		TPOI = TPOI(s.epochIndices,:);
		TPOI = unique(TPOI,'rows');

		c_plot_population(TPOI*1e3,...
			'axis',ha_TPOI,...
			...'style',{'box','scatter'},...
			...'style',{'box'},...
			'style',{c_if(size(TPOI,1) > 5,'box','scatter')},...
			...'boxplotArgs',{'notch','off'},...
			...'boxplotArgs',{'notch','off'},...
			...'boxplotArgs',{'doFill',false},...
			'boxplot_doPlotMean',false,...
			'defaultMultiOffset',1,...
			'defaultMultiWidth',1,...
			'doRotate',true,...
			'ifRotateDoFlip',true,...
			'labels',s.TPOILabels);
		ylim(ha_TPOI,[-0.2 size(TPOI,2)+1.2]);
		ha_TPOI.XLabel.String = ha_ep.XLabel.String;
		ha_ep.XLabel.String = '';
		%ha_ep.XTick = [];
		ha_ep.XTickLabel = '';
		ha_ep.Position([2 4]) = [0 ha_ep.Position(4) + ha_ep.Position(2)];
		ha_TPOI.XLim = ha_ep.XLim;
		ha_TPOI.Position(2) = ha_TPOI.Position(2) + 0.3;
		ha_TPOI.Position(4) = 1 - ha_TPOI.Position(2);

	end
else
	ha_TPOI = [];
end
	
doUseTilerForTPOITitles = true;

%% plot scalp maps
if s.doPlotSensorSpace && doPlotTopos
	sht = c_GUI_Tiler('parent',ht.add('relHeight',s.numMapRows));
 	sht.pauseAutoRetiling();
	sht.numRows = 1;
	ssht = c_GUI_Tiler('parent',sht.add());
	ssht.numRows = s.numMapRows;
	ssht.pauseAutoRetiling();
	ha_scalps = gobjects(0);
	timeOrder = 1:numTimes;
	if s.numMapRows == 2
		% stagger top and bottom rows in order
		timeOrder = timeOrder([1:2:end, 2:2:end]);
	end
	for iT = timeOrder
		if latencyTitlesNeedToBePlotted && doUseTilerForTPOITitles
			args = {'title', s.TPOILabels{timeOrder(iT)}};
		else
			args = {};
		end
		ha_scalps(end+1) = ssht.addAxes(args{:});
		vals = s.trialAggFn(s.TPOIData(:,iT,s.epochIndices),3);
		if s.doNormalizeMaps
			vals = vals / max(abs(vals(:)));
		end
		topoplot(vals,EEG.chanlocs,...
			'whitebk','on',...
			'colormap',parula(),...
			'intrad',0.5,...
			s.topoplotKwargs{:});
		set(ha_scalps(end),'XLim',[-1 1]*0.57,'YLim',[-1 1]*0.6);
		ha_scalps(end).Position = ha_scalps(end).OuterPosition - [0 0 0 c_if(latencyTitlesNeedToBePlotted,0.1,0)];
	end
	if doUseTilerForTPOITitles
		latencyTitlesNeedToBePlotted = false;
	else
		if latencyTitlesNeedToBePlotted
			for iT = 1:numTimes
				title(ha_scalps(end-numTimes+iT),s.TPOILabels{timeOrder(iT)});
			end
			latencyTitlesNeedToBePlotted = false;
		end
	end
	
	c_plot_setEqualAxes(ha_scalps,'axesToSet','c','doForceSymmetric',true);
	
	if ~s.doNormalizeMaps
		if ~isempty(s.ylim)
			set(ha_scalps,'CLim',s.ylim);
		end
	else
		set(ha_scalps,'CLim',[-1 1]);
	end
			
	
	if s.doShowColorbars
		hac = sht.addAxes('relWidth',0.1,'relHeight',0.6);
		if s.doNormalizeMaps
			clabel = normalizedAmplitudeAxisLabel;
		else
			clabel = amplitudeAxisLabel;
		end
		c_plot_colorbar('axis',hac,...
			'linkedAxes',ha_scalps,...
			'doForceSymmetric',true,...
			'clabel',clabel,...
			'FontSize',9);
	end
	ssht.resumeAutoRetiling();
	sht.resumeAutoRetiling();

	structOut.ha_scalps = ha_scalps;
end

%% plot source maps
if s.doPlotSourceSpace && doPlotTopos
	meshCortex = s.srcSurf;
	ha_brains = gobjects(0);
	hac = gobjects(0);
	for iDI = 1:length(s.doPlotInflated)
		sht = c_GUI_Tiler('parent',ht.add());
		sht.pauseAutoRetiling();
		sht.numRows = 1;
		ssht = c_GUI_Tiler('parent',sht.add());
		ssht.numRows = s.numMapRows;
		ssht.pauseAutoRetiling();
		ssht.numRows = s.numMapRows;
		
		timeOrder = 1:numTimes;
		if s.numMapRows == 2
			% stagger top and bottom rows in order
			timeOrder = timeOrder([1:2:end, 2:2:end]);
		end
		
		for iT = timeOrder
			
			% (slightly inefficient since calculated twice if plotting uninflated and inflated)
			
			if isempty(s.srcData) && isempty(s.srcTPOIData)
				if ~ischar(p.Results.trialAggFn) || ~ismember(p.Results.trialAggFn, {'mean', 'nanmean'})
					% note: using non-default trialAggFn. Below function generally assumes a mean-like agg fn 
					%  and may produce unreasonable results with a more exotic function like SNR or dB conversion.
				end
				%TODO: if EEG.src.data available, use above if extracting EEG.data into s.TPOIData
				srcData = c_EEG_applySrcKernel(EEG,...
					'srcKernel', s.srcKernel,...
					'data',s.TPOIData(:,iT,:),...
					'epochIndices',s.epochIndices,...
					'aggFn', {@nanmean, @nanmean, s.trialAggFn},...
					'aggDims',3);
			else
				assert(~isempty(s.srcTPOIData)); % was either provided or should have been calculated above
				srcData = s.trialAggFn(s.srcTPOIData(:, iT, s.epochIndices), 3);
			end
			
			if s.doNormalizeMaps
				srcData = srcData / max(abs(srcData(:)));
				clabel = 'Normalized amplitude';
				clabel = 'Normalized ampl';
			else
				srcData = c_convertValuesFromUnitToUnit(srcData,'uA-m','pA-m');
				clabel = 'Amplitude (pA-m)';
			end
			
			if latencyTitlesNeedToBePlotted && doUseTilerForTPOITitles
				args = {'title', s.TPOILabels{timeOrder(iT)}};
			else
				args = {};
			end
			
			ha_brains(end+1) = ssht.addAxes(args{:});
			htmp = c_plot_cortex(meshCortex,...
				'doInflate',s.doPlotInflated(iDI),...
				'axis',ha_brains(end),...
				'inputUnit',1,...
				'dispUnit',1,...
				'dataLimits', s.sourceMapDataLimits,...
				'data',srcData);
		end	
		
		if doUseTilerForTPOITitles
			latencyTitlesNeedToBePlotted = false;
		else
			if latencyTitlesNeedToBePlotted
				for iT = 1:numTimes
					title(ha_brains(end-numTimes+iT),s.TPOILabels{timeOrder(iT)});
				end
				latencyTitlesNeedToBePlotted = false;
			end
		end

		if s.doShowColorbars
			hac(end+1) = sht.addAxes('relWidth',0.1,'relHeight',0.6);
			c_plot_colorbar('axis',hac(end),...
				'linkedAxes',ha_brains,...
				'doForceSymmetric',true,...
				'clabel',clabel,...
				'FontSize',9);
		end
		
		ssht.resumeAutoRetiling();
		sht.resumeAutoRetiling();
	end
	c_plot_linkViews(ha_brains);
	if s.doShowColorbars
		c_plot_setEqualAxes([ha_brains, hac],'axesToSet','c');
	end
	%camzoom(ha_brains(1),1.35)
	camzoom(ha_brains(1),1.2)
	
	structOut.ha_brains = ha_brains;
end

%%

ht.resumeAutoRetiling();

drawnow;

ha_ep.Position([1 3]) = ha_ep.OuterPosition([1 3]) + [ha_ep.TightInset(1), -sum(ha_ep.TightInset([1 3]))];
if ~isempty(ha_TPOI)
	ha_TPOI.Position([1 3]) = ha_ep.Position([1 3]);
	c_plot_setEqualAxes([ha_ep, ha_TPOI],'axesToSet','x');
end

if s.doInsetButterflyLegend
	keepInsetSizeUpdated([], [], ha_ep, ha_epInset, insetShape);
end

if s.doVideo
	c_fig_arrange('top-half',s.parent,'mon',1); %TODO: debug, delete
	
	%TODO: add support for temporarily "flashing" background at time 0 to indicate stimulation
	% (maybe with finite duration fadeout of flash to indicate ~20 ms span of main artifacts)
	
	sht = c_GUI_Tiler('parent',ht.add());
	sht.numRows = 1;
	spacerWidth = 0.2;
	sht.add('relWidth',spacerWidth); % extra space
	if s.doPlotSensorSpace
		ha_scalp = sht.addAxes();
		ha_scalp.Position = ha_scalp.OuterPosition;
		if ~s.doNormalizeMaps && s.doShowColorbars
			ha_scalp_colorbar = sht.addAxes('relWidth',0.5,'relHeight',0.5);
			c_plot_colorbar(...
				'axis',ha_scalp_colorbar,...
				'clabel',amplitudeAxisLabel,...
				'clim',s.ylim);
		end
		sht.add('relWidth',spacerWidth); % extra space
	end
	if s.doPlotSourceSpace
		ha_src = gobjects(0);
		hh_src = {};
		srcData = nan(size(s.srcSurf.Vertices,1),1);
		
		for iDI = 1:length(s.doPlotInflated)
			ha_src(end+1) = sht.addAxes();
			hh_src{end+1} = c_plot_cortex(s.srcSurf,...
				'doInflate',s.doPlotInflated(iDI),...
				'axis',ha_src(iDI),...
				'inputUnit',1,...
				'dispUnit',1,...
				'dataLimits', s.sourceMapDataLimits,...
				'data',srcData);
		end
		c_plot_linkViews(ha_src);
		camzoom(ha_src(1),1.4*1.4);
		if ~s.doNormalizeMaps && s.doShowColorbars
			
			if isempty(s.srcData)
				if ~ismember(p.Results.trialAggFn, {'mean', 'nanmean'})
					error('Not implemented'); % TODO: change applySrcKernel call below and unit labels as needed for other agg fns
				end

				srcData = c_EEG_applySrcKernel(EEG,...
					'epochIndices',s.epochIndices,...
					'aggDims',3);
			else
				srcData = s.trialAggFn(s.srcData(:, :, s.epochIndices), 3);
			end
			
			srcLims = c_convertValuesFromUnitToUnit([-1 1]*prctile(abs(srcData(:)),99.99),'uA-m','pA-m');
			
			ha_src_colorbar = sht.addAxes('relWidth',0.5,'relHeight',0.5);
			c_plot_colorbar(...
				'axis',ha_src_colorbar,...
				'linkedAxes',ha_src,...
				'clabel','Amplitude (pA-m)',...
				'clim',srcLims);
		end
		sht.add('relWidth',spacerWidth); % extra space
	end
	if s.doNormalizeMaps && s.doShowColorbars
		ha_shared_colorbar = sht.addAxes('relHeight',0.5);
		c_plot_colorbar(...
			'axis',ha_shared_colorbar,...
			'clabel',normalizedAmplitudeAxisLabel,...
			'clim',[-1 1]);
	end
	
	keyboard % adjust window to desired size
	
	fr = c_FigureRecorder('filename',s.videoFilename,...
		'frameRate',s.videoFramerate);
	
	numFrames = floor(s.videoFramerate*s.videoDuration);
	frameTimes = linspace(s.xlim(1),s.xlim(2),numFrames); % in ms
	
	hl = [];
	if isempty(s.ylim)
		tmp = s.trialAggnFn(EEG.data, 3);
		globalYLim = [-1 1]*max(abs(extrema(tmp(:))));
	else
		globalYLim = s.ylim;
	end
	globalYLim = c_limits_multiply(globalYLim,10);
	
	for iT = 1:numFrames
		[~,iiT] = min(abs(EEG.times - frameTimes(iT)));
		
		% draw line on butterfly plot corresponding to current time
		hl = line(ha_ep,[1 1]*frameTimes(iT),globalYLim,...
			'LineWidth',1.5,...
			'Color',[[1 1 1]*0.6 0.5]);
		set(get(get(hl,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
		set(hl,'YLimInclude','off');
		ha_ep.Children = [ha_ep.Children(2:end); ha_ep.Children(1)]; % move lines below everything else
		
		if s.doPlotSensorSpace
			axes(ha_scalp);
			cla(ha_scalp);
			vals = s.trialAggFn(EEG.data(:,iiT,s.epochIndices),3);
			if s.doNormalizeMaps
				vals = vals / max(abs(vals(:)));
			end
			topoplot(vals,EEG.chanlocs,...
				'whitebk','on',...
				'colormap',parula(),...
				'intrad',0.5,...
				s.topoplotKwargs{:});
			set(ha_scalp,'XLim',[-1 1]*0.57,'YLim',[-1 1]*0.6);
			if ~s.doNormalizeMaps
				ha_scalp.CLim = s.ylim;
			else
				ha_scalp.CLim = [-1 1];
			end
		end
		
		if s.doPlotSourceSpace
			if isempty(s.srcData)
				if ~ismember(p.Results.trialAggFn, {'mean', 'nanmean'})
					error('Not implemented'); % TODO: change applySrcKernel call below and unit labels as needed for other agg fns
				end
				srcData = c_EEG_applySrcKernel(EEG,...
					'data',EEG.data(:,iiT,:),...
					'epochIndices',s.epochIndices,...
					'aggDims',3);
			else
				srcData = s.trialAggFn(s.srcData(:, :, s.epochIndices));
			end
			if s.doNormalizeMaps
				srcData = srcData / max(abs(srcData(:)));
			else
				srcData = c_convertValuesFromUnitToUnit(srcData,'uA-m','pA-m');
			end
			
			for iDI = 1:length(s.doPlotInflated)
				hh_src{iDI}.dataSurf.FaceVertexCData = srcData;
				indices = double(abs(srcData) > 0.5*max(abs(srcData)));
				hh_src{iDI}.dataSurf.FaceVertexAlphaData = indices;
			end
			if ~s.doNormalizeMaps
				set(ha_src,'CLim',srcLims);
			else
				set(ha_src,'CLim',[-1 1]);
			end
		end
		
		if s.videoDoInvert
			c_fig_invertColors(s.parent);
			c_fig_setAllBackgroundsToColor([0 0 0],s.parent);
		else
			c_fig_setAllBackgroundsToColor([1 1 1],s.parent);
		end
		
		drawnow;
		fr.captureFrame(s.parent);
		
		if s.videoDoInvert
			c_fig_invertColors();
		end
		
		delete(hl);
		hl = [];
	end
	
	fr.stop()
end

if nargout > 0
	varargout{1} = structOut;
end

end

function axisButtonDownFcn(obj,~,s,EEG, structOut)
persistent processingPreviousClick
if isempty(processingPreviousClick) || ~processingPreviousClick
	processingPreviousClick = true;
	pause(0.5);
	if processingPreviousClick
		% this is a single click
		isDoubleClick = false;
	else
		% this was first click in a double click
		return % response will have been triggered by second click
	end
else
	isDoubleClick = true;
end
processingPreviousClick = false;

if ~isDoubleClick
	return  % do nothing on single click
end
	
coord = obj.CurrentPoint(1,1:2);
clickedTime = coord(1);
c_saySingle('Clicked %s',c_toString(coord));

prevCurrentAx = gca;

if c_isEmptyOrEmptyStruct(obj.UserData) || ~c_isFieldAndNonEmpty(obj.UserData,'EEG_plotTimtopo_interactiveAxis_hf') ...
		|| ~ishandle(obj.UserData.EEG_plotTimtopo_interactiveAxis_hf)
	hf = figure('name','%s interactive breakout');
	ha = axes('parent',hf);
	obj.UserData.EEG_plotTimtopo_interactiveAxis_hf = hf;
	obj.UserData.EEG_plotTimtopo_interactiveAxis_ha = ha;
else
	hf = obj.UserData.EEG_plotTimtopo_interactiveAxis_hf;
	ha = obj.UserData.EEG_plotTimtopo_interactiveAxis_ha;
	figure(hf);
	cla(ha);
end

if c_isFieldAndNonEmpty(obj.UserData,'EEG_plotTimtopo_interactiveAxis_TPOIMarker') ...
		&& ishandle(obj.UserData.EEG_plotTimtopo_interactiveAxis_TPOIMarker)
	delete(obj.UserData.EEG_plotTimtopo_interactiveAxis_TPOIMarker);
end

axes(ha);

[~,iT] = min(abs(EEG.times - coord(1)));


if 1
	% draw line on main axis indicating clicked TPOI
	hl = line(obj,[1 1]*clickedTime,c_limits_multiply(obj.YLim,2),...
		'LineWidth',1.5,...
		'Color',[[1 1 1]*0.4 0.5]);
	obj.UserData.EEG_plotTimtopo_interactiveAxis_TPOIMarker = hl;
end

vals = s.trialAggFn(EEG.data(:,iT,s.epochIndices),3);
if s.doNormalizeMaps
	vals = vals / max(abs(vals(:)));
end

topoplot(vals,EEG.chanlocs,...
	'whitebk','on',...
	'colormap',parula(),...
	'intrad',0.5,...
	s.topoplotKwargs{:});
set(ha,'XLim',[-1 1]*0.57,'YLim',[-1 1]*0.6);

title(sprintf('%s ms',c_toString(round(EEG.times(iT)))));

if ~isequal(prevCurrentAx,ha)
	axes(prevCurrentAx);
	if prevCurrentAx == structOut.ha_ep && c_isFieldAndNonEmpty(structOut, 'ha_epInset')
		% restore inset visibility above ha_ep but don't make it the focus
		uistack(structOut.ha_epInset, 'top');
	end
end
	

end
