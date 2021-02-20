function vec = c_vec_makeRowVec(vec)
if iscell(vec)
	siz = size(vec);
	assert((siz(1)==1 || siz(2)==1) && length(siz)==2);
	if siz(1) > siz(2)
		vec = vec';
	end
else
	assert(isvector(vec));
	if size(vec,1) > size(vec,2)
		vec = vec.';
	end
end
end