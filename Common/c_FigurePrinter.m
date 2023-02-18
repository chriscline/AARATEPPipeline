classdef c_FigurePrinter < handle
	%FigurePrinter - Class to handle printing/exporting of figures to image files.
	%   Can write directly to a requested filepath, or can copy to clipboard by saving to a temp
	%    location and copying the temp location path to clipboard.
	%
	% Example:
	%	figure;
	%	plot(1:10, rand(10,1));
	%   c_FigurePrinter.copyToClipboard('magnification', 2)
	
	properties
		ext = '-dpng';
		size = [];
		parentDirectory;
		figureDirectory;
		resolution = 300;
		disabled = false;
		doPrintText = false;
		alsoSaveNativeFig = true;
	end
	
	methods(Static)
		function initialize()
			persistent pathModified;
			if isempty(pathModified)
				c_saySingle('Adding dependencies to path');
				mfilepath=fileparts(which(mfilename));
				addpath(fullfile(mfilepath,'./ThirdParty/export_fig'));
%				addpath(fullfile(mfilepath,'./ThirdParty/imclipboard'));
				addpath(fullfile(mfilepath,'./CopyFileToClipboard'));
				addpath(fullfile(mfilepath,'./ThirdParty/captureScreens'));
				CopyFileToClipboard();
				pathModified = true;
			end
		end
		
		function copyMonitorScreenshotToClipboard(varargin)
			p = inputParser();
			p.addParameter('monitors',[],@(x) isnumeric(x) && isvector(x));
			p.parse(varargin{:});
			s = p.Results;
			c_FigurePrinter.initialize();
			
			c_say('Copying monitor screenshot(s) to clipboard');
			c_say('Capturing screenshots');
			ims = captureScreens();
			if ~isempty(s.monitors)
				% reduce to just selected monitor(s)
				ims = ims(mod(s.monitors-1,length(ims))+1);
			end
			c_sayDone();
			c_say('Saving %d screenshot%s to temporary location',length(ims),c_strIfNumIsPlural(length(ims)));
			baseName = tempname;
			filenames = {};
			for i = 1:length(ims)
				filenames{i} = [baseName '_' num2str(i) '.png'];
				imwrite(ims{i},filenames{i});
			end
			c_sayDone();
			c_say('Copying %d screenshot%s to clipboard',length(ims),c_strIfNumIsPlural(length(ims)));
			for i = length(filenames):-1:1
				CopyFileToClipboard(filenames{i});
				if i~=1, pause(1); end;
			end
			c_sayDone();
			c_sayDone();
		end
		
		function copyMultipleToClipboard(h,varargin)
			prog = c_progress(length(h),'Copying figure %d/%d');
			for i = 1:length(h)
				prog.updateStart(i);
				figure(h(i));
				drawnow();
				c_FigurePrinter.copyToClipboard(varargin{:});
				pause(0.5);
				prog.updateEnd(i);
			end
			prog.stop();
		end
		
		function copyToClipboard(varargin)
			p = inputParser();
			p.addOptional('magnification',1,@isscalar);
			p.addOptional('doCrop',true,@islogical);
			p.addOptional('hf',[],@ishandle);
			p.addParameter('doTransparent',true,@islogical);
			p.parse(varargin{:});
			s = p.Results;
			
			c_say('Copying figure to clipboard');
			filename = [tempname '.png'];
			c_FigurePrinter.copyToFile(filename,...
				'magnification',s.magnification,...
				'doCrop',s.doCrop,...
				'doTransparent',s.doTransparent,...
				'hf',s.hf);
			c_saySingle('Copying to clipboard');
			CopyFileToClipboard(filename);
			c_sayDone();
		end
		
		function copyToFile(varargin)
			p = inputParser();
			p.addRequired('filepath',@ischar);
			p.addParameter('magnification',1,@isscalar);
			p.addParameter('doCrop',true,@islogical);
			p.addParameter('doTransparent',true,@islogical);
			p.addParameter('hf',[])
			p.parse(varargin{:});
			s = p.Results;
			
			if isempty(s.hf)
				s.hf = gcf;
			end
			
			c_say('Copying figure');
			tmp = findobj(s.hf,'Tag','c_NonPrinting');
			if ~isempty(tmp)
				c_saySingle('Hiding c_NonPrinting elements')
				tmpIndices = ismember(get(tmp,'Visible'),{'on'});
				set(tmp(tmpIndices),'Visible','off');
			end
			c_FigurePrinter.initialize();
			origBackground = get(s.hf,'Color');
			c_saySingle('Setting axis background');

			[~,~,ext] = fileparts(s.filepath);	

			if ismember(ext, {'.svg'})
				% transparency not supported in export (but background can be separated by editing vector graphic later)
				% force false to at least set backgrounds white
				s.doTransparent = false;  
			end

			if s.doTransparent
				set(s.hf, 'Color', 'none'); 
			else
				set(s.hf, 'Color', [1 1 1]); 
				hBackgrounds = findobj(s.hf,'-property','BackgroundColor');
				if ~isempty(hBackgrounds)
					%matchingBackgrounds = cellfun(@(bc) isequal(bc,[1 1 1]*),get(hBackgrounds,{'BackgroundColor'}));
					matchingBackgrounds = cellfun(@(bc) ~ischar(bc) && (...
						max(abs(bc(1,:)-[1 1 1]*0.94))<1e4*eps || ...
						max(abs(bc(1,:)-[1 1 1]*0.06))<1e4*eps),get(hBackgrounds,{'BackgroundColor'}));
					hBackgrounds(~matchingBackgrounds) = [];
				end
				if ~isempty(hBackgrounds)
					tbackposs = get(hBackgrounds,'Position');
					tbackcols = get(hBackgrounds,'BackgroundColor');
					set(hBackgrounds,'BackgroundColor',[1 1 1]);	
					for iH = 1:length(hBackgrounds)
						hBackgrounds(iH).Position = tbackposs{iH};
					end
					drawnow
				end
			end
			c_saySingle('Exporting figure %s', s.filepath);
			switch(ext)
				case '.png'
					extraArgs = {};
					if ~s.doCrop
						extraArgs = [extraArgs, '-nocrop'];
					end
					if s.doTransparent
						extraArgs = [extraArgs, '-transparent'];
					end
					try
						export_fig(s.filepath,'-png',['-m' num2str(s.magnification)],'-opengl',extraArgs{:},s.hf);
					catch
						% try again
						pause(0.5)
						try
							export_fig(s.filepath,'-png',['-m' num2str(s.magnification)],'-opengl',extraArgs{:},s.hf);
						catch
							% try one last time after longer delay
							pause(5)
							export_fig(s.filepath,'-png',['-m' num2str(s.magnification)],'-opengl',extraArgs{:},s.hf);
						end
					end
		
				case '.svg'
					saveas(s.hf, s.filepath)
			
				otherwise
					error('%s export not implemented', ext)
			end
			
			
			c_saySingle('Resetting axis background');
			set(s.hf,'Color',origBackground);
			if ~s.doTransparent && ~isempty(hBackgrounds)
				for iH = 1:length(hBackgrounds)
					hBackgrounds(iH).BackgroundColor = tbackcols{iH};
					hBackgrounds(iH).Position = tbackposs{iH};
				end
				drawnow
			end
			if ~isempty(tmp)
				c_saySingle('Restoring c_NonPrinting elements')
				set(tmp(tmpIndices),'Visible','on');
			end
			c_sayDone();
		end
	end
	
	methods
		function obj = c_FigurePrinter(FigureDirectory, defaultType, defaultSize)

			c_FigurePrinter.initialize();
			
			if nargin > 2
				obj.size = defaultSize;
			end
			if nargin > 1
				obj.ext = defaultType;
			end
			if nargin > 0
				obj.figureDirectory = FigureDirectory;
			else
				obj.figureDirectory = 'Figures';
			end
			
			if ~strcmp(obj.ext(1:2),'-d')
				error('Specified extension must begin with ''-d'', e.g. -dpng');
			end
			
			if ~exist(obj.figureDirectory,'dir') 
				mkdir(obj.figureDirectory);
			end
		end
		function enable(obj)
			obj.disabled = false;
		end
		function disable(obj)
			obj.disabled = true;
		end
		function disableNativeFigureSave(obj)
			obj.alsoSaveNativeFig = false;
		end
		function doPrint(obj)
			obj.doPrintText = true;
		end
		
		function save(obj,filename,ext,pageDimensions)
			if obj.disabled
				return % don't actually save
			end
			
			if nargin > 3
				set(gcf, 'PaperSize', [pageDimensions(1) pageDimensions(2)]);
				set(gcf,'PaperPosition',[0 0 pageDimensions(1) pageDimensions(2)]);
			elseif ~isempty(obj.size)
				set(gcf, 'PaperSize', [obj.size(1) obj.size(2)]);
			end
			if nargin <= 2 
				ext = obj.ext;
			end
			filepath = [obj.figureDirectory '/' filename];
			
			if obj.doPrintText
				fprintf('Saving figure to %s\n',filepath);
			end
			
			if obj.alsoSaveNativeFig
				savefig([filepath '.fig']);
			end
			
			print(ext,filepath,['-r' num2str(obj.resolution)]);
		end
		
		function export(obj,filename,ext,varargin)
			if obj.disabled
				return % don't actually save
			end
			
			if nargin <= 2 
				ext = obj.ext;
			end
			filepath = [obj.figureDirectory '/' filename];
			
			if obj.doPrintText
				fprintf('Saving figure to %s\n',filepath);
			end
			
			if obj.alsoSaveNativeFig
				savefig([filepath '.fig']);
			end
			
			doRemoveBackground = true;
			doCrop = true;
			
			extraArgs = {};
			
			if doRemoveBackground
				origBackground = get(gcf,'Color');
				set(gcf, 'Color', 'none'); % Sets axes background
				extraArgs = [extraArgs,'-transparent','-opengl'];
			end
				
			if ~doCrop
				extraArgs = [extraArgs,'-nocrop'];
			end
			
			%print(ext,filepath,['-r' num2str(obj.resolution)]);
			
			if strcmp(ext,'-dpng'), ext='-png'; end;
			if strcmp(ext,'-depsc'), ext='-eps'; end;
			export_fig(filepath,ext,extraArgs{:},varargin{:});
			
			if doRemoveBackground
				set(gcf,'Color',origBackground);
			end
		
		end
	end
	
end

