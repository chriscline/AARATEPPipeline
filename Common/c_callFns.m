function varargout = c_callFns(fnHandles,varargin)
% an ugly hack because Matlab doesn't allow multiline anonymous functions
% Instead, create a cell array of anonymous functions to call in sequence and feed in to this
% intermediate variables cannot be used since the same varargin is passed to all callbacks
%
% Only return output from first function

assert(iscell(fnHandles));
varargout = cell(nargout,length(fnHandles));
for i = 1:length(fnHandles)
	assert(isa(fnHandles{i},'function_handle'));
	if i==1
		[varargout{1:nargout}] = fnHandles{i}(varargin{:});
	else
		fnHandles{i}(varargin{:});
	end
end
end