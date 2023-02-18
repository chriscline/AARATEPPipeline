function [EEG, misc] = c_TMSEEG_prepareForPreprocessing(varargin)
%% this function does several miscellaneous data input tasks to prepare for other preprocessing
% (implemented here to not duplicate this common code in multiple dataset-specific analysis scripts)
% Main steps include:
% - (If needed) Load data 
% - (If needed) Infer pulse event based on most frequent event
% - (If needed) Infer reasonable epoch timespan (not yet implemented)
% - (If needed) Concatenate multiple datasets into one EEG struct
%	- (If needed) label each dataset prior to concatenation to allow later identification of original dataset


c_EEG_openEEGLabIfNeeded();

%% parse inputs

p = inputParser();
p.addParameter('inputFilePaths', '', @(x) ischar(x) || iscellstr(x));
p.addParameter('inputEEGs',[],@(x) isstruct(x) || iscell(x));
p.addParameter('inputDatasetLabels', 'auto', @(x) ischar(x) || iscellstr(x));
p.addParameter('pulseEvent', 'auto', @ischar);
p.addParameter('pulseEvents', {}, @iscellstr);  % can specify multiple pulse event types to be treated as the same
p.addParameter('epochTimespan', [], @c_isSpan);
p.parse(varargin{:});
s = p.Results;

assert(xor(isempty(s.inputFilePaths), isempty(s.inputEEGs)),'Must specify one of inputFilePaths or inputEEG');

misc = struct();

%%

if ~isempty(s.inputFilePaths)
	%% load EEG data
	assert(~isempty(s.inputFilePaths));
	if ischar(s.inputFilePaths)
		s.inputFilePaths = {s.inputFilePaths};
	end
	EEGs = {};
	prog = c_progress(length(s.inputFilePaths),'Loading EEG file %d/%d');
	prog.start('Loading EEG data');
	for iI = 1:length(s.inputFilePaths)
		prog.updateStart(iI);
		c_saySingle('Loading EEG from %s', s.inputFilePaths{iI});
		[~, ~, inputFileExt] = fileparts(s.inputFilePaths{iI});
		assert(c_exist(s.inputFilePaths{iI},'file')>0);
		switch(inputFileExt)
			case '.vhdr'
				EEGs{iI} = c_loadEEG_BrainProducts(s.inputFilePaths{iI});
			otherwise
				error('Unsupported input type: %s', ext);
		end
		prog.updateEnd(iI);
	end
	prog.stop()
	
	if isequal(s.inputDatasetLabels,'auto')
		[~, s.inputDatasetLabels] = c_str_findCommonPrefix(s.inputFilePaths);
		[~, s.inputDatasetLabels] = c_str_findCommonSuffix(s.inputFilePaths);
		c_saySingle('Using auto generated data labels: %s', c_toString(s.inputDatasetLabels));
	end
else
	if isstruct(s.inputEEGs)
		EEGs = {s.inputEEGs};
	else
		assert(all(cellfun(@isstruct, s.inputEEGs)));
		EEGs = s.inputEEGs;
	end
	if isequal(s.inputDatasetLabels,'auto')
		s.inputDatasetLabels = arrayfun(@(iD) sprintf('Dataset-%d', iD), 1:length(EEGs),'UniformOutput',false);
		c_saySingle('Using auto generated data labels: %s', c_toString(s.inputDatasetLabels));
	end
end

if ischar(s.inputDatasetLabels)
	assert(length(EEGs)==1);
	s.inputDatasetLabels = {s.inputDatasetLabels};
end
	
%% infer pulse event type if requested
if ~isempty(s.pulseEvents)
	assert(ismember(p.UsingDefaults, 'pulseEvent'), 'Should not specify both pulseEvent and pulseEvents');
	c_saySingle('Specified pulse event types: %s', c_toString(s.pulseEvents));
	misc.pulseEvents = s.pulseEvents;
	pulseEvents = s.pulseEvents;
else
	if strcmpi(s.pulseEvent,'auto')
		args = cellfun(@(EEG) EEG.event, EEGs, 'UniformOutput',false);
		allEvents = cat(2,args{:});
		[counts, eventTypes] = c_countUnique({allEvents.type});
		[~,index] = max(counts);
		mostFrequentEvent = eventTypes{index};
		pulseEvent = mostFrequentEvent;
		assert(~ismember(pulseEvent,{'boundary'}));
		assert(c_str_matchRegex(pulseEvent, {'[RST][ 0-9]*','Pulse'}));
		s.pulseEvent = pulseEvent;
		c_saySingle('Inferred pulse event type: ''%s''', s.pulseEvent);
	else
		c_saySingle('Specified pulse event type: ''%s''', s.pulseEvent);
	end
	misc.pulseEvent = s.pulseEvent;
	pulseEvents = {s.pulseEvent};
end


%%

