function logicalIndices = c_unfind(numericIndices, siz)
% while 'find' converts from logical to numeric indices, c_unfind does the opposite: convert from numeric indices to logical
	assert(~islogical(numericIndices));
	assert(nargin >= 2,'Must specify size of indexed array, i.e. ''%s(numericIndices, size)''',mfilename);
	if isscalar(siz)
		siz = [1 siz];
	end
	logicalIndices = false(siz);
	logicalIndices(numericIndices) = true;
	assert(nargout > 0);
end