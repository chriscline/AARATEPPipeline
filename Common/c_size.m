function sz = c_size(var,dims)
% c_size - like size(), but allows specifying nonscalar subset of dimensions
%
% Syntax:
%	sz = c_size(var,dims)
%
% Example:
% 	a = rand(10,20,30);
% 	sz = c_size(a,[1 3])
% 	% equivalent to:
% 	sz2 = size(a);
% 	sz2 = sz2([1 3])

	assert(isvector(dims) && ~islogical(dims)); %TODO: could add support for logical indexing
	sz = ones(1,max(max(dims),ndims(var)));
	sz(1:ndims(var)) = size(var);
	sz = sz(dims);
end