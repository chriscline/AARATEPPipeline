function handle = c_mesh_plot(varargin)
% c_mesh_plot - plot a mesh
%
% Example:
%	mesh = c_mesh_load('example_mesh.stl')
%	figure; c_mesh_plot(mesh);

	if nargin==0, testfn(); return; end;
	
	p = inputParser();
	p.KeepUnmatched = true;
	p.addRequired('mesh',@(x) c_mesh_isValid(x,'doAllowMultiple',false));
	p.addParameter('distUnit',[]);
	p.parse(varargin{:});
	s = p.Results;
	extraArgs = c_structToCell(p.Unmatched);
	
	if ~isempty(s.distUnit)
		if ~c_isFieldAndNonEmpty(s.mesh,'DistUnit')
			warning('Plotting distUnit specified, but mesh.DistUnit is unknown. Assuming %s',c_toString(s.distUnit));
			s.mesh.DistUnit = s.distUnit;
		end
		
		s.mesh.Vertices = c_convertValuesFromUnitToUnit(s.mesh.Vertices,s.mesh.DistUnit,s.distUnit);
	end

	if c_isFieldAndNonEmpty(s.mesh,'Faces')
		% surface mesh
		defaultArgs = {...
		'edgeColor','none',...
		'faceAlpha',1,...
		'view',[],...
		'renderingMode',1};

		handle = c_plotSurface(s.mesh.Vertices, s.mesh.Faces,defaultArgs{:},extraArgs{:});
	
	elseif c_isFieldAndNonEmpty(s.mesh,'Elements')
		% volume mesh
		handle = c_mesh_plotVolume(s.mesh,extraArgs{:});
	else
		error('No face or volume elements found in mesh.l');
	end
	
end

function testfn()

	filetypes = '*.stl;*.fsmesh;*.off';
	[fn,fp] = uigetfile(filetypes,'Choose mesh file to plot');
	if fn == 0
		error('no file chosen');
	end
	filepath = fullfile(fp,fn);
	
	mesh = c_mesh_load(filepath);
	
	figure('name',fn);
	c_mesh_plot(mesh);
end