function [mesh, extra] = c_mesh_load(varargin)
% c_mesh_load - load a surface or volume mesh from a file
% Currently supports the following extensions: {.off,.fsmesh,.stl,.mat,.msh,.obj}

p = inputParser();
p.addRequired('input',@ischar); %file to load from
p.addParameter('doAllowMultiple',false,@islogical);
p.addParameter('gmshIndex', 9, @isscalar);
p.parse(varargin{:});
s = p.Results;

% assume input is a filename
assert(exist(s.input,'file')>0);

[pathstr, filename, extension] = fileparts(s.input);

mesh = struct();

extra = struct();

switch(lower(extension))
	case '.off'
		c_AddIso2MeshToPath();
		[mesh.Vertices, mesh.Faces] = readoff(s.input);
		
	case '.fsmesh'
		[mesh.Vertices, mesh.Faces] = freesurfer_read_surf(s.input);
		
	case '.stl'
		if ~exist('import_stl_fast','file')
			mfilepath=fileparts(which(mfilename));
			addpath(fullfile(mfilepath,'../ThirdParty/stlread'));
		end
		
		[mesh.Vertices, mesh.Faces, mesh.FaceNormals] = import_stl_fast(s.input,1);
		if isempty(mesh.Vertices) % assume empty because stl file was not ascii format
			% try reading with stlread instead
			[mesh.Vertices, mesh.Faces, mesh.FaceNormals] = stlread(s.input);
		end
		
	case '.mat'
		mesh = load(s.input);
		assert(isfield(mesh,'Vertices'));
		assert(isfield(mesh,'Faces'));
		
	case '.msh'
		%TODO: check whether ascii or binary format
		meshes = c_mesh_load_GMSHBinary(s.input);
		% GMSH files often contain multiple submeshes, so need to either
		% choose a single mesh from set or return all
		if s.doAllowMultiple
			mesh = meshes;
		else
 			i = s.gmshIndex;
			i = mod(i-1,length(meshes))+1;
			warning('Only returning mesh #%d of %d loaded meshes',i,length(meshes));
			mesh = meshes{i};
			if false 
				keyboard
				figure;
				h = [];
				for iM= 1:length(meshes)
					h(iM) = c_subplot(iM,length(meshes));
					c_mesh_plot(meshes{iM});
				end
				c_plot_linkViews(h);
			end
		end
		
	case '.obj'
		if ~exist('readObj','file')
			mfilepath=fileparts(which(mfilename));
			addpath(fullfile(mfilepath,'../ThirdParty/readObj'));
		end
		
		tmp = readObj(s.input);
		
		mesh = struct();
		mesh.Vertices = tmp.v;
		mesh.Faces = tmp.f.v;
		
		%TODO: also import vertex normals if available
		
	case '.gii'
		[~,~,secondaryExt] = fileparts(filename);
		%assert(strcmpi(secondaryExt,'.surf'),'Only ''.surf.gii'' gifti files are supported');
		% gifti surface format
		c_mesh_AddGIfTILibToPath();

		g = gifti(s.input);

		mesh = struct();
		mesh.Vertices = g.vertices;
		mesh.Faces = g.faces;
		if isfield(g,'mat')
			if 1
				% just export transform in extra metadata
				extra.transf = g.mat;
			else
				% apply transform immediately
				mesh.Vertices = c_pts_applyTransform(mesh.Vertices,'quaternion',g.mat);
			end
		end
		%TODO: also import face normals from g.normals if present
	
	case '.vtk'
		c_mesh_AddGraphToolboxToPath();
		
		mesh = struct();
		[vertices, faces] = read_vtk(s.input);
		mesh.Vertices = vertices';
		mesh.Faces = faces';
		
	case '.bnd'
		% mesh format used by Visor / ANT Neuro 
		% (plaintext metadata + list of vertices and faces)
		mesh = c_mesh_loadVisorBnd(s.input);
		
	otherwise
		error('Unsupported input extension');
end

end
