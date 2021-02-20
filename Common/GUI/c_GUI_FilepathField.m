classdef c_GUI_FilepathField < c_GUI_handle
% c_GUI_FilepathField - GUI class for showing a selected filepath with buttons for interactive browsing, etc.

	properties
		label
		isDir
		validFileTypes
		Parent
		Units
		loadCallback
		saveCallback
		clearCallback
		browseCallback
		pathChangedCallback
	end
	
	properties(SetAccess=protected)
		doIncludeClearButton
		doAllowManualEditing
	end
	
	properties(Dependent) 
		relativeTo
		relPath % path relative to 'relativeTo' (if set)
		Position
		dir
		relDir
		filename
		ext
		path % full path, independent of 'relativeTo'
		BackgroundColor
		dispPath
	end
	
	properties(AbortSet) % only call set.* methods for these properties if their values change
		relPath_;
		relativeTo_;
	end
	
	properties(Access=protected)
		panel
		textfield
		loadButton
		reloadButton
		saveButton
		resaveButton
		clearButton
		browseButton
		mode
		mutex_checkingPathChange = false;
		constructorFinished = false;
		isForSaving = false;
		Position_;
	end
	
	methods
		function o = c_GUI_FilepathField(varargin)
			if nargin==0, c_GUI_FilepathField.testfn(); return; end
			
			c_GUI_FilepathField.addDependencies();
			
			p = inputParser();
			p.addParameter('label','File',@ischar);
			p.addParameter('isDir',false,@islogical);
			p.addParameter('relPath','',@ischar);
			p.addParameter('path','',@ischar);
			p.addParameter('relativeTo','',@ischar);
			p.addParameter('validFileTypes','*.*',@(x)ischar(x) || iscell(x)); % e.g. '*.stl;*.fsmesh;%.off'
			p.addParameter('mode','load-only',@(x)ismember(x,{...
				'load-only',...
				'save-only',...
				'load-reload',...
				'load-save',...
				'browse-only',...
				'save-browse',...
				}));
			p.addParameter('doIncludeClearButton',false,@islogical);
			p.addParameter('doAllowManualEditing',false,@islogical);
			p.addParameter('Parent',[],@ishandle);
			p.addParameter('Position',[0 0 1 1],@isvector);
			p.addParameter('Units','normalized',@ischar);
			p.addParameter('loadCallback',[],@(x)isa(x,'function_handle'));
			p.addParameter('saveCallback',[],@(x)isa(x,'function_handle'));
			p.addParameter('clearCallback',[],@(x)isa(x,'function_handle'));
			p.addParameter('browseCallback',[],@(x)isa(x,'function_handle'));
			p.addParameter('pathChangedCallback',[],@(x)isa(x,'function_handle'));
			p.addParameter('buttonHeight',30,@isscalar); % in pixels
			p.parse(varargin{:});
			s = p.Results;
			
			% assume each parser parameter has property with identical name
			for iF = 1:length(p.Parameters)
				if isprop(o,p.Parameters{iF})
					o.(p.Parameters{iF}) = s.(p.Parameters{iF});
				end
			end
			
						
			if ~isempty(s.path) && ~isempty(s.relPath)
				error('Should only specify one of ''path'' or ''relPath'' in constructor');
			end
			if ~isempty(s.path)
				o.path = s.path;
			end
			if ~isempty(s.relPath)
				o.relPath = s.relPath;
			end
			
			o.panel = uix.Panel(...
				'Parent',s.Parent,...
				'Title',o.label,...
				'Position',o.Position,...
				'Units',o.Units);
			
			doSingleRow = ismember(o.mode,{'browse-only','save-browse'});
			
			if ~doSingleRow
				box = uix.VBox('Parent',o.panel);
			else
				box = uix.HBox('Parent',o.panel);
			end
			
			if ~o.doAllowManualEditing
				o.textfield = uicontrol(box,...
					'style','text',...
					'String',o.dispPath); 
			else
				o.textfield = uicontrol(box,...
					'style','edit',...
					'String',o.relPath,...
					'Callback',@o.callback_manualEdit);
			end
			
			if ~doSingleRow
				btnBox = uix.HBox('Parent',box);
			end
			
			if ismember(o.mode,{'save-only','load-save','save-browse'})
				o.isForSaving = true;
			end
			
			switch(o.mode)
				case 'load-reload'
					o.loadButton = uicontrol(btnBox,...
						'style','pushbutton',...
						'String','Load from...',...
						'Callback',@o.callback_browseAndLoad);
					o.reloadButton = uicontrol(btnBox,...
						'style','pushbutton',...
						'String','Reload',...
						'Callback',@o.callback_load);
				case 'load-only'
					o.loadButton = uicontrol(btnBox,...
						'style','pushbutton',...
						'String','Load from...',...
						'Callback',@o.callback_browseAndLoad);
				case 'save-only'
					o.resaveButton = uicontrol(btnBox,...
						'style','pushbutton',...
						'String','Save',...
						'Callback',@o.callback_save);
					o.saveButton = uicontrol(btnBox,...
						'style','pushbutton',...
						'String','Save to...',...
						'Callback',@o.callback_browseAndSave);
				case 'load-save'
					o.loadButton = uicontrol(btnBox,...
						'style','pushbutton',...
						'String','Load from...',...
						'Callback',@o.callback_browseAndLoad);
					o.saveButton = uicontrol(btnBox,...
						'style','pushbutton',...
						'String','Save to...',...
						'Callback',@o.callback_browseAndSave);
				case 'browse-only'
					assert(~s.doIncludeClearButton); % browse-only mode assumes only one button, no clear
					o.browseButton = uicontrol(box,...
						'style','pushbutton',...
						'String','...',...
						'Callback',@o.callback_browse);
				case 'save-browse'
					assert(~s.doIncludeClearButton); % browse mode assumes only one button, no clear
					o.browseButton = uicontrol(box,...
						'style','pushbutton',...
						'String','...',...
						'Callback',@o.callback_browse);
				otherwise
					error('Invalid mode: %s',o.mode);
			end
			
			if s.doIncludeClearButton
				o.clearButton = uicontrol(btnBox,...
					'style','pushbutton',...
					'String','Clear',...
					'Callback',@o.callback_clear);
			end
			
			if ~doSingleRow
				set(box,'Units','pixels','Heights',[-1, s.buttonHeight]);
				%set(btnBox,'Widths',ones(1,length(get(btnBox,'Contents'))));
			else
				set(box,'Units','pixels','Widths',[-1, 50]);
			end
			
			o.constructorFinished = true;
		end
		
		function simulateButtonPress(o,buttonName)
			switch(lower(buttonName))
				case 'save to...'
					assert(ismember(o.mode,{'save-only','load-save'}));
					o.callback_browseAndSave([],[]);
				case 'save'
					assert(ismember(o.mode,{'save-only','load-save'}));
					o.callback_save([],[]);
				case 'load from...'
					assert(ismember(o.mode,{'load-reload','load-only','load-save'}));
					o.callback_browseAndLoad([],[]);
				case 'load'
					assert(ismember(o.mode,{'load-reload','load-only','load-save'}));
					o.callback_load([],[]);
				case 'clear'
					assert(o.doIncludeClearButton);
					o.callback_clear([],[]);
				otherwise
					error('Unsupported buttonName: %s',buttonName);
			end
		end
		%%
		
		function o = set.Parent(o,newParent)
			o.panel.Parent = newParent;
			o.Parent = newParent;
		end
		
		% note from MATLAB documentation: 
		% "A set method for one property can assign values to other properties of the object. 
		%  These assignments do call any set methods defined for the other properties"
		
		function o = set.Position(o,newPos)
			o.Position_ = newPos;
			o.panel.Position = newPos;
		end
		function pos = get.Position(o)
			pos = o.Position_;
		end
		
		function o = set.relPath(o,newRelPath)
