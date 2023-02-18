function EEG = c_EEG_epoch(varargin)
p = inputParser();
p.addRequired('EEG',@isstruct);
p.addParameter('timeBeforeEvent',0,@isscalar); % in s
p.addParameter('timeAfterEvent',0,@isscalar); % in s
p.addParameter('timespan',[],@(x) isempty(x) || (isvector(x) && length(x)==2) || (ischar(x) && strcmpi(x,'auto'))); % in s 
p.addParameter('eventType','',@(x) ischar(x) || iscell(x));
p.addParameter('eventTypeMarkingTrial','',@ischar); %TODO: legacy, delete
p.addParameter('eventFieldMarkingTrialType','position',@ischar);
p.addParameter('ifEventNearBoundary','error',@(x) ismember(x,{'error','padwithnan','dropEvent'}));
p.addParameter('doUseEEGLab',true,@islogical);
p.parse(varargin{:});
s = p.Results;

EEG = s.EEG;

if ~isempty(s.eventTypeMarkingTrial)
	warning('legacy use of eventTypeMarkingTrial.');
	s.eventType = s.eventTypeMarkingTrial;
end

doEpochAroundZero = false;

if isempty(s.eventType)
	if ~c_EEG_isEpoched(EEG)
		error('event type must be specified for data that is not already epoched');
	else
		% can get away without specifying event type when data is already epoched by applying new timespan around time=0
		% (e.g. to shorten epochs in previously epoched data without knowing what event was used for epoching)
		doEpochAroundZero = true;
	end
end

if ~iscell(s.eventType)
	s.eventType = {s.eventType};
end

if ~ismember('timespan',p.UsingDefaults) && ~isempty(s.timespan)
	% timespan input was specified
	if any(~ismember({'timeBeforeEvent','timeAfterEvent'},p.UsingDefaults))
		warning('Specified timeBeforeEvent and/or timeAfterEvent overriden by timespan');
	end
	if ischar(s.timespan)
		% calculate timespan from minimum epoch between consecutive events
		assert(strcmpi(s.timespan,'auto')); % no other string inputs accepted
		eventIndices = ismember({EEG.event.type},s.eventType);
		eventLatencies = sort(cell2mat({EEG.event(eventIndices).latency}));
		diffEventLatencies = diff(eventLatencies);
		if any(diffEventLatencies==0)
			warning('Ignoring repeated events with identical latencies for timespan estimation');
			diffEventLatencies(diffEventLatencies==0) = [];
		end
		minTimeDiff = min(diffEventLatencies)/EEG.srate;
		
		s.timespan = [-1 1]*minTimeDiff/2;
		
		% also make sure timespan does not exceed data boundaries for first and last epochs
		s.timespan(1) = max(-1*eventLatencies(1)/EEG.srate, s.timespan(1));
		s.timespan(2) = min((EEG.pnts - eventLatencies(end))/EEG.srate, s.timespan(2));
		
		% round to nicer intervals to encourage consistency across datasets
		if minTimeDiff > 0.5
			s.timespan = fix(s.timespan*10)/10; % round toward zero to nearest 0.1 s
			c_saySingle('Auto selected timespan of %s s for epoching',c_toString(s.timespan));
		else
			s.timespan = fix(s.timespan*1000)/1000; % round toward zero to nearest 0.001 s
			c_saySingle('Auto selected timespan of %s ms for epoching',c_toString(s.timespan*1e3));
		end
		
		if diff(s.timespan) < 1e-6
			warning('Timespan probably not detected correctly');
			keyboard
		end
	end
	s.timeBeforeEvent = -s.timespan(1);
	s.timeAfterEvent = s.timespan(2);
end



if doEpochAroundZero && ~p.Results.doUseEEGLab || s.timeBeforeEvent < 0
	didMergeAuxData = false;
	if c_EEG_hasAuxData(EEG)
		EEG = c_EEG_mergeAuxData(EEG);
		didMergeAuxData = true;
	end

	if min(EEG.times)/1e3 > -s.timeBeforeEvent || max(EEG.times)/1e3 < s.timeAfterEvent
		switch(lower(s.ifEventNearBoundary))
			case 'error'
				error('Requested epoch span exceeds original epoched data timespan');
			case 'padwithnan'
				keyboard %TODO: pad extra timespan with NaNs
			case 'dropevent'
				error('Requested epoch span exceeds original epoched data timespan. Dropping event is only an option when input is not epoched.');
			otherwise
				error('Un-implemented ifEventNearBoundary method: %s',s.ifEventNearBoundary);
		end
	end
	
	indicesToKeep = EEG.times/1e3 >= -s.timeBeforeEvent & EEG.times/1e3 <= s.timeAfterEvent;
	
	if sum(indicesToKeep)==0
		warning('No data remaining after epoching with timespan [%.2g,%.2g]',-s.timeBeforeEvent,s.timeAfterEvent)
		EEG = c_EEG_makeEmpty(EEG);
	else
		EEG.data = EEG.data(:,indicesToKeep,:);
		EEG.pnts = size(EEG.data,2);
		EEG.times = EEG.times(indicesToKeep);
		EEG.xmin = EEG.times(1)/1e3;
		EEG.xmax = EEG.times(end)/1e3;
		%TODO: remove events outside of epochs
	end
	
	if didMergeAuxData
		EEG = c_EEG_splitAuxData(EEG);
	end
