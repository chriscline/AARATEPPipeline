function path = c_path_convert(varargin)
% c_path_convert - converts filepaths, such as making an absolute path relative to another directory
%
% Example:
%	absPath = 'C:/folder1/file';
%	relPath = c_path_convert(absPath,'makeRelativeTo','C:/folder2')

if nargin==0, testfn(); return; end;

p = inputParser();
p.addRequired('path',@ischar);
p.addOptional('to','',@(x) isempty(x) || ismember(x,{'toAbsolute'}));
p.addParameter('makeRelativeTo','',@ischar);
p.parse(varargin{:});
s = p.Results;
path = s.path;

% add dependencies to path
persistent pathModified;
if isempty(pathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'./ThirdParty/GetFullPath'));
	pathModified = true;
end

%%
if ~ismember('makeRelativeTo',p.UsingDefaults)
	if isempty(s.makeRelativeTo) || isempty(s.path)
		return;
	end
	assert(isempty(s.to));
	
	path = GetFullPath(path);
	relToPath = GetFullPath(s.makeRelativeTo);
	
	if true
		longPathPrefix = '\\?\';
		if startsWith(path, longPathPrefix) && ~startsWith(relToPath, longPathPrefix)
			% this can get added to paths that exceed 260 characters in length
			% strip it out for equivalence testing
			path = path(length(longPathPrefix)+1:end);
		end
	end
	
	if (path(1)~=relToPath(1))
		if ispc
			% paths are on separate drive letters
			error('c_path_convert:differentVolumesException','Paths are on separate drive letters. Cannot make relative.\n\t%s\n\t%s',path,relToPath);
		else
			error('First character of absolute paths do not match, even though not on windows');
		end
	end
	if isequal(addTrailingSlash(path),addTrailingSlash(relToPath)) 
		% handle special case where path and relToPath are identical
		if 1
			if isequal(path,addTrailingSlash(relToPath))
				path = ['.' filesep];
			else
				path = '';
			end
		else
			if path(end) == filesep
				path = strcat('.',filesep);
			else
				path = '.';
			end
		end
	else
		relToPath = addTrailingSlash(relToPath);
		prefix = c_str_findCommonPrefix({path,relToPath});
		
		% make sure prefix ends in trailing slash to not be a partial filename match
		prefix = prefix(1:find(prefix==filesep,1,'last'));
		path = path(length(prefix)+1:end);
		
		i = 0;
		limit = 20;
		while ~isequal(GetFullPath(fullfile(s.makeRelativeTo,path)),GetFullPath(s.path)) && i<limit
			path = fullfile('../',path);
			i = i+1;
		end
		if i == limit
			keyboard
			error('Problem constructing relative path');
		end
	end
	assert(isequal(GetFullPath(fullfile(s.makeRelativeTo,path)),GetFullPath(s.path)));
	
	%c_saySingle('Converted ''%s'' to ''%s'' + ''%s''',s.path,s.makeRelativeTo,path);
else
	assert(~isempty(s.to));
	switch(s.to)
		case 'toAbsolute'
			path = GetFullPath(path);
		otherwise
			error('Unsupported conversion to: %s',s.to);
	end
end
	
end

function path = addTrailingSlash(path)
	if path(end) ~= filesep
		path(end+1) = filesep;
	end
end


function testfn()

% test makeRelativeTo

i = 0;
i = i+1;
testcase(i) = struct(...
	'input','../../folder2/test.file',...
	'relTo','../../folder2',...
	'output','test.file');

i = i+1;
testcase(i) = struct(...
	'input','../../folder2/test.file',...
	'relTo','../../folder',...
	'output','../folder2/test.file');

i = i+1;
testcase(i) = struct(...
	'input','../../folder2/',...
	'relTo','../../folder2',...
	'output','./');

i = i+1;
testcase(i) = struct(...
	'input','../../folder2',...
	'relTo','../../folder2',...
	'output','.');

i = i+1;
testcase(i) = struct(...
	'input','../../folder2/',...
	'relTo','../../folder2',...
	'output','./');

i = i+1;
testcase(i) = struct(...
	'input','../',...
	'relTo','./',...
	'output','../');

i = i+1;
testcase(i) = struct(...
	'input','',...
	'relTo','../',...
	'output','');

i = i+1;
testcase(i) = struct(...
	'input','./test',...
	'relTo','',...
	'output','./test');

i = i+1;
testcase(i) = struct(...
	'input','/test/test2/../test3',...
	'relTo','/test2',...
	'output','../test/test3');


for i = 1:length(testcase)
	testPath = testcase(i).input;
	relTo = testcase(i).relTo;
	newPath = c_path_convert(testPath,'makeRelativeTo',relTo);
	c_saySingle('Converted ''%s'' to ''%s'' + ''%s''',testPath,relTo,newPath);
	expectedOutput = testcase(i).output;
	assert(isequal(GetFullPath(expectedOutput),GetFullPath(newPath)));
end
	
end