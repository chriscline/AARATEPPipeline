classdef c_FigureRecorder < handle
	%FigureRecorder Summary of this class goes here
	%   Detailed explanation goes here
	
	properties(SetAccess=protected)
		size = [];
		outputDir;
		filename;
		doOverwriteExisting;
		doVerbose;
		method;
		frameRate;
		isInProgress = false;
		vidObj;
		outputPath;
		printPrefix = 'FigureRecorder: ';
	end
	
	properties(Access=protected)
		ims
	end
	
	methods(Static)
		function initialize()
			persistent pathModified;
			if isempty(pathModified)
				c_saySingle('FigureRecorder: Adding dependencies to path');
				mfilepath=fileparts(which(mfilename));
				addpath(fullfile(mfilepath,'./CopyFileToClipboard'));
				pathModified = true;
			end
		end
		
		function outputPath = recordFullRotation(varargin)
			p = inputParser();
			p.KeepUnmatched = true;
			p.addParameter('handle',[],@ishandle);
			p.addParameter('startView',[-37.5,30],@(x) isvector(x) && length(x)==2);
			p.addParameter('numFrames',500,@isscalar);
			p.addParameter('duration',10,@isscalar);
			p.addParameter('args',{},@iscell); % args to c_FigureRecorder
			p.addParameter('backgroundColor',[1 1 1],@isvector);
			p.parse(varargin{:});
			s = p.Results;
			
			unmatchedArgs = c_structToCell(p.Unmatched);
			o = c_FigureRecorder('frameRate',s.numFrames/s.duration,unmatchedArgs{:});
			
			if isempty(s.handle)
				s.handle = gcf;
			end
			
			if strcmpi(s.handle.Type,'Axes')
				axisHandle = s.handle;
			else
				set(s.handle,'Color',s.backgroundColor);
				axisHandles = findobj(s.handle,'type','Axes');
				assert(~isempty(axisHandles));
				axisHandle = axisHandles(1);
			end
			
			set(axisHandles,'CameraViewAngleMode','Manual');
			axis(axisHandles,'equal');
			set(axisHandles,'XTickMode','manual','YTickMode','manual','ZTickMode','manual');
			
			o.start();
			
			% assume we only want to sweep azimuth
			prog = c_progress(s.numFrames, 'Capturing frame %d/%d',...
				'waitToPrint', 5);
			for az = s.startView(1) + linspace(0,360,s.numFrames+1)
				prog.update()
				view(axisHandle,az,s.startView(2));
				drawnow;
				o.captureFrame(s.handle);
			end
			prog.stop();
			
			outputPath = o.outputPath;
			
			o.stop();
			
		end
		
		function testfn()
			hf = figure;
			
			fr = c_FigureRecorder();
			
			N = 100;
			x = 1:N;
			y = cumsum(rand(1,N));
			
			fr.start();
			for i=1:N
				plot(x(1:i),y(1:i));
				xlim(extrema(x));
				ylim(extrema(y));
				fr.captureFrame(hf);
			end
			fr.stop();
			
			fr.openLastSaved();
		end
		
		function testfn_rotatingFig() 
			figure;
			plot(rand(3,20)');
			path = c_FigureRecorder.saveRotatingGif('filename','todelete-test.gif');
			
			winopen(path);
			
			keyboard
		end
	end
	
	methods
		function o = c_FigureRecorder(varargin)
			p = inputParser();
			p.addParameter('outputDir','./Figures',@ischar);
			p.addParameter('filename','FigureMovie.avi',@ischar);
			p.addParameter('outputPath', '', @ischar);
			p.addParameter('doOverwriteExisting',false,@islogical);
			p.addParameter('doVerbose',false,@islogical);
			p.addParameter('method','',@ischar);
			p.addParameter('frameRate',10,@isscalar); % in fps
			p.parse(varargin{:});
			s = p.Results;

			if ~isempty(s.outputPath)
				assert(all(ismember({'outputDir', 'filename'}, p.UsingDefaults)));
				[s.outputDir, s.filename, ext] = fileparts(s.outputPath);
				s.filename = [s.filename ext];
			end
			s = rmfield(s, 'outputPath');
			
			if isempty(s.method)
				[~, ~, ext] = fileparts(s.filename);
				switch(ext)
					case '.gif'
						s.method = 'GifImwrite';
					otherwise
						s.method = 'VideoWriter';
				end
			end

			% copy parsed input to object properties of the same name
			fieldNames = fieldnames(s);
			for iF=1:length(fieldNames)
				if isprop(o,p.Parameters{iF})
					o.(fieldNames{iF}) = s.(fieldNames{iF});
				end
			end
		end
		
		function ensureOutputDirExists(o)
			if ~exist(o.outputDir,'dir')
				if o.doVerbose
					c_saySingle('%sCreating output dir at %s',o.printPrefix,o.outputDir);
				end
				mkdir(o.outputDir);
			end
		end
		
		function start(o)
			if o.isInProgress
				error('Already in progress');
			end
			
			o.ensureOutputDirExists();
			
			if o.doVerbose, c_say('%sSetting output path',o.printPrefix); end;
			o.outputPath = fullfile(o.outputDir,o.filename);
			counter = 0;
			while ~o.doOverwriteExisting && exist(o.outputPath,'file')
				if o.doVerbose, c_saySingle('%sFile already exists at %s',o.printPrefix,o.outputPath); end;
				counter = counter+1;
				[path,filename,ext] = fileparts(o.filename);
				filename = [filename '_' num2str(counter) ext];
				o.outputPath = fullfile(o.outputDir,path,filename);
			end
			if o.doVerbose
				if exist(o.outputPath,'file')
					c_saySingle('%sOverwriting file at %s',o.printPrefix,o.outputPath);
				else
					c_saySingle('%sOutput path: %s',o.printPrefix,o.outputPath);
				end
				c_sayDone();
			end
			
			switch(o.method)
				case 'VideoWriter'
					[~,~,ext] = fileparts(o.outputPath);
					switch(ext)
						case {'.mp4','.m4v'}
							profile = 'MPEG-4';
						case '.avi'
							profile = 'Motion JPEG AVI';
						otherwise
							error('Unrecognized extension: %s',ext);
					end
					o.vidObj = VideoWriter(o.outputPath,profile);
					o.vidObj.Quality = 100;
					o.vidObj.FrameRate = o.frameRate;
					open(o.vidObj);
				case 'GifImwrite'
					o.ims = [];
				otherwise
					error('Invalid method');
			end
			
			o.isInProgress = true;
		end
		
		function captureFrame(o,varargin) 
			p = inputParser();
			p.addOptional('graphicsHandle',[],@ishandle);
			p.parse(varargin{:});
			s = p.Results;
			
			if isempty(s.graphicsHandle)
				s.graphicsHandle = gcf;
			end
			
			if ~o.isInProgress
				o.start();
			end
			
			if o.doVerbose, c_say('%sCapturing frame',o.printPrefix); end;
			
			switch(o.method)
				case 'VideoWriter'
					writeVideo(o.vidObj, getframe(s.graphicsHandle));
				case 'GifImwrite'
					f = getframe(s.graphicsHandle);
					im = f.cdata;
					if isempty(o.ims)
						o.ims = im;
					else
						o.ims(:,:,:,end+1) = im;
					end
				otherwise
					error('Invalid method');
			end
			
			if o.doVerbose, c_sayDone(); end;
		end
		
		function stop(o)
			if ~o.isInProgress
				error('Not in progress');
			end

			if o.doVerbose, c_saySingle('%sClosing',o.printPrefix); end;
			
			switch(o.method)
				case 'VideoWriter'
					close(o.vidObj);
				case 'GifImwrite'
					ims = permute(o.ims,[1 2 4 3]);
					origSize = size(ims);
					ims = reshape(ims,prod(origSize(1:2)),origSize(3),origSize(4));
					[indexedIms,map] = rgb2ind(ims,256);
					indexedIms = reshape(indexedIms,origSize(1:3));
					indexedIms = permute(indexedIms,[1 2 4 3]);
					imwrite(indexedIms,map,o.outputPath,...
						'DelayTime',1/o.frameRate,...
						'LoopCount',inf);
				otherwise
					error('Invalid method');
			end
			
			c_saySingle('Wrote video to %s',o.outputPath);
			
			o.isInProgress = false;
		end
		
		function openLastSaved(o)
			if o.doVerbose
				c_say('%Opening last saved at %s',o.printPrefix,o.outputPath);
			end
			if o.isInProgress
				warning('Save still in progress');
			end
			
			if exist(o.outputPath,'file')
				winopen(o.outputPath);
			end
			
			if o.doVerbose, c_sayDone(); end;
		end
	end
	
end

