function index = c_EEG_getChannelIndex(EEG,channelName,caseSensitive)
%% c_EEG_getChannelIndex Get index of a channel within specified montage
%
% also supports vector (cell) argument for channelName, which returns
% retrieves a channel index for each of multiple channel names.

% use montage saved in EEG struct

if nargin < 3
	caseSensitive = false;
end

if ~isstruct(EEG)
	error('First argument should be EEG struct');
end

labels = {EEG.chanlocs.labels};

if ~caseSensitive
	labels = lower(labels);
	channelName = lower(channelName);
end

if ~iscell(channelName)
	channelName = {channelName};
end

[~,index] = ismember(channelName,labels);

if any(index==0)
	for i=find(index==0)
		warning('c_EEG_getChannelIndex:ChannelNotFound','Channel ''%s'' not present in chanlocs. Returning index of 0.',channelName{i});
	end
end

	
	
	