elseif p.Results.doUseEEGLab
	c_EEG_openEEGLabIfNeeded();
	
	if doEpochAroundZero
		s.eventType = {'_tempEvent'}; % dummy event type
		for iT = 1:EEG.trials
			% add dummy events at time 0
			EEG.event(end+1).latency = -EEG.xmin*EEG.srate + 1 + (EEG.pnts*(iT-1));
			EEG.event(end).type = s.eventType{1};
		end
	end
	
	didMergeAuxData = false;
	if c_EEG_hasAuxData(EEG)
		EEG = c_EEG_mergeAuxData(EEG);
		didMergeAuxData = true;
	end

	switch(lower(s.ifEventNearBoundary))
		case 'error'
			% do nothing here (fn call below will generate error if needed)
		case 'dropevent'
			evtIndices = find(ismember({EEG.event.type},s.eventType));
			evts = EEG.event(evtIndices);
			evtLatencies = [evts.latency];
			indicesToDelete = evtLatencies < s.timeBeforeEvent*EEG.srate+1 | evtLatencies > (EEG.xmax - s.timeAfterEvent)*EEG.srate+1;
			if sum(indicesToDelete) > 0
				c_saySingle('Dropping %d events too close to boundaries of data',sum(indicesToDelete));
				EEG.event(evtIndices(indicesToDelete)) = [];
			end
		case 'padwithnan'
			keyboard %TODO
		otherwise
			error('Unimplemented ifEventNearBoundary method: %s',s.ifEventNearBoundary);
	end
	
	fn = @() pop_epoch(EEG,s.eventType,[-s.timeBeforeEvent, s.timeAfterEvent]);
	if 1
		[~,EEG] = evalc('fn()');
	else
		EEG = fn();
	end
	
	if didMergeAuxData
		EEG = c_EEG_splitAuxData(EEG);
	end
	
	if doEpochAroundZero
		indicesToRemove = ismember({EEG.event.type},{s.eventType{1}}); % remove dummy events
		EEG.event(indicesToRemove) = [];
		% note, this may mess with epoch structure that refer to specific
		% numbered events
		if 1 
			% attempt to fix epoch structure as well
			for iE = 1:length(EEG.epoch)
				indicesToRemove = ismember(EEG.epoch(iE).eventtype,s.eventType);
				if any(indicesToRemove)
					fields = fieldnames(EEG.epoch);
					for iF = 1:length(fields)
						EEG.epoch(iE).(fields{iF})(indicesToRemove) = [];
					end
				end
			end
		end
	end
else
	% legacy code
	%TODO: delete
	warning('legacy code');

	EEG.epochs.timeBefore = p.Results.timeBeforeEvent;
	EEG.epochs.timeAfter = p.Results.timeAfterEvent;
	eventFieldMarkingTrialType = p.Results.eventFieldMarkingTrialType;

	EEG.epochs.numBefore = round(EEG.epochs.timeBefore*EEG.srate);
	EEG.epochs.numAfter = round(EEG.epochs.timeAfter*EEG.srate);

	trialEventIndices = strcmp({EEG.event.type},s.eventType);

	trialTypes = {EEG.event(trialEventIndices).(eventFieldMarkingTrialType)};
	if isnumeric(cell2mat(trialTypes)) % convert from cell array to numeric array if types are not strings
		trialTypes = cell2mat(trialTypes);
	end

	trialDataStartIndices = cell2mat({EEG.event(trialEventIndices).latency});

	trialDataEndIndices = trialDataStartIndices + cell2mat({EEG.event(trialEventIndices).duration}) - 1;

	trialEventIndices = find(trialEventIndices); % convert from logical to numbered indexing

	EEG.epochs.eventIndices = trialEventIndices;
	EEG.epochs.types = trialTypes;
	EEG.epochs.dataStartIndices = trialDataStartIndices;
	EEG.epochs.dataEndIndices = trialDataEndIndices;

	EEG.epochs.numEpochs = length(trialEventIndices);
	EEG.trials = EEG.epochs.numEpochs;
	EEG.epochs.uniqueTypes = unique(EEG.epochs.types);
end
	
	

end
