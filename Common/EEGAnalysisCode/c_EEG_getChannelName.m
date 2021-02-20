function labels = c_EEG_getChannelName(varargin)
%% c_EEG_getChannelIndex Get index of a channel within specified montage
%
% also supports vector argument for channelIndex, which returns
% retrieves a channel name for each of multiple channel indices.

p = inputParser();
p.addRequired('EEG',@isstruct);
p.addRequired('channelIndex',@isvector);
p.addParameter('forceCellOutput',false,@islogical);
p.parse(varargin{:});
s = p.Results;

% use montage saved in EEG struct

labels = {s.EEG.chanlocs(s.channelIndex).labels};
	
if isscalar(s.channelIndex) && ~s.forceCellOutput
	labels = labels{1}; % return str instead of cell
end
	
end


