function EEG = c_TMSEEG_Preprocess_AARATEPPipeline(varargin)
% c_TMSEEG_Preprocess_AARATEPPipeline - Preprocess raw TMS-EEG data
% 
% Inputs:
%   EEG: input dataset in EEGLab struct format, assumed to not yet have been epoched
%   'pulseEvent': string indicating event type marking each pulse 
%   'outputDir': path to a folder for saving output files. Will be created automatically. If already
%                 exists, the existing dir will be moved to a <outputDir>_old# folder to avoid
%                 overwriting old results
%   'epochTimespan': timespan, in seconds, around which to epoch. Duration should be less than the
%                     inter-trial interval. E.g. [-1 2] epochs 1 s before to 2 s after each pulse
%
% Optional inputs;
%   'outputFilePrefix': string to include as a prefix in every output filename
%   'artifactTimespan': timespan, in seconds, within which to replace data with interpolated values
%   'baselineTimespan': timespan, in seconds, to use for per-epoch baseline subtraction
%   'downsampleTo': frequency, in Hz, to downsample to before most preprocessing stages. Note that
%                    it is critical to pass in data before downsampling to do some artifact 
%                    interpolation prior to this downsampling stage.
%   'bandpassFreqSpan': frequency span, in Hz, for lower and upper bandpass filter cutoffs.
%   'badChannelDetectionMethod': string, method for bad channel detection
%   'badChannelThreshold': scalar, threshold at which to classify a channel as bad or good. Exact
%                           meaning of this threshold depends on the badChannelDetectionMethod
%   'SOUNDlambda': lambda regularization parameter used in SOUND
%   'initialEyeComponentThreshold': threshold for rejecting eye-related ICs during early eye-blink 
%						rejection stage. Set to 1 or greater to skip early eye IC rejection stage.
%   'leadFieldPath': path to lead field file or lead field matrix itself to be used by SOUND. If 
%                     empty, SOUND will use a template lead field
%   'doDecayRemovalPerTrial': whether to do decay fitting and removal partially on a per-trial basis
%                              (true) or to subtract the exact same decay timecourse from every 
%                              trial (false)
%   'ICAType': string, method of ICA to be used, as referenced in c_EEG_ICA
%   'stimMuscleComponentThreshold': scalar, threshold over which to classify ICs as TMS-induced 
%                                    muscle artifact
%   'onOverRejection': string, what to do if too many components are rejected.
%   'doDebug': bool, whether to keep intermediate results and generate additional plots
%   'doPlotFinalTimtopo': bool, whether to generate final timtopo plot after preprocessing
%   'maximizePlotsToMonitor': which monitor index on which to show debug plots
%   'plotXLim': timespan, in seconds, for final and debug timtopo plots
%   'plotTPOIs': time-points of interest, in seconds, for final and debug timtopo plots (e.g. 
%                 typical TEP latencies)
%   'plotChans': channels of interest, either as a cell list of labels or vector of channel indices,
%                 to be included in debug erpimage plots.

%% add dependencies to path
persistent pathModified
if isempty(pathModified)
	mfilepath = fileparts(which(mfilename));
	addpath(fullfile(mfilepath, './Common'));
	addpath(fullfile(mfilepath, './Common/EEGAnalysisCode'));
	addpath(fullfile(mfilepath, './Common/GUI'));
	c_EEG_openEEGLabIfNeeded();
	pathModified = true;
end

%% parse inputs
%defaultTPOIs = [15 25 45 60 95 115 180 280]*1e-3;
defaultTPOIs = [25 33 43 55 90 135 250]*1e-3;

