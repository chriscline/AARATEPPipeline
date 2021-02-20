function mappedArray = c_struct_mapToArray(structToMap,fieldMap)
% c_struct_mapToArray - extract fields from a struct (or struct array) into an array
%
% Examples:
%	a_struct = struct('X',1,'Y',2,'Z',3);
%	a = c_struct_mapToArray(a_struct,{'X','Y','Z'})
%	b_struct = struct('X',{1 4},'Y',{2 5},'Z',{3 6});
%	b = c_struct_mapToArray(b_struct,{'X','Y','Z'})
%
% See also: c_array_mapToStruct


if nargin == 0, testfn(); return; end;
if c_isEmptyStruct(structToMap), mappedArray = []; return; end;
assert(isstruct(structToMap) || all(ishandle(structToMap(:))) || all(isobject(structToMap(:))));
assert(iscell(fieldMap));
assert(length(fields(structToMap))>=numel(fieldMap));

if length(structToMap)~=numel(structToMap)
	% non-vector struct
	assert(length(fieldMap)==1,'For non-vector struct arrays, only a single field is supported');
	mappedArray = [structToMap.(fieldMap{1})];
	valSize = size(structToMap(1).(fieldMap{1}));
	assert(all(arrayfun(@(s) isequal(size(s.(fieldMap{1})),valSize),structToMap(:))));
	mappedArray = reshape(mappedArray,[size(structToMap) valSize]);
	return;
end

assert(length(structToMap)==numel(structToMap)); % only vector arrays of structs are supported below

numVars = numel(fieldMap);
numStructs = length(structToMap);
%varSize = size(structToMap(1).(fieldMap{1})); % assume that all variables have the same size
varSize = size(c_getField(structToMap(1),fieldMap{1}));
numSubvars = prod(varSize);
if numSubvars > 1
	% vars are not scalars
	% merge dimensions of structToMap with dimensions of variable.
	minNDim = min(ndims(fieldMap),length(varSize));
	maxNDim = max(ndims(fieldMap),length(varSize));
	nonsingletonDims_fieldMap = size(fieldMap)~=1;
	nonsingletonDims_var = varSize~=1;
	% require that there are no shared non-singleton dimensions for proper merging
	assert(~any(paren(nonsingletonDims_fieldMap,1:minNDim) & paren(nonsingletonDims_var,1:minNDim)));
	origSize = ones(1,maxNDim);
	origSize(nonsingletonDims_fieldMap) = paren(size(fieldMap),nonsingletonDims_fieldMap);
	origSize(nonsingletonDims_var) = paren(varSize,nonsingletonDims_var);
else
	nonsingletonDims_var = [];
	nonsingletonDims_fieldMap =size(fieldMap)~=1;
	origSize = size(fieldMap);
end

extraDim = find(origSize==1,1,'first');
if isempty(extraDim)
	extraDim = length(origSize)+1;
end

reshapedVarSize = [1,prod(varSize)];

finalSize = origSize;
finalSize(extraDim) = numStructs;

intermedSize = [finalSize(extraDim), finalSize((1:length(finalSize)~=extraDim))];
permOrder = [2:extraDim, 1, extraDim+1:length(finalSize)]; % to go from intermedSize to finalSize

reshapedFieldMap = reshape(fieldMap,1,numVars);
% use first array to initialize array, assuming everything is of the same type
%templateVar = structToMap(1).(reshapedFieldMap{1})(1);
templateVar = paren(c_getField(structToMap(1),reshapedFieldMap{1}),1);
mappedArray = repmat(templateVar,numStructs,numVars,numSubvars);
for iS=1:numStructs
	for iV=1:numVars
		%mappedArray(iS,iV,:) = structToMap(iS).(reshapedFieldMap{iV});
		mappedArray(iS,iV,:) = c_getField(structToMap(iS),reshapedFieldMap{iV});
	end
end

% expand subvars (if any)
mappedArray = reshape(mappedArray,[numStructs,numVars,varSize(nonsingletonDims_var)]);
subvarDims = 3:max(ndims(mappedArray),3);
varDims = 2;

% swap var dims to end
mappedArray = permute(mappedArray,[1,subvarDims,varDims]);
subvarDims = 1+(1:length(subvarDims));
varDims = subvarDims(end)+1;

