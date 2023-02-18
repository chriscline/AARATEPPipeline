function EEG = c_TMSEEG_applyModifiedBandpassFilter(varargin)
% do a variant of band-pass filtering, specialized to avoid propagating large-amplitude low-latency
%  stimulation artifact to surrounding times

p = inputParser();
p.addRequired('EEG', @isstruct);
p.addParameter('lowCutoff', [], @(x) isempty(x) || isscalar(x));
p.addParameter('highCutoff',[], @(x) isempty(x) || isscalar(x));
p.addParameter('filterMethod', 'butterworth', @ischar);
p.addParameter('artifactTimespan', [], @c_isSpan); % this can be wider than typical timespan to be sure to remove large artifact signals 
												   %  (only used for interpolating a temporary signal for filtering, not the output)
p.addParameter('doPiecewise', true, @islogical);
p.addParameter('piecewiseTimeToExtend', 0.5, @isscalar);
p.addParameter('interpolationArgs', {}, @iscell); % optional, non-default interpolation args
p.addParameter('doDebug', false, @islogical);
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;

assert(any(arrayfun(@(x) ~isempty(x) && x>0, [s.lowCutoff, s.highCutoff])), 'Must specify at least one of lowCutoff and highCutoff');

assert(~isempty(s.artifactTimespan), 'Must specify artifact timespan');

if s.doDebug
	iTr = 96;
	iCh = 5;
end

