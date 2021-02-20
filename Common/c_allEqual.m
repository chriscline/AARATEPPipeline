function allequal = c_allEqual(varargin)
% c_allEqual - similar to isequal() but allows arbitrary number of inputs instead of pairwise
%  (and uses isequaln instead of isequal to allow for NaNs)
%
% Examples:
%	c_allEqual(true,true,false)
%	c_allEqual(true,true,true)
%	c_allEqual([true,true,false])

	
	if length(varargin)==1
		allequal = true;
		for i=2:length(varargin{1})
			allequal = allequal && isequaln(varargin{1}(1),varargin{1}(i));
			if ~allequal
				break;
			end
		end
		return;
	end
	
	assert(length(varargin)>1);
	
	allequal = true;
	for i=2:nargin
		allequal = allequal && isequaln(varargin{1},varargin{i});
		if ~allequal
			break;
		end
	end
end