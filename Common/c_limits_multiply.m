function limits = c_limits_multiply(limits,scale)
% used to expand (or contract) limits in a logical way 
%
% if a scalar scale is specified, will multiply interval between limits by given scale symetrically
% if two scales are specified, will apply separately to lower and upper limits, still multiplying by width of interval

assert(isvector(limits) && length(limits)==2);

assert(limits(1) <= limits(2));

assert(isscalar(scale) || (isvector(scale) && length(scale)==2));

assert(all(scale>=0)); % do not allow negative scales

if isscalar(scale)
	scale = [scale-1 scale-1]/2+1;
end

span = diff(limits);

limits(1) = limits(1) - (scale(1)-1)*span;
limits(2) = limits(2) + (scale(2)-1)*span;

end