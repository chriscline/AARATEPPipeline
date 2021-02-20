classdef c_GUI_Tiler < c_GUI_handle
% 	c_GUI_Tiler - Class to manage tiling of plots or other graphics in a figure window.
% 	
% 	  Example:
% 			hf = figure;
% 			ht = c_GUI_Tiler('Parent', hf, 'Title', 'Example Tiler');
% 			ht.addAxes();
% 			plot(1:10,rand(10,1));
% 			ht.addAxes('title', 'Tile title', 'relWidth', 2);
% 			plot(1:20, rand(20,1));
% 			
			
	
	properties
		numRows
		numCols
		TitleHeight;
		SideTitleWidth
		SideTitleHeight
		doTranspose;
	end
	
	properties(Dependent)
		Parent
		Title
		SideTitle
		ChildrenRelWidths
		ChildrenRelHeights
	end
	
	properties(SetAccess=protected)
		ChildTitleHeight
		ChildrenAxes = gobjects(0); % this does not necessarily match length or order of Children
	end
	
	properties(Dependent, SetAccess=protected)
		Children
		ChildrenRoots
		ChildrenLabels
		numChildren
		numActiveChildren
		numInactiveChildren
		activeChildren
		inactiveChildren
		activeChildrenRoots
		activeChildMetadata
		autoRetilingPaused
	end
	
	properties(Access=protected)
		hc
		hc_hidden
		hcPlusTitle
		h_title
		h_sideTitle
		h_sideTitleVBox
		isConstructed = false;
		doAutoRetile
		autoRetilingPauseStackCounter = 0;
		autoRetileIsPending = false;
		childMetadata;
		childMetadataTemplate = struct(...
			'handle',[],...
			'h_title',[],...
			'h_root', [],...
			'label','',...
			'isActive',[],...
			'relWidth',[],...
			'relHeight',[]);
		currentChildPositions = [];
	end
	properties(Dependent,Access=protected)
		childIsActive
	end
	
	methods
		function o = c_GUI_Tiler(varargin)
			
			c_GUI_Tiler.addDependencies();
			
			p = inputParser();
			p.addParameter('Parent',[],@c_ishandle);
			p.addParameter('numRows',[],@(x) isscalar(x) || isempty(x));
			p.addParameter('numCols',[],@(x) isscalar(x) || isempty(x));
			p.addParameter('doAutoRetile',true,@islogical);
			p.addParameter('TitleHeight',30,@isscalar); % in pixels
			p.addParameter('ChildTitleHeight',20, @isscalar); % in pixels
			p.addParameter('Title','',@ischar);
			p.addParameter('SideTitleHeight',30,@isscalar);
			p.addParameter('SideTitleWidth',120,@isscalar);
			p.addParameter('SideTitle','',@ischar);
			p.addParameter('doTranspose',false,@islogical);
			p.parse(varargin{:});
			s = p.Results;
			
			if isempty(s.Parent)
				s.Parent = gcf;
			end
			
			o.childMetadata = c_struct_createEmptyCopy(o.childMetadataTemplate);
			
			o.hcPlusTitle = uix.Grid('Parent',s.Parent,...
				'UserData',struct('c_GUI_Tiler',o));
			o.addContextMenu_(o.hcPlusTitle);
			uix.Empty('Parent', o.hcPlusTitle);
			o.h_sideTitleVBox = uix.VBox('Parent', o.hcPlusTitle);
			uix.Empty('Parent', o.h_sideTitleVBox);
			o.h_sideTitle = c_GUI_Text('Parent', o.h_sideTitleVBox,...
				'FontWeight', 'bold',...
				'MaxFontSize', 12);
			uix.Empty('Parent', o.h_sideTitleVBox);
			set(o.h_sideTitleVBox,'Heights', [-1 s.SideTitleHeight -1]);
			o.addContextMenu_(o.h_sideTitle.th);
			o.h_title = c_GUI_Text('Parent',o.hcPlusTitle,...
				'FontWeight','bold',...
				'MaxFontSize',12);
			o.addContextMenu_(o.h_title.th);
			
			% create main container
			o.hc = uipanel('Parent',o.hcPlusTitle,...
				'BorderType','none'); 
			o.addContextMenu_(o.hc);
			
			set(o.hcPlusTitle, 'Heights', [0 -1], 'Widths', [0 -1]);
			
			o.hc_hidden = uipanel('Parent',s.Parent,...
				'Visible','off');
			
			for iF = 1:length(p.Parameters)
				if isprop(o,p.Parameters{iF})
					o.(p.Parameters{iF}) = s.(p.Parameters{iF});
				end
			end
			
			if isnumeric(s.Parent)
				s.Parent =  handle(s.Parent);
			end
			
			o.addContextMenu_(s.Parent);
			
			o.addContextMenu_();
			
			o.isConstructed = true;
			
			o.autoRetile();
		end
		
		%%
		
		function handle = add(o,varargin)
			p = inputParser();
			p.addOptional('handle',[],@(x) c_ishandle(x) || isa(x,'function_handle'));
			p.addParameter('label','',@ischar);
			p.addParameter('relWidth',1,@isscalar);
			p.addParameter('relHeight',1,@isscalar);
			p.addParameter('title', '', @ischar);
			p.parse(varargin{:});
			s = p.Results;
			
			if isempty(s.handle)
				s.handle = uipanel('BorderType','none'); % empty container
			end
			
			o.addContextMenu_(s.handle);
			
			doAllowChildTitles = true;
			
			if doAllowChildTitles
				h_childRoot = uix.VBox('Parent', o.hc);
				h_title = c_GUI_Text('Parent', h_childRoot,...
					'String', s.title,...
					'FontWeight', 'bold',...
					'MaxFontSize', 10);
				parent = h_childRoot;
				if isempty(s.label)
					s.label = s.title;
				end
			else
				assert(isempty(s.title), 'Not supported unless child titles are enabled');
				parent = o.hc;
			end
			
			if isa(s.handle,'function_handle')
				handle = s.handle(parent); % call function with parent as first argument
			else
				handle = s.handle;
				handle.Parent = parent;
			end
			
			if doAllowChildTitles
				set(h_childRoot, 'Heights', [c_if(isempty(s.title), 0, o.ChildTitleHeight), -1]);
			end
			
			assert(~ismember(handle,o.Children),'Handle is a duplicate');
			
			if ~isempty(s.label)
				assert(~ismember(s.label,o.ChildrenLabels),'Label is a duplicate');
			end
			
			newChild = o.childMetadataTemplate;
			newChild.handle = handle;
			if doAllowChildTitles
				newChild.h_title = h_title;
				newChild.h_root = h_childRoot;
			else
				newChild.h_root = handle;
			end
			newChild.isActive = true;
			newChild.label = s.label;
			newChild.relWidth = s.relWidth;
			newChild.relHeight = s.relHeight;
			
			o.childMetadata(end+1) = newChild;
			
			if isequal(handle.Type,'axes')
				warning(['May be preferable to add axis using ''addAxes'' instead of ''add''',...
					', so that it is wrapped in container']);
			end
			
			%TODO: add option to "pop out" entire panel in contex menu like in c_subplot
			
			o.autoRetile();
		end
		
		function handle = addAxes(o,varargin)
			% contain each added axis in its own uipanel so that legends stay grouped, etc.
			
			p = inputParser();
			p.KeepUnmatched = true;
			p.addOptional('handle',[],@(x) isgraphics(x) && isequal(x.Type,'axes'));
			p.parse(varargin{:});
			s = p.Results;
		
			extraArgs = c_structToCell(p.Unmatched);
			hp = o.add(uipanel('BorderType','none'),extraArgs{:});
			
			if isempty(s.handle)
				s.handle = axes('Parent',hp);
				axes(s.handle);
			else
				s.handle.Parent = hp;
			end
			
			o.addContextMenu_(s.handle);
			
			o.ChildrenAxes(end+1) = s.handle;
			
			handle = s.handle;
		end
		
		function reorder(o,varargin)
			p = inputParser();
			p.addParameter('byIndex',@isvector);
			p.parse(varargin{:});
			s = p.Results;
			
			assert(~isempty(s.byIndex)); % for now, this is the only supported method
			assert(~islogical(s.byIndex),'Only numeric indexing supported');
			assert(all(ismember(s.byIndex,1:o.numChildren)));
			assert(all(ismember(1:o.numChildren,s.byIndex)),'Specified ordering is incomplete (some missing)');
			
			o.pauseAutoRetiling();
			o.childMetadata = o.childMetadata(s.byIndex);
			o.autoRetileIsPending = true;
			o.resumeAutoRetiling();
		end
		
		function setActive(o,varargin)
			p = inputParser();
			p.addOptional('isActive',true,@islogical);
			p.addParameter('byHandle',[],@c_ishandle);
			p.addParameter('byIndex',[],@isvector);
			p.addParameter('byLabel','',@(x) ischar(x) || iscellstr(x));
			p.parse(varargin{:});
			s = p.Results;
			
			isActive = o.childIsActive;
			
			if ~isempty(s.byIndex)
				assert(isempty(s.byLabel));
				assert(isempty(s.byHandle));
				if islogical(s.byIndex)
					s.byIndex = find(s.byIndex);
				end
				assert(all(s.byIndex <= o.numChildren));
				isActive(s.byIndex) = s.isActive;
				
			elseif ~isempty(s.byLabel)
				assert(isempty(s.byHandle));
				assert(all(ismember(s.byLabel,o.ChildrenLabels)),'Label not found');
				if ischar(s.byLabel)
					s.byLabel = {s.byLabel};
				end
				indices = c_cell_findMatchingIndices(s.byLabel,o.ChildrenLabels);
				isActive(indices) = s.isActive;
				
			elseif ~isempty(s.byHandle)
				assert(length(s.byHandle)==1); %TODO: add support for multiple
				indices = o.getIndexOfHandle(s.byHandle);
				isActive(indices) = s.isActive;
				
			else
				if length(s.isActive) == o.numChildren
					isActive = s.isActive;
				else
					error('Must specify one of byHandle, byLabel, or byIndex, or specify vector isActive directly');
				end
			end
			
			for iC = 1:o.numChildren
				if isActive(iC) == o.childIsActive(iC)
					% no change needed
					continue;
				end
				o.childMetadata(iC).isActive = isActive(iC);
				if isActive(iC)
					o.ChildrenRoots(iC).Parent = o.hc;
				else
					o.ChildrenRoots(iC).Parent = o.hc_hidden;
				end
			end
			
			o.autoRetile();
		end
		
		function hts = getTilersInChildren(o)
			hcs = findobj(o.Children,'Type','uicontainer');
			hts = c_GUI_Tiler.empty();
			for i=1:length(hcs)
				if c_isFieldAndNonEmpty(hcs(i),'UserData.c_GUI_Tiler')
					hts(end+1) = hcs(i).UserData.c_GUI_Tiler;
				end
			end
		end
		
		
		%%
		function pauseAutoRetiling(o)
			o.autoRetilingPauseStackCounter = o.autoRetilingPauseStackCounter + 1;
		end
		
		function resumeAutoRetiling(o)
			assert(o.autoRetilingPaused);
			o.autoRetilingPauseStackCounter = o.autoRetilingPauseStackCounter - 1;
			
			if ~o.autoRetilingPaused && o.autoRetileIsPending
				o.autoRetile();
			end
		end
			
		%%
		function retile(o,varargin) %#ok<*PROPLC>
			if ~o.isConstructed
				return;
			end
			
			numChildren = o.numActiveChildren;
			
			if numChildren == 0
				return;
			end
			
			numRows = o.numRows; 
			numCols = o.numCols;
			
			if isempty(numRows) && isempty(numCols)
				% auto calculate grid size
				%TODO: also factor in container aspect ratio when generating grid size
				numCols = ceil(sqrt(numChildren));
				numRows = ceil(numChildren / numCols); 
			elseif isempty(numRows)
				numRows = ceil(numChildren / numCols);
			elseif isempty(numCols)
				numCols = ceil(numChildren / numRows);
			else
				% grid size fixed
				assert(numChildren <= o.numRows * o.numCols,...
					'Fixed grid size too small for number of children');
			end
			
			iC_perRow = cell(1,numRows);
			iC_perCol = cell(1,numCols);
			rowNum = 1;
			colNum = 0;
			for iC = 1:numChildren
				colNum = colNum+1;
				if colNum > numCols
					colNum = 1;
					rowNum = rowNum + 1;
					assert(rowNum <= numRows);
				end
				iC_perRow{rowNum}(end+1) = iC;
				iC_perCol{colNum}(end+1) = iC;
			end
			rowHeights = cellfun(@(iCs) c_if(~isempty(iCs),max([o.childMetadata(iCs).relHeight]),0),iC_perRow);
			colWidths = cellfun(@(iCs) c_if(~isempty(iCs),max([o.childMetadata(iCs).relWidth]),0),iC_perCol);
			
			rowNorm = sum(rowHeights);
			colNorm = sum(colWidths);
			rowHeights = rowHeights / rowNorm;
			colWidths = colWidths / colNorm;
			
			rowNum = 1;
			colNum = 0;
			
			activeChildMetadata = o.activeChildMetadata;
			
			o.currentChildPositions = nan(numChildren, 2);
			for iC = 1:numChildren
				colNum = colNum + 1;
				if colNum > numCols
					colNum = 1;
					rowNum = rowNum + 1;
					assert(rowNum <= numRows);
				end
				width = min(colWidths(colNum),o.childMetadata(iC).relWidth/colNorm);
				height = min(rowHeights(rowNum),o.childMetadata(iC).relHeight/rowNorm);
				pos = [sum(colWidths(1:colNum-1))+(colWidths(colNum)-width)/2,1-sum(rowHeights(1:rowNum-1))-height-(rowHeights(rowNum)-height)/2,width,height];
				
				if o.doTranspose
					newPos = pos;
					newPos(1) = 1-pos(2)-pos(4);
					newPos(2) = 1-pos(1)-pos(3);
					newPos([3 4]) = pos([4 3]);
					pos = newPos;
					
				end
				
				activeChildMetadata(iC).h_root.Units = 'normalized';
				activeChildMetadata(iC).h_root.Position = pos;
				o.currentChildPositions(iC,:) = [rowNum, colNum];
				
				if ~isempty(activeChildMetadata(iC).h_title) && ~isempty(activeChildMetadata(iC).h_title.String)
					activeChildMetadata(iC).h_title.queueUpdateFontSize();
				end
				
				if true
					% if any children have child titles, leave space for these titles in all children
					% (to ensure uniform sizing across rows)
					if any(arrayfun(@(md) ~isempty(md.h_title) && ~isempty(md.h_title.String), activeChildMetadata))
						if activeChildMetadata(iC).h_root.Heights(1) ~= o.ChildTitleHeight
							set(activeChildMetadata(iC).h_root, 'Heights', [o.ChildTitleHeight, -1]);
						end
					else
						if activeChildMetadata(iC).h_root.Heights(1) ~= 0
							set(activeChildMetadata(iC).h_root, 'Heights', [0, -1]);
						end
					end
				end
			end
			
			if ~isempty(o.SideTitle)
				o.h_sideTitle.queueUpdateFontSize();
			end
			if ~isempty(o.Title)
				o.h_title.queueUpdateFontSize();
			end
			
		end
		
		%%
		function val = get.Parent(o)
			val = o.hcPlusTitle.Parent;
		end
		function set.Parent(o,val)
			o.hcPlusTitle.Parent = val;
		end
		
		function val = get.Title(o)
			val = o.h_title.String;
		end
		function set.Title(o,val)
			prevVal = o.h_title.String;
			o.h_title.String = val;
			
			% give up space for title if it is unused
			if isempty(val) && ~isempty(prevVal) || ~o.isConstructed
				set(o.hcPlusTitle,...
					...'MinimumHeights',[0,0],...
					'Heights',[0, -1]);
			elseif ~isempty(val) && isempty(prevVal)
				set(o.hcPlusTitle,...
					...'MinimumHeights',[o.TitleHeight,0],...
					'Heights',[o.TitleHeight, -1]');
			end
		end
		
		function val = get.SideTitle(o)
			val = o.h_sideTitle.String;
		end
		function set.SideTitle(o,val)
			prevVal = o.h_sideTitle.String;
			o.h_sideTitle.String = val;
			
			% give up space for title if it is unused
			if isempty(val) && ~isempty(prevVal) || ~o.isConstructed
				set(o.hcPlusTitle,...
					...'MinimumWidths',[0,0],...
					'Widths',[0, -1]);
			elseif ~isempty(val) && isempty(prevVal)
				set(o.hcPlusTitle,...
					...'MinimumWidths',[o.SideTitleWidth,0],...
					'Widths',[o.SideTitleWidth, -1]');
			end
		end
		
		function set.TitleHeight(o,val)
			o.TitleHeight = val;
			if ~isempty(o.Title)
				set(o.hcPlusTitle,...
					...'MinimumHeights',[o.TitleHeight,0],...
					'Heights',[o.TitleHeight, -1]');
			end
		end
		
		function set.SideTitleWidth(o,val)
			o.SideTitleWidth = val;
			if ~isempty(o.SideTitle)
				set(o.hcPlusTitle,...
					...'MinimumWidths',[o.SideTitleHeight,0],...
					'Widths',[o.SideTitleWidth, -1]');
			end
		end
		
		function set.SideTitleHeight(o,val)
			o.SideTitleHeight = val;
			o.h_sideTitleVBox.Heights = [-1 val -1];
		end
		
		function val = get.ChildrenRelWidths(o)
			val = [o.childMetadata.relWidth];
		end
		function set.ChildrenRelWidths(o,val)
			assert(length(val)==o.numChildren);
			assert(isnumeric(val));
			[o.childMetadata.relWidth] = c_mat_deal(val);
			o.autoRetile();
		end
		function val = get.ChildrenRelHeights(o)
			val = [o.childMetadata.relHeight];
		end
		function set.ChildrenRelHeights(o,val)
			assert(length(val)==o.numChildren);
			assert(isnumeric(val));
			[o.childMetadata.relHeight] = c_mat_deal(val);
			o.autoRetile();
		end
			
		
		function val = get.Children(o)
			val = [o.childMetadata.handle];
		end
		function set.Children(o,newVal)
			error('NotImplemented');
		end
		
		function val = get.ChildrenRoots(o)
			% same as get.Children(o) if child titles are not enabled
			val = [o.childMetadata.h_root];
		end
		function set.ChildrenRoots(o, newVal)
			error('NotImplemented');
		end
		
		function val = get.ChildrenLabels(o)
			val = {o.childMetadata.label};
		end
		function set.ChildrenLabels(o,newVal)
			assert(iscellstr(newVal) && length(newVal)==o.numChildren);
			for iC = 1:o.numChildren
				o.childMetadata(iC).label = newVal{iC};
			end
		end
		
		function val = get.childIsActive(o)
			val = [o.childMetadata.isActive];
		end
		
		function val = get.numChildren(o)
			val = length(o.Children);
		end
		function val = get.numActiveChildren(o)
			val = sum(o.childIsActive);
		end
		function val = get.numInactiveChildren(o)
			val = sum(~o.childIsActive);
		end
		function val = get.activeChildren(o)
			val = o.Children(o.childIsActive);
		end
		function val = get.inactiveChildren(o)
			val = o.Children(~o.childIsActive);
		end
		
		function val = get.activeChildrenRoots(o)
			val = o.ChildrenRoots(o.childIsActive);
		end
		
		function val = get.activeChildMetadata(o)
			val = o.childMetadata(o.childIsActive);
		end
		
		function set.numRows(o,val)
			assert(isempty(val) || isscalar(val));
			o.numRows = val;
			o.autoRetile();
		end
		function set.numCols(o,val)
			assert(isempty(val) || isscalar(val));
			o.numCols = val;
			o.autoRetile();
		end
		
		function set.doTranspose(o,val)
			assert(islogical(val));
			o.doTranspose = val;
			o.autoRetile();
		end
		
		function val = get.autoRetilingPaused(o)
			val = o.autoRetilingPauseStackCounter > 0;
		end
		
		%%
		
		function chooseActive(o)
			
			isActive = o.childIsActive;
			
			childrenLabels = o.ChildrenLabels;
			for iC = 1:o.numChildren
				if isempty(childrenLabels{iC})
					childrenLabels{iC} = sprintf('Tile %d',iC);
					titleStr = '';
					% if there is a single axis in child and it has a title, add title to label
					ha = findobj(o.Children(iC),'type','axes');
					if length(ha)==1 % one axis in child
						if ~isempty(ha.Title.String)
							titleStr = ha.Title.String;
						end
					end
					%TODO: add support for pulling title from o.childMetadata.h_title if non-empty
					if isempty(titleStr)
						if iC==6
							tmp = findobj(o.Children(iC),'-property','UserData','-depth',1);
							for iT = 1:length(tmp)
								if c_isFieldAndNonEmpty(tmp(iT),'UserData.c_GUI_Tiler')
									titleStr = tmp(iT).UserData.c_GUI_Tiler.Title;
									if ~isempty(titleStr)
										break;
									end
								end
							end
						end
						sht = findobj(o.Children(iC),'Tag','c_GUI_Tiler');
					end
						
					if ~isempty(titleStr)
						if ischar(titleStr)
							childrenLabels{iC} = [childrenLabels{iC} ': ' titleStr];
						else
							childrenLabels{iC} = [childrenLabels{iC} ': ' strjoin(titleStr,' ')];
						end
					end
				end
			end
			
			[selection, ok] = listdlg(...
				'ListString',childrenLabels,...
				'SelectionMode','multiple',...
				'ListSize',[300, 100+2*length(childrenLabels)],...
				'InitialValue',find(isActive),...
				'Name','Tiler',...
				'PromptString','Choose active tiles');
			
			if ~ok
				% don't change anything
				return;
			end
			
			o.setActive(c_unfind(selection,o.numChildren));
		end
		
		function interactivelySetTileDims(o)
			ip = c_InputParser();
			ip.addParameter('numRows',o.numRows,@(x) isempty(x) || isscalar(x));
			ip.addParameter('numCols',o.numCols,@(x) isempty(x) || isscalar(x));
			try
				ip.parseFromDialog();
			catch
				return;
			end
			o.pauseAutoRetiling();
			o.numRows = ip.Results.numRows;
			o.numCols = ip.Results.numCols;
			o.resumeAutoRetiling();
		end
		
		function collapseSharedAxes(o,varargin)
			% note: this is currently unstable and only works in specific circumstances
			p = c_InputParser();
			p.addParameter('sharedAxes',{'y'},@iscellstr);
			p.addParameter('doRemoveAllLabels',false,@islogical);
			p.addParameter('doRemoveAllTitles',false,@islogical);
			p.addParameter('keepRightMargin',9,@isscalar); % negative in relative units, positive in pixels
			p.addParameter('keepTopMargin',9,@isscalar);
			p.addParameter('doInteractive',false,@islogical);
			p.parse(varargin{:});
			if p.Results.doInteractive
				try
					p.parseFromDialog();
				catch
					return;
				end
			end
			s = p.Results;
			
			assert(~o.doTranspose,'Collapsing of transposed tiles not currently supported');
			
			assert(~o.autoRetilingPaused);
			for iA = 1:length(s.sharedAxes)
				sharedAxis = s.sharedAxes{iA};
				switch(sharedAxis)
					case 'y'
						o.ChildrenRelWidths = ones(1,o.numChildren);
					case 'x'
						o.ChildrenRelHeights = ones(1,o.numChildren);
					otherwise
						error('error');
				end
			end
			o.pauseAutoRetiling();
			
			assert(all(ismember(s.sharedAxes,{'y','x'})));
			
			for iA = 1:length(s.sharedAxes)
				
				sharedAxis = s.sharedAxes{iA};

				hc = o.ChildrenRoots;
				hca = o.Children;
				for iC = 1:o.numChildren
					assert(length(hca(iC).Children)==1);
					assert(isequal(hca(iC).Children(1).Type,'axes'));
				end

				ha = [hca.Children];

				assert(~isempty(o.currentChildPositions));
				poss = o.currentChildPositions;

				numRows = max(poss(:,1));
				numCols = max(poss(:,2));

				assert(all(o.ChildrenRelHeights==1));


				switch(sharedAxis)
					case 'y'
						if s.doRemoveAllLabels
							c_setField(ha,'YLabel.String','');
						end
						for iR = 1:numRows
							% (assumes plots are in child order)
							iCInRow = poss(:,1)==iR;
							numInRow = sum(iCInRow);
							firstCol = min(poss(iCInRow,2));
							iCLeftmost = iCInRow & poss(:,2)==firstCol;
							iCOther = iCInRow & ~iCLeftmost;
							
							% (assume all plots already have the same relative positions in their containers)
							set(ha(iCInRow),'Units','pixels')
							set(hc(iCInRow),'Units','pixels');
							
							for iC = find(iCOther)'
								if ~isequal(ha(iCLeftmost).YLabel.String, ha(iC).YLabel.String)
									warning('YLabels are not equal');
									keyboard
								end
								if ~isequal(ha(iCLeftmost).YLim,ha(iC).YLim)
									warning('YLims are not equal');
								end
							end
							
							% estimate label width by temporarily removing from first plot
							haPos = ha(iCLeftmost).Position;
							origYTickLabels = ha(iCLeftmost).YTickLabel;
							origYLabel = ha(iCLeftmost).YLabel.String;
							set(ha(iCLeftmost),'YTickLabel',{});
							c_setField(ha(iCLeftmost),'YLabel.String','');
							haNewPos = ha(iCLeftmost).Position;
							leftLabelWidth = haNewPos(3) - haPos(3);
							set(ha(iCLeftmost),'YTickLabel',origYTickLabels);
							c_setField(ha(iCLeftmost),'YLabel.String',origYLabel);
							newLeftmostLabelWidth = 50;
							
							set(ha(iCOther),'YTickLabel',{});
							c_setField(ha(iCOther),'YLabel.String','');
							
							hcPos = hc(iCLeftmost).Position;
							extraXMarginPerPlot = haNewPos(1);
							rightMargin = hcPos(3) - haNewPos(3) - extraXMarginPerPlot;

							if s.keepRightMargin < 0
								% in relative units
								newRightMargin = rightMargin*s.keepRightMargin*-1;
							else
								% in pixels
								newRightMargin = s.keepRightMargin + 1;
							end
							extraXMarginPerPlot = extraXMarginPerPlot + (rightMargin - newRightMargin);
							
							extraXMarginPerPlot = round(extraXMarginPerPlot);
							rightMargin = round(rightMargin);

							numMoved = 0;
							ha(iCLeftmost).Position(1) = ha(iCLeftmost).Position(1) + newLeftmostLabelWidth - leftLabelWidth + rightMargin - 1;
							ha(iCLeftmost).Position(3) = ha(iCLeftmost).Position(3) + leftLabelWidth - 1;
							hc(iCLeftmost).Position(3) = hc(iCLeftmost).Position(3) + newLeftmostLabelWidth + rightMargin - 1;
							for iC = find(iCOther)'
								hc(iC).Position(1) = hc(iC).Position(1) - extraXMarginPerPlot*(numMoved) + newLeftmostLabelWidth;
								hc(iC).Position(3) = hc(iC).Position(3) - extraXMarginPerPlot;
								ha(iC).Position(1) = ha(iC).Position(1) - extraXMarginPerPlot + rightMargin - 1;
								numMoved = numMoved+1;
							end
							
							
							
							set(ha(iCInRow),'Units','normalized')
							set(hc(iCInRow),'Units','normalized');
						end
					case 'x'
						if s.doRemoveAllLabels
							c_setField(ha,'XLabel.String','');
						end
						if s.doRemoveAllTitles
							c_setField(ha,'Title.String','');
						end
						for iCol = 1:numCols
							% (assumes plots are in child order)
							iCInCol = poss(:,2)==iCol;
							numInCol = sum(iCInCol);
							firstRow = min(poss(iCInCol,1));
							iCTopmost = iCInCol & poss(:,1)==firstRow;
							lastRow = max(poss(iCInCol,1));
							iCBottommost = iCInCol & poss(:,1)==lastRow;
							iCNotTop = iCInCol & ~iCTopmost;
							iCNotBottom = iCInCol & ~iCBottommost;

							% (assume all plots already have the same relative positions in their containers)
							set(ha(iCInCol),'Units','pixels')
							set(hc(iCInCol),'Units','pixels');

							haPos = ha(iCTopmost).Position;
							hcPos = hc(iCTopmost).Position;
							bottomMargin = haPos(1);
							topMargin = hcPos(4) - haPos(4) - bottomMargin;
							
							titlesAreEqual = true;
							for iC = find(iCNotTop)'
								if ~isequal(ha(iCTopmost).Title.String,ha(iC).Title.String) && ~isempty(ha(iC).Title.String)
									titlesAreEqual = false;
								end
							end

							newBottomMargin = 1;

							if titlesAreEqual
								if s.keepTopMargin < 0
									% in relative units
									newTopMargin = topMargin*s.keepTopMargin*-1;
								else
									% in pixels
									newTopMargin = s.keepTopMargin + 1;
								end
							else
								newTopMargin = topMargin;
							end
							
							topMargin = round(topMargin);
							newTopMargin = round(newTopMargin);
							bottomMargin = round(bottomMargin);
							newBottomMargin = round(newBottomMargin);

							ha(iCTopmost).Position(2) = ha(iCTopmost).Position(2) - (bottomMargin - newBottomMargin) - 1;
							numMoved = 0;
							for iC = find(iCNotTop)'
								if ~iCBottommost(iC)
									hc(iC).Position(2) = hc(iC).Position(2) + (bottomMargin - newBottomMargin)*(numMoved+1) + (topMargin - newTopMargin)*(numMoved+1);
									hc(iC).Position(4) = hc(iC).Position(4) - (topMargin - newTopMargin) - (bottomMargin - newBottomMargin);
									ha(iC).Position(2) = ha(iC).Position(2) - (bottomMargin - newBottomMargin) + 1;
								else
									hc(iC).Position(2) = hc(iC).Position(2) + (bottomMargin - newBottomMargin)*(numMoved) + (topMargin - newTopMargin)*(numMoved+1);
									hc(iC).Position(4) = hc(iC).Position(4) - (topMargin - newTopMargin);
								end
								numMoved = numMoved+1;
							end

							set(ha(iCNotBottom),'XTickLabels','');
							for iC = find(iCNotBottom)'
								if ~isequal(ha(iCBottommost).XLabel.String, ha(iC).XLabel.String)
									warning('XLabels are not equal');
									keyboard
								end
								if ~isequal(ha(iCBottommost).XLim,ha(iC).XLim)
									warning('XLims are not equal');
								end
							end

							c_setField(ha(iCNotBottom),'XLabel.String','')
							if titlesAreEqual
								c_setField(ha(iCNotTop),'Title.String','');
							end

							set(ha(iCInCol),'Units','normalized')
							set(hc(iCInCol),'Units','normalized');
						end
					otherwise
						error('error');
				end
				drawnow
			end
		end
		
		
		
	end
	
	methods(Access = protected)
		function [inChildren, inActiveChildren, inInactiveChildren] = getIndexOfHandle(o,handle,errorIfNotFound)
			if nargin < 3
				errorIfNotFound = true;
			end
			
			inChildren = [];
			inActiveChildren = [];
			inInactiveChildren = [];
			
			if ismember(handle,o.Children)
				inChildren = find(ismember(o.Children,handle));
				if o.childIsActive(inChildren)
					inActiveChildren = sum(o.childIsActive(1:inChildren));
				else
					inInactiveChildren = sum(~o.childIsActive(1:inChildren));
				end
				return;
			end
			
			if isequal(handle.Type,'axes')
				% try looking for parent of axes
				handle = handle.Parent;
				[inChildren, inActiveChildren, inInactiveChildren] = o.getIndexOfHandle(handle,errorIfNotFound);
				return;
			end
						
			if errorIfNotFound
				error('Handle not found');
			end
		end
		
		function autoRetile(o)
			if ~o.doAutoRetile
				return;
			end
			
			if o.autoRetilingPaused
				o.autoRetileIsPending = true;
				return;
			end
			
			o.retile();
			
			o.autoRetileIsPending = false;
		end
		
		function toggleTranspose(o,doToggleChildrenTilers)
			if nargin < 2
				doToggleChildrenTilers = [];
			end
			o.doTranspose = ~o.doTranspose;
			childrenTilers = o.getTilersInChildren();
			if ~isempty(childrenTilers) && ...
					(isempty(doToggleChildrenTilers) && c_dialog_verify('Toggle transpose in children tilers?')) || ...
					(~isempty(doToggleChildrenTilers) && doToggleChildrenTilers)
				for iC = 1:length(childrenTilers)
					childrenTilers(iC).toggleTranspose(true);
				end
			end
		end
		
		function h_cmenu = addContextMenu_(o,h)
			if nargin < 2
				% add menu in parent figure's menu bar
				hf = ancestor(o.Parent,'figure');
				menuLabel = 'Tiler';
				existingMenus = findobj(hf,'type','uimenu');
				if ~isempty(existingMenus)
					matchingLabel = ismember({existingMenus.Label},{menuLabel});
					existingMenus = existingMenus(matchingLabel);
				end
				if ~isempty(existingMenus)
					hm = existingMenus(1);
				else
					hm = uimenu(hf,'Label',menuLabel);
				end
				existingChildMenus = findobj(hm.Children,'type','uimenu','-depth',0);
				if ~isempty(existingChildMenus)
					existingLabels = {existingChildMenus.Label};
				else
					existingLabels = {};
				end
				label = sprintf('Tiler %d',length(existingLabels)+1);
				if ~isempty(o.Title)
					label = sprintf('%s: %s',label,o.Title);
				elseif ~isempty(o.SideTitle)
					label = sprintf('%s: %s',label,o.SideTitle);
				end
				h_cmenu = uimenu(hm,'Label',label);
			else
				% add context menu
				h_cmenu = get(h,'uicontextmenu');
				if isempty(h_cmenu)
					hf = ancestor(h,'figure');
					h_cmenu = uicontextmenu(hf);
					h.UIContextMenu = h_cmenu;
				end
			end
			uimenu(h_cmenu,'Label','Show/hide tiles...','Callback',@(h,e) o.chooseActive());
			uimenu(h_cmenu,'Label','Set tile dims...','Callback',@(h,e) o.interactivelySetTileDims());
			uimenu(h_cmenu,'Label','Enable/disable transpose','Callback',@(h,e) o.toggleTranspose());
			uimenu(h_cmenu,'Label','Collapse shared x axes','Callback',@(h,e) o.collapseSharedAxes('sharedAxes',{'x'},'doInteractive',true));
			uimenu(h_cmenu,'Label','Collapse shared y axes','Callback',@(h,e) o.collapseSharedAxes('sharedAxes',{'y'},'doInteractive',true));
			uimenu(h_cmenu,'Label','Collapse shared x and y axes','Callback',@(h,e) o.collapseSharedAxes('sharedAxes',{'x','y'},'doInteractive',true));
			uimenu(h_cmenu,'Label','Retile','Callback',@(h,e) o.retile());
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
		
		function testfn()
			c_say('%s test',mfilename);
			c_saySingle('Building test figure');
			hf = figure('name',sprintf('%s test',mfilename));
			
			hT = c_GUI_Tiler('Parent',hf,...
				'Title', sprintf('%s test', mfilename),...
				'SideTitle',sprintf('%s\n side title test',mfilename));
			
			ha = hT.addAxes();
			plot(ha,1:10,rand(10,1));
			
% 			pause
			
			hT.add(...
				uicontrol('Background','r'),'relWidth',0.5,...
				'title', 'Red');
			
% 			pause
			
			hT.add(...
				uicontrol('Background','g'),...
				'title', 'Green');
			
			c_saySingle('About to add more children');
			pause(1)
			
			hc_b = hT.add(...
				uicontrol('Background','b'),'relHeight',0.5,...
				'title', 'Blue');
			
			ha = hT.addAxes('relWidth',0.5);
			plot(ha,1:10,rand(10,1));
			title('Plot title');
			
			c_saySingle('About to deactivate a child (blue box)');
 			pause(1)
			
			hT.setActive(false,'byHandle',hc_b);
			
			c_saySingle('About to reactive a child (blue box)');
 			pause(1)
			
			hT.setActive(true,'byHandle',hc_b);
			
			c_saySingle('About to remove titles');
 			pause(1)
			
			prevTitle = hT.Title;
			hT.Title = '';
			prevSideTitle = hT.SideTitle;
			hT.SideTitle = '';
			
			c_saySingle('About to re-add titles');
 			pause(1)
			
			hT.Title = prevTitle;
			hT.SideTitle = prevSideTitle;
			
			c_saySingle('About to add nested tiler');
 			pause(1)
			shT = c_GUI_Tiler('parent',hT.add(),'Title','Nested tiler');
			shT.add(uicontrol('Background','r'),'relWidth',0.5);
			shT.add(uicontrol('Background','b'));
			
			c_saySingle('About to open dialog to choose active tiles');
			pause(1)
			
			hT.chooseActive();
			
			c_sayDone('Test completed');
			pause
			
			close(hf);
			
		end
		
		function testfn2()
			c_say('%s test',mfilename);
			c_saySingle('Building test figure');
			hf = figure('name',sprintf('%s test',mfilename));
			
			ht = c_GUI_Tiler('Parent',hf,'Title',sprintf('%s test',mfilename));
			ht.numRows = 4;
			ht.numCols = 5;
			for iR = 1:ht.numRows
				for iC = 1:ht.numCols
					ht.addAxes();
					N = 20;
					scatter(rand(1,N)+iR,rand(1,N)+iC);
					xlabel('X label');
					ylabel('Y label');
					title('Title');
				end
			end
			c_plot_setEqualAxes(ht.ChildrenAxes);
			
			pause
			if 1
				ht.collapseSharedAxes('sharedAxes',{'x','y'});
			else
				ht.collapseSharedAxes('sharedAxes',{'x'});

				pause

				ht.collapseSharedAxes('sharedAxes',{'y'});
			end
			pause
			
			keyboard % try collapsing
		end
	end
end