if s.doPiecewise
	% do autoregressive prediction forward from negative times and backward from positive times,
	%  and apply filter in piecewise fashion to avoid large post-pulse artifact from "leaking"
	%  into pre-pulse time periods
	interpArgs = c_cellToStruct(s.interpolationArgs);
	if ~isfield(interpArgs, 'method')
		interpArgs.method = 'ARExtrapolation';
	else
		assert(isequal(interpArgs.method, 'ARExtrapolation'), 'Only one interp method supported for piecewise modification');
	end
	
	if ~c_isFieldAndNonEmpty(interpArgs, 'prePostFitDurations')
		% use a longer pre duration since signals are expected to be more stationary there
		prePostFitDurations = [100 30]*1e-3;
	else
		prePostFitDurations = interpArgs.prePostFitDurations;
	end
	
	assert(EEG.xmin < s.artifactTimespan(2) - s.piecewiseTimeToExtend);
	assert(EEG.xmax > s.artifactTimespan(1) + s.piecewiseTimeToExtend);
	
	interpArgs = c_structToCell(interpArgs);
	EEG_pre = c_EEG_ReplaceEpochTimeSegment(EEG,...
		'timespanToReplace', [s.artifactTimespan(1), s.artifactTimespan(1) + s.piecewiseTimeToExtend],...
		interpArgs{:},...
		'prePostFitDurations', [prePostFitDurations(1) 0]);
	
	EEG_post = c_EEG_ReplaceEpochTimeSegment(EEG,...
		'timespanToReplace', [s.artifactTimespan(2) - s.piecewiseTimeToExtend, s.artifactTimespan(2)],...
		interpArgs{:},...
		'prePostFitDurations', [0 prePostFitDurations(2)]);

	% blend pre-filter results
	preIndices = EEG.times < s.artifactTimespan(1) * 1e3;
	postIndices = EEG.times > s.artifactTimespan(2) * 1e3;
	blendIndices = ~preIndices & ~postIndices;
	if true
		% sigmoidish 
		fn = @(x, k)  1 - 1./(1+(1./x - 1).^-k);
		pre_weights = fn(linspace(1, 0, sum(blendIndices)), 2);
	else
		% linear
		pre_weights = linspace(1, 0, sum(blendIndices));
	end
	post_weights = 1 - pre_weights;
	tmpEEG = EEG_pre;
	tmpEEG.data(:,postIndices, :) = EEG_post.data(:, postIndices, :);
	tmpEEG.data(:, blendIndices, :) = tmpEEG.data(:, blendIndices, :) .* pre_weights + EEG_post.data(:, blendIndices, :) .* post_weights;
	
	if s.doDebug
		
		hf = figure;
		has = gobjects(0);
		
		numSubplots = 9;
		
		for iSP=1:numSubplots
			has(end+1) = c_subplot(numSubplots+1, 1, iSP);
		end
		
		colors = [...
					0 0 0;
					0.8 0 0;
					0 0 0.8;
					0 0.6 0;
					0 0.4 0];
		
		plotIndices = EEG.times >= (s.artifactTimespan(2) - s.piecewiseTimeToExtend*0.5)*1e3 & EEG.times <= (s.artifactTimespan(1) + s.piecewiseTimeToExtend*0.5)*1e3;
		assert(sum(plotIndices)>1);
		
		% plot original
		axes(has(1));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 1];
		ylabel('Original');
		
		% plot pre-stim extrapolation
		axes(has(2));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		fitIndices = plotIndices & EEG.times >= (s.artifactTimespan(1) - prePostFitDurations(1))*1e3 & EEG.times <= s.artifactTimespan(1)*1e3;
		hp = plot(EEG.times(fitIndices), EEG.data(iCh, fitIndices, iTr));
		hp.Color = [colors(1,:) 1];
		extrapIndices = plotIndices & EEG.times >= s.artifactTimespan(1)*1e3 & EEG.times <= (s.artifactTimespan(1) + s.piecewiseTimeToExtend)*1e3;
		hp = plot(EEG.times(extrapIndices), EEG_pre.data(iCh, extrapIndices, iTr));
		hp.Color = [colors(2,:), 0.5];
		ylabel('pre-stim extrap');
		
		% leave a place for pre-stim extrap filtered
		
		% plot post-stim extrapolation
		axes(has(4));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		fitIndices = plotIndices & EEG.times <= (s.artifactTimespan(2) + prePostFitDurations(1))*1e3 & EEG.times >= s.artifactTimespan(2)*1e3;
		hp = plot(EEG.times(fitIndices), EEG.data(iCh, fitIndices, iTr));
		hp.Color = [colors(1,:) 1];
		extrapIndices = plotIndices & EEG.times <= s.artifactTimespan(2)*1e3 & EEG.times >= (s.artifactTimespan(2) - s.piecewiseTimeToExtend)*1e3;
		hp = plot(EEG.times(extrapIndices), EEG_post.data(iCh, extrapIndices, iTr));
		hp.Color = [colors(3,:), 0.5];
		ylabel('post-stim extrap');
		
		% leave a place for post-stim extrap filtered
		
		% plot pre-filter blended
		axes(has(6));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		thisIndices = plotIndices & EEG.times <= s.artifactTimespan(1)*1e3;
		hp = plot(EEG.times(thisIndices), EEG.data(iCh, thisIndices, iTr));
		hp.Color = [colors(1,:) 1];
		thisIndices = plotIndices & EEG.times >= s.artifactTimespan(2)*1e3;
		hp = plot(EEG.times(thisIndices), EEG.data(iCh, thisIndices, iTr));
		hp.Color = [colors(1,:) 1];
		hp = plot(EEG.times(blendIndices), tmpEEG.data(iCh, blendIndices, iTr));
		hp.Color = [colors(4,:) 0.5];
		ylabel('pre-filt blended');
	end
	
	% apply filter
	EEG_pre = applyFilter(EEG_pre, s);
	EEG_post = applyFilter(EEG_post, s);
	
	if s.doDebug
		% plot pre-stim filtered
		axes(has(3));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		thisIndices = plotIndices & EEG.times <= (s.artifactTimespan(1) + s.piecewiseTimeToExtend)*1e3;
		hp = plot(EEG.times(thisIndices), EEG_pre.data(iCh, thisIndices, iTr));
		hp.Color = [colors(2,:) 0.5];
		ylabel('pre-stim filt');
		
		% plot post-stim filtered
		axes(has(5));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		thisIndices = plotIndices & EEG.times >= (s.artifactTimespan(2) - s.piecewiseTimeToExtend)*1e3;
		hp = plot(EEG.times(thisIndices), EEG_post.data(iCh, thisIndices, iTr));
		hp.Color = [colors(3,:) 0.5];
		ylabel('post-stim filt');
	end
	
	% blend post-filter results
	tmpEEG2 = EEG_pre;
	EEG_pre = [];
	tmpEEG2.data(:,postIndices, :) = EEG_post.data(:, postIndices, :);
	tmpEEG2.data(:, blendIndices, :) = tmpEEG2.data(:, blendIndices, :) .* pre_weights + EEG_post.data(:, blendIndices, :) .* post_weights;
	EEG_post = [];
	
	if s.doDebug
		% plot blended filtered
		axes(has(7));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		hp = plot(EEG.times(plotIndices), tmpEEG2.data(iCh, plotIndices, iTr));
		hp.Color = [colors(4,:) 0.5];
		ylabel('blended filt');
	end
	
	tmpEEG.data = tmpEEG.data - tmpEEG2.data;
	tmpEEG2 = [];
	
	if s.doDebug
		% plot residual
		axes(has(8));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		hp = plot(EEG.times(plotIndices), tmpEEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(4,:) 0.5];
		ylabel('residual');
		
		% prepare to plot final
		axes(has(9));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
	end
	
	EEG.data = EEG.data - tmpEEG.data;
	
	if s.doDebug
		% plot final
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(5,:) 1];
		
		c_plot_setEqualAxes(has);
		xlim(extrema(EEG.times(plotIndices)));
		xlabel('Time (ms)');
		ylabel('final');
		
		for iSP = 1:numSubplots
			if iSP < numSubplots
				has(iSP).XTickLabel = {};
			end
			has(iSP).YTickLabel = {};
			set(has(iSP).Children, 'LineWidth', 1.5);
			has(iSP).Position([2 4]) = [1/(numSubplots+1)*(numSubplots + 1 - iSP) 1/(numSubplots+1)*0.9];
		end
		
		hf.Position = [2 50 440 1300];
	end
	
	
