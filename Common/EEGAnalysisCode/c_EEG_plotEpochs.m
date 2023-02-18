function c_EEG_plotEpochs(varargin)
p = inputParser();
p.addRequired('EEG',@isstruct);
p.addParameter('data','data',@(x) ischar(x) || isnumeric(x)); % name of field in EEG struct or raw data
p.addParameter('COI',[],@(x) iscell(x) || isnumeric(x)); % channel(s) of interest (channel labels if cell array), or
	% indices into first dimension of data (for channels, dipoles, ROIs, etc.)
p.addParameter('dataLabels',{},@iscell);
p.addParameter('dataColors',[],@ismatrix);
p.addParameter('dataAlpha',[],@isvector);
p.addParameter('doAutoXLimits',true,@islogical);
p.addParameter('doAutoYLimits',true,@islogical);
p.addParameter('doSoftmaxLimits',false,@islogical);
p.addParameter('autoscaleIgnoreTimespan',[],@isnumeric); % in s, time period to ignore when autoscaling
p.addParameter('doPlotIndividualEpochs',false,@islogical);
p.addParameter('individualEpochOpacity',0.4,@isscalar);
p.addParameter('doPlotBounds',false,@islogical);
p.addParameter('doPlotGMFA',false,@islogical);
p.addParameter('reduceOperation','mean',@(x) ischar(x) || isa(x,'function_handle'));
p.addParameter('doShowLegend',true,@islogical);
p.addParameter('legendLocation','southwest',@ischar);
p.addParameter('doClickableLegend',true,@islogical);
p.addParameter('axis',[],@isgraphics); % only used when not plotting stacked
p.addParameter('parent',[],@isgraphics); %  only used when plotting stacked
p.addParameter('doPlotStacked',false,@islogical);
p.addParameter('boundsMethod','stderr',@(x) ischar(x) || isa(x,'function_handle')); % valid: std, stderr, or custom callback of form f(x,dim)
p.addParameter('groupIndices',{},@iscell);
p.addParameter('groupLabels',{},@iscell);
p.addParameter('xLabel','Time (ms)',@ischar);
p.addParameter('yLabel','Amplitude (uV)',@ischar);
p.addParameter('singleTraceColor',[1 1 1]*0.5,@isnumeric);
p.addParameter('singleTraceAvgColor',[0 0 0],@isnumeric);
p.addParameter('lineWidth',[],@isscalar);
p.addParameter('SNRdBFloor',-30,@isscalar);
p.parse(varargin{:});
s = p.Results;

%% initialization and parsing
EEG = s.EEG;
gi = s.groupIndices;

persistent pathModified;
if isempty(pathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'../ThirdParty/boundedline'));
	addpath(fullfile(mfilepath,'../ThirdParty/clickable_legend'));
	pathModified = true;
end

% data
if ischar(s.data)
	% name of field in EEG struct
	data = c_getField(EEG,s.data);
else
	% raw data
	data = s.data;
end

% COI
if isempty(s.COI)
	% plot all channels
	s.COI = 1:size(data,1);
end
if iscell(s.COI)
	% convert from cell array of channel labels to indices
	s.COI = c_EEG_getChannelIndex(EEG,s.COI);
end

if length(s.COI) > 1 
	if isempty(s.dataColors)
		s.dataColors= c_getColors(length(s.COI));
	else
		assert(isequal(size(s.dataColors),[length(s.COI),3]));
	end
	if isempty(s.dataAlpha)
		s.dataAlpha = ones(1,length(s.COI));
	elseif isscalar(s.dataAlpha)
		s.dataAlpha = repmat(s.dataAlpha,1,length(s.COI));
	else
		assert(length(s.dataAlpha)==length(s.COI));
	end
end

if ischar(s.reduceOperation)
	switch(s.reduceOperation)
		case 'mean'
			s.reduceOperation = @(x,dim) nanmean(x,dim);
		case 'median'
			s.reduceOperation = @(x,dim) nanmedian(x,dim);
		case 'std'
			s.reduceOperation = @(x,dim) nanstd(x,0,dim);
		case 'SNR'
			s.reduceOperation = @(x,dim) abs(nanmean(x,dim)) ./ nanstd(x,0,dim);
			if ismember('yLabel',p.UsingDefaults)
				s.yLabel = 'SNR';
			end
		case 'SNRdB'
			s.reduceOperation = @(x,dim) 20*log10(abs(nanmean(x,dim)) ./ nanstd(x,0,dim));
			if ismember('yLabel',p.UsingDefaults)
				s.yLabel = 'SNR (dB)';
			end
		otherwise
			error('Unrecognized reduce operation: %s',s.reduceOperation);
	end
end

% reduce data to just relevant subset
data = data(s.COI,:,:);


