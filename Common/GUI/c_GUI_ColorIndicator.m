classdef c_GUI_ColorIndicator < c_GUI_handle
% c_GUI_ColorIndicator - simple GUI class to draw a color indicator with an optional label

	properties
		Units
		Position
		Callback
	end
	
	properties(Dependent)
		Label
		Color
	end
	
	properties(SetAccess=protected)
		Parent;
	end
	
	properties(Access=protected)
		gcont
		hEdit
		indicatorAxis
		labelHandle
	end
	
	
	methods
		function o = c_GUI_ColorIndicator(varargin)
			if nargin == 0, c_GUI_ColorIndicator.testfn(); return; end;
			
			c_GUI_ColorIndicator.addDependencies()
			
			p = inputParser();
			p.addParameter('Position',[0 0 1 1],@isvector);
			p.addParameter('Units','normalized',@ischar);
			p.addParameter('IndicatorSize',[15 15],@(x) numel(x)==2 && isnumeric(x)); % in pixels
			p.addParameter('Parent',[],@ishandle);
			p.addParameter('Color',[1 1 1]*0.5,@isvector);
			p.addParameter('Label','',@ischar);
			p.addParameter('LabelPosition','right',@(x) ismember(x,{'right'}));
			p.addParameter('LabelFontWeight','normal',@ischar);
			p.addParameter('LabelMayHaveSubscripts',false,@islogical);
			p.addParameter('Padding',5,@isscalar);
			p.parse(varargin{:});
			s = p.Results;
			
			% assume each parser parameter has property with identical name
			for iF = 1:length(p.Parameters)
				if isprop(o,p.Parameters{iF})
					o.(p.Parameters{iF}) = s.(p.Parameters{iF});
				end
			end
			
			assert(~isempty(s.Parent));
			
			% construct GUI
			switch(s.LabelPosition)
				case 'right'
					hvb = uix.VBox('Parent',o.Parent,'Padding',s.Padding);
					
					if s.LabelMayHaveSubscripts
						s.IndicatorSize = s.IndicatorSize*2;
					end
					doAnnotationLabel = s.LabelMayHaveSubscripts;
					
					uix.Empty('Parent',hvb);
					hhb = uix.HBox('Parent',hvb,'Spacing',5);
					uix.Empty('Parent',hvb);
					set(hvb,'Heights',[-1 s.IndicatorSize(2) -1],...
						'MinimumHeights',[0 s.IndicatorSize(2) 0]);
					
					o.indicatorAxis = axes('Parent',hhb,...
						'ActivePositionProperty','position');
					
					
					
					if ~doAnnotationLabel
						labelHandle = uicontrol('style','Text',...
							'Parent',hhb,...
							'FontSize',s.IndicatorSize(2)-7,...
							'FontWeight',s.LabelFontWeight,...
							'HorizontalAlignment','left',...
							'String',o.Label);
						if 0
							jh = findjobj(labelHandle);
							jh.setVerticalAlignment(javax.swing.JLabel.CENTER)
						elseif 0
							% run after delay to reduce drawnow time in findjobj
							c_fn_runAfterDelay(@(th) c_use(...
								findjobj(th),...
									@(jh) jh.setVerticalAlignment(javax.swing.JLabel.CENTER)),...
									1,...
								'args',{labelHandle})
						else
							% do no vertical alignment
						end

						set(hhb,'Widths',[s.IndicatorSize(1), -1]);
					else
						hhhp = uipanel('Parent',hhb,'BorderType','none');
						tmp = annotation(hhhp,'TextBox',...
							'FitBoxToText','off',...
							'Units','normalized',...
							'Position',[0 0 1 0.9],...
							'String',o.Label,...
							'HorizontalAlignment','left',...
							'VerticalAlignment',c_if(s.LabelMayHaveSubscripts,'top','middle'),...
							'FontWeight',s.LabelFontWeight,...
							'FontUnits','normalized',...
							'FontSize',c_if(s.LabelMayHaveSubscripts,0.45,0.9),...
							'EdgeColor','none');
						tmp
						set(hhb,'Widths',[s.IndicatorSize(1), -1]);
					end
					
					patch(o.indicatorAxis,[0 1 1 0],[0 0 1 1],s.Color);
					o.indicatorAxis.Clipping = 'off';
					o.indicatorAxis.Color = 'none';
					axis(o.indicatorAxis,'equal');
					xlim(o.indicatorAxis,c_limits_multiply([-0.1 1.1],c_if(s.LabelMayHaveSubscripts,2,1)));
					ylim(o.indicatorAxis,c_limits_multiply([-0.1 1.1],c_if(s.LabelMayHaveSubscripts,2,1)));
					axis(o.indicatorAxis,'off');
					
					if doAnnotationLabel
						
					end
					
					
					
					%axis(o.indicatorAxis,'off');
					
				otherwise
					error('Invalid LabelPosition: %s',s.LabelPosition);
			end
		end
		
		function set.Color(o,newColor) 
			assert(isvector(newColor));
			set(findobj(o.indicatorAxis,'type','patch'),'FaceColor',newColor);
		end
		
		function col = get.Color(o)
			obj = findobj(o.indicatorAxis,'type','patch');
			if isempty(obj)
				col = [];
			else
				obj = obj(1);
				col = obj.FaceColor;
			end
		end
		
		function set.Label(o,newLabel)
			o.labelHandle.String = newLabel;
		end
		function label = get.Label(o)
			if isprop(o,'labelHandle')
				label = o.labelHandle.String;
			else
				label = '';
			end
		end
	end
	
	methods(Access=protected)
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
			h = c_GUI_ColorIndicator('Parent',hf,'Label','label','Color',[0 1 0]);
			pause(1);
			h.Color = [1 0 0];
		end
	end
end
	