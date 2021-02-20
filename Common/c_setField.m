function struct = c_setField(struct,fieldName,value)

if nargout == 0 && ~isa(struct,'handle')
	warning('Must assign output of %s to store changes to struct',mfilename);
end

if length(struct) > 1
	for i=1:numel(struct)
		struct(i) = c_setField(struct(i),fieldName,value);
	end
	return;
end
assert(ischar(fieldName));
i = find(fieldName=='.',1,'first');
if isempty(i)
	struct.(fieldName) = value;
else
	% recursive call
	struct.(fieldName(1:i-1)) = c_setField(struct.(fieldName(1:i-1)),fieldName(i+1:end),value);
end

end
