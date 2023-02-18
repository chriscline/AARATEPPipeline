function output = c_mat_sliceToCell(mat,dim)
% c_mat_sliceToCell - slice a matrix up into pieces and return each piece as an element in a cell array
% (e.g. for constructing x,y,z input to scatter3 from a single list of 3d coordinates)
% 
% Example:
%   pts = rand(10,3);
%   args = c_mat_sliceToCell(pts,2)
%   figure; scatter3(args{:});

if nargin < 2
	dim = c_findFirstNonsingletonDimension(mat);
end

%assert(isnumeric(mat) || ischar(mat)); % not actually necessary, could be removed 

if isscalar(dim)
	numSlices = size(mat,dim);
	output = cell(1,numSlices);
	permOrder = 1:ndims(mat);
	permOrder = circshift(permOrder,-dim+1,2);
	mat = permute(mat,permOrder);
	origSize = size(mat);
	mat = reshape(mat,origSize(1),prod(origSize(2:end)));
	for i=1:numSlices
		sliceMat = mat(i,:);
		sliceMat = reshape(sliceMat,[1, origSize(2:end)]);
		sliceMat = ipermute(sliceMat,permOrder);
		output{i} = sliceMat;
	end
elseif length(dim)==2
	output = cell(paren(size(mat),dim));
	permOrder = 1:ndims(mat);
	permOrder = [permOrder(dim), permOrder(~ismember(1:ndims(mat),dim))];
	mat = permute(mat, permOrder);
	origSize = size(mat);
	mat = reshape(mat,[origSize(1:length(dim)), numel(mat)/prod(origSize(1:length(dim)))]);
	for iX=1:origSize(1)
		for iY=1:origSize(2)
			sliceMat = mat(iX,iY,:);
			sliceMat = reshape(sliceMat,[1, 1, origSize(3:end)]);
			sliceMat = ipermute(sliceMat,permOrder);
			output{iX,iY} = sliceMat;
		end
	end
else
	error('not implemented');
end
	
end