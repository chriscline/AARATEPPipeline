function sc = c_struct_createEmptyCopy(s)
% c_struct_createEmptyCopy - create empty copy of input struct, keeping the same fields

	assert(isstruct(s));
	fields = fieldnames(s);
	args = cell(1,length(fields)*2);
	args(1:2:end) = fields;
	for i=1:length(fields)
		args{i*2} = {};
	end
	sc = struct(args{:});
end