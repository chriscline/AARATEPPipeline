function hSlider = c_plot_addSlider(varargin)
p = inputParser();
p.addParameter('callback',@exampleCallback,@(x) isa(x,'function_handle')); % first arg is slider value [0,1], second arg is axis handle(s)
p.addParameter('axisHandle',gca,@isscalar);
p.addParameter('InitialValue',1,@isscalar);
p.addParameter('MinValue',0,@isscalar);
p.addParameter('MaxValue',1,@isscalar);
p.addParameter('SliderStep',[],@isscalar); % determines increment when arrow button is clicked. Must be > 1e-6
p.addParameter('ExistingSliderHandle',[],@(x) isscalar(x) || isempty(x));
p.addParameter('ValueToString',@(x) sprintf('%.3g',x),@(x) isa(x,'function_handle'));
	% can be used for formatting, converting units (e.g. indices to time), etc.
p.parse(varargin{:});
s = p.Results;

if isempty(s.SliderStep)
	s.SliderStep = (s.MaxValue - s.MinValue)/100;
end

if ~isempty(s.ExistingSliderHandle)
	existingMin = get(s.ExistingSliderHandle,'Min');
	existingMax = get(s.ExistingSliderHandle,'Max');
	if existingMin ~= s.MinValue || existingMax ~= s.MaxValue
		c_saySingle('New limits do not limits of existing slider. Using more restrictive limits.');
		set(s.ExistingSliderHandle,...
			'Min',max(existingMin,s.MinValue),...
			'Max',min(existingMax,s.MaxValue));
	end
	
	hSlider = s.ExistingSliderHandle;
	
	addlistener(hSlider,'ContinuousValueChange',...
		@(hObject,event) internalCallback_existing(hObject,event,hSlider,s));
else
	hSlider = uicontrol(...
		'style','slider',...
		'units','pixel',...
		'position',[20 20 300 20],... %TODO: make dynamic and autoincrement if other sliders already exist
		'SliderStep',[s.SliderStep, s.SliderStep*10]/(s.MaxValue - s.MinValue),...
		'Value',s.InitialValue,...
		'Min',s.MinValue,... %TODO: make possible to set other minimimums, and correct value scaling elsewhere in this function
		'Max',s.MaxValue);
	hText = uicontrol(...
		'style','text',...
		'units','pixel',...
		'position',[330 20 240 20],...
		'string',s.ValueToString(s.InitialValue));
	
	set(hSlider,'tag','c_NonPrinting');
	set(hText,'tag','c_NonPrinting');
	
	addlistener(hSlider,'ContinuousValueChange',...
		@(hObject,event) internalCallback(hObject,event,hSlider,hText,s));
end

set(gcf,'toolbar','figure');

end

function internalCallback(hObject,event,hSlider,hText,s)
	sliderValue = get(hSlider,'Value');
	
	set(hText,'string',s.ValueToString(sliderValue));

	s.callback(sliderValue,s.axisHandle);

end

function internalCallback_existing(hObject,event,hSlider,s)

	sliderValue = get(hSlider,'Value');
	
	s.callback(sliderValue,s.axisHandle);
end


function exampleCallback(sliderValue,axisHandle)
	ud = get(axisHandle,'UserData');
	if ~c_isFieldAndNonEmpty(ud,'originalXLimits')
		ud.originalXLimits = xlim(axisHandle);
	end
	if sliderValue ~= 0
		xlim(axisHandle,ud.originalXLimits*sliderValue);
	end
	set(axisHandle,'UserData',ud);
end