% convert multiple channels to single "channel" GMFA if requested
if s.doPlotGMFA
	if ~isempty(gi)
		error('Not implemented');
	end
	data = s.reduceOperation(data, 3); % apply reduce operation before GMFA to not include single-trial variance in GMFA
	data = c_EEG_calculateGMFA(data);
	s.COI = 1; 
end

% if ~c_EEG_isEpoched(EEG)
% 	error('EEG not epoched.');
% end
	
t = EEG.times;
	
if isempty(gi) || s.doPlotStacked
	% no groups (make all data one group)
	groupColors = s.singleTraceColor;
	groupAvgColors = s.singleTraceAvgColor;
	
	gi{1} = true(1,size(data,3));
else
	if length(s.COI) > 1
		error('Multiple channels and multiple groups not currently supported unless plotting stacked.');
	end
	
	groupColors = c_getColors(length(gi));
	groupAvgColors = groupColors * 0.8;
end
	
if ~s.doPlotStacked
	if isempty(s.axis)
		if isempty(s.parent)
			s.axis = gca;
		else
			s.axis = axes('parent',s.parent);
		end
		prevHold = true;
	else
		assert(isempty(s.parent),'Should not specify both parent and axis');
		prevHold = ishold(s.axis);
	end
else
	if isempty(s.parent)
		s.parent = gcf;
	end
	tmpY = nan(length(t),length(gi));
	stackedHandles = c_plot_stacked(t,tmpY,...
		'parent',s.parent,...
		'xlabel',s.xLabel,...
		'ylabel',s.yLabel,...
		'ylabels',s.groupLabels);
	
	 % axis specification would be ignored when plotting stacked
	assert(isempty(s.axis),'Specify parent instead of axis when plotting stacked');
end

if s.doPlotIndividualEpochs
	if length(s.COI) > 1
		error('Plotting individual epochs for multiple channels not currently supported');
		%TODO
	end
	
	for g=1:length(gi)
		groupData = data(1,:,gi{g});
		if isempty(groupData)
			continue;
		end
	
		if s.doPlotStacked
			s.axis = stackedHandles(g);
		end
		plot(s.axis,t,squeeze(groupData(1,:,:)),...
			'Color',[groupColors(g,:) s.individualEpochOpacity],...
			'LineWidth',0.05);
		hold(s.axis,'on');
	end
end

groupwiseDataToPlotExtrema = [inf, -inf];

if ~isempty(s.autoscaleIgnoreTimespan)
	indicesToIgnore = t>=s.autoscaleIgnoreTimespan(1)*1e3 & t<=s.autoscaleIgnoreTimespan(2)*1e3;
else
	indicesToIgnore = false(size(t));
end

hl = [];
hp = [];
for g=1:length(gi)
	groupData = data(:,:,gi{g});
	
	dataToPlot = s.reduceOperation(groupData,3);
			
	dataToPlotExtrema = extrema(dataToPlot(:,~indicesToIgnore,:),[],2);
	if ~isvector(dataToPlotExtrema) % multichannel data
		dataToPlotExtrema = diag(extrema(dataToPlotExtrema,[],1));
	end
	if groupwiseDataToPlotExtrema(1) > dataToPlotExtrema(1), groupwiseDataToPlotExtrema(1) = dataToPlotExtrema(1); end;
	if groupwiseDataToPlotExtrema(2) < dataToPlotExtrema(2), groupwiseDataToPlotExtrema(2) = dataToPlotExtrema(2); end;
	
	if s.doPlotStacked
		%set(figHandle, 'CurrentAxes', stackedHandles(g));
		s.axis = stackedHandles(g);
	end
	
	if ~s.doPlotBounds
		if length(s.COI)==1
			hl(g) = plot(s.axis,t,squeeze(dataToPlot),'Color',groupAvgColors(g,:),'LineWidth',1.5);
		else
			if all(s.dataAlpha==1)
				set(s.axis,'Colororder',s.dataColors,'NextPlot','replacechildren');
				hl(g,:) = plot(s.axis,t,squeeze(dataToPlot));
			else
				for iC = 1:size(dataToPlot,1)
					hl(g,iC) = plot(s.axis,t,squeeze(dataToPlot(iC,:,:)),'Color',[s.dataColors(iC,:) s.dataAlpha(iC)]);
					if iC==1
						hold(s.axis,'on');
					end
				end
			end
		end
	else
		assert(all(s.dataAlpha==1),'Data alpha not supported when plotting bounds');
		if ischar(s.boundsMethod)
			switch(s.boundsMethod)
				case 'std'
					boundsFn = @(x,dim) nanstd(x,0,dim);
				case 'stderr'
					boundsFn = @(x,dim) nanstd(x,0,dim)./sqrt(sum(~isnan(x), dim));
				otherwise
					error('invalid');
			end
		else
			boundsFn = s.boundsMethod;
		end
		
		groupBounds = boundsFn(groupData,3);
		
		if length(s.COI)==1
			[hl(g), hp(g)] = c_boundedline(t,dataToPlot,groupBounds,'cmap',groupAvgColors(g,:),'nan','gap','alpha',s.axis);
		else
			[hl(g,:), hp(g,:)] = c_boundedline(t,dataToPlot,permute(groupBounds,[2 3 1]),'cmap',s.dataColors,'nan','gap','alpha',s.axis);
		end
		xlim(s.axis,'auto'); % this is for some reason necessary when plotting stacked with bounds, but not other cases
	end
	if ~isempty(s.lineWidth)
		set(hl,'LineWidth',s.lineWidth);
	end
	hold(s.axis,'on');
