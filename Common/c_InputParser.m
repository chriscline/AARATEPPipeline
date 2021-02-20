classdef c_InputParser < handle
% c_InputParser - similar to inputParser(), but with extra features such as interactive GUI dialog
	
	%% instance variables
	properties
		Results = [];
		isParsed = false;
	end
	
	properties(Dependent)
		numParameters;
	end
	
	properties(SetAccess=protected)
		parameters = [];
	end
	
	properties(Access=protected)
		templateParam = struct(...
			'name',[],...
			'default',[],...
			'validator',[],...
			'description','',...
			'isRequired',false,...
			'isOptional',false,...
			'extraInfo',struct());
	end
	
	%% internal instance methods
	methods (Access=protected)
		function addParam_(o,varargin)
			p = inputParser();
			p.addRequired('paramName',@ischar);
			p.addRequired('paramDefault');
			p.addOptional('paramValidator',@true,@(x) isa(x,'function_handle'));
			p.addParameter('description','',@ischar);
			p.addParameter('isRequired',false,@islogical);
			p.addParameter('isOptional',false,@islogical);
			p.addParameter('extraInfo',struct(),@isstruct);
			p.parse(varargin{:});
			s = p.Results;
			
			newParam = o.templateParam;
			newParam.name = s.paramName;
			newParam.default = s.paramDefault;
			newParam.validator = s.paramValidator;
			newParam.description = s.description;
			newParam.isRequired = s.isRequired;
			newParam.isOptional = s.isOptional;
			newParam.extraInfo = s.extraInfo;
			
			paramNames = {o.parameters.name};
			assert(~ismember(newParam.name, paramNames)); % parameter with same name should not already exist
			
			o.parameters(end+1) = newParam;
		end
		
	end
	
	%% instance methods
	methods
		%% constructor
		function o = c_InputParser()
			o.parameters = c_struct_createEmptyCopy(o.templateParam);
		end	
		
		%%
		
		function addRequired(o,varargin)
			o.addParam_(varargin{1},[],varargin{2:end},'isRequired',true,'isOptional',false);
		end
		
		function addOptional(o,varargin)
			o.addParam_(varargin{:},'isRequired',false,'isOptional',true);
		end
		
		function addParameter(o,varargin)
			o.addParam_(varargin{:},'isRequired',false,'isOptional',false);
		end
		
		function addRequiredFilename(o,varargin)
			o.addParameterFilename(varargin{1},'',varargin{2:end},'isRequired',true,'isOptional',false);
		end
		
		function addOptionalFilename(o,varargin)
			o.addParameterFilename(varargin{:},'isRequired',false,'isOptional',true);
		end
		
		function addParameterFilename(o,varargin)
			p = inputParser();
			p.addRequired('paramName',@ischar);
			p.addRequired('paramDefault');
			p.addOptional('paramValidator',@(x) true,@(x) isa(x,'function_handle'));
			p.addParameter('description','',@ischar);
			p.addParameter('doAssertExists',false,@islogical);
			p.addParameter('doAssertFileExists',false,@islogical); % legacy, use doAssertExists + isDir instead
			p.addParameter('doAssertDirExists',false,@islogical); % legacy, use doAssertExists + isDir instead
			p.addParameter('doAllowEmpty',true,@islogical);
			p.addParameter('relativeToDir','',@ischar);
			p.addParameter('validFileTypes','',@(x)ischar(x) || iscell(x)); % e.g. '*.stl;*.fsmesh;%.off'
			p.addParameter('isForWriting',false,@islogical); % affects whether file selection GUI says "open" or "save"
			p.addParameter('isDir',false,@islogical);
			p.addParameter('isRequired',false,@islogical);
			p.addParameter('isOptional',false,@islogical);
			p.parse(varargin{:});
			s = p.Results;
			
			% construct validator
			customValidator = s.paramValidator;
			if 1
				fpConstructor = @(relPath) fullfile(s.relativeToDir,relPath);
			else				
				% for debugging
				fpConstructor1 = @(relPath) fullfile(s.relativeToDir,relPath);
				fpConstructor2 = @(relPath) c_saySingle('File at %s does %sexist',fpConstructor1(relPath),c_if(exist(fpConstructor1(relPath),'file')>0,'','not '));
				fpConstructor = @(relPath) c_callFns({fpConstructor1, fpConstructor2},relPath);
			end
			
			if s.doAssertExists
				existsValidator = @(relPath) (s.doAllowEmpty && isempty(relPath)) || exist(fpConstructor(relPath),'file')>0;
			else
				existsValidator = @(relPath) true;
			end
			if s.doAssertFileExists || (s.doAssertExists && ~s.isDir)
				fileExistsValidator = @(relPath) (s.doAllowEmpty && isempty(relPath)) || ismember(exist(fpConstructor(relPath),'file'),[2 3 4 5 6]);
			else
				fileExistsValidator = @(relPath) true;
			end
			if s.doAssertDirExists || (s.doAssertExists && s.isDir)
				dirExistsValidator = @(relPath) (s.doAllowEmpty && isempty(relPath)) || exist(fpConstructor(relPath),'dir')>0;
			else
				dirExistsValidator = @(relPath) true;
			end
			if ~s.doAllowEmpty
				emptyValidator = @(relPath) ~isempty(relPath);
			else
				emptyValidator = @(relPath) true;
			end
			if ~isempty(s.validFileTypes)
				fileTypeValidator = @(relPath) true; %TODO: debug, delete
				%TODO: add validator to check file types, either in '*.stl;*.fsmesh;%.off' or {'*.stl','*.fsmesh','%.off'} format
			else
				fileTypeValidator = @(relPath) true;
			end
				
			validator = @(relPath) ...
				customValidator(relPath) &&...
				existsValidator(relPath) &&...
				fileExistsValidator(relPath) &&...
				dirExistsValidator(relPath) &&...
				emptyValidator(relPath) &&...
				fileTypeValidator(relPath);
			
			extraInfo = struct();
			
			extraInfo.isFilename = true;
			extraFields = {... % to copy into extraInfo
				'isForWriting',...
				'relativeToDir',...
				'isDir',...
				'validFileTypes'};
			for iF = 1:length(extraFields)
				extraInfo.(extraFields{iF}) = s.(extraFields{iF});
			end
			
			o.addParam_(s.paramName, s.paramDefault, validator, ...
				'description',s.description,...
				'extraInfo',extraInfo,...
				'isRequired',s.isRequired,...
				'isOptional',s.isOptional);
		end
		
		function changeDefault(o,varargin)
			p = inputParser();
			p.addRequired('paramName',@ischar)
			p.addRequired('newDefault');
			p.parse(varargin{:});
			s = p.Results;
			
			paramNames = {o.parameters.name};
			n = find(ismember(paramNames,s.paramName));
			assert(~isempty(n));
			o.parameters(n).default = s.newDefault;
		end
		
		function changeDefaults(o,varargin)
			p = inputParser();
			p.addRequired('newDefaults',@isstruct);
			p.parse(varargin{:});
			s = p.Results;
			
			fields = fieldnames(s.newDefaults);
			for iF = 1:length(fields)
				o.changeDefault(fields{iF},s.newDefaults.(fields{iF}));
			end
		end
		
		function removeParameter(o,varargin)
			p = inputParser();
			p.addRequired('paramName');
			p.parse(varargin{:});
			s = p.Results;
			
			paramNames = {o.parameters.name};
			index = find(ismember(paramNames,s.paramName));
			assert(~isempty(index) && isscalar(index));
			o.parameters(index) = [];
		end
		
		function parseFromDialog(o,varargin)
			p = inputParser();
			p.addParameter('title','Input parser',@ischar);
			p.addParameter('doLiveValidation',true,@ischar);
			p.parse(varargin{:});
			s = p.Results;
			
			o.Results = [];
			
			prompts = cell(1,o.numParameters);
			for i=1:o.numParameters
				if isempty(o.parameters(i).description)
					prompts{i} = o.parameters(i).name;
				else
					prompts{i} = [o.parameters(i).name ' (' o.parameters(i).description ')'];
				end
			end
			doUseBuiltinInputDlg = false;
			if doUseBuiltinInputDlg
				defaults = cellfun(@c_toString,{o.parameters.default},'UniformOutput',false);
				resp = inputdlg(prompts,s.title,1,defaults);
			else
				defaults = {o.parameters.default};
				if s.doLiveValidation
					resp = c_inputdlg(prompts,s.title,1,defaults,...
						'Validators',{o.parameters.validator},...
						'ParamExtraInfos',{o.parameters.extraInfo},...
						'doLiveValidation',true);
				else
					resp = c_inputdlg(prompts,s.title,1,defaults,...
						'ParamExtraInfos',{o.parameters.extraInfo});
				end
				
			end
			
			if length(resp) ~= o.numParameters
				% user pressed cancel, or some other error
				error('Parsing canceled');
			end
			
			res = struct();
			for i=1:o.numParameters
				if doUseBuiltinInputDlg
					if isempty(resp{i})
						convertedValue = '';
					else
						convertedValue = eval(resp{i});
					end
				else
					convertedValue = resp{i};
				end
				if o.parameters(i).validator(convertedValue)
					res.(o.parameters(i).name) = convertedValue;
				else
					error('Invalid input: %s=%s should obey %s',...
						o.parameters(i).name,resp{i},func2str(o.parameters(i).validator));
				end
			end
			o.Results = res;
			o.isParsed = true;
		end
		
		function parse(o,varargin)
			o.Results = [];
			
			p = inputParser();
			for i=1:o.numParameters
				if o.parameters(i).isRequired
					p.addRequired(o.parameters(i).name,o.parameters(i).validator);
				else
					if o.isParsed
						defaultVal = o.Results.(o.parameters(i).name);
					else
						defaultVal = o.parameters(i).default;
					end
					if o.parameters(i).isOptional
						p.addOptional(o.parameters(i).name,defaultVal,o.parameters(i).validator);
					else
						p.addParameter(o.parameters(i).name,defaultVal,o.parameters(i).validator);
					end
				end
			end
			p.parse(varargin{:});
			
			o.Results = p.Results;
		
			o.isParsed = true;
		end
		%%
		function numParams = get.numParameters(o)
			numParams = length(o.parameters);
		end
	end
end



function testfn()
%%
	cp = c_InputParser();
	cp.addParameter('Str','test',@ischar,'description','a string');
	cp.addParameter('Num',3.14,@isscalar,'description','a number');
	cp.addParameter('Vec',[1 2 3],@isvector,'description','a vector');
	cp.addParameter('Cell',{1, 'test'},@iscell,'description','a cell');
	cp.addParameterFilename('File1','','relativeToDir','../','validFileTypes','*.m','doAssertExists',true);
	cp.addParameterFilename('File2','','relativeToDir','../','doAssertExists',true);
	cp.addParameterFilename('Dir','','isDir',true,'doAssertExists',true);
	cp.addParameter('Str2','test2',@ischar,'description','a string');
	
	if 0
		cp.parse('Str','test2','Vec',[1:5],'Cell',{'test2',2},'File','./c_InputParser.m','Dir','./');
		res1 = cp.Results
	end
	
	cp.parseFromDialog();
	
	res2 = cp.Results
	
	keyboard
end