if ~isempty(s.inputDatasetLabels)
	% before concatenation, label individual epochs with their parent dataset so that 
	%  later analyses which epochs in concatenated data came from which original dataset
	assert(length(s.inputDatasetLabels)==length(EEGs));
	for iD = 1:length(EEGs)
		assert(~isfield(EEGs{iD}.event,'datasetLabel'));
		[EEGs{iD}.event.datasetLabel] = deal(s.inputDatasetLabels{iD});
	end
end

if length(EEGs) > 1
	% before concatenation, trim any large excess of non-pulse data at beginning and end of each file
	c_say('Trimming continuous data');
	extraTime = s.epochTimespan*2; % time in seconds before first and after last pulse to keep
	for iD = 1:length(EEGs)
		EEG = EEGs{iD};
		firstEventIndex = find(ismember({EEG.event.type}, pulseEvents),1,'first');
		startTime = EEG.event(firstEventIndex).latency/EEG.srate + extraTime(1);
		lastEventIndex = find(ismember({EEG.event.type},pulseEvents),1,'last');
		endTime = EEG.event(lastEventIndex).latency/EEG.srate + extraTime(2);
		if startTime > 0 || (EEG.pnts-1)/EEG.srate - endTime > 0
			c_saySingle('Cutting %.2f s at beginning and %.2f s at end', startTime, (EEG.pnts-1)/EEG.srate - endTime);
			EEGs{iD} = pop_select(EEG,'time',[startTime, endTime]);
		else
			c_saySingle('Trim not needed');
		end
	end
	c_sayDone();
	
	c_say('Concatenating EEG data');
	EEG = pop_mergeset(cell2mat(EEGs), 1:length(EEGs), 0);
	c_sayDone();
else
	EEG = EEGs{1};
end
clearvars EEGs

%% infer reasonable epoch timespan if not specified
if isempty(s.epochTimespan)
	keyboard %TODO
	
end
misc.epochTimespan = s.epochTimespan; 

%% make sure chanlocs are set (interpolation and plotting in ARTIST needs channel locations)
if length([EEG.chanlocs.X]) < EEG.nbchan ....
		&& length([EEG.chanlocs.sph_theta]) < EEG.nbchan ...
		&& length([EEG.chanlocs.theta]) < EEG.nbchan
	% missing chanlocs, load from default
	
	% require that labels are set
	assert(~any(cellfun(@isempty, {EEG.chanlocs.labels})));

	% drop EMG channels
	removeChanIndices = c_str_matchRegex({EEG.chanlocs.labels}, 'EMG.*');
	if any(removeChanIndices)
		c_say('Removing %d EMG channels', sum(removeChanIndices));
		EEG = pop_select(EEG, 'nochannel', find(removeChanIndices));
		c_sayDone();
	end
	
	switch(EEG.nbchan)
		case 95
			c_saySingle('No chanlocs set, loading ActiCAP-96 default locations');
			defaultChanlocsPath = fullfile(fileparts(which(mfilename)),'Resources','ActiCAP-96.ced');
		case 63
			c_saySingle('No chanlocs set, loading ActiCAP-64 default locations');
			defaultChanlocsPath = fullfile(fileparts(which(mfilename)),'Resources','ActiCAP-64.ced');
		otherwise
			error('No chanlocs template available for %d channel montage', EEG.nbchan);
	end
	
	chanlocs = readlocs(defaultChanlocsPath);
	% all our electrodes should be in the default chanlocs
	labelsAreNumeric = all(~isnan(cellfun(@str2double, {EEG.chanlocs.labels})));
	if labelsAreNumeric
		% assume channel order is the same as in template chanlocs
		indices = cellfun(@str2double, {EEG.chanlocs.labels});
	else
		assert(all(ismember({EEG.chanlocs.labels}, {chanlocs.labels})));
		indices = c_cell_findMatchingIndices({EEG.chanlocs.labels}, {chanlocs.labels});
	end
	% if just one channel from default (aside from ground) is not in these electrodes, assume 
	%  it was the reference and save here to include when average rereferencing later
	otherIndices = find(~c_unfind(indices,size(chanlocs)));
	if ismember(length(otherIndices),[1 2])
		if length(otherIndices)==2
			groundIndex = otherIndices(ismember({chanlocs(otherIndices).labels},{'GND'}));
			EEG.gndloc = chanlocs(groundIndex);
			assert(length(groundIndex)==1);
			otherIndices = setdiff(otherIndices, groundIndex);
		end
		assert(length(otherIndices)==1);
		reflocIndex = otherIndices;
		c_saySingle('Saving separate refloc (assuming %s was reference)', chanlocs(reflocIndex).labels);
		EEG.refloc = chanlocs(reflocIndex);
	end
	EEG.chanlocs = chanlocs(indices);
end

if ~isfield(EEG.chanlocs, 'type') || all(cellfun(@isempty, {EEG.chanlocs.type}))
	% if no channel types are set, assume all channels are EEG channels
	c_saySingle('No channel types specified, assuming all are EEG.');
	[EEG.chanlocs.type] = deal('EEG');
end




end