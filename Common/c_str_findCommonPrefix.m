function [prefix, strsWithoutPrefix] = c_str_findCommonPrefix(strArray)
% c_str_findCommonPrefix - find common prefix string shared by all strings in a cell array
%
% Example:
%	strs = {'Test_1','Test_2','Test_c'};
%	c_str_findCommonPrefix(strs)

assert(iscellstr(strArray));

if isempty(strArray)
	prefix = '';
	return;
end

minLength = min(cellfun(@length,strArray));
sharedLength = minLength;
for i=1:minLength
	if ~all(cellfun(@(x) x(i)==strArray{1}(i),strArray))
		% found a difference
		sharedLength = i-1;
		break;
	end
end

prefix = strArray{1}(1:sharedLength);

if nargout > 1
	strsWithoutPrefix = strArray;
	for j=1:length(strArray)
		strsWithoutPrefix{j} = strArray{j}(length(prefix)+1:end);
	end
end
end