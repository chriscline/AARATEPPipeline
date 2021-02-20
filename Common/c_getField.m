function varargout = c_getField(struct,fieldName)
% c_getField - like getfield(), but allows nested field names
%
% Example:
%	a_struct = struct('outer',struct('inner',1))
%	c_getField(a_struct,'outer.inner')

	assert(ischar(fieldName))
	i = find(fieldName=='.',1,'first');
	if isempty(i)
		[varargout{1:nargout}] = struct.(fieldName);
	else
		% recursive call
		if length(struct)==1
			[varargout{1:nargout}] = c_getField(struct.(fieldName(1:i-1)),fieldName(i+1:end));
		else
			varargout = cell(1,length(struct));
			for iS = 1:length(struct)
				varargout{iS} = c_getField(struct(iS).(fieldName(1:i-1)),fieldName(i+1:end));
			end
		end
	end
end