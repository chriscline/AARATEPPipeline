classdef c_GUI_uix_VBox < c_GUI_handle
% c_GUI_uix_VBox - wrapper around uix.VBox() that automates handling of children heights

	properties
		DefaultHeight;
		DefaultFixedHeight;
		DefaultMinHeight;
	end
	
	properties(SetAccess=protected)
		hbs
		hb
		h_scroll;
		numChildren = 0;
		childHeights = [];
		childMinHeights = [];
		doAllowScroll;
	end
	
	properties(Dependent)
		MinHeight;
	end
	
	methods
		function o = c_GUI_uix_VBox(varargin)
			c_GUI_uix_VBox.addDependencies();
			
			p = inputParser();
			p.addParameter('Parent',[],@ishandle);
			p.addParameter('Spacing',5,@isscalar);
			p.addParameter('DefaultHeight',-1,@isscalar);
			p.addParameter('DefaultMinHeight',NaN,@isscalar);
			p.addParameter('doAllowScroll',false,@islogical);
			p.parse(varargin{:});
			s = p.Results;
			
			if isempty(s.Parent)
				warning('Parent not specified. You probably want to specify parent.');
			end
			
			for iF = 1:length(p.Parameters)
				if isprop(o,p.Parameters{iF})
					o.(p.Parameters{iF}) = s.(p.Parameters{iF});
				end
			end
			
			if o.doAllowScroll
				o.h_scroll = uix.ScrollingPanel('Parent',s.Parent);
				hbParent = o.h_scroll;
			else
				hbParent = s.Parent;
			end
				
			o.hb = uix.VBox(...
				'Parent',hbParent,...
				'Spacing',s.Spacing);
		end
		
		function handle = add(o,varargin)
			p = inputParser();
			p.addRequired('handle',@(x) c_ishandle(x) || isa(x,'function_handle'));
			p.addParameter('Height',o.DefaultHeight,@(x) isscalar(x) || isvector(x));
			p.addParameter('MinHeight',o.DefaultMinHeight,@(x) isscalar(x) || isvector(x));
			p.parse(varargin{:});
			s = p.Results;
			
			if length(s.Height)==length(s.MinHeight)
				% if MinHeight is NaN, copy value from Height
				indicesToCopy = isnan(s.MinHeight) & s.Height >= 0;
				indicesToZero = isnan(s.MinHeight) & s.Height < 0;
				s.MinHeight(indicesToCopy) = s.Height(indicesToCopy);
				s.MinHeight(indicesToZero) = 0;
			end
			
			%TODO: if nondefault height is specified, but default min height is used, 
			% and if default min height is greater than positive height, change minheight to match
			
			% if multiple handles, replicate specs to match size
			fields = {'Height','MinHeight'};
			for iF = 1:length(fields)
				if isscalar(s.(fields{iF})) && length(s.handle) > 1
					s.(fields{iF})= repmat(s.(fields{iF}),1,length(s.handle));
				end
				assert(length(s.(fields{iF}))==length(s.handle));
			end

			if isa(s.handle,'function_handle')
				handle = s.handle(o.hb); % call function with parent as first argument
				% (for cases where parent has to be set on construction)
			else
				handle = s.handle;
				handle.Parent = o.hb;
			end			
			o.numChildren = o.numChildren + length(handle);
			o.childHeights = cat(2,o.childHeights,s.Height);
			o.childMinHeights = cat(2,o.childMinHeights,s.MinHeight);
			
			o.updateHeights();
		end
		
		function setLast(o,varargin)
			p = inputParser();
			p.addParameter('Height',[],@(x) isscalar(x) || isvector(x));
			p.addParameter('MinHeight',[],@(x) isscalar(x) || isvector(x));
			p.parse(varargin{:});
			s = p.Results;
			
			if ~isempty(s.Height)
				o.childHeights(end-length(s.Height)+1:end) = s.Height;
			end
			
			if ~isempty(s.MinHeight)
				if length(s.Height)==length(s.MinHeight)
					% if MinHeight is NaN, copy value from Height
					indices = isnan(s.MinHeight) & s.Height >= 0;
					s.MinHeight(indices) = s.Height(indices);
				end
				o.childMinHeights(end-length(s.MinHeight)+1:end) = s.MinHeight;
			end
			
			o.updateHeights();
		end
		
		function minHeight = get.MinHeight(o)
			minHeight = sum(o.childMinHeights) + (o.numChildren-1)*get(o.hb,'Spacing');
		end
	end
	
	methods(Access=protected)
		function updateHeights(o)
			set(o.hb,...
				'Heights',o.childHeights,...
				'MinimumHeights',o.childMinHeights);
			
			if o.doAllowScroll
				set(o.h_scroll,'MinimumHeights',o.MinHeight);
			end
		end
	end
	
	methods(Static)
		function addDependencies()
			persistent pathModified;
			if isempty(pathModified)
				mfilepath=fileparts(which(mfilename));
				addpath(fullfile(mfilepath,'../'));
				c_GUI_initializeGUILayoutToolbox();
				pathModified = true;
			end
		end
	end
end