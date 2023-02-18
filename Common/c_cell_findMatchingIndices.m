function indices = c_cell_findMatchingIndices(findQueries,inCellArray)
% c_cell_findMatchingIndices - Find single matching index for each element in a cell of queries in another cell
%
% Example:
%	list = {'a', 'b', 'c'};
%   queries = {'c', 'a'};
%   assert(isequal(c_cell_findMatchingIndices(queries, list), [3 1]))

	assert(iscell(findQueries));
	assert(iscell(inCellArray));
	indices = nan(1,length(findQueries));
	for iQ = 1:length(findQueries)
		try
			index = find(ismember(inCellArray,findQueries{iQ}));
		catch 
			% try using isequal element-wise instead, since ismember can't handle non-character cell arrays
			index = find(cellfun(@(possibleMatch) isequal(possibleMatch, findQueries{iQ}), inCellArray));
		end
		if isempty(index)
			error('Query %s not found in %s',c_toString(findQueries{iQ}),c_toString(inCellArray));
		end
		if length(index) > 1
			% this fn. assumes all findQueries appear once and only once in inCellArray
			error('Query %s found multiple times in %s',c_toString(findQueries{iQ}),c_toString(inCellArray));
		end
		indices(iQ) = index;
	end
end