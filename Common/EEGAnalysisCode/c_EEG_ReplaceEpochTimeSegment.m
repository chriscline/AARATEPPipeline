function EEG = c_EEG_ReplaceEpochTimeSegment(EEG,varargin)
	if nargin == 0
		testfn();
		return;
	end

	p = inputParser();
	%p.addRequired('EEG',@isstruct);
	p.addParameter('timespanToReplace',[],@(x) isnumeric(x) && length(x)==2); % in s
	p.addParameter('prePostFitDurations', [], @(x) isvector(x) && (isempty(x) || length(x)==2)); % in s
	p.addParameter('eventType','',@ischar);
	p.addParameter('method','spline',@(x) ischar(x) || isscalar(x)); % if scalar, will be used as a constant to replace values
	p.addParameter('doDebug', false, @islogical);
	p.parse(varargin{:});
	s = p.Results;
	assert(isstruct(EEG));
	
	if isempty(s.timespanToReplace)
		error('Need to specify timespanToReplace');
	end

	if c_EEG_isEpoched(EEG)
		if ~isempty(s.eventType)
			indicesToReplace = false(1,EEG.pnts,EEG.trials);
			for iE = 1:EEG.trials
				ep = EEG.epoch(iE);
				epEvtIndices = find(ismember(ep.eventtype,{s.eventType}));
				for iEvt = epEvtIndices
					indicesToReplace(:,:,iE) = indicesToReplace(:,:,iE) |...
						(EEG.times >= s.timespanToReplace(1)*1e3 + ep.eventlatency{iEvt} & ...
						 EEG.times <= s.timespanToReplace(2)*1e3 + ep.eventlatency{iEvt});
					 % (note that ep.eventlatency is in ms not the usual units of samples)
				end
			end
			keyboard
		else
			% epoch around time 0 in epoch
			indicesToReplace = EEG.times >= s.timespanToReplace(1)*1e3 & EEG.times <= s.timespanToReplace(2)*1e3;
		end
		
		if strcmp(s.method,'delete')
			% don't actually interpolate, but instead delete data entirely, and fix time and other metadata
			assert(size(indicesToReplace,3)==1,'Deletion only supported when deleting common time across all trials');
			EEG.data(:,indicesToReplace,:) = [];
			EEG.times(indicesToReplace) = [];
			EEG.pnts = length(EEG.times);
		else
			for iE=1:EEG.trials
				if size(indicesToReplace,3)==1
					thisIndicesToReplace = indicesToReplace;
				else
					thisIndicesToReplace = indicesToReplace(:,:,iE);
				end
				tmp = interpolateWithinIndices(EEG.data(:,:,iE),thisIndicesToReplace,s.method,...
					'prePostFitDurations', s.prePostFitDurations*EEG.srate,...
					'doDebug', s.doDebug,...
					'indexOfTimeZero', sum(EEG.times<0),...
					'srate', EEG.srate);
				EEG.data(:,:,iE) = tmp;
			end
		end
	else
		if isempty(s.eventType)
			error('Event type must be specified if data is not epoched');
		end
		
		if strcmp(s.method,'delete')
			error('Delete not supported for continuous data');
			%TODO: implement
		end
		
		t = c_EEG_epoch_getOriginalEventTimes(EEG,'eventType', s.eventType, 'outputUnits', 's');
		
		indicesToReplace = false(1,length(EEG.times));
		
		for i=1:length(t)
			tstart = (t(i)+s.timespanToReplace(1))*1e3;
			tend = (t(i)+s.timespanToReplace(2))*1e3;
			indicesToReplace(EEG.times >= tstart & EEG.times <= tend) = true;
		end
		
		EEG.data = interpolateWithinIndices(EEG.data,indicesToReplace,s.method,...
			'prePostFitDurations', s.prePostFitDurations*EEG.srate,...
			'doDebug', s.doDebug);
	end
end