% 			c_say('Start set.relPath');
			if ~isequal(newRelPath,o.relPath_)
				o.relPath_ = newRelPath;	
				o.pathUpdated();
			end
% 			c_sayDone('End set.relPath');
		end
		
		function o = set.path(o,newPath)
% 			c_say('Start set.path');
			if ~isempty(o.relativeTo)
				try
					newRelPath = c_path_convert(newPath,'makeRelativeTo',o.relativeTo);
				catch E
					if strcmp(E.identifier,'c_path_convert:differentVolumesException')
						warning('Absolute path ''%s'' is on a different volume than ''%s''. Changing file field to store absolute paths only.',...
							newPath,o.relativeTo);
						o.relativeTo = '';
						o.relPath = newPath;
						return;
					else
						rethrow(E);
					end
				end
			else 
				newRelPath = newPath;
			end
			o.relPath = newRelPath;
% 			c_sayDone('End set.path: relPath=%s',o.relPath);
		end
		
		function o = set.dir(o,newDir) % assumes dir is not relative to relativeTo
% 			c_say('Start set.dir');
			o.path = fullfile(newDir,o.filename);
% 			c_sayDone('End set.dir');
		end
		
		function o = set.filename(o,newFilename)
% 			c_say('Start set.filename');
			o.path = fullfile(o.dir, newFilename);
