function isFieldAndTrue = c_isFieldAndTrue(s,field)
	isFieldAndTrue = c_isField(s,field) && c_use(c_getField(s,field),@(val) islogical(val) && val);
end