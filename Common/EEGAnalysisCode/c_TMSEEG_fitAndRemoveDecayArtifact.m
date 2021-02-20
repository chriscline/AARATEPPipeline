function [EEG, misc] = c_TMSEEG_fitAndRemoveDecayArtifact(varargin)
p = inputParser();
p.addRequired('EEG', @isstruct);
p.addParameter('artifactTimespan', [], @c_isSpan);
p.addParameter('topoFitDuration', 10e-3, @isscalar); % in s (specify this or topoFitTimespan)
p.addParameter('topoFitTimespan', [], @c_isSpan); % in s (specify this or topoFitDuration)
p.addParameter('maxTau', 20e-3, @isscalar);
p.addParameter('blendedRemovalTauSpan', [2 3], @c_isSpan) % timespan after primary artifact, scaled by Tau, to blend removal (e.g. a value of [2 3] does full removal
														  % from artifactTimespan(1) to artifactTimespan(2) + 2*tau, and blended removal
														  % from artifactTimespan(2)+2*tau to artifactTimespan(2)+3*tau
p.addParameter('doPlot', false, @islogical);
p.addParameter('aggMethod', 'mean', @ischar);
p.addParameter('trialAggMethod_topoEstimation', 'mean', @ischar);
p.addParameter('trialAggMethod_timeCourseRemoval', 'none', @ischar);
p.addParameter('trialAggMethod_timeCourseBounds', 'mean', @ischar);
p.addParameter('aggTrimPercent', 0, @isscalar);
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;

if s.topoFitDuration > 100e-3
	error('Topo fit duration > %s s. Are units correct?', c_toString(s.topoFitDuration));
end

if isempty(s.topoFitTimespan)
	assert(~isempty(s.topoFitDuration));
	if false
		startTime = max(0, (s.artifactTimespan(2)-s.topoFitDuration/2));
	else
		startTime = s.artifactTimespan(2);
	end
	endTime = startTime + s.topoFitDuration;
else
	assert(ismember('topoFitDuration', p.UsingDefaults));
	startTime = s.topoFitTimespan(1);
	endTime = s.topoFitTimespan(2);
end
timeIndices = EEG.times >= startTime*1e3 & EEG.times < endTime*1e3;
numTimes = sum(timeIndices);
assert(numTimes>0);
topoFitData = EEG.data(:, timeIndices, :);
switch(s.trialAggMethod_topoEstimation)
	case 'mean'
		topoFitData = c_trimmean(topoFitData, s.aggTrimPercent, 3);
	case 'none'
		topoFitData = reshape(topoFitData, EEG.nbchan, numTimes*EEG.trials);
	otherwise
		error('Not implemented');
end
[U,S,V] = svd(topoFitData, 'econ');
decayTopography = U(:, 1);
if mean(V(:,1)) < 0
	% invert topography
	decayTopography = decayTopography*-1;
end
% figure; topoplot(decayTopography, EEG.chanlocs)

switch(s.trialAggMethod_timeCourseRemoval)
	case 'mean'
		timeFitData = c_trimmean(EEG.data, s.aggTrimPercent, 3);
		meanDecayAct = decayTopography \ timeFitData; 
		if true % TODO: debug, set to false
			decayAct = reshape(decayTopography \ reshape(EEG.data, EEG.nbchan, EEG.pnts*EEG.trials), 1, EEG.pnts, EEG.trials);
		end
	case 'none'
		timeFitData = reshape(EEG.data, EEG.nbchan, EEG.pnts*EEG.trials);
		decayAct = decayTopography \ timeFitData; 
		decayAct = reshape(decayAct, 1, EEG.pnts, EEG.trials);
		meanDecayAct = c_trimmean(decayAct, s.aggTrimPercent, 3);
	otherwise
		error('Not implemented');
end

switch(s.trialAggMethod_timeCourseBounds)
	case 'mean'
		% means already calculated above
	otherwise
		error('Not implemented'); % other methods will require changes to the code below
end

% figure; imagesc(EEG.times, 1:EEG.trials, squeeze(decayAct)')

% figure; imagesc(EEG.times, 1:EEG.trials, squeeze(decayAct - meanDecayAct)');
% xlim([-10 50]);
% caxis([-1 1]*100);
% xlabel('Time (ms)');
% ylabel('Trial #');
% hc = colorbar;
% ylabel(hc, 'Residual (perTrialDecayAct - meanDecayAct)')

% figure; plot(EEG.times, meanDecayAct);

%% fit actual exponential decay curve

timeIndices = EEG.times > s.artifactTimespan(2)*1e3 & (EEG.times < (s.artifactTimespan(2) + s.maxTau*2)*1e3);
tmpY = meanDecayAct(timeIndices);
tmpY(tmpY<0) = 0;
tmpY = double(tmpY);
if false
	% allow small time offset
	[fobj, gof] = fit(EEG.times(timeIndices)', tmpY', 'a*d^(-1/b*(x - c))',...
		'Lower',      [0         1                0		                  exp(1)],...
		'Upper',	  [1e6   s.maxTau*2*1e3   s.artifactTimespan(2)*1e3   exp(1)],...
		'StartPoint', [5e3  min(s.maxTau, 10)     0                       exp(1)],...            
		'Weights', linspace(1, 0.5, sum(timeIndices)).^2);
else
	[fobj, gof] = fit(EEG.times(timeIndices)', tmpY', 'a*c^(-1/b*x)',...
		'Lower',      [0         1            exp(1)     ],...
		'Upper',	  [1e6   s.maxTau*2*1e3   exp(1) ],...
		'StartPoint', [1e3  min(s.maxTau, 10) exp(1)],...            
		'Weights', linspace(1, 0.5, sum(timeIndices)).^2);
end

predIndices = EEG.times > s.artifactTimespan(2)*1e3;
predY = fobj(EEG.times(predIndices));

% use fitted curve as an upper bound on time-course to remove
tauDecay = fobj.b*1e-3;
tauIndex = c_cell_findMatchingIndices({'b'}, coeffnames(fobj));
tauBounds = paren(confint(fobj), ':', tauIndex)*1e-3;
tauUpperBound = tauBounds(2);
if tauUpperBound > s.maxTau*2
	c_saySingle('Curve fitting did not produce precise tau coefficient. Assuming no significant decay component exists');
	didFit = false;
	doRemove = false;
	toRemove = nan(EEG.nbchan, EEG.pnts);
else
	switch(s.trialAggMethod_timeCourseRemoval)
		case 'mean'
			timeCourseToRemove = meanDecayAct;
		case 'none'
			timeCourseToRemove = decayAct;
		otherwise
			error('Not implemented');
	end
	
	timeCourseUpperBounds = inf(size(EEG.times));
	timeCourseLowerBounds = -inf(size(EEG.times));

	% before artifact timespan, reject nothing
	timeIndices = EEG.times < s.artifactTimespan(1)*1e3;
	timeCourseUpperBounds(timeIndices) = 0;
	timeCourseLowerBounds(timeIndices) = 0;

	% in artifact timespan, reject exact fit

	K1_tau = 2; K2_tau = 3;
%  	K1_tau = 3; K2_tau = 4;
	
	% in early times, we expect larger magnitude deviations from the curve fit, so just reject exact positive fit
	timeIndices = EEG.times >= s.artifactTimespan(1)*1e3 & EEG.times <= (s.artifactTimespan(2) + tauDecay*K1_tau)*1e3;
	timeCourseLowerBounds(timeIndices) = 0;

	% after K tau, start bounding by curve fit 
	timeIndices = EEG.times > (s.artifactTimespan(2) + tauDecay*K1_tau)*1e3;
	predY = fobj(EEG.times(timeIndices));
	constraintMultiplier = 1.1;
	timeCourseUpperBounds(timeIndices) = abs(predY)*constraintMultiplier; % allow for some small deviation exceeding curve fit value
	timeCourseLowerBounds(timeIndices) = 0;

	for iTr = 1:size(timeCourseToRemove, 3)
		timeCourseUpperBounds_iTr = timeCourseUpperBounds;
		% allow for a transition region to avoid discontinuity at beginning of bounds
		timeIndex = find(timeIndices, 1, 'first');
		if timeCourseToRemove(:, timeIndex, iTr) > timeCourseUpperBounds(timeIndex)
			timeIndices = EEG.times > (s.artifactTimespan(2) + tauDecay*K1_tau)*1e3 & EEG.times <(s.artifactTimespan(2) + tauDecay*K2_tau)*1e3;
			blendWeights = linspace(1, 0, sum(timeIndices));
			timeCourseUpperBounds_iTr(timeIndices) = timeCourseToRemove(:, timeIndices, iTr).*blendWeights + timeCourseUpperBounds(timeIndices).*(1-blendWeights);
		end

		indicesToBound = timeCourseToRemove(:, :, iTr) > timeCourseUpperBounds_iTr; 
		timeCourseToRemove(:, indicesToBound, iTr) = timeCourseUpperBounds_iTr(indicesToBound);

		indicesToBound = timeCourseToRemove(:, :, iTr) < timeCourseLowerBounds;
		timeCourseToRemove(:, indicesToBound, iTr) = timeCourseLowerBounds(indicesToBound);
	end
		
	doRemove = true;
	didFit = true;

	if doRemove || s.doPlot
		toRemove = decayTopography .* timeCourseToRemove;
	end
end


% 	figure;
% 	plot(EEG.times(predIndices), predY)
% 	hold on; 
% 	plot(EEG.times, meanDecayAct);
% 	xlim([-30 100]);





if s.doPlot
	hf = figure; 
	hf.Position = [50 50 1000 800];
	
	plotInfTo = max(abs(extrema(EEG.data(:))))*2;
	legendLocation = 'eastoutside';

	ht = c_GUI_Tiler('numRows', 1);
	ht.addAxes('relWidth', 0.3);
	topoplot(decayTopography, EEG.chanlocs);
	hc = colorbar('location', 'southoutside');
	xlabel(hc, 'Scaled amplitude (arbitrary units)');
	title('Decay topography');

	sht = c_GUI_Tiler('numCols', 1, 'parent', ht.add());

	has = gobjects(0);
	has(end+1) = sht.addAxes();
	traceColors = c_EEG_getButterflyTraceColors(EEG, 'seedColor', [0 0 1; 0 1 0; 1 0 0]);
	c_EEG_plotEpochs(EEG,...
		'dataColors', traceColors,...
		'dataAlpha', 0.5,...
		'xlabel', '',...
		'lineWidth', 1,...
		'axis', has(end));
	if true
		xp = (s.artifactTimespan-[0.5 0]/EEG.srate)*1e3;
		hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.5,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
		has(end).Children = [has(end).Children(2:end); has(end).Children(1)];
		legendLabels = ['Artifact timespan'];
		legend(legendLabels, 'location', legendLocation);
	end
	title(has(end), 'Before decay removal');

	has(end+1) = sht.addAxes();
	plot(EEG.times, meanDecayAct, 'LineWidth', 3, 'Color', has(end).ColorOrder(1,:));
	legendLabels = {'Decay topography time-course'};
	hold on;
	if didFit
		predIndices = EEG.times > s.artifactTimespan(2)*1e3;
		predY = fobj(EEG.times(predIndices));
		plot(EEG.times(predIndices), predY, 'LineWidth', 2, 'Color', has(end).ColorOrder(4,:))
		legendLabels{end+1} = 'Curve fit';
	end
	if true
		xp = (s.artifactTimespan+[-0.5 0]/EEG.srate)*1e3;
		hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.5,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
		if didFit
			xp = (s.artifactTimespan(2) + [0 tauDecay*K1_tau])*1e3;
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.7,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			xp = (s.artifactTimespan(2) + [tauDecay*K1_tau tauDecay*K2_tau])*1e3;
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.85,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			xp(1) = (s.artifactTimespan(2) + tauDecay*K2_tau)*1e3;
			xp(2) = EEG.times(paren(find(predIndices), find(predY < fobj.a/1e4, 1, 'first'))); % find time where constrained removal is essentially zero
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.9,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			has(end).Children = [has(end).Children(5:end); has(end).Children(1:4)];
			legendLabels = ['Artifact timespan', 'Full removal timespan', 'Blended removal timespan', 'Constrained removal timespan', legendLabels];
		else
			legendLabels = ['Artifact timespan', legendLabels];
		end
	end
	legend(legendLabels, 'location', legendLocation);
	title(has(end), sprintf('Fitted decay (tau=%.1f ms [%s ms])', tauDecay*1e3, c_toString(tauBounds*1e3, 'precision', 2)));
	
	has(end+1) = sht.addAxes();
	if didFit
		legendLabels = {};
	
		
		if size(timeCourseToRemove,3) > 1
			if false
				lowerColor = c_color_adjust(plotColor, 'makeDarker');
				upperColor = c_color_adjust(plotColor, 'makeBrighter');
				weights = linspace(0,1, size(timeCourseToRemove, 3))';
				plotColors = (1-weights) .* lowerColor + weights .* upperColor;
			else
				plotColors = repmat(has(end).ColorOrder(3,:), size(timeCourseToRemove,3),1);
			end
			plotColors(:, 4) = 0.5; % add transparency
			for iTr = 1:size(timeCourseToRemove, 3)
				hp = plot(EEG.times, timeCourseToRemove(:, :, iTr), 'Color', plotColors(iTr, :), 'LineWidth', 0.5);
				if iTr > 1
					hp.Annotation.LegendInformation.IconDisplayStyle = 'off';
				else 
					hold on;
				end
			end
			ylim(extrema(reshape(prctile(timeCourseToRemove, [0 99], 3), 1, [])));
		end
		legendLabels{end+1} = 'Per-trial time-course to remove';
		
		plotColor = has(end).ColorOrder(2,:);
		plot(EEG.times, c_trimmean(timeCourseToRemove, s.aggTrimPercent, 3), 'LineWidth', 2, 'Color', plotColor);
		legendLabels{end+1} = 'Mean time-course to remove';
		hold on;
		
		if true
			toPlot = timeCourseUpperBounds;
			toPlot(EEG.times < s.artifactTimespan(2)*1e3) = nan;
			toPlot(isinf(toPlot)) = nan;
			plot(EEG.times, toPlot, 'LineWidth', 1.5, 'Color', has(end).ColorOrder(4,:))
			legendLabels{end+1} = 'Constraint boundary';
		end
		
		if false
			plotBounds_upper = max(timeCourseUpperBounds, max(timeCourseToRemove, [], 3));
			plotBounds_lower = min(timeCourseLowerBounds, min(timeCourseToRemove, [], 3));
			
			firstPatchDrawn = false;
			
			iT_start = [];
			for iT=2:EEG.pnts+1
				if iT > EEG.pnts || (plotBounds_upper(iT)==0 && plotBounds_lower(iT)==0)
					if isempty(iT_start)
						continue % don't start patch yet
					else
						% reached end of current patch, draw it
						patchX = [];
						patchY = [];
						for iTP = iT_start:min(iT, EEG.pnts)
							patchX(end+1) = EEG.times(iTP);
							patchY(end+1) = min(plotBounds_upper(iTP), plotInfTo);
						end
						for iTP = min(iT, EEG.pnts):-1:iT_start
							patchX(end+1) = EEG.times(iTP);
							patchY(end+1) = max(plotBounds_lower(iTP), -plotInfTo);
						end
						hp = patch('XData', patchX, 'YData', patchY,...
							'FaceColor', [1 1 1]*0.85,...
							'YLimInclude', 'off',...
							'EdgeColor', 'none');
						if firstPatchDrawn
							hp.Annotation.LegendInformation.IconDisplayStyle = 'off';
						else
							legendLabels = ['Removal bounds', legendLabels];
						end
						iT_start = [];
						has(end).Children = [has(end).Children(2:end); has(end).Children(1)];
						firstPatchDrawn = true;
					end
				else
					if isempty(iT_start)
						% start a new patch
						iT_start = iT-1;
					end
				end
			end
		elseif true
			xp = (s.artifactTimespan-[0.5 0]/EEG.srate)*1e3;
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.5,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			xp = (s.artifactTimespan(2) + [0 tauDecay*K1_tau])*1e3;
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.7,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			xp = (s.artifactTimespan(2) + [tauDecay*K1_tau tauDecay*K2_tau])*1e3;
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.85,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			xp(1) = (s.artifactTimespan(2) + tauDecay*K2_tau)*1e3;
			xp(2) = EEG.times(paren(find(predIndices), find(predY < fobj.a/1e4, 1, 'first'))); % find time where constrained removal is essentially zero
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.9,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			has(end).Children = [has(end).Children(5:end); has(end).Children(1:4)];
			legendLabels = ['Artifact timespan', 'Full removal timespan', 'Blended removal timespan', 'Constrained removal timespan', legendLabels];
		end
		
		legend(legendLabels, 'location', legendLocation);
		title('To remove');
	end
	
	has(end+1) = sht.addAxes();
	gmfa_orig = c_EEG_calculateGMFA(c_trimmean(EEG.data, s.aggTrimPercent, 3));
	plot(EEG.times, gmfa_orig, 'LineWidth', 4, 'Color', has(end).ColorOrder(1,:));
	legendLabels = {'GMFA before removal'};
	hold on;
	if didFit
		gmfa_toRemove = c_EEG_calculateGMFA(c_trimmean(toRemove, s.aggTrimPercent, 3));
		plot(EEG.times, gmfa_toRemove, 'LineWidth', 3, 'Color', has(end).ColorOrder(2,:));
		legendLabels{end+1} = 'GMFA to remove';
		if doRemove
			gmfa_residual = c_EEG_calculateGMFA(c_trimmean(EEG.data - toRemove, s.aggTrimPercent, 3));
			plot(EEG.times, gmfa_residual, 'LineWidth', 2, 'Color', has(end).ColorOrder(5,:));
			legendLabels{end+1} = 'GMFA after removal';
		end
	end
	if true
		xp = (s.artifactTimespan-[0.5 0]/EEG.srate)*1e3;
		hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.5,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
		if didFit
			xp = (s.artifactTimespan(2) + [0 tauDecay*K1_tau])*1e3;
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.7,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			xp = (s.artifactTimespan(2) + [tauDecay*K1_tau tauDecay*K2_tau])*1e3;
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.85,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			xp(1) = (s.artifactTimespan(2) + tauDecay*K2_tau)*1e3;
			xp(2) = EEG.times(paren(find(predIndices), find(predY < fobj.a/1e4, 1, 'first'))); % find time where constrained removal is essentially zero
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.9,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			has(end).Children = [has(end).Children(5:end); has(end).Children(1:4)];
			legendLabels = ['Artifact timespan', 'Full removal timespan', 'Blended removal timespan', 'Constrained removal timespan', legendLabels];
		else
			has(end).Children = [has(end).Children(2:end); has(end).Children(1)];
			legendLabels = ['Artifact timespan', legendLabels];
		end
	end
	ylabel('Amplitude (uV)');
	legend(legendLabels, 'location', legendLocation);
	title('GMFAs');
end
	
if doRemove
	% remove fitted decay artifact
	EEG.data = EEG.data - toRemove;
end

if s.doPlot
	doPlotAfterInterp = true;
	
	has(end+1) = sht.addAxes();
	if doRemove
		c_EEG_plotEpochs(EEG,...
			'dataColors', traceColors,...
			'dataAlpha', 0.5,...
			'doShowLegend', false,...
			'lineWidth', 1,...
			'xLabel', '',...
			'axis', has(end));
		title(has(end), 'After decay removal');
		if true
			xp = (s.artifactTimespan-[0.5 0]/EEG.srate)*1e3;
			hp = patch('XData', [xp flip(xp)],...
					'YData', [1 1 -1 -1]*plotInfTo,...
					'FaceColor', [1 1 1]*0.5,...
					'YLimInclude', 'off',...
					'EdgeColor', 'none');
			xp = (s.artifactTimespan(2) + [0 tauDecay*K1_tau])*1e3;
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.7,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			xp = (s.artifactTimespan(2) + [tauDecay*K1_tau tauDecay*K2_tau])*1e3;
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.85,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			xp(1) = (s.artifactTimespan(2) + tauDecay*K2_tau)*1e3;
			xp(2) = EEG.times(paren(find(predIndices), find(predY < fobj.a/1e4, 1, 'first'))); % find time where constrained removal is essentially zero
			hp = patch('XData', [xp flip(xp)],...
				'YData', [1 1 -1 -1]*plotInfTo,...
				'FaceColor', [1 1 1]*0.9,...
				'YLimInclude', 'off',...
				'EdgeColor', 'none');
			has(end).Children = [has(end).Children(5:end); has(end).Children(1:4)];
			legendLabels = {'Artifact timespan', 'Full removal timespan', 'Blended removal timespan', 'Constrained removal timespan'};
			legend(legendLabels, 'location', legendLocation);
		end
	else
		text(has(end), 0, 0.5, 'Inadequate fit. Decay not removed');
		axis(has(end), 'off')
	end
	
	if true
		% also plot after (temporary) autoregressive interpolation, since this is typically done in 
		%  pipeline immediately after and can be critical in suppressing some transient artifact 
		%  introduced by decay removal
		tmpEEG = c_EEG_ReplaceEpochTimeSegment(EEG,...
			'timespanToReplace', s.artifactTimespan,...
			'method', 'ARExtrapolation',...
			'prePostFitDurations', [20 20]*1e-3);
		has(end+1) = sht.addAxes();
		if doRemove
			c_EEG_plotEpochs(tmpEEG,...
				'dataColors', traceColors,...
				'dataAlpha', 0.5,...
				'doShowLegend', false,...
				'lineWidth', 1,...
				'xLabel', '',...
				'axis', has(end));
			title(has(end), 'After interpolation');
			if true
				xp = (s.artifactTimespan-[0.5 0]/EEG.srate)*1e3;
				hp = patch('XData', [xp flip(xp)],...
						'YData', [1 1 -1 -1]*plotInfTo,...
						'FaceColor', [1 1 1]*0.5,...
						'YLimInclude', 'off',...
						'EdgeColor', 'none');
				xp = (s.artifactTimespan(2) + [0 tauDecay*K1_tau])*1e3;
				hp = patch('XData', [xp flip(xp)],...
					'YData', [1 1 -1 -1]*plotInfTo,...
					'FaceColor', [1 1 1]*0.7,...
					'YLimInclude', 'off',...
					'EdgeColor', 'none');
				xp = (s.artifactTimespan(2) + [tauDecay*K1_tau tauDecay*K2_tau])*1e3;
				hp = patch('XData', [xp flip(xp)],...
					'YData', [1 1 -1 -1]*plotInfTo,...
					'FaceColor', [1 1 1]*0.85,...
					'YLimInclude', 'off',...
					'EdgeColor', 'none');
				xp(1) = (s.artifactTimespan(2) + tauDecay*K2_tau)*1e3;
				xp(2) = EEG.times(paren(find(predIndices), find(predY < fobj.a/1e4, 1, 'first'))); % find time where constrained removal is essentially zero
				hp = patch('XData', [xp flip(xp)],...
					'YData', [1 1 -1 -1]*plotInfTo,...
					'FaceColor', [1 1 1]*0.9,...
					'YLimInclude', 'off',...
					'EdgeColor', 'none');
				has(end).Children = [has(end).Children(5:end); has(end).Children(1:4)];
				legendLabels = {'Artifact timespan', 'Full removal timespan', 'Blended removal timespan', 'Constrained removal timespan'};
				legend(legendLabels, 'location', legendLocation);
			end
		else
			text(has(end), 0, 0.5, 'Inadequate fit. Decay not removed');
			axis(has(end), 'off')
		end
	end
	
	set(has,'Layer','top'); % show tick marks above patchs
	
	positions = reshape([has.Position], 4, [])';
	maxLeft = max(positions(:, 1));
	for iA = 1:length(has)
		has(iA).Position(1) = maxLeft;
	end
	positions = reshape([has.Position], 4, [])';
	minWidth = min(positions(:, 3))*0.99;
	for iA = 1:length(has)
		has(iA).Position(3) = minWidth;
	end
	
	if true && didFit
		% add an inset zooming in on constraint boundary for removal
		ha = has(3);
		hp = ha.Parent;
		pos = [];
		pos(1) = ha.Position(1) + ha.Position(3)*0.48;
		pos(2) = ha.Position(2) + ha.Position(4)*0.32;
		pos(3) = ha.Position(3) * 0.51;
		pos(4) = ha.Position(4) * 0.65;
		hai = copyobj(ha, hp);
		hai.Position = pos;
		title(hai, '');
		xlim(hai, [s.artifactTimespan(2)+tauDecay*K1_tau+tauDecay*0.5, s.artifactTimespan(2)+tauDecay*K2_tau + 2*tauDecay]*1e3);
		ylim(hai, [0 timeCourseUpperBounds(find(EEG.times>hai.XLim(1), 1, 'first'))])
	end
	
	c_plot_setEqualAxes(has, 'axesToSet', 'x')
	xlim(has(1), [-10 80])
	misc.hf = hf;
	
	
% 	hf2 = figure;
% 	c_EEG_plotERPImage(EEG, 'COI', 'C3')
% 	xlim([-50 100]);
% 	colorbar;
% 	caxis([-1 1]*100);
end

misc.didRemoveDecay = doRemove;

end


