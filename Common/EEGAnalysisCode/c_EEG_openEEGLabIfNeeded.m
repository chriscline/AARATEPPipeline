function c_EEG_openEEGLabIfNeeded()
	persistent EEGLabOpened;
	if ~isempty(EEGLabOpened) && EEGLabOpened
		hh = true;
	else
		hh = findobj('tag', 'EEGLAB');
	end
	
% 	versionSuffix = '';
	versionSuffix = '2021.1';
	
	if isempty(hh)
		if ~exist('eeglab.m','file')
			if ispc
				addpath(fullfile([getenv('HOMEDRIVE') getenv('HOMEPATH')],['Documents/MATLAB/eeglab' versionSuffix]));
			else
				if ismac
					addpath(fullfile('~/','Documents','MATLAB',['eeglab' versionSuffix]));
				else
					eeglabPath = fullfile('~/',['matlab/eeglab' versionSuffix]);
					if ~c_exist(eeglabPath, 'dir')
						eeglabPath = fullfile('~/',['Documents/MATLAB/eeglab' versionSuffix]);
					end
					assert(c_exist(eeglabPath, 'dir'))
					addpath(eeglabPath);
				end
			end
		end
		hf = get(groot,'CurrentFigure'); % keep track of previous active figure to not accidentally plot into EEGLab window in the future
		c_say('Opening eeglab');
		[g_EEGLab.ALLEEG, g_EEGLab.EEG, g_EEGLab.CURRENTSET] = eeglab;
		set(gcf,'CloseRequestFcn',@(~,~) callback_EEGLab_close());
		EEGLabOpened = true;
		c_sayDone();
		if ~isempty(hf)
			figure(hf);
		end
	end
	
	str = which('timefreq');
	if ~c_str_matchRegex(str,'ThirdParty/FromEEGLab')
		% add custom functions overriding eeglab equivalents
		mfilepath = fileparts(which(mfilename));
		addpath(genpath(fullfile(mfilepath,'../ThirdParty/FromEEGLab')),'-begin');
		if c_exist(fullfile(mfilepath, '../ThirdParty/TESA'), 'dir')
			addpath(fullfile(mfilepath,'../ThirdParty/TESA'));
		end
		addpath(fullfile(mfilepath,'../ThirdParty/FromEEGLab/plugins/bva-io1.5.13'));
		addpath(fullfile(mfilepath,'../ThirdParty/FromEEGLab/plugins/Viewprops1.5.4'));
	end
	
	function callback_EEGLab_close()
		EEGLabOpened = false;
		c_saySingle('EEGLab closed');
		closereq();
	end
end