function data = interpolateWithinIndices(data,indices, varargin)
	p = inputParser();
	p.addOptional('method', 'spline', @(x) ischar(x) || isscalar(x));
	p.addParameter('prePostFitDurations', []);
	p.addParameter('doDebug', false, @islogical);
	p.addParameter('indexOfTimeZero', [], @isscalar); % only used for debug plotting
	p.addParameter('srate', [], @isscalar); % only used for debug plotting
	p.parse(varargin{:});
	s = p.Results;
	
	if ischar(s.method) && ismember(s.method, {'localSmoothedCubic', 'ARExtrapolation'})
		assert(~isempty(s.prePostFitDurations), 'prePostFitDurations must be specified for method ''%s''', s.method);
	else
		assert(isempty(s.prePostFitDurations), 'prePostFitDurations not used for method ''%s''', c_toString(s.method));
	end

	assert(length(indices)==size(data,2));
	assert(length(size(data))==2) % code below assumes data is [nchan x ntime]	
	assert(islogical(indices)); % code below assumes logical indexing
	
	if strcmp(s.method,'zero')
		s.method = 0; % convert string to num for below
	end

	times = 1:size(data,2); % arbitrary units
	knownTimes = times(~indices);
	unknownTimes = times(indices);

	
	switch(s.method)
		case 'ARExtrapolation'
			replaceStarts = find(diff(indices)>0)+1;
			replaceEnds = find(diff(indices)<0);
			assert(length(replaceStarts)==length(replaceEnds));
			
			s.prePostFitDurations = round(s.prePostFitDurations);
			assert(all(s.prePostFitDurations >= 0));
			
			prevReplaceEnd = 0;
			for iR = 1:length(replaceStarts)
				fitStart = replaceStarts(iR) - s.prePostFitDurations(1);
				if fitStart <= prevReplaceEnd
					warning('Reduced data available for fitting prior to timespanToReplace');
					fitStart = prevReplaceEnd + 1;
					assert(replaceStarts(iR) - fitStart > 1);
				end
				prevReplaceEnd = replaceEnds(iR);
				
				fitEnd = replaceEnds(iR) + s.prePostFitDurations(2);
				if iR < length(replaceStarts)
					nextStart = replaceStarts(iR+1);
				else
					nextStart = size(data, 2);
				end
				if fitEnd >= nextStart
					warning('Reduced data available for fitting after timespanToReplace');
					fitEnd = nextStart - 1;
					assert(nextStart - fitEnd > 1);
				end
				
				
				if s.doDebug
% 				toFit = data(:, fitStart:fitEnd);
					x = 1:(fitEnd-fitStart)+1;
	% 				xAll = x; % TODO: debug, delete
				
					relReplaceStart = s.prePostFitDurations(1) + 1;
					relReplaceStop = s.prePostFitDurations(1) + (replaceEnds(iR) - replaceStarts(iR)) + 1;
				
