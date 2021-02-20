function isValid = c_ishandle(handle)
% c_ishandle - similar to ishandle() but also accepts custom graphics classes as valid.
% Since can't easily subclass matlab's graphics handle classes with my custom GUI elements, recognized
%  subclasses of 'c_GUI_handle' as valid graphics handles here too

	isValid = ishandle(handle) | isa(handle,'c_GUI_handle');
end