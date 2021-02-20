function c_sayDone(varargin)
% c_sayDone - Wrapper around fprintf with other added features
%
% See also: c_say

global sayNestLevel;
if isempty(sayNestLevel)
	sayNestLevel = 0;
end

global saySilenceLevel;
if ~isempty(saySilenceLevel) && sayNestLevel-1 >= saySilenceLevel
	% don't print anything
	sayNestLevel = max(sayNestLevel-1,0);
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

sayNestLevel = max(sayNestLevel-1,0);
for i=1:sayNestLevel
	if mod(i,2)==0
		fprintf(' ');
	else
		fprintf('|');
	end
end
fprintf('^ ');
if ~isempty(varargin)
	fprintf(varargin{:});
end
fprintf('\n');

end