p = inputParser();
p.addRequired('EEG', @isstruct);
p.addParameter('pulseEvent', '', @ischar);
p.addParameter('outputDir', '', @ischar);
p.addParameter('outputFilePrefix', 'PreprocessedResults', @ischar);
p.addParameter('epochTimespan', [], @c_isSpan);
p.addParameter('artifactTimespan', [-0.002, 0.012], @c_isSpan);
p.addParameter('baselineTimespan', [-0.5 -0.01], @c_isSpan);
p.addParameter('downsampleTo', 1000, @isscalar);
p.addParameter('bandpassFreqSpan', [1 200], @c_isSpan);
p.addParameter('badChannelDetectionMethod', 'TESA_DDWiener_PerTrial', @ischar);
p.addParameter('badChannelThreshold', 10, @isscalar);
p.addParameter('initialEyeComponentThreshold', 0.9, @isscalar);
p.addParameter('SOUNDlambda', 10^-1.5, @isscalar);
p.addParameter('leadFieldPath', '', @(x) ischar(x) || ismatrix(x));  % used by SOUND
p.addParameter('doDecayRemovalPerTrial', true, @islogical);
p.addParameter('ICAType', 'fastica', @ischar);
p.addParameter('stimMuscleComponentThreshold', 8, @isscalar);
p.addParameter('onOverRejection', 'pause', @ischar);
p.addParameter('doPostICAArtifactInterpolation', false, @islogical);
p.addParameter('doDebug', false, @islogical);
p.addParameter('doPlotFinalTimtopo', true, @islogical);
p.addParameter('maximizePlotsToMonitor', 2, @isschar);
p.addParameter('plotXLim', [-0.1 0.35], @c_isSpan);
p.addParameter('plotTPOIs', defaultTPOIs, @isnumeric);
p.addParameter('plotChans', {'Fz', 'Pz'}, @(x) iscellstr(x) || isnumeric(x));
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;

md = struct();
md.pipelineVersion = '2.0.1';

% check for required named arguments
assert(~isempty(s.pulseEvent), 'Pulse event must be specified');
assert(~isempty(s.outputDir),'Output directory must be specified');
assert(~isempty(s.epochTimespan), 'Epoch timespan must be specified');

if s.doDebug
    intermediateEEGs = {};
    intermediateLabels = {};
end


%% make sure no pulses are unexpectedly close together
EEG = c_TMSEEG_handleBurstEvents(EEG,...
	'pulseEvent', s.pulseEvent,...
	'method', 'error',...
	'burstMaxIPI', max(abs(s.epochTimespan)));

%% make output directory
assert(~isempty(s.outputDir),'Output directory must be specified');

if c_exist(s.outputDir,'dir')
	% if outputDir already exists, assume it has old results that we should
	%  move somewhere else rather than deleting / ovewriting
	listing = dir([s.outputDir '_old*']);
	existingDirs = arrayfun(@(listItem) fullfile(listItem.folder, listItem.name), listing, 'UniformOutput',false);
	movePrevOutputTo = c_str_makeUnique(existingDirs, [s.outputDir '_old']);
	movefile(s.outputDir, movePrevOutputTo);
	pause(1); % give time for move to process before making dir again below
	c_saySingle('Moved previous output to %s',...
		c_path_convert(movePrevOutputTo, 'makeRelativeTo', fileparts(s.outputDir)));
end

if ~c_exist(s.outputDir,'dir')
	c_saySingle('Making output directory at %s', s.outputDir);
	mkdir(s.outputDir);
end

%% epoch
c_say('Epoching');
fn = @() pop_epoch(EEG, {s.pulseEvent},s.epochTimespan);
if true
	[~,EEG] = evalc('fn()');
else
	EEG = fn();
end
c_sayDone('Extracted %d epochs', EEG.trials);

%     if s.doDebug
%         intermediateEEGs{end+1} = EEG;
%         intermediateLabels{end+1} = 'Epoched';
%     end

%% interpolate artifact timespan
c_say('Interpolating artifact timespan');
EEG = c_EEG_ReplaceEpochTimeSegment(EEG,...
	'timespanToReplace', s.artifactTimespan,...
	'method', 'ARExtrapolation',...
	'prePostFitDurations', [20 20]*1e-3);
c_sayDone();

%     if s.doDebug
%         intermediateEEGs{end+1} = EEG;
%         intermediateLabels{end+1} = 'Artifact interpolated';
%     end

%% downsample
if EEG.srate > s.downsampleTo
	c_say('Downsampling to %.1f Hz', s.downsampleTo);
	EEG = pop_resample(EEG, s.downsampleTo);
	c_sayDone();

%         if s.doDebug
%             intermediateEEGs{end+1} = EEG;
%             intermediateLabels{end+1} = 'Downsampled';
%         end
end

%% baseline correct
baselineTimespan = s.baselineTimespan;
baselineTimespan(2) = min(baselineTimespan(2), s.artifactTimespan(1));
tIndices = EEG.times >= baselineTimespan(1)*1e3 & EEG.times < baselineTimespan(2)*1e3;
toSubtract = nanmean(EEG.data(:, tIndices, :), 2);
EEG.data = EEG.data - toSubtract;

