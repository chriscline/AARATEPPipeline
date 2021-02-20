function [isValid, validatedMesh] = c_mesh_isValid(mesh,varargin)
% c_mesh_isValid - checks if a mesh struct is valid
%
% Mesh must at minimum specify vertices and face/volume elements. Other fields are optional
% E.g.
% 	mesh.Vertices: [N,3] matrix
% 	mesh.Faces: [M,3] matrix for triange surface mesh
% 	(or mesh.Elements: [M,4] matrix for tetredra volume mesh)
% May also include:
% 	mesh.VertConn: Brainstorm-like matrix describing vertex connectivity (for quickly finding neighboring vertices, etc.)
% 	mesh.SphericalVertices: [N,3] extra set of vertices, assumed to be 1-for-1 correspondence with
% 		mesh.Vertices and reflecting the same points projected out to a spherical space (often used for mapping meshes points across subjects or resolutions)
% 	mesh.isValidated: boolean indicating whether mesh has already been validated
% 	mesh.FaceData: [M,P] matrix or {Q}[M,P] cell array of data values for each surface element,
% 		where if a cell array, each cell is a separate set of data values
% 	mesh.FaceDataLabels: string (if mesh.FaceData is a matrix/vector), or cellstr (if mesh.FaceData is cell arary)
% 		with string(s) describing corresponding set of data in mesh.FaceData.
% 	mesh.ElementData: (same as mesh.FaceData but for volume mesh elements)
% 	mesh.ElementDataLabels: (similar to mesh.FaceDataLabels)
% 	mesh.VertexData: (same as mesh.FaceData but [N,P] with a value for each vertex)
% 	mesh.VertexDataLabels: (similar to mesh.FaceDataLabels)
% 	mesh.Label: string
% 	mesh.DistUnit: string
% May alternatively be a cell array of structs with the fields above
%


