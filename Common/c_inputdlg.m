function Answer = c_inputdlg(varargin)
if nargin == 0, testfn(); return; end;

persistent pathModified;
if isempty(pathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'./ThirdParty/findjobj'));
	addpath(fullfile(mfilepath,'./GUI'));
	pathModified = true;
end

p = inputParser();
p.addRequired('prompt',@iscell);
p.addOptional('Title','',@ischar);
p.addOptional('NumLines',1,@(x) isscalar(x) || isvector(x));
p.addOptional('defAns',{},@iscell); % unlike inputdlg, this should match type expected by validator, not necessarily a string
p.addParameter('Resize','off',@(x) ischar(x) && ismember(x,{'on','off'}));
p.addParameter('WindowStyle','modal',@(x) ischar(x) && ismember(x,{'normal','modal'}));
p.addParameter('Interpreter','none',@(x) ischar(x) && ismember(x,{'none','tex'}));
p.addParameter('Validators',{},@iscell); % cell array of validator function handles
p.addParameter('ParamExtraInfos',{},@iscell); % see c_InputParser for example contents of this parameter
p.addParameter('FigWidth',275,@iscalar);
p.addParameter('FigHeight',70,@isscalar);
p.addParameter('ButtonHeight',20,@isscalar);
p.addParameter('doLiveValidation',true,@islogical);
p.parse(varargin{:});
s = p.Results;

numFields = length(s.prompt);
if isscalar(s.NumLines)
	s.NumLines = repmat(s.NumLines,1,numFields);
end
assert(length(s.NumLines)==numFields);

if isempty(s.Validators)
	s.Validators = cell(1,numFields);
end;
assert(length(s.Validators)==numFields);

if isempty(s.defAns)
	s.defAns = cell(1,numFields);
end
assert(length(s.defAns)==numFields);

if isempty(s.ParamExtraInfos)
	s.ParamExtraInfos = cell(1,numFields);
end
assert(length(s.ParamExtraInfos)==numFields);

s.BottomOffset = s.ButtonHeight*2;
s.TopOffset = s.FigHeight - s.BottomOffset;

s.LeftOffset = 10;

interfieldSpacing = 10;
lineHeight = 20;
totalNumLines = sum(s.NumLines)+numFields; %TODO: update to allow for multiline prompts
s.FigHeight = s.FigHeight + lineHeight*totalNumLines + (numFields-1)*interfieldSpacing;

s.ButtonWidth = (s.FigWidth - 2*s.ButtonHeight)/2;

%%%%%%%%%%%%%%%%%%%%%%%
%%% Create InputFig %%%
%%%%%%%%%%%%%%%%%%%%%%%

FigColor=get(0,'DefaultUicontrolBackgroundColor');

InputFig=dialog(                     ...
  'Visible'          ,'off'      , ...
  'KeyPressFcn'      ,@doFigureKeyPress, ...
  'Name'             ,s.Title      , ...
  'Pointer'          ,'arrow'    , ...
  'Units'            ,'pixels'   , ...
  'UserData'         ,'Cancel'   , ...
  'Tag'              ,s.Title      , ...
  'HandleVisibility' ,'callback' , ...
  'Color'            ,FigColor   , ...
  'NextPlot'         ,'add'      , ...
  'WindowStyle'      ,s.WindowStyle, ...
  'Resize'           ,s.Resize   ,    ...
  'Position',[0,0,s.FigWidth,s.FigHeight] ...
  );

ypos = s.FigHeight - s.TopOffset + lineHeight;
xpos = s.LeftOffset;
fieldWidth = s.FigWidth - 2*s.LeftOffset;
isFile = false(1,numFields);
for iF = 1:numFields
	if ~c_isEmptyOrEmptyStruct(s.ParamExtraInfos{iF})
		si = s.ParamExtraInfos{iF};
		isFile(iF) = c_isFieldAndNonEmpty(si,'isFilename') && si.isFilename;
	end
	
	if ~isempty(s.defAns{iF})
		defaultVal = s.defAns{iF};
	else
		defaultVal = '';
	end
	if ~isempty(s.Validators{iF})
		validator = s.Validators{iF};
	else
		validator = @(x) true;
	end
	
	if ~isFile(iF)
		ypos = ypos - lineHeight;
		h_f_description(iF) = uicontrol(InputFig,...
			'style','text',...
			'Position',[xpos,ypos,fieldWidth,lineHeight],...
			'HorizontalAlignment','left',...
			'String',[s.prompt{iF} ':']);

		height = lineHeight*s.NumLines(iF);
		ypos = ypos - height;
		h_f_field(iF) = uicontrol(InputFig,...
			'style','edit',...
			'Position',[xpos,ypos,fieldWidth,height],...
			'String',c_toString(defaultVal),...
			'Callback',@(h,e) revalidateField(h,e,h,validator,s.doLiveValidation),...
			'Max',s.NumLines(iF));
		if s.doLiveValidation
			hfj = handle(java(findjobj(h_f_field(iF))),'CallbackProperties');
			set(hfj,'KeyPressedCallback',@(h,e) revalidateField(h,e,h_f_field(iF),validator,s.doLiveValidation));
		end
	else
		height = lineHeight*(s.NumLines(iF)+1);
		ypos = ypos - height;
		pos = [xpos/s.FigWidth, ypos/s.FigHeight,fieldWidth/s.FigWidth,height/s.FigHeight];
		if ~isempty(si.relativeToDir)
			path = fullfile(si.relativeToDir,defaultVal);
		else
			path = defaultVal;
		end
		h_f_filefield(iF) = c_GUI_FilepathField(...
			'parent',InputFig,...
			'mode','browse-only',...
			'label',[s.prompt{iF}],...
			'relativeTo',si.relativeToDir,...
			'path',path,...
			'isDir',si.isDir,...
			'validFileTypes',si.validFileTypes,...
			'Position',pos);
		if s.doLiveValidation
			h_f_filefield(iF).pathChangedCallback = ...
				@(file) revalidateField(struct('String',sprintf('''%s''',h_f_filefield(iF).relPath)),...
					[],h_f_filefield(iF),validator,s.doLiveValidation);
		end
	end

	ypos = ypos - interfieldSpacing;
