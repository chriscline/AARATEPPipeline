function varargout = c_boundedline(varargin)
% wrapper around boundedline(), mainly just to not include bounds in legend entries

% dependencies
persistent pathModified;
if isempty(pathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(genpath(fullfile(mfilepath,'./ThirdParty/boundedline')));
	addpath(fullfile(mfilepath,'./ThirdParty/inpaint_nans'));
	pathModified = true;
end

%
[hl, hp] = boundedline(varargin{:});

% do not include bounds in legend entries
htmp = get(hp,'Annotation');
if ~iscell(htmp)
	htmp = {htmp};
end
for i=1:length(htmp);
	set(get(htmp{i},'LegendInformation'),'IconDisplayStyle','off');
end
%set(get(get(hp,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');

if nargout >= 1
	varargout{1} = hl;
end

if nargout >= 2
	varargout{2} = hp;
end
end