end


if s.doPlotStacked
	% redo axis labels
	for g = 1:length(gi)
		ylabel(stackedHandles(g),'');
		%set(stackedHandles(g),'XTick',[]);
		set(stackedHandles(g),'YTick',[]);
		ylabel(stackedHandles(g),'');
	end
	tmpY = nan(length(t),length(gi));
	c_plot_stacked(t,tmpY,...
		'xlabel',s.xLabel,...
		'ylabels',s.groupLabels,...
		'existingHandles',stackedHandles);
end

if s.doShowLegend
	if ~isempty(s.groupLabels) && length(s.COI)==1 && ~s.doPlotStacked
		if ~s.doClickableLegend
			legend(s.axis,s.groupLabels,'location',s.legendLocation);
		else
			if ~s.doPlotBounds
				%clickableLegend(s.axis,s.groupLabels,'location',s.legendLocation);
				c_clickableLegend('axis',s.axis,'labels',s.groupLabels,'location',s.legendLocation);
			else
				% specify groups so that bounds and lines are enabled/disabled together
				%clickableLegend(s.axis,[hl hp],s.groupLabels,'groups',[repmat(1:length(hl),1,2)],'location',s.legendLocation);
				c_clickableLegend('axis',s.axis,'obj',arrayfun(@(i) [hl(i) hp(i)],1:length(hl),'UniformOutput',false),'labels',s.groupLabels,'location',s.legendLocation);
			end
		end
	elseif length(s.COI)~=1 
		if ~isempty(s.dataLabels)
			labels = s.dataLabels;
			assert(length(s.dataLabels)==length(s.COI))
		else
			if ~isequal('data',s.data)
				% data isn't necessarily channel data
				labels = arrayfun(@num2str,s.COI,'UniformOutput',false);
			else
				labels = c_EEG_getChannelName(EEG,s.COI);
			end
		end
		if ~s.doClickableLegend
			legend(s.axis,labels,'location',s.legendLocation);
		else
			if s.doPlotStacked
				% group identical legend entries across stacked plots
				groupObj = cell(1,length(labels));
				% assert(size(hl,2)==length(labels));
				hl = handle(hl); % convert from double to objects
				for iL = 1:length(labels)
					groupObj{iL} = hl(:,iL);
				end
				if s.doPlotBounds
					keyboard %TODO: also add hp to groupObj 
				end
			else
				if s.doPlotBounds
					groupObj = arrayfun(@(i) [hl(i) hp(i)],1:length(hl),'UniformOutput',false);
				else
					groupObj = {};
				end
			end
			if ~s.doPlotBounds
				%clickableLegend(s.axis,labels,'location',s.legendLocation);
				c_clickableLegend('axis',s.axis,'obj',groupObj,'labels',labels,'location',s.legendLocation);
			else
				% specify groups so that bounds and lines are enabled/disabled together
				%clickableLegend(s.axis,[hl hp],labels,'groups',[repmat(1:length(hl),1,2)],'location',s.legendLocation);
				c_clickableLegend('axis',s.axis,'obj',groupObj,'labels',labels,'location',s.legendLocation);
			end
		end
		if length(labels) > 10
			legend(s.axis,'hide');
		end
	end
end

if s.doAutoYLimits
	if s.doSoftmaxLimits
		tmpData = s.reduceOperation(data(:,~indicesToIgnore,:),3);

		upperLim = prctile(tmpData,95)*3;
	% 	upperLim = prctile(tmpData(tmpData>=0),90)*3;
		lowerLim= prctile(tmpData,5)*3;
	% 	lowerLim= prctile(tmpData(tmpData<=0),10)*3;
		ylim(s.axis,[lowerLim, upperLim]);
	else
		ylims = c_limits_multiply(groupwiseDataToPlotExtrema,1.1);
		ylim(s.axis,ylims);
	end
end

if s.doAutoXLimits
	xlim(s.axis,[EEG.xmin EEG.xmax]*1e3);
end

if ~s.doPlotStacked
	if ~isempty(s.xLabel)
		xlabel(s.axis,s.xLabel);
	end
	if ~isempty(s.yLabel)
		ylabel(s.axis,s.yLabel);
	end
end

if ~s.doPlotStacked && ~prevHold
	hold(s.axis,'off');
end

end