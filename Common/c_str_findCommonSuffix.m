function [suffix, strsWithoutSuffix] = c_str_findCommonSuffix(strArray)

assert(iscellstr(strArray));

if isempty(strArray)
	suffix = '';
	return;
end

strArray = cellfun(@flip,strArray,'UniformOutput',false);
[suffix, strsWithoutSuffix] = c_str_findCommonPrefix(strArray);
suffix = flip(suffix);
if nargout > 1
	strsWithoutSuffix = cellfun(@flip,strsWithoutSuffix,'UniformOutput',false);
end
end