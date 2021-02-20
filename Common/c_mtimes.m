function C = c_mtimes(A,B)
	% reshape extra dimensions of A and/or B prior to matrix multiplication
	sizeA = size(A);
	sizeB = size(B);
	
	if sizeA(end) ~= sizeB(1)
		error('Incompatible sizes: %s and %s',c_toString(sizeA),c_toString(sizeB));
	end
	
	didReshapeA = false;
	if length(sizeA) > 2
		A = reshape(A,[prod(sizeA(1:(end-1))) sizeA(end)]);
		didReshapeA = true;
	end
	
	didReshapeB = false;
	if length(sizeB) > 2
		B = reshape(B,[sizeB(1) prod(sizeB(2:end))]);
		didReshapeB = true;
	end
	
	if didReshapeA && didReshapeB
		error('Can only reshape A or B, not both. One input should be a 2D matrix.');
	end
	
	C = A*B;
	
	sizeC = size(C);
	
	if didReshapeA
		C = reshape(C,[sizeA(1:(end-1)),sizeC(end)]);
	end
	
	if didReshapeB
		C = reshape(C,[sizeC(1) sizeB(2:end)]);
	end
end