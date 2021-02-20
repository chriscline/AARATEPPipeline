function isSpan = c_isSpan(x)
isSpan = isvector(x) && isnumeric(x) && length(x)==2 && x(1) <= x(2);
end