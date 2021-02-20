function colors = c_getColors(n_colors,varargin)
% c_getColors - wrapper around third-party distinguishable_colors()
%
% Example:
%	figure; c_plot_scatter3(rand(10,3),'ptColors',c_getColors(10))

persistent PathModified;
if isempty(PathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'./ThirdParty/distinguishable_colors'));
	PathModified = true;
end

if nargin > 1 && ischar(varargin{1})
	% handle custom color keys
	switch(varargin{1})
		case 'not bright'
			% add additional "background" colors to avoid
			bg = [1 1 1; 1 1 0.5; 1 0.8 1; 0.6 1 1; 1 0.8 0.8; 0.5 1 0.5; 0.9 0.9 1; 1 0.4 0.9];
		otherwise
			error('Unexpected color string: %s',varargin{1});
	end
	varargin{1} = bg;
end

colors = distinguishable_colors(n_colors,varargin{:});

end

function testfn()

N = 10;

colors = c_getColors(N,'not bright');
% colors = c_getColors(N);

x = 1:20;
y = rand(N,length(x)) + (1:N)';

figure;
for iN = 1:N
	plot(x,y(iN,:),'Color',colors(iN,:));
	hold on;
end

end