if s.doDebug
	intermediateEEGs{end+1} = EEG;
	intermediateLabels{end+1} = 'Baseline subtracted';
end

%% High-pass filtering
c_say('Highpass filtering')
timeToExtend = 0.5;
maxTimeToExtend = min(abs(s.epochTimespan - s.artifactTimespan*3));
timeToExtend = min(timeToExtend, maxTimeToExtend);
EEG = c_TMSEEG_applyModifiedBandpassFilter(EEG,...
	'piecewiseTimeToExtend', timeToExtend,...
	'lowCutoff', s.bandpassFreqSpan(1),...
	'artifactTimespan', s.artifactTimespan*3);
c_sayDone();
if s.doDebug
	intermediateEEGs{end+1} = EEG;
	intermediateLabels{end+1} = 'High-pass filtered';
end

%% basic channel rejection
doReplaceBadChanImmediately = true;

[EEG, misc] = c_TMSEEG_detectBadChannels(EEG,...
	'detectionMethod', s.badChannelDetectionMethod,...
	'artifactTimespan', s.artifactTimespan*2,...
	'threshold', s.badChannelThreshold,...
	'replaceMethod', c_if(doReplaceBadChanImmediately, 'interpolate', 'none'),...
	'doPlot', true);

badChannels = misc.badChannelIndices;

title('Early channel rejection');
c_FigurePrinter.copyToFile(fullfile(s.outputDir, [s.outputFilePrefix '_QC_EarlyChannelRejection.png']),...
	'magnification', 2, 'doTransparent', false);
close(misc.hf);

md.earlyRejectedChannels = badChannels;

if s.doDebug
	if ~isempty(badChannels)
		if doReplaceBadChanImmediately
			intermediateEEGs{end+1} = EEG;
		else
			intermediateEEGs{end+1} = pop_select(EEG, 'nochannel', badChannels);
		end
		intermediateLabels{end+1} = 'After channel rejection';
	else
		intermediateEEGs{end+1} = EEG;
		intermediateLabels{end+1} = '(After channel rejection)';
	end
	tmpEEG = [];
end

%% Initial eye-blink removal
% Note: do this prior to SOUND, since SOUND tends to make eye blink topographies look more "brain-like" in a way
%  that makes them more difficult to reject later.

if s.initialEyeComponentThreshold < 1
	c_say('Rereferencing');
	EEG = pop_reref(EEG, []);
	c_sayDone();
	
	c_say('Running early ICA for eye artifacts');
	EEG = c_EEG_ICA(EEG, 'method', 'fastica');
	c_sayDone();
	
	c_say('Labeling ICs using ICLabel');
	[EEG, misc] = c_TMSEEG_runICLabel(EEG,...
		'eyeComponentThreshold', s.initialEyeComponentThreshold,...
		'muscleComponentThreshold', nan,...
		'brainComponentThreshold', nan,...
		'otherComponentThreshold', nan,...
		'doPlot', true,...
		'doRejection', false);
	c_sayDone();

	md.eyeICA_numComp = length(misc.rejectComponents);
	md.eyeICA_numRejComp = sum(misc.rejectComponents);

	if true
		figure(misc.hf);
		c_FigurePrinter.copyToFile(fullfile(s.outputDir, [s.outputFilePrefix, '_QC_EyeICA_ClassifiedComponents.png']),...
			'magnification', 2,...
			'doTransparent', false);
		close(misc.hf);
	end

	if  md.eyeICA_numRejComp > 0
		c_say('Rejecting %d/%d components', md.eyeICA_numRejComp, md.eyeICA_numComp);
		if false
			EEG = pop_subcomp(EEG, find(misc.rejectComponents));
		else
			compproj_toRemove = EEG.icawinv(:, misc.rejectComponents) * eeg_getdatact(EEG, 'component', find(misc.rejectComponents), 'reshape', '2d');
			compproj_toRemove = reshape(compproj_toRemove, size(compproj_toRemove, 1), EEG.pnts, EEG.trials);
			if false
				EEG_a = pop_subcomp(EEG, find(misc.rejectComponents));
				EEG_b = EEG;
				EEG_b.data = EEG_b.data - compproj_toRemove;
				c_EEG_plotRawComparison({EEG_a, EEG_b}, 'descriptors', {'pop_subcomp', 'custom subcomp'});
				EEG_c = EEG;
				EEG_c.data = EEG_b.data - EEG_a.data;
				pop_eegplot(EEG_c, 1, 1, 0);
			end
			EEG.data = EEG.data - compproj_toRemove;
		end
		c_sayDone();
	end
	
	if s.doDebug
		intermediateEEGs{end+1} = EEG;
		intermediateLabels{end+1} = sprintf('Eye components%s removed', c_if(md.eyeICA_numRejComp > 0, '', ' (not)'));
	end
