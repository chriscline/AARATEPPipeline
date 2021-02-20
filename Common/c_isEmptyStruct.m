function isEmpty = c_isEmptyStruct(struct)
	assert(isstruct(struct) || isobject(struct));
	isEmpty = isempty(struct) || isempty(fieldnames(struct));
end