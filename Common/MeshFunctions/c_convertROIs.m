function newROIs = c_convertROIs(varargin)
p = inputParser();
p.addRequired('ROIs',@isstruct);
p.addParameter('fromFormat','Brainstorm',@ischar);
p.addParameter('toFormat','eConnectome',@ischar);
p.parse(varargin{:});

ROIs = p.Results.ROIs;

if strcmpi('Brainstorm',p.Results.fromFormat) && strcmpi('eConnectome',p.Results.toFormat)
% convert between different formats (Brainstorm and econnectome)
	if ~isfield(ROIs,'nodeIndices')
		if ~isfield(ROIs,'Vertices')
			error('Unrecognized ROI format');
		end
		if isfield(ROIs,'Label')
			newROIs.labels = {ROIs.Label};
		end
		if isfield(ROIs,'Seed')
			newROIs.centerIndices = cell2mat({ROIs.Seed});
		end
		for r=1:length(ROIs)
			newROIs.nodeIndices{r} = ROIs(r).Vertices;
			newROIs.colors(r,:) = ROIs(r).Color;
		end
	end
else
	error('Unsupported conversion requested');
end

end