else
	c_saySingle('Skipping early eye component rejection stage.')
end


if true
	% save EEG prior to SOUND for some analyses
	outputPath = fullfile(s.outputDir, [s.outputFilePrefix '_preSOUND.mat']);
	c_say('Prior to ICA rejection, saving results to %s', outputPath);
	save(outputPath, 'EEG', 'md');
	c_sayDone();
end

%% SOUND

c_say('Running SOUND');
EEG = c_TMSEEG_runSOUND(EEG,...
	'doRereferenceBeforeSOUND', false,...
	'replaceChannels', badChannels,...
	'lambda', s.SOUNDlambda,...
	'leadFieldPath', s.leadFieldPath);
c_sayDone();

if s.doDebug
	intermediateEEGs{end+1} = EEG;
	intermediateLabels{end+1} = 'After SOUND';
end

if true
    % save EEG prior to component rejection to allow different component rejection choices later
    outputPath = fullfile(s.outputDir, [s.outputFilePrefix '_preDecayRemoval.mat']);
    c_say('Prior to ICA rejection, saving results to %s', outputPath);
    c_save(outputPath, 'EEG', 'md');
    c_sayDone();
end

%% decay fitting and removal
[EEG, misc] = c_TMSEEG_fitAndRemoveDecayArtifact(EEG,...
	'artifactTimespan', s.artifactTimespan,...
	'trialAggMethod_timeCourseRemoval', c_if(s.doDecayRemovalPerTrial, 'none', 'mean'),...
	'aggTrimPercent', 10,...
	'doPlot', true);

figure(misc.hf);
c_FigurePrinter.copyToFile(fullfile(s.outputDir, [s.outputFilePrefix '_QC_DecayFitAndRemoval.png']), 'magnification', 2, 'doTransparent', false);
close(misc.hf);

md.didRemoveDecay = misc.didRemoveDecay;

if s.doDebug
	intermediateEEGs{end+1} = EEG;
	intermediateLabels{end+1} = 'After decay removal';
end

%% interpolate artifact timespan (to remove any large decay residuals in artifactTimespan)
c_say('Interpolating artifact timespan');
EEG = c_EEG_ReplaceEpochTimeSegment(EEG,...
	'timespanToReplace', s.artifactTimespan,...
	'method', 'ARExtrapolation',...
	'prePostFitDurations', [20 20]*1e-3);
c_sayDone();

if s.doDebug
	intermediateEEGs{end+1} = EEG;
	intermediateLabels{end+1} = 'Artifact interpolated';
end

%% notch
c_say('Notch filtering');
if false
	EEG = pop_eegfiltnew(EEG, 58, 62, 2*EEG.srate, 1);
else
	EEG = c_EEG_filter_butterworth(EEG, [58 62], 'type', 'bandstop');
end
c_sayDone();

%% ICA
c_say('Running ICA');
EEG = c_EEG_ICA(EEG, 'method', s.ICAType);
c_sayDone();

c_say('Labeling ICs using ICLabel');
[EEG, misc] = c_TMSEEG_runICLabel(EEG,...
    'doPlot', true,...
    'doRejection', false);
c_sayDone();

% EEG.reject.gcompreject should have been set to rejectComponents inside c_TMSEEG_runICLabel

if s.doDebug
    tmpEEG = pop_subcomp(EEG,find(misc.rejectComponents));
    intermediateEEGs{end+1} = tmpEEG;
    intermediateLabels{end+1} = 'After ICA + ICLabel';
end

