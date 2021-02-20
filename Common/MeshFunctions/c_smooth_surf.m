function surf = c_smooth_surf(varargin)

persistent PathModified;
if isempty(PathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'../ThirdParty/FromBrainstorm/anatomy')); % requires brainstorm's tess_smooth function
	PathModified = true;
end

p = inputParser();
p.addRequired('surfStruct',@isstruct);
p.addParameter('smoothingScalar',0.5,@isscalar);
p.addParameter('doKeepSize',true,@islogical);
p.parse(varargin{:});
s = p.Results;

surf = s.surfStruct;

if s.smoothingScalar == 0
	return;
end

assert(isfield(surf,'Vertices'));
if ~isfield(surf,'VertConn')
	assert(isfield(surf,'Faces'));
	surf.VertConn = tess_vertconn(surf.Vertices,surf.Faces);
end

numIterations = ceil(300 * s.smoothingScalar * size(surf.Vertices,1) / 100000);

surf.Vertices = tess_smooth(surf.Vertices,...
	s.smoothingScalar,numIterations,surf.VertConn,s.doKeepSize);

end
