function n = c_norm(A,p,dim)
% c_norm: calculate pth norm along specified dimension
%
% Syntax:
%   n = c_norm(A,p,dim)
%
% Inputs:
%    A - array from which to calculate norm(s)
%    p - norm specifier (e.g. p=2 will calculate Euclidean norm).
%    dim - dimension of A to operate along. If not specific, will use first nonsingleton dimension
%
% Outputs:
%    n - norm values
%
% Examples:
%   A = rand(3,4);
%   nA_2 = c_norm(A,2,1); % L2 norm along first dimension
%   nA_1 = c_norm(A,1,1); % L1 norm along first dimension

	if nargin < 3
		dim = c_findFirstNonsingletonDimension(A);
	end
	switch(p)
		case 1
			n = sum(abs(A),dim);
		case 2
			n = sqrt(sum(A.^2,dim));
		case '2sq'
			n = sum(A.^2,dim); % L2 norm, squared
		case inf
			n = max(abs(A),[],dim);
		otherwise
			error('%d norm not supported',dim);
	end
			
end