% inspired by tesa_compselect, classify as TMS-evoked muscle if very localized to short latency response
tmsMuscleWinTimespan = [11 30]*1e-3; % in s
icaact = eeg_getica(EEG);
numComps = size(EEG.icaweights, 1);
tmsMuscleRatio = nan(numComps, 1);
for iC = 1:numComps
    indicesInWin = EEG.times >= tmsMuscleWinTimespan(1)*1e3 & EEG.times < tmsMuscleWinTimespan(2)*1e3;
    assert(any(indicesInWin));
    muscleScore = abs(mean(icaact(iC, :, :), 3));
    winScore = mean(muscleScore(:, indicesInWin), 2);
    tmsMuscleRatio(iC) = winScore / mean(muscleScore);
end
toRejectForMuscle = tmsMuscleRatio > s.stimMuscleComponentThreshold;

numNewRejected = sum(~misc.rejectComponents & toRejectForMuscle);
if numNewRejected > 0
    c_saySingle('Marked %d additional components for rejection as TMS-induced muscle artifacts');
    misc.rejectComponents = misc.rejectComponents | toRejectForMuscle;
    EEG.reject.gcompreject = misc.rejectComponents;
    didRejectExtra = true;
    
    % re-plot components after changing rejection labels
    close(misc.hf);
    pop_viewprops(EEG, 0, 1:size(EEG.icawinv, 2), {}, {}, 0, 'ICLabel');
    misc.hf = gcf;
else
    didRejectExtra = false;
end

if sum(~misc.rejectComponents) < 4
    % very small number of components remain after rejection
	msg = sprintf('Only %d/%d components remain after rejection', sum(~misc.rejectComponents), length(misc.rejectComponents));
    switch(s.onOverRejection)
		case 'error'
			error('%s', msg);
		case 'warn'
			warning('%s', msg);
		case 'pause'
			c_say('%s. Pausing', msg);
			keyboard
			c_sayDone();
		otherwise
			error('Not implemented');
	end
end

md.ICA_numComp = length(misc.rejectComponents);
md.ICA_numRejComp = sum(misc.rejectComponents);

if true
    % save EEG prior to component rejection to allow different component rejection choices later
    outputPath = fullfile(s.outputDir, [s.outputFilePrefix '_preICARejection.mat']);
    c_say('Prior to ICA rejection, saving results to %s', outputPath);
    c_save(outputPath, 'EEG', 'md');
    c_sayDone();
end

if true
    figure(misc.hf);
    c_FigurePrinter.copyToFile(fullfile(s.outputDir, [s.outputFilePrefix '_QC_ClassifiedComponents.png']), 'magnification', 2, 'doTransparent', false);
    close(misc.hf);
end

c_say('Rejecting %d/%d components', md.ICA_numRejComp, md.ICA_numComp);
EEG = pop_subcomp(EEG,find(misc.rejectComponents));
c_sayDone();

if s.doDebug
    intermediateEEGs{end+1} = EEG;
    if didRejectExtra
        intermediateLabels{end+1} = 'After ICA + ICLabel + Extra';
    else
        intermediateLabels{end+1} = 'After ICA + ICLabel (+ Extra)';
    end
end

%% interpolate again
if s.doPostICAArtifactInterpolation
	c_say('Interpolating artifact timespan');
	EEG = c_EEG_ReplaceEpochTimeSegment(EEG,...
		'timespanToReplace', s.artifactTimespan,...
		'method', 'ARExtrapolation',...
		'prePostFitDurations', [20 20]*1e-3);
	c_sayDone();
end

%% low-pass
c_say('Lowpass filtering');
EEG = c_EEG_filter_butterworth(EEG, [0 s.bandpassFreqSpan(2)]);
c_sayDone();

if s.doDebug
    intermediateEEGs{end+1} = EEG;
    intermediateLabels{end+1} = 'Filtered';
end

%% rereference
c_say('Rereferencing');
EEG = pop_reref(EEG, []);
c_sayDone();

if s.doDebug
    intermediateEEGs{end+1} = EEG;
    intermediateLabels{end+1} = 'Rereferenced';
end

%% save output
outputPath = fullfile(s.outputDir, [s.outputFilePrefix '.mat']);
c_say('Saving results to %s', outputPath);
c_save(outputPath, 'EEG', 'md');
c_sayDone();

