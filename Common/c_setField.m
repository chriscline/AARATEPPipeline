function s = c_setField(s,fieldName,value)

if nargout == 0 && ~isa(s,'handle')
	warning('Must assign output of %s to store changes to struct',mfilename);
end

if length(s) > 1
	for i=1:numel(s)
		s(i) = c_setField(s(i),fieldName,value);
	end
	return;
end
assert(ischar(fieldName));
i = find(fieldName=='.',1,'first');
if isempty(i)
	s.(fieldName) = value;
else
	% recursive call
	if ~isfield(s, (fieldName(1:i-1)))
		s.(fieldName(1:i-1)) = struct();
	end
	s.(fieldName(1:i-1)) = c_setField(s.(fieldName(1:i-1)),fieldName(i+1:end),value);
end

end
