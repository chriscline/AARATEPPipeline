function handle = c_plotSurface(varargin)
	p = inputParser();
	p.addRequired('nodes',@isnumeric);
	p.addRequired('faces',@isnumeric);
	p.addParameter('nodeData',[],@isnumeric);
	p.addParameter('faceData',[],@isnumeric);
	p.addParameter('elemData',[],@isnumeric);
	p.addParameter('renderingMode',0,@isscalar);
	p.addParameter('doInterpolate',true,@islogical);
	p.addParameter('edgeColor',[0 0 0],@(x) ischar(x) || isvector(x));
	p.addParameter('faceColor',[0.7 0.7 0.9],@isvector);
	p.addParameter('faceAlpha',0.9,@(x) isscalar(x) || isvector(x));
	p.addParameter('faceoffsetbias', 0);
	p.addParameter('axis',[],@ishandle);
	p.addParameter('view',[-72,40]);
	p.addParameter('doClip',false,@islogical);
	p.parse(varargin{:});
	s = p.Results;
	
	if isempty(s.axis)
		s.axis = gca;
	end
	
	s.axis.Clipping = c_if(s.doClip,'on','off');
	
	if size(s.faces,2)~=3
		error('faces should m x 3, each row corresponding to a triangle.');
	end
	
	if ~isempty(s.nodeData) && ~ismember('faceColor',p.UsingDefaults)
		error('Both face color and nodeData specified, contradicting.');
	end
	
	if ~isempty(s.elemData) 
		% elemData or faceData can be used interchangeably, but should not both be specified
		assert(isempty(s.faceData));
		s.faceData = s.elemData;
		s.elemData = [];
	end
	
	if ~isempty(s.nodeData) && ~isempty(s.faceData)
		error('Both faceData and nodeData specified.');
	end
	
	if ~isempty(s.nodeData)
		assert(size(s.nodeData,1)==size(s.nodes,1));
		doColorByNode = true;
		if ismember('edgeColor',p.UsingDefaults)
			s.edgeColor = 'none';
		end
		faceOrNodeData = s.nodeData;
	else
		doColorByNode = false;
	end
		
	if ~doColorByNode
		if ~isempty(s.faceData)
			assert(size(s.faceData,1) == size(s.faces,1));
			faceOrNodeData = s.faceData;
			if ismember('edgeColor',p.UsingDefaults)
				s.edgeColor = 'none';
			end
		else
			faceOrNodeData = repmat(s.faceColor,size(s.nodes,1),1);
		end
	end
	
	if s.doInterpolate && doColorByNode
		faceColorStr = 'interp';
	else
		faceColorStr = 'flat';
	end
	
	if size(faceOrNodeData,2)==1
		handle = trisurf(s.faces,s.nodes(:,1),s.nodes(:,2),s.nodes(:,3),faceOrNodeData,...
			'FaceColor',faceColorStr,...
			'faceoffsetbias',s.faceoffsetbias,...
			'EdgeColor',s.edgeColor,...
			'Parent',s.axis);
		s.axis.Clipping = c_if(s.doClip,'on','off');
		
	elseif size(faceOrNodeData,2)==3
		% rgb values specified
		handle = patch('Faces',s.faces,'Vertices',s.nodes,'FaceVertexCData',faceOrNodeData,...
			'FaceColor',faceColorStr,...
			'faceoffsetbias',s.faceoffsetbias,...
			'EdgeColor',s.edgeColor,...
			'Parent',s.axis);
	else
		error('unexpected data size');
	end
	
	% handle alpha value(s)
	if isscalar(s.faceAlpha)
		% single alpha value for entire surface
		faceAlpha = s.faceAlpha;
	else
		if length(s.faceAlpha) == size(s.nodes,1)
			% individual alpha value for each vertex
			faceAlpha = 'interp';
		elseif length(s.faceAlpha) == size(s.faces,1)
			% individual alpha value for each face
			faceAlpha = 'flat';
		else
			error('Invalid alpha value');
		end
		set(handle,'FaceVertexAlphaData',s.faceAlpha);
	end
	set(handle,'FaceAlpha',faceAlpha);
	
	axis(s.axis,'equal');
	
	axis(s.axis,'off');
	
	material(s.axis,'dull');
	
	if s.renderingMode == 1
		lighting(s.axis,'gouraud');
	elseif s.renderingMode == 2
		lighting(s.axis,'phong');
	end
	if s.renderingMode > 0
		% delete any previous lights
		htmp = findobj(s.axis,'Type','light');
		if ~isempty(htmp)
			delete(htmp);
		end
		
		% change options to provide more depth to rendering, but much slower for zooming/rotating plot
		lightColor = [0.5 0.5 0.5];
		
		light('Parent',s.axis,'Position',[0 1 1]*2,'Style','infinite','Color',lightColor);
		light('Parent',s.axis,'Position',[-1 -1 1]*2,'Style','infinite','Color',lightColor);
%		light('Parent',s.axis,'Position',[1 -1 1]*2,'Style','infinite','Color',lightColor);
		light('Parent',s.axis,'Position',[0 0 -1]*2,'Style','infinite','Color',lightColor);
		light('Parent',s.axis,'Position',[1 -1 1]*2,'Style','infinite','Color',lightColor);
% 		light('Parent',s.axis,'Position',[-1 1 -1]*2,'Style','local','Color',lightColor);
% 		light('Parent',s.axis,'Position',[1 -1 -1]*2,'Style','local','Color',lightColor);
% 		light('Parent',s.axis,'Position',[-1 -1 -1]*2,'Style','local','Color',lightColor);
	end
	
% 	xlabel(s.axis,'X');
% 	ylabel(s.axis,'Y');
% 	zlabel(s.axis,'Z');

	if ~isempty(s.view)
		view(s.axis,s.view);
	end

end