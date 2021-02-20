function varargout = c_use(varargin)
% adapted from https://www.mathworks.com/matlabcentral/fileexchange/39735-functional-programming-constructs

[varargout{1:nargout}] = varargin{end}(varargin{1:end-1});

end