function EEG = c_TMSEEG_findTMSPulses(EEG,varargin)
% assuming no events available for TMS pulses, try to find based on artifacts
p = inputParser();
p.addRequired('EEG',@isstruct);
p.addParameter('filterMethod','median',@ischar);
p.addParameter('maxPulseRate',100,@isscalar); % in Hz
p.addParameter('addEventsOfType','Pulse',@ischar); % leave empty to not add events
p.addParameter('doRefineOnsetTimes',false,@islogical);
p.addParameter('minPulseThreshold',1e3,@isscalar);
p.addParameter('maxPulseThreshold',1e4,@isscalar);
p.addParameter('minNumPulses',0,@isscalar);
p.parse(EEG,varargin{:});
s = p.Results;

origEEG = EEG;

assert(~c_EEG_isEpoched(EEG),'Only continuous (non-epoched) data supported');

switch(s.filterMethod)
	case 'median'
		% subtract median filter to remove drift without drastically changing TMS waveforms
		c_say('Temporarily subtracting median filtered data');
		medFiltOrder = 1/s.maxPulseRate*EEG.srate;
		medFiltDat = medfilt1(EEG.data,medFiltOrder,[],2,'truncate');
		EEG.data = EEG.data - medFiltDat;
		c_sayDone();
	case 'highpass'
		% highpass to remove low freq drifts that would throw off threshold detection
		c_say('Temporarily high-pass filtering');
		EEG = c_EEG_filter_butterworth(EEG,[1 0]);
		c_sayDone();
	otherwise
		error('Unsupported filterMethod: %s',s.filterMethod);
end


iChans = ismember({EEG.chanlocs.type},{'EEG'}); % if marked, only use EEG channels
if ~any(iChans)
	iChans = true(1,EEG.nbchan); % otherwise use all channels
end
tmpDat = EEG.data(iChans,:);

if 0
	% histogram of data values
	figure; histogram(tmpDat(:))
	ha = gca;
	ha.YScale = 'log';
end

thresh = extrema(tmpDat(:))/10;
while true
	% estimate threshold for spike/artifact detection
	%TODO: could implement sliding window non-global threshold if needed
	%TODO: could use other criteria for estimating threshold
	%TODO: could use channel-specific threshold
	
	thresh(1) = min(thresh(1),-s.minPulseThreshold);
	thresh(2) = max(thresh(2),s.minPulseThreshold);

	thresh(1) = max(thresh(1),-s.maxPulseThreshold);
	thresh(2) = min(thresh(2),s.maxPulseThreshold);

	% mark approx onset times by first threshold crossing within 1/maxPulseRate windows
	suprathreshIndices = tmpDat < thresh(1) | tmpDat > thresh(2);

	% require that at least 25% of channnels exceed threshold at each time point
	suprathreshIndices = sum(suprathreshIndices,1) > EEG.nbchan / 4;

	% sliding from left to right, only keep first indices within a sliding window
	windowLength = ceil(1/s.maxPulseRate*EEG.srate);
	i = 0;
	while i < EEG.pnts
		iOffset = find(suprathreshIndices(i+1:end),1,'first');
		if isempty(iOffset)
			break;
		end
		i = i + iOffset;
		suprathreshIndices(min(i+(1:windowLength),EEG.pnts)) = false;
	end

	suprathreshIndices = find(suprathreshIndices);

	if length(suprathreshIndices) > 1
		maxDetectedPulseRate = 1/min(diff(suprathreshIndices))*EEG.srate;
		c_saySingle('Max detected pulse rate: %s Hz',c_toString(maxDetectedPulseRate));
	end
	numDetectedPulses = length(suprathreshIndices);
	c_saySingle('Num detected pulses: %d',numDetectedPulses)

	if numDetectedPulses < s.minNumPulses
		if thresh(2) > s.minPulseThreshold
			thresh = thresh*0.8;
			c_saySingle('Fewer pulses than expected, lowering threshold to %s', c_toString(thresh))
			continue;
		else
			warning('c_TMSEEG_findTMSPulses:NumPulsesBelowMin', 'Detected fewer pulses than expected: %d instead of at least %d',...
				numDetectedPulses, s.minNumPulses);
			keyboard
		end
	end
	break
end

% revert to original EEG for returning
EEG = origEEG;

if ~isempty(s.addEventsOfType) && numDetectedPulses > 0
	eventLatencies = suprathreshIndices; % assuming latencies start at 1
	newEvents = c_struct_createEmptyCopy(EEG.event);
	newEvents(length(suprathreshIndices)).latency = NaN; % to set size 
	[newEvents.latency] = c_mat_deal(eventLatencies);
	[newEvents.duration] = deal(1);
	[newEvents.type] = deal(s.addEventsOfType);
	
	EEG = c_EEG_addEvents(EEG,'events',newEvents);
end

if s.doRefineOnsetTimes && numDetectedPulses > 0
	c_say('Refining onset times');
	assert(~isempty(s.addEventsOfType));
	% note that this could allow some pulses to end up closer together than 1/s.maxPulseRate 
	EEG = c_TMSEEG_correctTriggerTimes(EEG,...
		'eventType',s.addEventsOfType,...
		'correctionLimits',[-1/s.maxPulseRate/2,1/s.maxPulseRate/2]);
	c_sayDone();
end


end