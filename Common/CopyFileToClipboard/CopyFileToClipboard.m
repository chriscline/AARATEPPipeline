function CopyFileToClipboard(pathsToCopy)
	persistent pathModified;
	if isempty(pathModified)
		mfilepath=fileparts(which(mfilename));
		if ~exist('JavaCopyFileToClipboard','class')
			c_saySingle('Adding to Java path (clears global and persistent variables)');
			javaaddpath(fullfile(mfilepath,'./'));
		end
		addpath(fullfile(mfilepath,'../ThirdParty/GetFullPath'));
		pathModified = true;
	end
	
	if nargin == 0
		% assume we just wanted to add dependencies to path without actually copying anything yet
		return;
	end

	if ischar(pathsToCopy)
		pathsToCopy = {pathsToCopy};
	end
	if ~iscell(pathsToCopy)
		error('Input should either be single string or cell array of strings');
	end
	
	
	for i=1:length(pathsToCopy)
		pathsToCopy{i} = GetFullPath(pathsToCopy{i});
		if ~exist(pathsToCopy{i},'file')
			error('File does not exist at %s',pathsToCopy{i});
		end
	end
	
	tmp = JavaCopyFileToClipboard();
	tmp.copy(pathsToCopy{:});

end