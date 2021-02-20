function c_plot_linkViews(varargin)
% c_plot_linkViews - link camera views, axis limits, and colorscales across multiple axes
%
% Example:
% 	figure;
% 	h1 = c_subplot(1,2);
% 	c_plot_scatter3(rand(10,3));
% 	axis equal;
% 	view(3);
% 	h2 = c_subplot(2,2);
% 	c_plot_scatter3(rand(10,3)*5);
% 	axis equal;
% 	view(20,20);
% 	c_plot_linkViews([h1 h2]);

p = inputParser();
p.addOptional('axisHandles',[],@(x) all(ishandle(x)));
p.addParameter('doLinkCameraPosition',true,@islogical);
p.addParameter('doLinkCameraUpVector',true,@islogical);
p.addParameter('doLinkCameraTarget',true,@islogical);
p.addParameter('doLinkCameraViewAngle',true,@islogical);
p.addParameter('doSetAxesEqual',true,@islogical);
p.addParameter('doSetColorScaleEqual',true,@islogical);
p.addParameter('doEmbedLinkHandle',true,@islogical);
p.parse(varargin{:});
s = p.Results;

if isempty(s.axisHandles)
	% no handles given, assume we should grab all axes from current figure
	s.axisHandles = gcf;
end

axisHandles = [];
for i=1:length(s.axisHandles)
	if isgraphics(s.axisHandles(i),'Figure')
		% figure handle given, assume we should grab all axes from the figure
		childHandles = findobj(s.axisHandles(i),'Type','axes');
		if s.doSetColorScaleEqual
			keyboard %TODO: current code only extracts normal axes from a figure, not colorbars. Add code to get colorbars
		end
		axisHandles = [axisHandles; childHandles];
	elseif isgraphics(s.axisHandles(i),'axes')
		axisHandles = [axisHandles;s.axisHandles(i)];
	else
		error('invalid handle');
	end
end
s.axisHandles = axisHandles;

if s.doSetAxesEqual && s.doSetColorScaleEqual
	axesToSet = 'xyzc';
elseif s.doSetAxesEqual
	axesToSet = 'xyz';
elseif s.doSetColorScaleEqual
	axesToSet = 'c';
else
	axesToSet = '';
end
if ~isempty(axesToSet)
	c_plot_setEqualAxes('axisHandles',s.axisHandles,'axesToSet',axesToSet);
end

paramsToLink = {};
if s.doLinkCameraPosition
	paramsToLink = [paramsToLink,'CameraPosition'];
end
if s.doLinkCameraUpVector
	paramsToLink = [paramsToLink,'CameraUpVector'];
end
if s.doLinkCameraTarget
	paramsToLink = [paramsToLink,'CameraTarget'];
end
if s.doLinkCameraViewAngle
	paramsToLink = [paramsToLink,'CameraViewAngle'];
end

if ~isempty(paramsToLink)
	hlink = linkprop(s.axisHandles,paramsToLink);
	if s.doEmbedLinkHandle
		ud = get(s.axisHandles(1),'UserData');
		if ~isfield(ud,'LinkPropertiesHandle')
			ud.LinkPropertiesHandle = hlink;
		else
			ud.LinkPropertiesHandle(end+1) = hlink;
		end
		set(s.axisHandles(1),'UserData',ud);
	end
end

