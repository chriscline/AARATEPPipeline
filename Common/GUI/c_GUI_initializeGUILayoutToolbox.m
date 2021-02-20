function c_GUI_initializeGUILayoutToolbox()
persistent pathModified;
if isempty(pathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'../ThirdParty/GUILayoutToolbox/layout'));
	pathModified = true;
end
end