% 			c_sayDone('End set.filename');
		end
		
		function o = set.relativeTo(o,newRelativeTo)
% 			c_say('Start set.relativeTo');
			if ~isequal(newRelativeTo,o.relativeTo_);
				o.relativeTo_ = newRelativeTo;
				o.pathUpdated();
			end
% 			c_sayDone('End set.relativeTo');
		end
		
		function path = get.path(o)
			if ~isempty(o.relativeTo)
				path = fullfile(o.relativeTo,o.relPath);
			else
				path = o.relPath;
			end
		end
		
		function relPath = get.relPath(o)
			relPath = o.relPath_;
		end
		
		function dispPath = get.dispPath(o)
			dispPath = o.relPath;
			if ~o.doAllowManualEditing && length(strfind(dispPath,'..'))>2
				% if a path contains many '..' (making it hard to read), show an absolute path instead
				dispPath = c_path_convert(o.path,'toAbsolute');
			end
		end
		
		function relativeTo = get.relativeTo(o)
			relativeTo = o.relativeTo_;
		end
		
		function filename = get.filename(o)
			if isempty(o.relPath)
				filename = '';
				return;
			end
			[~,filename] = fileparts(o.relPath);
		end
		
		function dir = get.dir(o)
			if isempty(o.path)
				dir = '';
				return;
			end
			[dir,~] = fileparts(o.path);
		end
		
		function relDir = get.relDir(o)
			[relDir,~] = fileparts(o.relPath);
		end
		
		function o = set.BackgroundColor(o,newColor)
			o.textfield.BackgroundColor = newColor;
		end
		function color = get.BackgroundColor(o)
			color = o.textfield.BackgroundColor;
		end
		
		function path = getPath(o)
			path = o.path;
		end
		
		function changeBasePath(o,newRelativeTo)
			% change relative to only (i.e. afterwards, o.relPath will be different but o.path will be unchaged)
			path = o.path;
			o.relativeTo = newRelativeTo;
			o.path = path;
		end
	end
	%%
	methods(Access=protected)
		
		function pathUpdated(o)
% 			c_say('Start pathUpdated');
			o.textfield.String = o.dispPath;
			if o.constructorFinished && ~isempty(o.pathChangedCallback)
				o.pathChangedCallback(o.path);
			end
