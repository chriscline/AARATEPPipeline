classdef c_GUI_Text < c_GUI_handle
% c_GUI_Text - GUI class for drawing text
% Similar to uicontrol('style','text') but allows for autoresizing and other misc

	properties
		doAutoResize
		MaxFontSize
	end
	
	properties(Dependent)
		String
		Units
		Position
		FontWeight
		HorizontalAlignment
	end
	
	properties(SetAccess=protected)
		Parent
		th
	end
	
	properties(Access=protected)
		listenerHandles
		numUpdatesQueued
		currentlyUpdating = false;
	end
	
	
	methods
		function o = c_GUI_Text(varargin)
			if nargin == 0, c_GUI_Text.testfn(); return; end;
			p = inputParser();
			p.addParameter('Units','normalized',@ischar);
			p.addParameter('Position',[0 0 1 1],@isvector);
			p.addParameter('Parent',[],@ishandle);
			p.addParameter('String','',@ischar);
			p.addParameter('FontWeight','normal',@ischar);
			p.addParameter('HorizontalAlignment','center',@ischar);
			p.addParameter('doAutoResize',true,@islogical);
			p.addParameter('MaxFontSize',inf,@isscalar);
			p.parse(varargin{:});
			s = p.Results;
			
			% construct GUI
			o.th = uicontrol('style','text',...
				'Parent',s.Parent);
			
			% assume each parser parameter has property with identical name
			
			lateParams = {'Position','String'}; % skip some parameters until later
			
			for iF = 1:length(p.Parameters)
				if ismember(p.Parameters{iF},lateParams)
					continue;
				end
				if isprop(o,p.Parameters{iF})
					o.(p.Parameters{iF}) = s.(p.Parameters{iF});
				end
			end
			
			for iF = 1:length(lateParams)
				o.(lateParams{iF}) = s.(lateParams{iF});
			end
			
			o.numUpdatesQueued = 0;
			
			parent = o;
			while c_isFieldAndNonEmpty(parent,'Parent')
				parent = parent.Parent;
				if isequal(parent.Type,'root')
					break
				end
				newListener = addlistener(parent,'SizeChanged',@(h,e) o.queueUpdateFontSize());
				if isempty(o.listenerHandles)
					o.listenerHandles = newListener;
				else
					o.listenerHandles(end+1) = newListener;
				end
			end
			% add listener to child as well, in case its position is changed directly without going through o.Position
			o.listenerHandles(end+1) = addlistener(o.th,'SizeChanged',@(h,e) o.queueUpdateFontSize());
		end
		
		function delete(o)
		end
		
		function setVerticalAlignment(o,val)
			if nargin < 2
				val = javax.swing.JLabel.CENTER;
			end
			if 0
				jh = findjobj(o.th);
				jh.setVerticalAlignment(val);
			else
				% run after delay to reduce drawnow time in findjobj
				c_fn_runAfterDelay(@(th) c_use(findjobj(th),@(jh) jh.setVerticalAlignment(val)),1,'args',{o.th})
			end
		end
		
		function set.String(o,newStr) 
			assert(ischar(newStr));
			o.th.String = newStr;
			o.queueUpdateFontSize();
		end
		
		function queueUpdateFontSize(o)
			% run twice, once immediately and once some time later after giving elements time to resize
			o.updateFontSize();
			
			%c_saySingle('Queued font size update');
			
			timerName = sprintf('c_GUI_Text_UpdateTimer');
			
			o.numUpdatesQueued = o.numUpdatesQueued + 1;
			
			t = timer(...
				'BusyMode','drop',...
				'ExecutionMode','singleShot',...
				'Name',timerName,...
				'StartDelay',0.1,...
				'TimerFcn',@(h,e) o.updateFontSize_delayed(),...
				'StopFcn',@(h,e) delete(h));
			start(t);
		end
		
		function updateFontSize(o)
			%c_saySingle('Updating font size');
			if o.doAutoResize && ~isempty(o.th.String)
				prevUnits = o.th.Units;
				if 0
					o.th.Units = 'normalized';
					sizeChange = 1/max(o.th.Extent(3:4)./o.th.Position(3:4));
					if sizeChange > 1 && sizeChange < 1.2
						sizeChange = 1; % if only a small increase in size, don't change at all 
						% (to avoid distracting font size variations with small changes to text content)
					end
					o.th.FontSize = min(o.th.FontSize * sizeChange,o.MaxFontSize);
				else
					o.th.Units = 'pixels';
					sizeChange = 1/max(o.th.Extent(3:4)./o.th.Position(3:4))*0.9;
					if sizeChange > 1 && sizeChange < 1.2
						sizeChange = 1; % if only a small increase in size, don't change at all 
						% (to avoid distracting font size variations with small changes to text content)
					end
					newFontSize = roundDownToReasonableFontSize(o.th.FontSize * sizeChange);
					newFontSize = min(newFontSize, o.MaxFontSize);
					if newFontSize ~= 0
						o.th.FontSize = newFontSize;
					end
					%c_saySingle('New font size: %s',c_toString(o.th.FontSize));
				end
				o.th.Units = prevUnits;
			end
		end
		
		function str = get.String(o)
			str = o.th.String;
		end
		
		function set.Units(o,newUnits)
			o.th.Units = newUnits;
		end
		function u = get.Units(o)
			u = o.th.Units;
		end
		
		function set.Position(o,newPos)
			o.th.Position = newPos;
			o.updateFontSize();
		end
		function pos = get.Position(o)
			pos = o.th.Position;
		end
		
		function set.MaxFontSize(o,val)
			o.MaxFontSize = val;
			o.updateFontSize();
		end
		
		function set.FontWeight(o,fw)
			o.th.FontWeight = fw;
		end
		function fw = get.FontWeight(o)
			fw = o.th.FontWeight;
		end
		
		function set.HorizontalAlignment(o,ha)
			o.th.HorizontalAlignment = ha;
		end
		function ha = get.HorizontalAlignment(o)
			ha = o.th.HorizontalAlignment;
		end
	end
	
	methods(Access=protected)
		function updateFontSize_delayed(o)
			% finding and deleting previously queued timers is too expensive, so instead
			%  just track number of queued timers and only execute task at last in queue
			o.numUpdatesQueued = o.numUpdatesQueued - 1;
			if o.numUpdatesQueued == 0
				o.updateFontSize();
			end
		end
	end
	
	methods(Static)
		function addDependencies()
			persistent pathModified;
			if isempty(pathModified)
				mfilepath=fileparts(which(mfilename));
				addpath(fullfile(mfilepath,'../ThirdParty/findjobj'));
				addpath(fullfile(mfilepath,'../'));
				c_GUI_initializeGUILayoutToolbox();
				pathModified = true;
			end
		end
		
		function testfn()
			hf = figure;
% 			hp = uipanel('Title','Test container',...
% 				'Units','pixels',...
% 				'Position',[10 20 120 80]);
			hp = uipanel('Title','Test container',...
				'Units','normalized',...
				'Position',[0.1 0.2 0.4 0.3]);
			c_GUI_Text('Parent',hp,...
				'String','Test text');
		end
	end
end

function val = roundDownToReasonableFontSize(val)
	% for very large numbers, round to nearest 10, and for smaller numbers progressively round to nearest 5,1,0.5,0.1
	if val > 100
		interval = 10;
	elseif val > 50
		interval = 5;
	elseif val > 10
		interval = 1;
	elseif val > 2
		interval = 0.5;
	elseif val > 0.5 
		interval = 0.1;
	else
		return; % don't modify val
	end
	
	val = floor(val/interval)*interval;		
end
	