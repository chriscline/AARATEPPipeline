function isEmpty = c_isEmptyOrEmptyStruct(struct)
	isEmpty = isempty(struct) || ((isstruct(struct) || isobject(struct)) && isempty(fieldnames(struct)));
end