end

h_button_ok = uicontrol(InputFig,...
	'style','pushbutton',...
	'String','OK',...
	'Position',[s.ButtonWidth + 1.5*s.ButtonHeight,s.ButtonHeight/2,s.ButtonWidth,s.ButtonHeight],...
	'KeyPressFcn',@doControlKeyPress , ...
	'Callback',@doCallback,...
	'Tag'        ,'OK', ...
	'UserData'   ,'OK'...
	);
fh = handle(InputFig);
fh.setDefaultButton(h_button_ok); % from setdefaultbutton (undocumented/unsupported)
h_button_cancel = uicontrol(InputFig,...
	'style','pushbutton',...
	'String','Cancel',...
	'Position',[0.5*s.ButtonHeight,s.ButtonHeight/2,s.ButtonWidth,s.ButtonHeight],...
	'KeyPressFcn',@doControlKeyPress , ...
	'Callback',@doCallback,...
	'Tag'        ,'Cancel', ...
	'UserData'   ,'Cancel'...
	);

movegui(InputFig,'center');

if ishghandle(InputFig)
	uiwait(InputFig);
end

if ishghandle(InputFig)
	% get response
	for iF = 1:numFields
		if ~isFile(iF)
			val = h_f_field(iF).String;
			if isempty(val)
				val = '';
			else
				tmp = val;
				try
					val = eval(tmp);
					invalid = false;
				catch
					invalid = true;
				end
			end
		else
			val = h_f_filefield(iF).relPath;
			invalid = false;
		end
		if invalid || ~isempty(s.Validators{iF}) && ~s.Validators{iF}(val)
			if ~isFile(iF)
				warning('Invalid value ''%s'' for field %s',h_f_field(iF).String,s.prompt{iF});
			else
				warning('Invalid value ''%s'' for field %s',val,s.prompt{iF});
				keyboard
			end
			Answer{iF} = NaN;
		else
			Answer{iF} = val;
		end
	end
	delete(InputFig);
else
	Answer = {};
end
drawnow;
end

function revalidateField(h,e,hf,validator,doLive)
	if ~doLive
		% do nothing
		return;
	end
	
	if isprop(h,'String') || isfield(h,'String')
		str = h.String;
	else
		% java callback
		str = char(h.getText);
	end
	
	invalid = false;
	if isempty(str)
		val = '';
	else
		try
			val = eval(str);
		catch
			invalid = true;
		end
	end
	if ~invalid && isa(validator,'function_handle') && ~validator(val)
		invalid = true;
	end
	
	if ~invalid
		hf.BackgroundColor = [0.4 1 0.4];
	else
		hf.BackgroundColor = [1 0.4 0.4];
	end
end

function doCallback(obj, evd) %#ok
if ~strcmp(get(obj,'UserData'),'Cancel')
  set(gcbf,'UserData','OK');
  uiresume(gcbf);
else
  delete(gcbf)
end
end


function doFigureKeyPress(obj, evd) %#ok
switch(evd.Key)
  case {'return','space'}
    set(gcbf,'UserData','OK');
    uiresume(gcbf);
  case {'escape'}
    delete(gcbf);
end
end

function doControlKeyPress(obj, evd) %#ok
switch(evd.Key)
  case {'return'}
    if ~strcmp(get(obj,'UserData'),'Cancel')
      set(gcbf,'UserData','OK');
      uiresume(gcbf);
    else
      delete(gcbf)
    end
  case 'escape'
    delete(gcbf)
end
end

function testfn()
	a = c_inputdlg({'Test 1','Test 2'},'Prompt title',1,{'Answer 1 default',''})

end