function str = c_getMachineIdentifier(varargin)

persistent p_str;

if ~isempty(p_str)
	str = p_str;
	return;
end

[~, ~] = system('hostname');  % in some edge cases, previous stdout warning pollute system call response, so call twice to try to clear these
[~, hostname] = system('hostname');

hostname = strtrim(hostname);

str = hostname;

p_str = str;

end