% 			c_sayDone('End pathUpdated');
		end
		
		function callback_manualEdit(o,h,e)
			o.relPath = o.textfield.String;
		end
		
		function callback_browseAndLoad(o,h,e)
			dlgStr = sprintf('Select %s to load',o.label);
			if o.isDir
				pn = uigetdir(deepestExistingPath(o.path),dlgStr);
				fn = '';
			else
				[fn, pn] = uigetfile(o.validFileTypes,...
					dlgStr,...
					o.path);
			end
			if (~o.isDir && isscalar(fn) && fn==0) || (o.isDir && isscalar(pn) && pn==0)
				% user cancelled browse, don't change anything
				return
			end
			o.path = fullfile(pn,fn);
			o.callback_load(h,e);
		end
		
		function callback_load(o,h,e)
			if ~isempty(o.loadCallback)
				o.loadCallback(o.path);
			else
				warning('No load callback set');
				keyboard
			end
		end
		
		function callback_browseAndSave(o,h,e)
			dlgStr = sprintf('Select where to save %s',o.label);
			if o.isDir
				pn = uigetdir(deepestExistingPath(o.path),dlgStr);
				fn = '';
			else
				[fn, pn] = uiputfile(o.validFileTypes,...
					dlgStr,...
					o.path);
			end
			if (~o.isDir && isscalar(fn) && fn==0) || (o.isDir && isscalar(pn) && pn==0)
				% user cancelled browse, don't change anything
				return
			end
			o.path = fullfile(pn,fn);
			o.callback_save(h,e);
		end
		
		function callback_save(o,h,e)
			if ~isempty(o.saveCallback)
				o.saveCallback(o.path);
			else
				warning('No save callback set');
				keyboard
			end
		end

		function callback_clear(o,h,e)
			o.relPath = '';
			if ~isempty(o.clearCallback)
				o.clearCallback(o.path);
			end
		end
		
		function callback_browse(o,h,e)
			dlgStr = sprintf('Select %s',o.label);
			if o.isDir
				pn = uigetdir(deepestExistingPath(o.path),dlgStr);
				fn = '';
			else
				if ~o.isForSaving
					guiFn = @uigetfile;
					startStr = deepestExistingPath(o.path);
				else
					guiFn = @uiputfile;
					startStr = o.path;
				end
				[fn, pn] = guiFn(o.validFileTypes,dlgStr,startStr);
			end
			if (~o.isDir && isscalar(fn) && fn==0) || (o.isDir && isscalar(pn) && pn==0)
				% user cancelled browse, don't change anything
				return
			end
			o.path = fullfile(pn,fn);
			if ~isempty(o.browseCallback)
				o.browseCallback(o.path);
			end
		end
	end
	
	methods(Static)
		function addDependencies()
			persistent pathModified;
			if isempty(pathModified)
				mfilepath=fileparts(which(mfilename));
				addpath(fullfile(mfilepath,'../'));
				addpath(fullfile(mfilepath,'../ThirdParty/findjobj'));
				c_GUI_initializeGUILayoutToolbox();
				pathModified = true;
			end
		end
		
		function testfn()
			c_GUI_FilepathField.addDependencies();
			hf = figure;
			unitHeight = 80;
			hp = c_GUI_uix_VBox('parent',hf);
			hp.add(@(parent)...
				c_GUI_FilepathField(...
					'parent',parent,...
					'label','Load-save absolute',...
					'mode','load-save',...
					'doIncludeClearButton',true,...
					'validFileTypes',{'*.mat','*.txt'},...
					'pathChangedCallback',@(filepath) c_saySingle('Path changed callback: %s',filepath),...
					'loadCallback',@(filepath) c_saySingle('Load callback: %s',filepath),...
					'saveCallback',@(filepath) c_saySingle('Save callback: %s',filepath),...
					'clearCallback',@(filepath)  c_saySingle('Clear callback: %s',filepath)...
				),...
				'Height',unitHeight);
			
			hp.add(@(parent)...
				c_GUI_FilepathField(...
					'parent',parent,...
					'label','Load-only relative',...
					'mode','load-only',...
					'doAllowManualEditing',true,...
					'doIncludeClearButton',true,...
					'relativeTo','./',...
					'pathChangedCallback',@(filepath) c_saySingle('Path changed callback: %s',filepath),...
					'loadCallback',@(filepath) c_saySingle('Load callback: %s',filepath),...
					'saveCallback',@(filepath) c_saySingle('Save callback: %s',filepath),...
					'clearCallback',@(filepath)  c_saySingle('Clear callback: %s',filepath)...
				),...
				'Height',unitHeight);
			
			hp.add(@(parent)...
				c_GUI_FilepathField(...
					'parent',parent,...
					'label','Save-browse relative prespecified',...
					'mode','save-browse',...
					'relativeTo','./',...
					'relPath','../../../test.txt',...
					'pathChangedCallback',@(filepath) c_saySingle('Path changed callback: %s',filepath),...
					'browseCallback',@(filepath) c_saySingle('Browse callback: %s',filepath),...
					'loadCallback',@(filepath) c_saySingle('Load callback: %s',filepath),...
					'saveCallback',@(filepath) c_saySingle('Save callback: %s',filepath),...
					'clearCallback',@(filepath)  c_saySingle('Clear callback: %s',filepath)...
				),...
				'Height',unitHeight);
			
			
			
			keyboard
					
		end
	end
end

function path = deepestExistingPath(path)
	if isempty(path)
		return;
	end
	if exist(path,'file')
		return;
	else
		path = deepestExistingPath(fileparts(path));
	end
end
	