function str = c_str_makeUnique(varargin)
p = inputParser();
p.addRequired('strs',@iscell);
p.addRequired('str',@ischar);
p.addParameter('delimiter','',@ischar);
p.addParameter('doAppendOnly',false,@islogical);
p.parse(varargin{:});
s = p.Results;

strs = s.strs;
str = s.str;

assert(isempty(strs) || iscellstr(strs) || (iscell(strs) && all(cellfun(@isempty,strs))));
if nargin < 2
	str = strs{end};
end
if isempty(strs) || (iscell(strs) && all(cellfun(@isempty,strs))) && ~isempty(str)
	return;
end
if ~ismember(str, strs)
	return;
end

if s.doAppendOnly
	index = length(str) + 1;
else
	index = find(~ismember(str,'0123456789'),1,'last');
	if isempty(index)
		index = 0;
	end
	index = index + 1;
end

if index <= length(str)
	numSuffixStr = str(index:end);
	count = str2double(numSuffixStr);
	assert(~isnan(count));

	if ~isempty(s.delimiter)
		if ~isequal(str(index-(length(s.delimiter):-1:1)),s.delimiter)
			count = 0;
			index = length(str)+1;
		end
	end
else
	count = 0;
end

if index <= length(str)
	baseStr = str(1:(index-1-length(s.delimiter)));
else
	baseStr = str;
end

if ismember(baseStr,strs)
	strs = cat(c_findFirstNonsingletonDimension(strs),strs, sprintf('%s%s%d',baseStr,s.delimiter,1)); % treat baseStr the same as baseStr_1
end

while(true)
	count = count + 1;
	str = sprintf('%s%s%d',baseStr,s.delimiter,count);
	if ~ismember(str,strs)
		return;
	end
end

end