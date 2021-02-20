classdef c_progress < handle
% c_progress - Class for printing loop progress updates and estimating time remaining
% 
% Example:
% 	N = 100;
%   prog = c_progress(N,'Loop %d/%d'); % first %d is current loop variable, second %d is total
%   prog.start();
%   for i=1:N
%      prog.update();
%      pause(0.1) % do some work here
%   end
%   prog.stop(); % print elapsed time
	
	
	properties
		N % total number expected
		formatStr 
		n % current number
		startTime
		lastTime
		lastNPrinted
		nextTimeToPrint
		doPrintTimeEstimate
		doAssumeUpdateAtEnd
		waitToPrint
		printEvery
		didSayStart
		waitbarSimpleStr;
	end
	
	properties(SetAccess=protected)
		isParallel
		isDisabled
		doShowWaitbar
		doShowWaitbarOnly
		waitbarTitle
	end
	
	properties(Access=protected)
		par_tmpDir = '';
		endsToNotPrintCounter = 0;
		ticTimer
		h_waitbar = [];
	end
	
	methods
		function o = c_progress(varargin)
			
			if nargin==0
				o.testfn();
				return;
			end
			
			p = inputParser;
			p.addRequired('N',@isscalar);
			p.addOptional('formatStr','%d/%d',@(x) ischar(x) || isa(x,'function_handle'));
				% should be format string with two fields, first for current n, and second for total N
				% or a function handle that takes current n as input and returns a formatted string
			p.addParameter('initialn',0,@isscalar);
			p.addParameter('doPrintTimeEstimate',true,@islogical);
			p.addParameter('waitToPrint',0,@isscalar); % s
			p.addParameter('printEvery',1,@isscalar);
			p.addParameter('doAssumeUpdateAtEnd',false,@islogical);
			p.addParameter('isParallel',false,@islogical);
			p.addParameter('isDisabled',false,@islogical);
			p.addParameter('doShowWaitbar',false,@islogical);
			p.addParameter('doShowWaitbarOnly',false,@islogical);
			p.addParameter('waitbarTitle','',@ischar);
			p.addParameter('waitbarSimpleStr','',@ischar); % if not specified, will use formatStr for waitbar instead
			p.parse(varargin{:});
			s = p.Results;
			
			% copy parsed input to object properties of the same name
			fieldNames = fieldnames(p.Results);
			for iF=1:length(fieldNames)
				if isprop(o,p.Parameters{iF})
					o.(fieldNames{iF}) = p.Results.(fieldNames{iF});
				end
			end
			
			o.n = s.initialn;
			
			o.didSayStart = false;
			
			if o.isParallel
				o.par_tmpDir = tempname();
				assert(exist(o.par_tmpDir,'file')==0);
				mkdir(o.par_tmpDir);
			end
			
			if o.doShowWaitbarOnly
				o.doShowWaitbar = true;
			end
			
			if o.doShowWaitbar
				assert(~o.isParallel,'Graphical waitbar not currently supported when running in parallel');
			end
			
			o.start();
		end
		
		function start(o,message,varargin)
			if ~isempty(o.h_waitbar)
				close(o.h_waitbar);
				o.h_waitbar = [];
			end
			o.n = 0;
			o.ticTimer = tic;
			o.startTime = toc(o.ticTimer);
			o.lastTime = o.startTime;
			%o.nextTimeToPrint = o.startTime + o.waitToPrint;
			o.nextTimeToPrint = 0;
			o.lastNPrinted = 0;
			
			if ~o.isDisabled
				if nargin > 1
					o.didSayStart = true;
					if ~o.doShowWaitbarOnly
						c_say(message,varargin{:});
					end
					if o.doShowWaitbar
						o.h_waitbar = waitbar(0,sprintf(message,varargin{:}),'Name',o.waitbarTitle);
					end
				elseif o.doShowWaitbar
					o.h_waitbar = waitbar(0,'');
				end
			end
		end
		
		function stop(o,message,varargin)
			if o.isDisabled
				return;
			end
			
			if o.didSayStart
				say = @c_sayDone;
			else
				say = @c_saySingle;
			end
			if ~o.doShowWaitbarOnly
				if nargin < 2
					say('Total time: %s',c_relTime_toStr(toc(o.ticTimer) - o.startTime));
				else
					say([message,' Total time: %s'],varargin{:},c_relTime_toStr(toc(o.ticTimer) - o.startTime));
				end
			end
			
			if ~isempty(o.h_waitbar)
				close(o.h_waitbar);
			end
			
			if o.isParallel
				rmdir(o.par_tmpDir,'s');
			end
		end
		
		function delete(o)
			if ~isempty(o.h_waitbar) && ishandle(o.h_waitbar)
				close(o.h_waitbar);
			end
		end
		
		function updateStart(o,n)
			if o.isDisabled
				return;
			end
			
			if nargin < 2
				o.n = o.n + 1;
			else
				o.n = n;
			end
			didPrint = o.printUpdate(true);
			if ~didPrint
				o.endsToNotPrintCounter = o.endsToNotPrintCounter + 1;
			end
		end
		
		function updateEnd(o,n,varargin)
			if o.isDisabled || o.doShowWaitbarOnly
				return;
			end
			
			if o.endsToNotPrintCounter > 0
				o.endsToNotPrintCounter = o.endsToNotPrintCounter - 1;
				return;
			end
			c_sayDone(varargin{:});
		end
		
		function update(o,n,message,varargin)
			if o.isDisabled
				return;
			end
			
			if nargin < 2 || isempty(n)
				if o.isParallel
					warning('Should specify counter value during update when running inside parfor');
				end
				o.n = o.n + 1;
			else
				assert(isscalar(n));
				o.n = n;
				if n==0
					o.start();
				end
			end
			if nargin < 3 || o.doShowWaitbarOnly
				o.printUpdate();
			else
				assert(ischar(message));
				o.printUpdate(true);
				c_saySingle(message,varargin{:});
				c_sayDone();
			end
		end
	end
			
	methods (Access=protected)
		function didPrint = printUpdate(o,isExplicitStart)
			
			if nargin < 2
				isExplicitStart = false;
			end
			
			numFinished = o.n;
			if ~o.doAssumeUpdateAtEnd
				numFinished = numFinished - 1;
			end
			
			if o.isParallel
				listing = dir(o.par_tmpDir);
				numFiles = length(listing)-2; % assuming everything other than '.' and '..' is a file left by another worker
				numFinished = numFiles + o.doAssumeUpdateAtEnd;
				
				fclose(fopen(fullfile(o.par_tmpDir, [num2str(o.n) '.tmp']), 'w')); % make empty file recording the update for this n'th iteration
			end
			
			if (numFinished < o.lastNPrinted + o.printEvery - 1) 
				% do not print
				didPrint = false;
				return;
			end
				
			currentTime = toc(o.ticTimer);
			
			if o.waitToPrint > 0 && currentTime < o.nextTimeToPrint
				% do not print
				didPrint = false;
				return;
			end
			
			didPrint = true;
			
			currentDateTime = clock();
			
			totalElapsedTime = currentTime - o.startTime;
			
			if numFinished > 0
				ETR = (o.N - numFinished) * totalElapsedTime / (numFinished);
				ETRStr = c_relTime_toStr(ETR);
				ETA = datenum(currentDateTime) + ETR/(60*60*24);
				ETAStr = c_dateNum_toStr(ETA);
				timeEstimateValid = true;
			else
				timeEstimateValid = false;
			end
			
			if isExplicitStart
				say = @c_say;
			else
				say = @c_saySingle;
			end
			
			elapsedTime = currentTime - o.lastTime;
			
			o.lastTime = currentTime;
			
			o.lastNPrinted = numFinished;
			
			if o.waitToPrint > 0
				o.nextTimeToPrint = currentTime + o.waitToPrint;
			end
			
			if ischar(o.formatStr)
				formatStr = sprintf(o.formatStr,o.n,o.N);
			else
				% assume formatStr is actually a function handle
				formatStr = o.formatStr(o.n);
				assert(ischar(formatStr));
			end
			
			if ~o.isParallel
				if o.doPrintTimeEstimate && timeEstimateValid
					strToPrint = sprintf('%s\t Elapsed: %s \t ETR: %s \t ETA: %s',...
						formatStr,c_relTime_toStr(elapsedTime), ETRStr,ETAStr);
				else
					strToPrint = formatStr;
				end
			else
				if o.doPrintTimeEstimate && timeEstimateValid
					strToPrint = sprintf('%s\t (parallel %d/%d) \t Elapsed: %s \t ETR: %s \t ETA: %s',...
						formatStr,numFinished+1,o.N,c_relTime_toStr(elapsedTime), ETRStr,ETAStr);
				else
					strToPrint = sprintf('%s\t (parallel %d/%d)',formatStr,numFinished+1,o.N);
				end
			end
			
			if ~o.doShowWaitbarOnly
				say('%s',strToPrint);
			end
			
			if o.doShowWaitbar
				assert(~isempty(o.h_waitbar));
				if isempty(o.waitbarSimpleStr)
					waitbar(o.n/o.N,o.h_waitbar,c_str_wrap(strToPrint,'toLength',50));
				else
					waitbar(o.n/o.N,o.h_waitbar,o.waitbarSimpleStr);
				end
			end
		end
	end
		
	methods (Static)
		function testfn(varargin)
			%%
			clearvars -except varargin
			
			N = 20;
			prog = c_progress(N,'Progress test function %3d/%d',varargin{:});
			pause(0.5);
			prog.start();
			for i=1:N
				prog.update();
				pause(1);
			end
			prog.stop();
		end
		
		function partestfn()
			N = 200;
			prog = c_progress(N,'Parallel progress test function %d/%d','isParallel',true);
			prog.start();
			parfor i=1:N
				prog.update(i);
				pause(0.5);
			end
			prog.stop();
		end
	end



	
end

function str = c_relTime_toStr(relTimeSec)

	remainder = relTimeSec;

	days = 0;
% 	days = fix(remainder / (60*60*24));
% 	remainder = rem(remainder,(60*60*24));
	
	hours = fix(remainder / (60*60));
	remainder = rem(remainder,(60*60));
	
	minutes = fix(remainder / 60);
	seconds = rem(remainder,60);
	
	if days ~= 0
		str =sprintf('%d d %d h %d m %4.3g s',days,hours,minutes,seconds);
	elseif hours ~= 0
		str =sprintf(	  '%d h %d m %4.3g s'	 ,hours,minutes,seconds);
	elseif minutes ~= 0
		str =sprintf(		   '%d m %4.3g s'		   ,minutes,seconds);
	else
		str =sprintf(				'%4.3g s'				   ,seconds);
	end
end
	
function str = c_dateNum_toStr(absDateNum,relToDateNum)
	if nargin < 2
		relToDateNum = now();
	end
	
	%TODO: subtract comment elements if they are the same (i.e. don't show month if it is the same as current)

	str = datestr(absDateNum);
end
	
