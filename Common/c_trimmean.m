function m = c_trimmean(X, percent, varargin)
% wrapper around trimmean, which uses nanmean() directly if percent==0
% (this can result in ~50x speedup since trimmean doesn't optimize for the percent==0 case)

if percent == 0
	m = nanmean(X, varargin{:});
else
	m = trimmean(X, percent, varargin{:});
end

end