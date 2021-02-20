function varargout = c_saySingle(varargin)
% c_saySingle - Wrapper around fprintf with other added features
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
	
	global sayDateFormat;
	if isempty(sayDateFormat)
		sayDateFormat = 'HH:MM:ss';
	end
	
	if verLessThan('matlab','8.4')
		fprintf('%s ',datestr(now,13));
	else
		fprintf('%s ',datestr(datetime,sayDateFormat));
	end

	for i=1:sayNestLevel
		if mod(i,2)==0
			fprintf(' ');
		else
			fprintf('|');
		end
	end
	fprintf('> ');
	fprintf(varargin{:});
	fprintf('\n');
end