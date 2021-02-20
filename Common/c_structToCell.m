function c = c_structToCell(s)
% convert a struct array to a cell array of named parameter arguments

if nargin == 0 % example
	c = c_structToCell(struct('FirstArg',1,'SecondArg','example'));
	return
end

if ~isstruct(s)
	error('Input should be a struct array');
end

c = {};
fieldNames = fieldnames(s);
for i=1:length(fieldNames)
	c = [c, fieldNames{i}, {s.(fieldNames{i})}];
end

end