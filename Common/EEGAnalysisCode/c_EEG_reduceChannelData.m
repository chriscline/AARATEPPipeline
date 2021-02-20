function EEG = c_EEG_reduceChannelData(EEG,channelsToKeep)
% 
% channelsToKeep in string list format, e.g. {'C3','C4'}

if ischar(channelsToKeep)
	channelsToKeep = {channelsToKeep};
end

if iscellstr(channelsToKeep)
	channelsToKeep = unique(channelsToKeep);
	channelIndicesToKeep = c_EEG_getChannelIndex(EEG,channelsToKeep);
else
	assert(isnumeric(channelsToKeep));
	channelIndicesToKeep = channelsToKeep;
end

numChannelsToKeep = length(channelIndicesToKeep);

% cut out data
EEG.data = EEG.data(channelIndicesToKeep,:,:);

% update other parameters within EEG struct
EEG.nbchan = numChannelsToKeep;
EEG.chanlocs = EEG.chanlocs(channelIndicesToKeep);

% update epochs struct if present
if isfield(EEG,'epochs') && isfield(EEG.epochs,'data')
	EEG.epochs.data = EEG.epochs.data(channelIndicesToKeep,:,:);
end

end