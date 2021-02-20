function s = c_cellToStruct(c,varargin)
% convert a cell array of named parameter arguments to a struct array

if nargin == 0 % example
	s = c_cellToStruct({'FirstArg',1,'SecondArg','example'});
	return
end

p = inputParser();
p.addParameter('RecursionLevel',1,@isscalar); % e.g. to convert an appropriately formatted cell array to a struct of structs, set RecursionLevel=2
p.parse(varargin{:});

if ~iscell(c)
	error('Input should be a cell array');
end

if isempty(c)
	s = struct();
	return;
end

if mod(length(c),2)~=0
	error('Cell should consist of pairs of (name, value) elements');
end

for i=1:length(c)/2
	j = i*2-1;
	if p.Results.RecursionLevel < 2
		s.(c{j}) = c{j+1};
	else
		s.(c{j}) = c_cellToStruct(c{j+1},'RecursionLevel',p.Results.RecursionLevel-1);
	end
end

end