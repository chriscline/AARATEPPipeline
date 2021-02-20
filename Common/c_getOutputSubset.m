function varargout = c_getOutputSubset(outputIndices,fn,varargin)
% c_getOutputSubset - return a subset of output arguments from a function call
% Useful for only getting the second return value of a function inside an anonomyous function, for example.
%
% Adapted from http://stackoverflow.com/questions/33621137/matlab-function-to-extract-one-of-a-multiple-return-value-function
	
	if nargin == 0, testfn(); return; end;
	if islogical(outputIndices)
		outputIndices = find(outputIndices);
	end
	nout = max(nargout(fn),max(outputIndices));
	[all_out{1:nout}] = fn(varargin{:});
	varargout = all_out(outputIndices);
end

function testfn()
	examplePath = 'C:\foldername\filename.extension';
	[origDir, origFilename, origExt] = fileparts(examplePath);
	[filename, ext] = c_getOutputSubset(2:3,@fileparts,examplePath);
	assert(isequal(filename,origFilename) && isequal(ext,origExt));
	assert(isequal(origExt,c_getOutputSubset(3,@fileparts,examplePath)));
	keyboard
end