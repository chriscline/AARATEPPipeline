function EEG = c_EEG_grow(varargin)
% note: this does not (currently) properly update event latencies or other similar parameters,
% just the core EEG struct timing variables and data field.


p = inputParser();
p.addRequired('EEG', @isstruct);
p.addParameter('padWith', NaN, @isscalar);
p.addParameter('timespan', [], @(x) isempty(x) || c_isSpan(x));
% TODO: add arguments and code below to support padding channels and trials too
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;

if ~isempty(s.timespan)
	% pad in time
	origEEG = EEG;
	origTSpan = extrema(EEG.times)/1e3;

	assert(s.timespan(1) <= origTSpan(1));
	assert(s.timespan(2) >= origTSpan(2));

	newTSpan = s.timespan;
	
	if newTSpan(1) < origTSpan(1)
		newTimes_start = flip(EEG.xmin : -1/EEG.srate : newTSpan(1))*1e3;
		newTimes_start(end) = [];
	else
		newTimes_start = [];
	end
	if newTSpan(2) > origTSpan(2)
		newTimes_end = (EEG.xmax : 1/EEG.srate : newTSpan(2))*1e3;
		newTimes_end(1) = [];
	else
		newTimes_end = [];
	end
	
	EEG.times = [newTimes_start, EEG.times, newTimes_end];
	
	EEG.pnts = length(EEG.times);
	EEG.data = repmat(s.padWith, EEG.nbchan, EEG.pnts, EEG.trials);
	EEG.data(:, length(newTimes_start)+(1:origEEG.pnts), :) = origEEG.data;
	EEG.xmin = EEG.times(1) / 1e3;
	EEG.xmax = EEG.times(end) / 1e3;

	% update event starts
	for iEvt = 1:length(EEG.event)
		evt = EEG.event(iEvt);
		origModuloLatency = mod(evt.latency, origEEG.pnts);
		numEpochsBeforeThisEvt = floor(evt.latency / origEEG.pnts);
		latencyToAdd = numEpochsBeforeThisEvt * (length(newTimes_start) + length(newTimes_end)) + length(newTimes_start);
		EEG.event(iEvt).latency = evt.latency + latencyToAdd;
	end
else
	error('No pad dimension(s) specified')
end

end