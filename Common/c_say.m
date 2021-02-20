function c_say(varargin)
% c_say - Wrapper around fprintf with other added features
% The collection of c_say* functions can be used to print formatted strings  
% with indication of level of nesting, e.g. to show that a sequence of printed lines all nest within
% a particular function call.
%
% Syntax matches that of fprintf(), except that newlines are automatically added at end of string
%
% Example:
% 	c_say('Outer print')
% 	c_saySingle('Indented print');
% 	c_say('Further indenting');
% 	c_saySingle('Indented print with formatting: %.3f',pi)
% 	c_sayDone('End of inner');
% 	c_sayDone('End of outer');
%
% See also: c_sayDone, c_saySingle, c_saySingleMultiline, c_sayResetLevel

	global sayNestLevel;
	if isempty(sayNestLevel)
		sayNestLevel = 0;
	end
	
	global saySilenceLevel;
	if ~isempty(saySilenceLevel) && sayNestLevel >= saySilenceLevel
		% don't print anything
		sayNestLevel = sayNestLevel + 1;
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
	sayNestLevel = sayNestLevel + 1;
	fprintf('v ');
	fprintf(varargin{:});
	fprintf('\n');
end