else
	
	if s.doDebug
		
		hf = figure;
		has = gobjects(0);
		
		numSubplots = 5;
		
		for iSP=1:numSubplots
			has(end+1) = c_subplot(numSubplots+1, 1, iSP);
		end
		
		colors = [...
					0 0 0;
					0 0.6 0;
					0 0.4 0];
	end
	
	interpArgs = c_cellToStruct(s.interpolationArgs);
	if ~isfield(interpArgs, 'method')
		interpArgs.method = 'ARExtrapolation';
	end
	
	if isequal(interpArgs.method, 'ARExtrapolation')
		if ~c_isFieldAndNonEmpty(interpArgs, 'prePostFitDurations')
			% use a longer pre duration since signals are expected to be more stationary there
			interpArgs.prePostFitDurations = [100 30]*1e-3;
		end
	end
	interpArgs = c_structToCell(interpArgs);

	tmpEEG = c_EEG_ReplaceEpochTimeSegment(EEG,...
		'timespanToReplace', s.artifactTimespan,...
		interpArgs{:});

	tmpEEG2 = applyFilter(tmpEEG, s);
	
	if s.doDebug
		plotIndices = EEG.times >= (s.artifactTimespan(2) - 0.25)*1e3 & EEG.times <= (s.artifactTimespan(1) + 0.25)*1e3;
		assert(sum(plotIndices)>1);
		
		% plot original
		axes(has(1));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 1];
		
		% plot interp
		axes(has(2));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		thisIndices = plotIndices & EEG.times <= s.artifactTimespan(1)*1e3;
		hp = plot(EEG.times(thisIndices), EEG.data(iCh, thisIndices, iTr));
		hp.Color = [colors(1,:) 1];
		thisIndices = plotIndices & EEG.times >= s.artifactTimespan(2)*1e3;
		hp = plot(EEG.times(thisIndices), EEG.data(iCh, thisIndices, iTr));
		hp.Color = [colors(1,:) 1];
		blendIndices = plotIndices & EEG.times >= s.artifactTimespan(1)*1e3 & EEG.times <= s.artifactTimespan(2)*1e3;
		hp = plot(EEG.times(blendIndices), tmpEEG.data(iCh, blendIndices, iTr));
		hp.Color = [colors(2,:) 0.5];
		
		% plot interp filtered
		axes(has(3));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		hp = plot(EEG.times(plotIndices), tmpEEG2.data(iCh, plotIndices, iTr));
		hp.Color = [colors(2,:) 0.5];
	end
	
	tmpEEG.data = tmpEEG.data - tmpEEG2.data;
	tmpEEG2 = [];
	
	if s.doDebug
		% plot residual
		axes(has(4));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
		hp = plot(EEG.times(plotIndices), tmpEEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(2,:) 0.5];
		
		% prepare to plot final
		axes(has(5));
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(1,:) 0.1];
		hold on;
	end
	
	EEG.data = EEG.data - tmpEEG.data;
	
	if s.doDebug
		hp = plot(EEG.times(plotIndices), EEG.data(iCh, plotIndices, iTr));
		hp.Color = [colors(3,:) 1];
		
		c_plot_setEqualAxes(has);
		xlim(extrema(EEG.times(plotIndices)));
		xlabel('Time (ms)');
		
		for iSP = 1:numSubplots
			if iSP < numSubplots
				has(iSP).XTickLabel = {};
			end
			has(iSP).YTickLabel = {};
			set(has(iSP).Children, 'LineWidth', 1.5);
			has(iSP).Position([2 4]) = [1/(numSubplots+1)*(numSubplots + 1 - iSP) 1/(numSubplots+1)*0.9];
		end
		
		hf.Position = [2 50 440 1300*6/10];
	end
end

end

function EEG = applyFilter(EEG, s)
	switch(s.filterMethod)
		case 'eegfiltnew'
			EEG = pop_eegfiltnew(EEG, s.lowCutoff, s.highCutoff);
		case 'butterworth'
			EEG = c_EEG_filter_butterworth(EEG, [s.lowCutoff, c_if(isempty(s.highCutoff), 0, s.highCutoff)]);
		otherwise
			error('Not implemented');
	end
end