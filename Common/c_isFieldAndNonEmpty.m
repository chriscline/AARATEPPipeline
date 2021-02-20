function res = c_isFieldAndNonEmpty(struct,field)
	res = c_isField(struct,field) && ~c_isEmptyOrEmptyStruct(c_getField(struct,field));
end