% 				toFit(:, relReplaceStart:relReplaceStop) = [];
% 				x_toInterp = x(relReplaceStart:relReplaceStop);
% 				x(relReplaceStart:relReplaceStop) = [];
				end
				
				for iCh = 1:size(data,1)
					if s.prePostFitDurations(1) > 0
						arModelOrder = ceil(s.prePostFitDurations(1)/3); % TODO: determine better way to determine this
						extrapSig_pre = c_extrapolateSignal(data(iCh, fitStart:replaceStarts(iR)-1), replaceEnds(iR)-replaceStarts(iR) + 1, arModelOrder);
						extrapSig_pre = extrapSig_pre(replaceStarts(iR)-fitStart+1:end);
					end
					
					if s.doDebug
						extrapX = x(relReplaceStart:relReplaceStop);
					end
					
					if s.prePostFitDurations(2) > 0
						arModelOrder = ceil(s.prePostFitDurations(2)/3); % TODO: determine better way to determine this
						extrapSig_post = c_extrapolateSignal(flip(data(iCh, replaceEnds(iR)+1:fitEnd)), replaceEnds(iR)-replaceStarts(iR) + 1, arModelOrder);
						extrapSig_post = flip(extrapSig_post(fitEnd-replaceEnds(iR)+1:end));
					end
					
					if all(s.prePostFitDurations > 0)
						% blend pre/post extrapolations
						if true
							% sigmoidish 
							fn = @(x, k)  1 - 1./(1+(1./x - 1).^-k);
							pre_weights = fn(linspace(1, 0, length(extrapSig_pre)), 2)';
						else
							% linear
							pre_weights = linspace(1, 0, length(extrapSig_pre))';
						end
						post_weights = 1 - pre_weights;
						extrapSig = extrapSig_pre .* pre_weights + extrapSig_post .* post_weights;
					elseif s.prePostFitDurations(1) > 0
						extrapSig = extrapSig_pre;
					elseif s.prePostFitDurations(2) > 0
						extrapSig = extrapSig_post;
					else
						error('At least one of pre and post fit durations must be greater than zero');
					end

					if s.doDebug && ismember(iCh, 1:5)
						if false
							figure; 
							labels = {};
							hp = plot(x, data(iCh, fitStart:fitEnd), 'lineWidth', 1.5); 
							hp.Color = [hp.Color 0.5];
							labels{end+1} = 'Original';
							hold on; 
							if s.prePostFitDurations(1) > 0
								hp = plot(extrapX, extrapSig_pre, 'lineWidth', 1.5);
								hp.Color = [hp.Color 0.5];
								labels{end+1} = 'Extrap pre';
								ylim(c_limits_multiply(extrema(extrapSig_pre), 2));
							end
							if s.prePostFitDurations(2) > 0
								hp = plot(extrapX, extrapSig_post, 'lineWidth', 1.5);
								hp.Color = [hp.Color 0.5];
								labels{end+1} = 'Extrap post';
								ylim(c_limits_multiply(extrema(extrapSig_post), 2));
							end
							if all(s.prePostFitDurations>0)
								hp = plot(extrapX, extrapSig, 'lineWidth', 1.5);
								hp.Color = [hp.Color 0.5];
								labels{end+1} = 'Extrap blended';
								ylim(c_limits_multiply(extrema([extrapSig_pre; extrapSig_post]), 2));
							end
							legend(labels, 'location', 'eastoutside');
						else 
							times_real = ((1:size(data,2)) - s.indexOfTimeZero)/s.srate*1e3;  % in ms
							plotStart = replaceStarts(iR) - 1.5*s.prePostFitDurations(1);
							plotEnd = replaceEnds(iR) + 1.5*s.prePostFitDurations(2);

							hf = figure;
	% 						ht = c_GUI_Tiler('numCols', 1);
							if true
								colors = [...
									0 0 0;
									0.8 0 0;
									0 0 0.8;
									0 0.6 0];
							else
								colors = c_getColors(4);
							end
							numSubplots = 5;
							has = gobjects(0);

	% 						sht = c_GUI_Tiler('parent', ht.add(), 'SideTitle', 'Original');
	% 						has(end+1) = sht.addAxes();
							has(end+1) = c_subplot(numSubplots, 1, 1);
							hp = plot(times_real(plotStart:plotEnd), data(iCh, plotStart:plotEnd), 'lineWidth', 1.5); 
							hp.Color = [colors(1,:) 1];
	% 						ylabel('Original');

	% 						sht = c_GUI_Tiler('parent', ht.add(), 'SideTitle', sprintf('Pre-stim\nextrapolation'));
	% 						has(end+1) = sht.addAxes();
							has(end+1) = c_subplot(numSubplots, 1, 2);
							% plot pre-fit span and post-fit span in lighter color
							hp = plot(times_real(plotStart:plotEnd), data(iCh, plotStart:plotEnd), 'lineWidth', 1.5); 
							hp.Color = [colors(1,:) 0.1];
							hold on;
							% plot timespan used for fitting in darker color
							hp = plot(times_real(fitStart:replaceStarts(iR)-1), data(iCh, fitStart:replaceStarts(iR)-1), 'lineWidth', 1.5);
							hp.Color = [colors(1,:) 1];
							% plot extrapolated span in different color
							hp = plot(times_real(replaceStarts(iR):replaceEnds(iR)), extrapSig_pre, 'lineWidth', 1.5);
							hp.Color = [colors(2,:) 0.5];
							ylim(c_limits_multiply(extrema(extrapSig_pre), 2));
	% 						ylabel('Pre-stim extrapolation');

	% 						sht = c_GUI_Tiler('parent', ht.add(), 'SideTitle', sprintf('Post-stim\nextrapolation'));
	% 						has(end+1) = sht.addAxes();
							has(end+1) = c_subplot(numSubplots, 1, 3);
							% plot pre-fit span and post-fit span in lighter color
							hp = plot(times_real(plotStart:plotEnd), data(iCh, plotStart:plotEnd), 'lineWidth', 1.5); 
							hp.Color = [colors(1,:) 0.1];
							hold on;
							% plot timespan used for fitting in darker color
							hp = plot(times_real(replaceEnds(iR)+1:fitEnd), data(iCh, replaceEnds(iR)+1:fitEnd), 'lineWidth', 1.5);
							hp.Color = [colors(1,:) 1];
							% plot extrapolated span in different color
							hp = plot(times_real(replaceStarts(iR):replaceEnds(iR)), extrapSig_post, 'lineWidth', 1.5);
							hp.Color = [colors(3,:) 0.5];
							ylim(c_limits_multiply(extrema(extrapSig_post), 2));
	% 						ylabel('Post-stim extrapolation');

	% 						sht = c_GUI_Tiler('parent', ht.add(), 'SideTitle', sprintf('Blending\nweights'));
	% 						has(end+1) = sht.addAxes();
							has(end+1) = c_subplot(numSubplots, 1, 4);
							y = ones(1, size(data,2));
							y(replaceStarts(iR):replaceEnds(iR)) = 0;
							hp = plot(times_real(plotStart:plotEnd), y(plotStart:plotEnd), 'lineWidth', 2);
							hp.Color = [colors(1,:), 1];
							hold on;
							hp = plot(times_real(replaceStarts(iR):replaceEnds(iR)), pre_weights, 'lineWidth', 2);
							hp.Color = [colors(2,:) 0.5];
							hp = plot(times_real(replaceStarts(iR):replaceEnds(iR)), post_weights, 'lineWidth', 2);
							hp.Color = [colors(3,:) 0.5];
							ylim([-0.1 1.1]);
	% 						ylabel('Blending weights');

	% 						sht = c_GUI_Tiler('parent', ht.add('relHeight', 1.25), 'SideTitle', sprintf('Interpolated\nresult'));
	% 						has(end+1) = sht.addAxes();
							has(end+1) = c_subplot(numSubplots, 1, 5);
							hp = plot(times_real(plotStart:plotEnd), data(iCh, plotStart:plotEnd), 'lineWidth', 1.5); 
							hp.Color = [colors(1,:) 0.1];
							hold on;
							hp = plot(times_real(plotStart:replaceStarts(iR)-1), data(iCh, plotStart:replaceStarts(iR)-1), 'lineWidth', 1.5); 
							hp.Color = [colors(1,:) 1];
							hp = plot(times_real(replaceEnds(iR)+1:plotEnd), data(iCh, replaceEnds(iR)+1:plotEnd), 'lineWidth', 1.5); 
							hp.Color = [colors(1,:) 1];
							hp = plot(times_real(replaceStarts(iR):replaceEnds(iR)), extrapSig, 'lineWidth', 1.5);
							hp.Color = [colors(4,:) 0.5];
	% 						ylabel('Interpolated result');
							xlabel('Time (ms)');

							for iA = 1:length(has)-1
								set(has(iA), 'XTick', []);
							end

							c_plot_setEqualAxes(has, 'axesToSet', 'x');
							c_plot_setEqualAxes([has(1:end-2), has(end)], 'axesToSet', 'y');

							ylim(c_limits_multiply(extrema([extrapSig_pre; extrapSig_post]), 2.5));
							xlim(extrema(times_real(plotStart:plotEnd)));
						end
					end

					data(iCh, replaceStarts(iR):replaceEnds(iR)) = extrapSig;
				end
			end
			
		case 'localSmoothedCubic'
			% (inspired by tesa_interpdata)
			% Especially with high-sampling rate data, the default behavior of spline interpolation to 
			%  use single or pairs of endpoint samples results in a spline that doesn't reduce
			%  low-frequency discontinuities in the way we want for TMS-EEG. So instead take a local amount
			%  of data at beginning and end of timespan to replace to fit a spline better to the low-frequency 
			%  component of the signal
			
			% find continuous segments to replace
			replaceStarts = find(diff(indices)>0)+1;
			replaceEnds = find(diff(indices)<0);
			assert(length(replaceStarts)==length(replaceEnds));
			
			s.prePostFitDurations = round(s.prePostFitDurations);
			assert(all(s.prePostFitDurations > 1));
			
			prevReplaceEnd = 0;
			for iR = 1:length(replaceStarts)
				fitStart = replaceStarts(iR) - s.prePostFitDurations(1);
				if fitStart <= prevReplaceEnd
					warning('Reduced data available for fitting prior to timespanToReplace');
					fitStart = prevReplaceEnd + 1;
					assert(replaceStarts(iR) - fitStart > 1);
				end
				prevReplaceEnd = replaceEnds(iR);
				
				fitEnd = replaceEnds(iR) + s.prePostFitDurations(2);
				if iR < length(replaceStarts)
					nextStart = replaceStarts(iR+1);
				else
					nextStart = size(data, 2);
				end
				if fitEnd >= nextStart
					warning('Reduced data available for fitting after timespanToReplace');
					fitEnd = nextStart - 1;
					assert(nextStart - fitEnd > 1);
				end
				
				toFit = data(:, fitStart:fitEnd);
				x = 1:(fitEnd-fitStart)+1;
				if s.doDebug
					xAll = x;
				end
				
				relReplaceStart = s.prePostFitDurations(1) + 1;
				relReplaceStop = s.prePostFitDurations(1) + (replaceEnds(iR) - replaceStarts(iR)) + 1;
				
				toFit(:, relReplaceStart:relReplaceStop) = [];
				x_toInterp = x(relReplaceStart:relReplaceStop);
				x(relReplaceStart:relReplaceStop) = [];
				
				for iCh = 1:size(data,1)
					y_toFit = toFit(iCh,:);
					if false
						% center and scale
						mu = mean(y_toFit);
						y_toFit = y_toFit - mu;
						sd = std(y_toFit);
						y_toFit = y_toFit/sd;
						p = polyfit(x, y_toFit, 3);
						data(iCh,replaceStarts(iR):replaceEnds(iR)) = polyval(p, x_toInterp)*sd + mu;
					else
						[p,~,mu] = polyfit(x, y_toFit, 3);
						if s.doDebug
							figure; 
							hp = plot(xAll, data(iCh, fitStart:fitEnd), 'lineWidth', 1.5);
							hp.Color = [hp.Color 0.5];
							hold on;
