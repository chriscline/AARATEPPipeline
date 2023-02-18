function handles = c_plot_scatter3(varargin)
% c_plot_scatter3 - 3D scatterplot
% Various improvements over built-in scatter3, including plotting of 3D spheres rather than 2D markers,
%  and various size, color, scaling, and labeling options.
%
% Syntax:
%   handles = c_plot_scatter3(Name,Value,...)
%
% (Name,Value) inputs:
%	'pts' - Array of Nx3 values representing XYZ coordinates
%	...
%
% Example: 
%   figure; 
%   c_plot_scatter3(rand(10,3),'ptColors',1:10); 
%   view(3);
%   axis equal;

p = inputParser();
p.addRequired('pts',@(x) ismatrix(x) && size(x,2)==3);
p.addParameter('ptSizes',[],@(x) isempty(x) || (isnumeric(x) && (isscalar(x) || isvector(x))))
p.addParameter('ptColors',[],@ismatrix);
p.addParameter('ptAlphas',[],@isvector);
p.addParameter('ptLabels',[],@iscellstr);
p.addParameter('doPlotLabels',false,@(x) islogical(x) || (ischar(x) && strcmpi(x,'auto'))); % 'auto'=plot if specified
p.addParameter('labelColors',[0.4 0.4 0.4],@ismatrix);
p.addParameter('labelLineColors',[0.4 0.4 0.4],@ismatrix);
p.addParameter('labelOrigin', [], @ismatrix);  % if empty, will use mean of pts
p.addParameter('labelOffset', 0.3, @isscalar);
p.addParameter('markerType','sphere',@(x) ischar(x) || c_mesh_isValid(x)); % valid: 'sphere', custom mesh, or any of scatter3's 'o+*.xsd^v><ph' or 'none'
												% if a custom mesh is specified, will be scaled by ptSize (i.e. should start as unit scale)
p.addParameter('ptRotations',[], @isnumeric); % [Nx3x3]: one rotation matrix per point, for specifying varying orientations of custom mesh markerType
p.addParameter('aspectRatio',[],@isvector); % for drawing 3D marker shapes such as sphere, what aspect ratio to use
p.addParameter('doRelativeSize',false,@(x) islogical(x) || ismember(x,{'limits','mindiff'}));
p.addParameter('normalizedSize',NaN,@isscalar);
p.addParameter('axis',[],@ishandle);
p.addParameter('sphereN',20,@isscalar);
p.addParameter('patchArgs',{'EdgeColor','none'},@iscell);
p.addParameter('scatter3Args',{},@iscell);
p.parse(varargin{:});
s = p.Results;

if isempty(s.axis)
	s.axis = gca;
end

if all(ismember({'ptSizes','doRelativeSize','normalizedSize'},p.UsingDefaults))
	s.doRelativeSize = true;
end

numPts = size(s.pts,1);

if isempty(s.aspectRatio)
	% assume axes will be equal aspect ratio
	s.aspectRatio = [1 1 1];
end

if isempty(s.ptSizes)
	s.ptSizes = 5;
end
if isscalar(s.ptSizes)
	s.ptSizes = repmat(s.ptSizes,numPts,1);
end

if ~isempty(s.ptColors)
	assert(isvector(s.ptColors) || size(s.ptColors,2) == 3);
	if isvector(s.ptColors) && length(s.ptColors) ~= 3
		s.ptColors = c_vec_makeColVec(s.ptColors);
	end
end

if ~isnan(s.normalizedSize)
	s.ptSizes = s.ptSizes / max(s.ptSizes) * s.normalizedSize;
end
if islogical(s.doRelativeSize)
	if s.doRelativeSize
		s.doRelativeSize = 'limits';
	else
		s.doRelativeSize = 'off';
	end
