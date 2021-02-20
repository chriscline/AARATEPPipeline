function pts = c_pts_applyTransform(varargin)
% originally based on https://nifti.nimh.nih.gov/pub/dist/src/niftilib/nifti1.h

p = inputParser();
p.addRequired('pts',@(x) isnumeric(x) && ismatrix(x) && size(x,2)==3);
p.addOptional('transfMatrix',[],@(x) ismatrix(x) && isequal(size(x),[4 4]));
p.addParameter('quaternion',[],@(x) ismatrix(x) && isequal(size(x),[4 4])); % deprecated 
p.parse(varargin{:});
s = p.Results;
%TODO: add support for other transform inputs (e.g. rotation matrix)

if ~isempty(s.quaternion)
	% handle deprecated input
	assert(isempty(s.transfMatrix));
	s.transfMatrix = s.quaternion;
end

if ~isempty(s.transfMatrix)
	if all(isnan(s.transfMatrix(:)))
		pts = nan(size(s.pts));
		return;
	end
	assert(isnumeric(s.transfMatrix));
	assert(all(abs(s.transfMatrix(4,1:3))<eps*1e2));
	assert(abs(abs(s.transfMatrix(4,4))-1)<eps*1e4);
end
	
pts = bsxfun(@plus,s.transfMatrix(1:3,1:3)*bsxfun(@times,s.pts,[1 1 s.transfMatrix(4,4)]).',s.transfMatrix(1:3,4)).';
end