function s = c_struct_sortByField(s,field,sortArgs)
	if length(s) <= 1
		return;
	end

	if nargin < 3
		sortArgs = {};
	end
	assert(isfield(s,field));
	toSort = {s.(field)};
	if ~iscellstr(toSort)
		toSort = cell2mat(toSort);
	end
	[~, ind] = sort(toSort,sortArgs{:});
	s=s(ind);
end