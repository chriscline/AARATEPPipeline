function mesh = c_mesh_applyTransform(varargin)
% c_mesh_applyTransform - apply a spatial transformation to a mesh

p = inputParser();
p.addRequired('mesh',@isstruct);
p.addOptional('transfMatrix',[],@(x) ismatrix(x) && isequal(size(x),[4 4]));
p.addParameter('quaternion',[],@ismatrix); % deprecated
p.parse(varargin{:});
s = p.Results;

mesh = s.mesh;

if ~isempty(s.quaternion)
	% handle deprecated input
	assert(isempty(s.transfMatrix));
	s.transfMatrix = s.quaternion;
end

mesh.Vertices = c_pts_applyTransform(mesh.Vertices,s.transfMatrix);

%TODO: also update face orientations if present, etc.

end