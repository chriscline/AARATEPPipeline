function EEG = c_TMSEEG_runSOUND(varargin)
% Wrapper around TESA SOUND
% Note: data should be high-pass filtered (e.g. with c_TMSEEG_applyModifiedBandpassFilter) prior to calling this
% Note: the output will be rereferenced by SOUND

p = inputParser();
p.addRequired('EEG', @isstruct);
p.addParameter('replaceChannels', [], @isnumeric); % these channels should still exist in data, will be removed prior to passing to SOUND internally
p.addParameter('doRereferenceBeforeSOUND', false, @islogical);
p.addParameter('lambda', 0.1, @isscalar);
p.addParameter('numIterations', 10, @isscalar);
p.addParameter('leadFieldPath', '', @ischar);
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;


if ~isempty(s.replaceChannels)
	% remove bad channels entirely in data passed to SOUND
	%  and specify that they are to be filled in during processing

	EEGAllChans = struct();
	EEGAllChans.data = nan(EEG.nbchan, 1); % used to validate size of leadField within SOUND
	EEGAllChans.pnts = 1;
	EEGAllChans.trials = 1;
	EEGAllChans.xmin = 0;
	EEGAllChans.xmax = 0;
	fieldsToCopy = {...
		'chanlocs',...
		'nbchan',...
		'srate',...
		'setname'};
	for iF = 1:length(fieldsToCopy)
		EEGAllChans.(fieldsToCopy{iF}) = EEG.(fieldsToCopy{iF});
	end
	fieldsToInitEmpty = {...
		'icawinv',...
		'icaweights',...
		'icasphere',...
		'icaact',...
		'filename',...
	};
	for iF = 1:length(fieldsToInitEmpty)
		EEGAllChans.(fieldsToInitEmpty{iF}) = [];
	end
	eeg_checkset(EEGAllChans)

	EEGAllChansPath = [tempname '.set'];
	c_say('Saving temp dataset with full chanlocs');
	pop_saveset(EEGAllChans, EEGAllChansPath);
	c_sayDone();
	
	c_say('Removing %d bad channel(s) to be filled within SOUND', length(s.replaceChannels));
	EEG = pop_select(EEG, 'nochannel', s.replaceChannels);
	c_sayDone();
	
else
	EEGAllChansPath = [];
end

if s.doRereferenceBeforeSOUND
	c_say('Rereferencing');
	EEG = pop_reref(EEG, []);
	c_sayDone();
end

assert(any(~isnan(EEG.data(:))));

c_say('Running SOUND');
EEG = tesa_sound(EEG,...
	'lambdaValue', s.lambda,...
	'iter', s.numIterations,...
	'leadfieldInFile', s.leadFieldPath,...
	'replaceChans', EEGAllChansPath);
c_sayDone();

assert(any(~isnan(EEG.data(:))), 'Problem with SOUND: returned all NaNs');

if ~isempty(EEGAllChansPath)
	delete(EEGAllChansPath);
end

end