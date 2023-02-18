function color = c_color_adjust(varargin)
p = inputParser();
p.addRequired('color',@(x) ismatrix(x) && size(x,2)==3);
p.addOptional('adjustment','',@ischar);
p.addParameter('by',[],@isscalar);
p.parse(varargin{:});
s = p.Results;

color = s.color;

if size(color, 1) > 1
	for iC = 1:size(color, 1)
		color(iC, :) = c_color_adjust(color(iC, :), varargin{2:end});
	end
	return;
end

switch(s.adjustment)
	case {'makeBrighter','makeDarker'}
		if ~isempty(s.by)
			assert(s.by > 0);
			assert(s.by <= 1);
		else
			s.by = 0.2;
		end
		color = rgb2ntsc(color);
		switch(s.adjustment)
			case 'makeDarker'
				maxDiff = -0.5-color(1);
			case 'makeBrighter'
				maxDiff = 1-color(1);
		end
		color(1) = color(1) + maxDiff*s.by;
		color = ntsc2rgb(color);
	otherwise
		error('Unsupported adjustment: %s',s.adjustment);
end
end