function [extremeVals imin imax] = extrema(varargin)
% extrema - calculate min and max values
%
% Syntax:
%   [minmax, imin, imax] = extrema(vals)
%   [minmax, imin, imax] = extrema(vals,[],dim)
%
% Emulates syntax of min() and max(), see those functions for details.
%
% Inputs:
%	vals - array of values
%   [] - second output not used, for compatibility with min() and max() syntax
%   dim - dimension of vals along which to operate
%
% Examples:
%   extremeVals = extrema([1 2 3])
%   extremeVals = extrema(rand(2,10),[],2)
	
	if nargin > 2
		assert(isempty(varargin{2}));
	end

	if nargout >= 3
		[minval, imin] = min(varargin{:});
	else
		minval = min(varargin{:});
	end
	if nargout >= 4
		[maxval, imax] = max(varargin{:});
	else
		maxval = max(varargin{:});
	end
	
	if nargin==3 && varargin{3} ~= 1
		extremeVals = [minval,maxval];
	else
		extremeVals = [minval.', maxval.'];
	end
end