% 							hp = plot(x, toFit(iCh,:), 'linewidth', 1.5); 
% 							hp.Color = [hp.Color 0.5];
							hp = plot(xAll, polyval(p, xAll, [], mu), 'lineWidth', 1.5); 
							hp.Color = [hp.Color 0.5];
							ha = gca;
 							ha.ColorOrderIndex = ha.ColorOrderIndex+1;
							hp = plot([xAll(relReplaceStart-1), x_toInterp, xAll(relReplaceStop+1)],...
								[data(iCh, replaceStarts(iR)-1), polyval(p, x_toInterp, [], mu), data(iCh, replaceEnds(iR)+1)],...
								'linewidth', 1.5);
							hp.Color = [hp.Color 0.5];
% 							legend('Original', 'Data to fit', 'Cubic fit', 'Replacement timespan', 'location', 'eastoutside')
							legend('Original', 'Cubic fit', 'Replacement timespan', 'location', 'eastoutside')
						end
						data(iCh, replaceStarts(iR):replaceEnds(iR)) = polyval(p, x_toInterp, [], mu);
						if s.doDebug
							ylim(c_limits_multiply(extrema(data(iCh, fitStart:fitEnd)), 1.5));
							keyboard
						end
					end
					
				end
			end
		otherwise
			if ischar(s.method)
				if s.doDebug
						tmp = interp1(knownTimes,data(:,~indices).',unknownTimes,s.method).';
						replaceStart = find(indices>0, 1, 'first');
						replaceStop = find(diff(indices)<0, 1, 'first');
						
						nearbyStart = replaceStart - 500;
						nearbyEnd = replaceStop + 500;
						
						iCh = 1;
						
						xAll = 1:nearbyEnd-nearbyStart+1;
						xReplace = (replaceStart:replaceStop)-nearbyStart+1;
						
						figure; 
						hp = plot(xAll, data(iCh, nearbyStart:nearbyEnd), 'lineWidth', 1.5);
						hp.Color = [hp.Color 0.5];
						hold on;
						hp = plot(xReplace, tmp(iCh, 1:replaceStop-replaceStart+1), 'lineWidth', 1.5); 
						hp.Color = [hp.Color 0.5];
						ylim(c_limits_multiply(extrema(tmp(iCh, 1:replaceStop-replaceStart+1)), 4));
						legend('Original', sprintf('%s interpolation', s.method), 'location', 'eastoutside')
						keyboard
						
						data(:, indices) = tmp;
				else
						data(:,indices) = interp1(knownTimes,data(:,~indices).',unknownTimes,s.method).';
				end
			elseif isscalar(s.method)
				% method is actually a constant scalar to use to replace all unknown values
				data(:,indices) = s.method;
			else
				error('Invalid method');
			end
	end
end

function [extrapSig,modelCoeff] = c_extrapolateSignal(sig,numAddedPts,modelOrder,modelCoeff)
	if isvector(sig) && size(sig,2) > 1
		sig = sig';
	end
	if nargin < 3
		modelOrder = floor(size(sig,1)-1);
	end
	if nargin < 4
		modelCoeff = arburg(sig,modelOrder);
	end
	
	extrapSig = zeros(size(sig,1) + numAddedPts,size(sig,2));
	
	extrapSig(1:size(sig,1),:) = sig; % do not extrapolate what we already know
	
	if any(isnan(modelCoeff))
		if all(sig==0)
			% special case: if input is all zeros, arburg will return [1 NaN NaN ...] for coefficients
			assert(modelCoeff(1)==1);
			assert(all(isnan(modelCoeff(2:end))));
			extrapSig((size(sig,1)+1):end,:) = 0;
			return;
		elseif c_allEqual(sig)
			% special case: if all constant values, arburg will return [1 NaN NaN ...]
			assert(modelCoeff(1)==1);
			assert(all(isnan(modelCoeff(2:end))));
			extrapSig((size(sig,1)+1):end,:) = extrapSig(1);
			return;
		else
			error('NaN coefficients in fitted model');
			% perhaps can happen if model order is too high, maybe add support by pruning tailing NaNs from coefficients
		end
	end
	
	[~,zf] = filter(-[0 modelCoeff(2:end)], 1, sig,[],1);
	extrapSig((size(sig,1)+1):end,:) = filter([0 0], -modelCoeff, zeros(size(extrapSig,1)-size(sig,1),size(sig,2)), zf,1);
end


function testfn()	
	close all;
	tmin = -0.2;
	tmax = 0.4;
	srate = 1000;
	N = (tmax-tmin)*srate;
	t = linspace(tmin,tmax,N);
	x(1,:) = sin(10*pi*t);
	x(2,:) = cos(25*pi*t);
	x(3,:) = cumsum(randn(1,length(t)));
	x(3,:) = x(3,:) / max(abs(x(3,:)));
	
	timespanToReplace = [-0.01 0.05];
	indicesToReplace = t>=timespanToReplace(1) & t<timespanToReplace(2);
	
	hf = figure;
	c_subplot(2,1,1);
	plot(t,x);
	title('Original signals');
	
	ha = c_subplot(2,1,2);
	
	debugArgs = {'doDebug', true, 'indexOfTimeZero', sum(t<0), 'srate', srate};
	
% 	y = interpolateWithinIndices(x,indicesToReplace,'localSmoothedCubic', ...
% 		'prePostFitDurations', [100 100]*1e-3*srate);
	y = interpolateWithinIndices(x,indicesToReplace,'ARExtrapolation', ...
		'prePostFitDurations', [100 100]*1e-3*srate,...
		debugArgs{:});
% 	y = interpolateWithinIndices(x,indicesToReplace,'makima');
	plot(ha, t,y);
	title(ha, sprintf('Signals with %s interpolated', c_toString(timespanToReplace)));
end