function c_fig_setAllBackgroundsToColor(varargin)
p = inputParser();
p.addRequired('color',@isvector);
p.addOptional('hf',[],@ishandle);
p.parse(varargin{:});
s = p.Results;

if isempty(s.hf)
	s.hf = gcf;
end

s.hf.Color = s.color;

hBackgrounds = findobj(s.hf,'-property','BackgroundColor');
if ~isempty(hBackgrounds)
	%matchingBackgrounds = cellfun(@(bc) isequal(bc,[1 1 1]*),get(hBackgrounds,{'BackgroundColor'}));
	matchingBackgrounds = cellfun(@(bc) ~ischar(bc) && ...
		max(abs(bc-[1 1 1]*0.94))<1e4*eps || ...
		max(abs(bc-[1 1 1]*0.06))<1e4*eps,get(hBackgrounds,{'BackgroundColor'}));
	hBackgrounds(~matchingBackgrounds) = [];
end

if ~isempty(hBackgrounds)
	tbackposs = get(hBackgrounds,'Position');
	tbackcols = get(hBackgrounds,'BackgroundColor');
	set(hBackgrounds,'BackgroundColor',[0 0 0]);	
	for iH = 1:length(hBackgrounds)
		hBackgrounds(iH).Position = tbackposs{iH};
	end
end

end