function c_save(varargin)
% wrapper around save to automatically switch to -v7.3 format if file is too large

warnID = 'MATLAB:save:sizeTooBigForMATFile';
prevwarn = warning('off',warnID);
lastwarn('');

args = '';
for i=1:length(varargin)
	args = [args, '''' varargin{i} '''',','];
end
args = args(1:end-1); % remove trailing comma
evalin('caller',['save(' args ')']);

[~,msgid] = lastwarn();

if ~isempty(msgid) && strcmp(msgid,warnID)
	% retry save as v7.3 format
	evalin('caller',['save(' args ',''-v7.3'')']);
end

warning(prevwarn); % restore previous warning state
	


