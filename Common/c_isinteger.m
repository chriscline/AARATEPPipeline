function out = c_isinteger(x)
	out = isinteger(x) || (isnumeric(x) && all(ceil(x(:)) == floor(x(:))));
end