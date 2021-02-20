function hc = c_plot_colorbar(varargin)
if nargin==0, testfn(); return; end
p = inputParser();
p.addParameter('axis',[],@ishandle);
p.addParameter('linkedAxes',[],@(x) all(ishandle(x)));
p.addParameter('clim',[],@c_isSpan);
p.addParameter('location','west',@ischar);
p.addParameter('FontSize',12,@isscalar);
p.addParameter('clabel','',@ischar);
p.addParameter('doForceSymmetric',false,@islogical);
p.parse(varargin{:});
s = p.Results;

if isempty(s.axis)
	s.axis = gca;
end

if isempty(get(s.axis,'Children'))
	% assume axis was created just for colorbar and hide it
	axis(s.axis,'off');
	drawnow
	s.axis.Position = s.axis.OuterPosition;
end

args = struct;
if ~isempty(s.location)
	args.location = s.location;
end
if ~isempty(s.FontSize)
	args.FontSize = s.FontSize;
end

args = c_structToCell(args);

hc = colorbar(s.axis,args{:});

if ~isempty(s.clabel)
	ylabel(hc,s.clabel);
end

if ~isempty(s.linkedAxes)
	%TODO: make sure that any linked axes use the same colormap
	caxis(s.axis,caxis(s.linkedAxes(1)));
	c_plot_setEqualAxes([s.linkedAxes s.axis],'axesToSet','c','doForceSymmetric',s.doForceSymmetric);
	drawnow
	colormap(s.axis,colormap(s.linkedAxes(1)));
	if isempty(s.clim)
		s.clim = s.linkedAxes(1).CLim;
	end
end
if s.doForceSymmetric
	if isempty(s.clim)
		s.clim = [-1 1];
	else
		s.clim = [-1 1]*max(abs(s.clim));
	end
end
if ~isempty(s.clim)
	caxis(s.axis,s.clim);
end

end

function testfn()
figure;
ht = c_GUI_Tiler();
ht.numRows = 1;
ha = gobjects(0);

ha(end+1) = ht.addAxes();
[X,Y,Z] = peaks(25);
surf(X,Y,Z);

ha(end+1) = ht.addAxes();
[X,Y,Z] = peaks(50);
surf(X,Y,Z);

c_plot_linkViews(ha);

hac = ht.addAxes('relWidth',0.5);
c_plot_colorbar('axis',hac,...
	'linkedAxes',ha,...
	'clabel','Arbitrary units',...
	'doForceSymmetric',true);

end