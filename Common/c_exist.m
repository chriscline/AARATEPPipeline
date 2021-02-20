function out = c_exist(varargin)
p = inputParser();
p.addRequired('name', @ischar);
p.addOptional('searchType', '', @ischar);
p.addParameter('doubleCheck', true, @islogical);
p.parse(varargin{:});
s = p.Results;

if ~isempty(s.searchType)
	args = {s.name, s.searchType};
else
	args = {s.name};
end

out = exist(args{:});

if ~out && s.doubleCheck
	% check again, for file systems like Box drive where first query returns false if a file exists
	%  but hasn't been previously downloaded
	out = max(out, exist(args{:}));
end

end