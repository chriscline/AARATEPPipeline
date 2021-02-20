function EEG = c_EEG_filter_butterworth(EEG, varargin)
% adapted from TESA tesa_filtbutter function

p = inputParser();
p.addRequired('cutoffFreqs',@(x) isnumeric(x) && isvector(x) && length(x)==2); % in Hz
p.addParameter('order',4,@(x) isscalar(x) && mod(x,2)==0);
p.addParameter('type','auto',@ischar);
p.parse(varargin{:});
s = p.Results;
assert(isstruct(EEG));

switch(s.type)
	case 'auto'
		if all(s.cutoffFreqs>0)
			s.type = 'bandpass';
		elseif s.cutoffFreqs(1) > 0
			s.type = 'high';
			s.cutoffFreqs = s.cutoffFreqs(1);
		elseif s.cutoffFreqs(2) > 0
			s.type = 'low';
			s.cutoffFreqs = s.cutoffFreqs(2);
		else
			% both cutoffs are 0 or < 0
			warning('Cutoff frequencies invalid: %s. Not filtering.',c_toString(s.cutoffFreqs));
			return;
		end
	case 'bandpass'
		% do nothing
	case 'bandstop'
		s.type = 'stop';
	case 'lowpass'
		s.type = 'low';
		s.cutoffFreqs = s.cutoffFreqs(2);
	case 'highpass'
		s.type = 'high';
		s.cutoffFreqs = s.cutoffFreqs(1);
	otherwise
		error('Invalid type: %s',s.type);
end

if length(s.cutoffFreqs) > 1 && s.cutoffFreqs(1) > s.cutoffFreqs(2)
	error('Cutoff frequencies not in ascending order. Swapped?')
end

[z,p] = butter(s.order/2, s.cutoffFreqs./(EEG.srate/2), s.type);

% temporarily move time dimension to first dimension for filtfilt
EEG.data = permute(EEG.data,[2 1 3]);

didConvertFromSingle = false;
if isa(EEG.data,'single')
	c_say('Temporarily converting EEG.data from single to double');
	EEG.data = double(EEG.data);
	c_sayDone();
	didConvertFromSingle = true;
end

% apply filter
EEG.data = filtfilt(z,p,EEG.data);

if didConvertFromSingle
	c_say('Converting EEG.data back from double to single');
	EEG.data = single(EEG.data);
	c_sayDone();
end

% undo rearrangement of dimensions
EEG.data = ipermute(EEG.data,[2 1 3]);

end