end
switch(s.doRelativeSize)
	case 'limits'
		% size specified in percent of size of largest dimension
		% (e.g. size of 1 corresponds to 1% of max xyz width, accounting for aspect ratio)
		xyzLim = extrema(s.pts,[],1);
		xyzWidths = diff(xyzLim,1,2)';
		effectiveWidths = s.aspectRatio.*xyzWidths;
		s.ptSizes = s.ptSizes * max(effectiveWidths) / 100;
	case 'mindiff'
		% size specified as fraction of smallest distance between any pair of points
		% (e.g. size of 1 corresponds to two closest points' markers just barely touching)
		minDist = min(pdist(s.pts));
		s.ptSizes = s.ptSizes * minDist/2;
	case 'off'
		% size specified in absolute units
		% do nothing
	otherwise
		error('Unsupported setting for doRelativeSize: %s',s.doRelativeSize)
end

if isvector(s.ptSizes)
	s.ptSizes = bsxfun(@times,c_vec_makeColVec(s.ptSizes),s.aspectRatio);
end

handles = [];

if ~isempty(s.ptLabels)
	if (islogical(s.doPlotLabels) && s.doPlotLabels) || (ischar(s.doPlotLabels) && strcmpi(s.doPlotLabels,'auto'))
		h1 = [];
		h2 = [];
		if isempty(s.labelOrigin)
			s.labelOrigin = nanmean(s.pts,1);
		end
		for iP = 1:numPts
			labelCoords = s.pts(iP,:) + (s.pts(iP,:)-s.labelOrigin)*s.labelOffset;
			args = c_mat_sliceToCell(labelCoords);
			h1(iP) = text(args{:},s.ptLabels{iP},...
				'Color',s.labelColors(mod(iP-1,size(s.labelColors,1))+1,:),...
				'Parent',s.axis);
			linePts = cat(1,labelCoords,s.pts(iP,:));
			args = c_mat_sliceToCell(linePts,2);
			h2(iP) = line(args{:},...
				'Color',s.labelLineColors(mod(iP-1,size(s.labelLineColors,1))+1,:),...
				'Parent',s.axis);
		end
		handles = cat(2,handles,h1,h2);
	end
end

customMarkerTypes = {'sphere'};

if ~isempty(s.ptAlphas)
	if ischar(s.markerType) && ~ismember(s.markerType,customMarkerTypes)
		warning('Alpha values not supported when using built-in scatter3. Ignoring.');
	else
		if isscalar(s.ptAlphas)
			s.ptAlphas = repmat(s.ptAlphas,numPts,1);
		else
			assert(length(s.ptAlphas)==numPts);
		end
	end
end


if ~ischar(s.markerType) && c_mesh_isValid(s.markerType)
	% custom mesh specified
	hms = gobjects(1,numPts);
	for iP = 1:numPts
		meshTransf = eye(4);
		if ~isempty(s.ptRotations)
			meshTransf(1:3,1:3) = s.ptRotations(iP,:,:);
		end
		meshTransf(1:3,1:3) = meshTransf(1:3,1:3) * diag(s.ptSizes(iP,:)); % TODO: check OOP
		meshTransf(1:3,4) = s.pts(iP,:);
		mesh = c_mesh_applyTransform(s.markerType, meshTransf);
		
		plotArgs = {'axis', s.axis};
		
		if ~isempty(s.ptColors)
			if size(s.ptColors,1)==1
				plotArgs = [plotArgs, 'faceColor', s.ptColors];
			else
				plotArgs = [plotArgs, 'faceColor', s.ptColors(iP,:)];
			end
		end
		
		if ~isempty(s.ptAlphas)
			plotArgs = [plotArgs, 'faceAlpha', s.ptAlphas(iP)];
		end
		
		hms(iP) = c_mesh_plot(mesh, plotArgs{:});
		
		if iP==1
			hold(s.axis, 'on');
		end
	end
	
	handles = cat(2, handles, hms);
	
	return;
else
	assert(isempty(s.ptRotations), 'Point rotations only supported when also specifying a custom mesh');
	
	if ismember(s.markerType,customMarkerTypes)
		% use custom plotting code
		switch s.markerType
			case 'sphere'
				[x,y,z] = sphere(s.sphereN);
				%spherePatch = surf2patch(x,y,z,'triangles');
				spherePatch = surf2patch(x,y,z);
				for iP = 1:numPts
					tmpPatch = spherePatch;
					tmpPatch.vertices = bsxfun(@times,tmpPatch.vertices,s.ptSizes(iP,:));
					tmpPatch.vertices = bsxfun(@plus,tmpPatch.vertices,s.pts(iP,:));
					patchArgs = {'parent',s.axis};
					if ~isempty(s.ptColors)
						if size(s.ptColors,1)==1
							patchArgs = [patchArgs,'FaceColor',s.ptColors];
						else
							%patchArgs = [patchArgs,'FaceColor',s.ptColors(iP,:)];
							patchArgs = [patchArgs,'FaceColor','flat','FaceVertexCData',s.ptColors(iP,:)];
						end
					end
					if ~isempty(s.ptAlphas)
						patchArgs = [patchArgs,'FaceAlpha',s.ptAlphas(iP)];
					end
					patchArgs = [patchArgs, s.patchArgs];

					h = patch(tmpPatch,patchArgs{:});
					handles = cat(2,handles,h);
					if iP==1
						hold(s.axis,'on');
					end
				end
			otherwise
				error('Invalid marker type');
		end
	else
		% use built-in scatter3
		xyzArgs = c_mat_sliceToCell(s.pts,2);
		ptColors = [0,0,0];
		if ~isempty(s.ptColors)
			ptColors = s.ptColors;
		end
		h = scatter3(xyzArgs{:},mean(s.ptSizes,2)*10,ptColors,s.markerType,...
			'parent',s.axis,...
			s.scatter3Args{:});
		handles = cat(2,handles,h);
	end
end
end
