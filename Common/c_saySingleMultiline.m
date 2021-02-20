function varargout = c_saySingleMultiline(varargin)
% c_saySingleMultiline - Wrapper around fprintf with other added features
%
% See also: c_say

	global sayNestLevel;
	
	if nargout > 0
		varargout{1} = ''; %TODO: possibly change in the future to return meaningful strings
	end

	if isempty(sayNestLevel)
		sayNestLevel = 0;
	end
	
	global saySilenceLevel
	if ~isempty(saySilenceLevel) && sayNestLevel >= saySilenceLevel
		% don't print anything
		return
	end
	
	strToPrint = sprintf(varargin{:});
	strsToPrint = strsplit(strToPrint,'\n');
	
	for i=1:length(strsToPrint)
		c_saySingle('%s',strsToPrint{i});
	end
end