%% plot
if s.doPlotFinalTimtopo
	c_say('Plotting final timtopo');
	outputPath = fullfile(s.outputDir, [s.outputFilePrefix '_Plot_TEPTimtopo.png']);
	hf = figure;
	tmp = c_EEG_plotTimtopo(EEG,...
		'doShowColorbars', false,... 
		'doPlotGMFA', true,...
		'TPOI', s.plotTPOIs,...
		'xlim', s.plotXLim*1e3);
	hf.Position = [50 50 600 400];
	c_FigurePrinter.copyToFile(outputPath,...
		'doCrop', true,...
		'doTransparent', false,...
		'magnification', 2);
	close(hf);
	c_sayDone();
end

%%
if s.doDebug
    plotTEPComparison(s, intermediateEEGs, intermediateLabels);
    
    outputPath = fullfile(s.outputDir, [s.outputFilePrefix '_Debug_IntermediateTEPs.png']);
    hf = gcf;
    c_fig_arrange('maximize', hf, 'monitor', s.maximizePlotsToMonitor);
    c_FigurePrinter.copyToFile(outputPath, 'magnification', 2, 'doTransparent', false);
    close(hf);
	
	if ~isempty(s.plotChans)
		plotERPImComparison(s, intermediateEEGs, intermediateLabels);

		outputPath = fullfile(s.outputDir, [s.outputFilePrefix '_Debug_IntermediateERPIms.png']);
		hf = gcf;
		c_fig_arrange('maximize', hf, 'monitor',  s.maximizePlotsToMonitor);
		c_FigurePrinter.copyToFile(outputPath, 'magnification', 2, 'doTransparent', false);
		close(hf);
	end
end

end

function plotTEPComparison(s, EEGs, datasetLabels)
c_say('Plotting TEP comparison');
hf = figure;
ht = c_GUI_Tiler();

ht.pauseAutoRetiling();
for iEEG = 1:length(EEGs)
    tmp = c_EEG_plotTimtopo(EEGs{iEEG},...
		'doShowColorbars', false,...
        'TPOI', s.plotTPOIs,...
		'doPlotGMFA', true,...
        'xlim', [-100 350],...
        'parent', ht.add(),...
		'doSymmetricYLim', true,...
        'title', datasetLabels{iEEG});
end

if length(EEGs) < 4
    hf.Position = [50 50 700*length(EEGs) 600];
    ht.numRows = 1;
else
    c_fig_arrange('maximize', hf, 'monitor',  s.maximizePlotsToMonitor);
end
ht.resumeAutoRetiling();

c_sayDone();
end

function plotERPImComparison(s, EEGs, datasetLabels)
c_say('Plotting ERPImage comparison');
hf = figure;
ht = c_GUI_Tiler();

ht.pauseAutoRetiling();
for iEEG = 1:length(EEGs)
	sht = c_GUI_Tiler('parent', ht.add(), 'title', datasetLabels{iEEG}, 'numRows', 1);
	has = gobjects(0);
	for iCh = 1:length(s.plotChans)
		if iscellstr(s.plotChans) && ~ismember(s.plotChans{iCh}, {EEGs{iEEG}.chanlocs.labels})
			ha = sht.addAxes(); % placeholder
		else
			ha = sht.addAxes();
			has(end+1) = ha;
			c_EEG_plotERPImage(EEGs{iEEG},...
				'COI', s.plotChans(iCh),...
				'axis', ha);
			xlim(ha, [-100 350]);
		end
		if iscellstr(s.plotChans)
			title(ha, sprintf('Chan %s', s.plotChans{iCh}));
		else
			title(ha, sprintf('Chan %d', s.plotChans(iCh)))
		end
	end
	ha = sht.addAxes('relWidth', 0.3, 'relHeight', 0.5);
	ignoreTimeIndices = EEGs{iEEG}.times > s.artifactTimespan(1)*2*1e3 & EEGs{iEEG}.times < s.artifactTimespan(2)*2*1e3; 
	c_plot_colorbar(...
		'axis', ha,...
		'clim', [-1 1]*max(abs(extrema(reshape(mean(EEGs{iEEG}.data(:, ~ignoreTimeIndices, :), 3), 1, []))))*2,...
		'linkedAxes', has,...
		'doForceSymmetric', true,...
		'clabel', 'Amplitude (\mu{V})');
	
end

if length(EEGs) < 4
    hf.Position = [50 50 700*length(EEGs) 600];
    ht.numRows = 1;
else
    c_fig_arrange('maximize', hf, 'monitor',  s.maximizePlotsToMonitor);
end
ht.resumeAutoRetiling();

c_sayDone();
end
