function EEG = c_TMSEEG_correctTriggerTimes(varargin)
p = inputParser;
p.addRequired('EEG',@isstruct);
p.addParameter('eventType','R128',@ischar); % only used if data is not already epoched
p.addParameter('doBaselineSubtraction',true,@islogical);
p.addParameter('method','rise',@ischar); % valid: peak, baseline, rise
p.addParameter('correctionLimits',[-10 10]/1e3,@c_isSpan);
p.addParameter('earliestBaselineTime',-inf,@isscalar);
p.addParameter('COI',{},@iscellstr);
p.addParameter('doPerTrialCorrection',true,@islogical);
p.addParameter('Fs',[],@(x) isscalar(x) || isempty(x));
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;

% reduce to COI
if ~isempty(s.COI)
	EEG = c_EEG_reduceChannelData(EEG,s.COI);
end

assert(~c_EEG_isEpoched(EEG)); % require that EEG is not epoched

c_say('Temporarily epoching');
EEG = c_EEG_epoch(EEG,...
	'timespan','auto',...
	'eventType',s.eventType);
c_sayDone();

assert(EEG.xmin <= s.correctionLimits(1))
assert(EEG.xmax >= s.correctionLimits(2))

baselineTimespan = [max(s.earliestBaselineTime,EEG.xmin) s.correctionLimits(1)];

if s.doBaselineSubtraction	
	c_say('Performing baseline subtraction using baseline %s ms',c_toString(baselineTimespan*1e3));
	EEG = pop_rmbase(EEG,baselineTimespan*1e3);
	c_sayDone();
end

if ismember(s.method,{'baseline','rise'})
		% assume that there is *never* a trigger in baseline timespans, so
		% set threshold for detection accordingly
		c_say('Calculating baseline values for setting threshold');
		timeIndices = EEG.times >= baselineTimespan(1)*1e3 & EEG.times < baselineTimespan(2)*1e3;
		baselineValues = c_EEG_calculateGMFA(EEG.data(:,timeIndices,:));
		baselineThreshold = max(baselineValues(:));	
		c_saySingle('Max baseline value: %.3g',baselineThreshold);
		c_sayDone();
end

% reduce data to just correctionLimits for efficiency
EEG = c_EEG_epoch(EEG,'timespan',s.correctionLimits); % epoch around existing events

% upsample if needed
if ~isempty(s.Fs)
	assert(s.Fs >= EEG.srate); % probably don't want to downsample before doing this, especially if it would
	%  be necessary to apply an anti-aliasing filter
	if s.Fs ~= EEG.srate
		c_say('Upsampling');
		EEG = c_EEG_resample(EEG,s.Fs,'method','nofilt');
		c_sayDone();
	end
end

sig = c_EEG_calculateGMFA(EEG);

switch(s.method)
	case 'baseline'
		% set actual trigger time to time of first value exceeding baseline threshold
		
		for iE = 1:EEG.trials
			index = find(sig(:,:,iE) > baselineThreshold*5,1,'first');
			if isempty(index)
				warning('No values exceeding threshold in trial %d/%d',iE,EEG.trials);
				% do not change trigger time
				actualTimes(iE) = 0;
			else
				actualTimes(iE) = EEG.times(index)/1e3;
			end
		end
		
	case 'rise'
		% set actual trigger time to first point exceeding halfway amplitude between baseline and (max across epochs)
		doGlobalThresh = false;
		if doGlobalThresh
			maxVal = max(sig(:));
			threshold = (maxVal + baselineThreshold)/2;
		end
		for iE = 1:EEG.trials
			if ~doGlobalThresh
				maxVal = max(sig(:,:,iE),[],2);
				threshold = (maxVal + baselineThreshold)/2;
			end
			index = find(sig(:,:,iE) > threshold,1,'first');
			if isempty(index)
				warning('No values exceeding threshold in trial %d/%d',iE,EEG.trials);
				% do not change trigger time
				actualTimes(iE) = 0;
				pause(0.1);
			else
				actualTimes(iE) = EEG.times(index)/1e3;
			end
		end
		
	case 'peak'
		% set actual trigger time to time of maximal positive peak within epoch
		
		keyboard %TODO
		
	otherwise
		error('Invalid method: %s',s.method);
end
	
% correct event latencies

epochedEEG = EEG;
EEG = s.EEG; % restore unmodified EEG
% note that this assumes original EEG was *not* epoched

if s.doPerTrialCorrection
	c_saySingleMultiline('Calculated time corrections of (ms):\n%s',...
		c_str_wrap(c_toString(actualTimes*1e3,'printLimit',inf),'toLength',100))
else
	actualTime = median(actualTimes);
	c_saySingle('Calculated time correction: %s ms', c_toString(actualTime*1e3));
	actualTimes = repmat(actualTime,size(actualTimes));
end

for iE = 1:length(epochedEEG.epoch)
	% find index of event corresponding to time zero in epoch
	%hasMultipleEvents = length(epochedEEG.epoch(iE).eventlatency) > 1;
	hasMultipleEvents = iscell(epochedEEG.epoch(iE).eventlatency);
	eventLatencies = epochedEEG.epoch(iE).eventlatency;
	
	if hasMultipleEvents
		eventLatencies = cell2mat(eventLatencies);
		eventSubIndex = find(eventLatencies==0 & ismember(epochedEEG.epoch(iE).eventtype, s.eventType),1,'first');
		assert(strcmpi(epochedEEG.epoch(iE).eventtype{eventSubIndex},s.eventType));
		ureventIndex = epochedEEG.epoch(iE).eventurevent{eventSubIndex};
	else
		eventSubIndex = find(eventLatencies==0,1,'first');
		assert(eventSubIndex==1 && strcmpi(epochedEEG.epoch(iE).eventtype,s.eventType));
		ureventIndex = epochedEEG.epoch(iE).eventurevent(eventSubIndex);
	end
	urevents = {EEG.event.urevent};
	indices = cellfun(@isempty,urevents);
	if any(indices)
		urevents(indices) = {nan};
	end
	urevents = cell2mat(urevents);
	eventIndex = find(ismember(urevents,ureventIndex));
	assert(isscalar(eventIndex));
	
	% adjust event latency
	latencyCorrection = actualTimes(iE)*EEG.srate; % number of samples to correct by
	% assume epoch latencies are in units of samples (not s)
	EEG.event(eventIndex).latency = EEG.event(eventIndex).latency + latencyCorrection;
end

end