% expand vars (if any)
prevNumDims = max(ndims(mappedArray),3);
mappedArray = reshape(mappedArray,...
	[numStructs,paren(size(mappedArray),subvarDims),paren(size(fieldMap),nonsingletonDims_fieldMap)]);
varDims = prevNumDims:max(ndims(mappedArray),prevNumDims);

% permute to get final array with dimensions in correct order
newSubvarDims = find(nonsingletonDims_var);
newVarDims = find(nonsingletonDims_fieldMap);
if isempty(newVarDims)
	newVarDims = 2;
	while ismember(newVarDims,newSubvarDims)
		newVarDims = newVarDims + 1;
	end
end
if isempty(newSubvarDims)
	newSubvarDims = 3;
	if newSubvarDims == extraDim, newSubvarDims = 4;
	end
end
permOrder = zeros(1,length(finalSize));
permOrder(newSubvarDims) = subvarDims;
permOrder(newVarDims) = varDims;
permOrder(extraDim) = 1;
tmp = permute(mappedArray,permOrder);
mappedArray = tmp;
end


function testfn()

%% very simple
s = struct('Loc_X',1,'Loc_Y',2);
res = c_struct_mapToArray(s,{'Loc_X'});
expectedRes = [1];
assert(isequal(res,expectedRes));

%% simple
s = struct('Loc_X',1,'Loc_Y',2,'Loc_Z',3);
res = c_struct_mapToArray(s,{'Loc_X','Loc_Y','Loc_Z'});
expectedRes = [1,2,3];
assert(isequal(res,expectedRes));

%% struct array of scalar values 
s1 = struct('Loc_X',1,'Loc_Y',2,'Loc_Z',3);
s2 = struct('Loc_X',4,'Loc_Y',5,'Loc_Z',6);
s = [s1, s2];
res = c_struct_mapToArray(s,{'Loc_X','Loc_Y','Loc_Z'});
expectedRes = [1,2,3; 4,5,6];
assert(isequal(res,expectedRes));

%% struct array of vector values
s1 = struct('Loc_X',[1 1],'Loc_Y',[2 2],'Loc_Z',[3 3]);
s2 = struct('Loc_X',[4 4],'Loc_Y',[5 5],'Loc_Z',[6 6]);
s = [s1, s2];
res = c_struct_mapToArray(s,{'Loc_X';'Loc_Y';'Loc_Z'});
expectedRes = cat(3,[1,1;2,2;3,3],[4,4;5,5;6,6]);
assert(isequal(res,expectedRes));

s1 = struct('Loc_X',[1 1]','Loc_Y',[2 2]','Loc_Z',[3 3]');
s2 = struct('Loc_X',[4 4]','Loc_Y',[5 5]','Loc_Z',[6 6]');
s = [s1, s2];
res = c_struct_mapToArray(s,{'Loc_X','Loc_Y','Loc_Z'});
expectedRes = cat(3,[1,2,3;1,2,3],[4,5,6;4,5,6]);
assert(isequal(res,expectedRes));

%% single-field from struct array of vector values
s1 = struct('Loc_X',[1 2 3]);
s2 = struct('Loc_X',[4 5 6]);
s = [s1, s2];
res = c_struct_mapToArray(s,{'Loc_X'});
expectedRes = [1 2 3; 4 5 6];
assert(isequal(res,expectedRes));

%% struct array mapped to matrix
s1 = struct('Loc_X',1,'Loc_Y',2,'Loc_Z',3,'Loc_T',4);
s2 = struct('Loc_X',5,'Loc_Y',6,'Loc_Z',7,'Loc_T',8);
s3 = struct('Loc_X',9,'Loc_Y',10,'Loc_Z',11,'Loc_T',12);
s = [s1, s2, s3];
res = c_struct_mapToArray(s,{'Loc_X','Loc_Y'; 'Loc_Z','Loc_T'});
expectedRes = cat(3,[1 2; 3 4],[5 6; 7 8],[9 10; 11 12]);
assert(isequal(res,expectedRes));

%% struct array with variables of object type
obj = datetime();
s1 = struct('dt',obj);
s2 = struct('dt',obj + seconds(1));
s = [s1 s2];
res = c_struct_mapToArray(s,{'dt'});
expectedRes = [obj, obj+seconds(1)]';
assert(isequal(res,expectedRes));

%%
c_saySingle('Tests passed');

end