%%
	p = inputParser();
	p.addRequired('mesh');
	p.addParameter('doWarn',true,@islogical);
	p.addParameter('exhaustive',false,@islogical); % whether to do more computationally expensive checks
	p.addParameter('doAssertSurfaceMesh',false,@islogical);
	p.addParameter('doAssertVolumeMesh',false,@islogical);
	p.addParameter('doAllowMultiple',false,@islogical);
	p.addParameter('hasSphericalVertices',[],@islogical);
	p.parse(mesh,varargin{:});
	s = p.Results;
	
	validatedMesh = struct();
	
	if s.doAllowMultiple && iscell(mesh)
		assert(isvector(mesh));
		numMeshes = length(mesh);
		isValid = false(1,numMeshes);
		validatedMesh = mesh;
		for iM = 1:length(mesh)
			[isValid(iM), validatedMesh{iM}] = c_mesh_isValid(mesh{iM},varargin{:},'doAllowMultiple',false);
		end
		isValid = all(isValid);
		return;
	end
	
	if isstruct(mesh) && isfield(mesh,'isValidated') && mesh.isValidated
		 % set mesh.isValidated=true to skip future validation
		validatedMesh = mesh;
		isValid = true;
		return;
	end
	
	isValid = false;
	
	if ~isstruct(mesh)
		conditionalWarning(s.doWarn,'Not a struct');
		return;
	end
	
	meshFields = fieldnames(mesh);
	requiredFields = {'Vertices'};
	missingIndices = ~ismember(requiredFields, meshFields);
	if any(missingIndices)
		conditionalWarning(s.doWarn,'Missing fields: %s',c_toString(requiredFields(missingIndices)));
		return;
	end
	
	if ~isempty(mesh.Vertices)
		if ~ismatrix(mesh.Vertices)
			conditionalWarning(s.doWarn,'Unexpected Vertices type/dimensionality');
			return;
		end
		
		if ~ismember(size(mesh.Vertices,2),[2 3])
			conditionalWarning(s.doWarn,'Unexpected Vertices size');
			return;
		end
	end
	
	% for surface meshes only
	if s.doAssertSurfaceMesh
		assert(c_isFieldAndNonEmpty(mesh,'Faces'));
	end
	if c_isFieldAndNonEmpty(mesh,'Faces')
		if ~ismatrix(mesh.Faces)
			conditionalWarning(s.doWarn,'Unexpected Faces type/dimensionality');
			return;
		end
		
		if ~ismember(size(mesh.Faces,2),[3 4])
			conditionalWarning(s.doWarn,'Unexpected Faces size');
			return;
		end	
		
		if s.exhaustive
			if ~c_isinteger(mesh.Faces)
				conditionalWarning(s.doWarn,'Non-integer indices in Faces');
				return;
			end
			
			extremeVals = extrema(mesh.Faces(:));
			if extremeVals(1) < 1 || extremeVals(2) > size(mesh.Vertices,1)
				conditionalWarning(s.doWarn,'Invalid index in Faces');
				return;
			end
		end
	end
	
	% for volume meshes only
	if s.doAssertVolumeMesh
		assert(c_isFieldAndNonEmpty(mesh,'Elements'));
	end
	if c_isFieldAndNonEmpty(mesh,'Elements')
		if ~ismatrix(mesh.Elements)
			conditionalWarning(s.doWarn,'Unexpected Elements type/dimensionality');
			return;
		end
			
		if ~ismember(size(mesh.Elements,2),[4])
			conditionalWarning(s.doWarn,'Unexpected Elements size');
			return;
		end
		
		if s.exhaustive
			if ~c_isinteger(mesh.Elements)
				conditionalWarning(s.doWarn,'Non-integer indices in Elements');
				return;
			end
			
			extremeVals = extrema(mesh.Elements(:));
			if extremeVals(1) < 1 || extremeVals(2) > size(mesh.Vertices,1)
				conditionalWarning(s.doWarn,'Invalid index in Elements');
				return;
			end
		end
	end
	
	if isfield(mesh,'VertConn') && ~isempty(mesh.VertConn)
		if ~ismatrix(mesh.VertConn) || size(mesh.VertConn,1) ~= size(mesh.Vertices,1) || size(mesh.VertConn,2) ~= size(mesh.Vertices,1)
			conditionalWarning(s.doWarn,'Invalid VertConn size');
			return;
		end
		
		if ~islogical(mesh.VertConn)
			conditionalWarning(s.doWarn,'VertConn not logical');
			return;
		end
	end
	
	if ~isempty(s.hasSphericalVertices)
		if s.hasSphericalVertices && ~c_isFieldAndNonEmpty(mesh,'SphericalVertices')
			conditionalWarning(s.doWarn,'Does not have spherical vertices');
			return;
		elseif ~s.hasSphericalVertices && c_isFieldAndNonEmpty(mesh,'SphericalVertices')
			conditionalWarning(s.doWarn,'Has spherical vertices');
			return;
		elseif s.hasSphericalVertices
			if size(mesh.SphericalVertices,2)~=3
				conditionalWarning(s.doWarn,'Incorrect size of SphericalVertices');
				return;
			end
		end
	end
	
	if isfield(mesh,'DistUnit') && ~isempty(mesh.DistUnit)
		if ~ischar(mesh.DistUnit)
			conditionalWarning(s.doWarn,'DistUnit is not string');
		end
	end
	
	if isfield(mesh,'distUnit')
		conditionalWarning(s.doWarn,'field ''distUnit'' should actually be ''DistUnit''');
	end
	
	%TODO: add validation of *data* fields (FaceData, FaceDataLabels, ElementData, etc.)
	
	if nargout >= 2
		validatedMesh = mesh;
		validatedMesh.isValidated = true;
	end
	
	isValid = true;
end

function conditionalWarning(doWarn,varargin)
	if doWarn
		warning(varargin{:});
	end
end
	
	
	
	