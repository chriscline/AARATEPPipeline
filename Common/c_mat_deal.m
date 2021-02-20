function varargout = c_mat_deal(array)
% c_mat_deal - similar to deal(), but can be used to split an array to multiple outputs
%
% Example:
%	[X,Y,Z] = c_mat_deal([1 2 3])

	if isvector(array)
		if nargout > length(array)
			error('Number of output arguments (%d) exceed number of elements in input (%d)',nargout,length(array));
		end
		varargout = cell(1,nargout);
		for i=1:nargout
			varargout{i} = array(i);
		end
	else
		tmp = c_mat_sliceToCell(array);
		if length(tmp) < nargout
			error('Number of output arguments (%d) exceed number of elements in input (%d)',nargout,length(tmp));
		end
		varargout = tmp;
	end
end