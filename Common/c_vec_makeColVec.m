function vec = c_vec_makeColVec(vec)
if iscell(vec)
	siz = size(vec);
	assert((siz(1)==1 || siz(2)==1) && length(siz)==2);
	if siz(2) > siz(1)
		vec = vec';
	end
else
	assert(isvector(vec));
	if size(vec,2) > size(vec,1)
		vec = vec.';
	end
end
end