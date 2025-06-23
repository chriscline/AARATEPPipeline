function [EEG, misc] = c_TMSEEG_detectBadChannels(varargin)
%
% output struct `misc` includes the following:
% - misc.badChannelIndices: numeric indices of bad channels 
%   (if removing bad channels, these indices index into the channels prior to rejection)
% - misc.channelScores: per-ch scores, where greater magnitudes indicate more likely to be bad channels 
%		if detectionMethod==PREP_deviation, then these scores are robustChanDeviation scores

p = inputParser();
p.addRequired('EEG', @isstruct);
p.addParameter('detectionMethod', 'PREP_deviation', @(x) ischar(x) || iscellstr(x));
p.addParameter('replaceMethod', 'interpolate', @ischar);
p.addParameter('artifactTimespan', [], @c_isSpan);
p.addParameter('threshold', [], @isscalar); % default value for this is method-specific
p.addParameter('doPlot', false, @islogical);
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;

if iscellstr(s.detectionMethod)
	% if multiple methods specified, reject a channel that is identified as bad by any of the listed methods

	if s.doPlot
		misc.hf = figure;
		ht = c_GUI_Tiler();
	end

	badChannelIndices = false(EEG.nbchan, 1);
	misc.channelScores = nan(EEG.nbchan, length(s.detectionMethod));
	misc.scoreThresholds = repmat({}, 1, length(s.detectionMethod));

	EEG_tmp = EEG;

	for iDM = 1:length(s.detectionMethod)
		kwargs = c_cellToStruct(varargin(2:end));
		kwargs.detectionMethod = s.detectionMethod{iDM};
		%kwargs.replaceMethod = 'none';
		kwargs = c_structToCell(kwargs);
		[EEG_tmp, misc_iDM] = c_TMSEEG_detectBadChannels(EEG_tmp, kwargs{:});

		badChannelIndices(misc_iDM.badChannelIndices) = true;
		misc.channelScores(:, iDM) = misc_iDM.channelScores;
		misc.scoreThresholds{iDM} = misc_iDM.scoreThreshold;

		if s.doPlot
			hp = ht.add();
			copyobj(misc_iDM.hf.Children(2:end), hp)
			title(gca, s.detectionMethod{iDM})
			close(misc_iDM.hf);
		end
	end

	badChannels = find(badChannelIndices);

	s.detectionMethod = '__multiple__';
end

% TODO: also do artifact timespan interpolation for TESA_DDWiener* methods or issue warning if specifying a timespan that is ignored
if ismember(s.detectionMethod, '__multiple__')
	% handled within each method, do nothing here
elseif ismember(s.detectionMethod, {'PREP_deviation', 'TESA_DDWiener_PerTrial_IgnoreArtifactTime', 'TESA_DDWiener_PerTrial_BaselineOnly'})
	if ismember('artifactTimespan', p.UsingDefaults)
		warning('Artifact timespan unspecified. Will not ignore artifact timespan for bad channel detection');
	end
	if ~isempty(s.artifactTimespan)
		if ismember(s.detectionMethod, {'PREP_deviation'})
			tmpEEG = c_EEG_ReplaceEpochTimeSegment(EEG,...
				'timespanToReplace', s.artifactTimespan,...
				'method', 'zero');
		elseif ismember(s.detectionMethod, {'TESA_DDWiener_IgnoreArtifactTime', 'TESA_DDWiener_PerTrial_IgnoreArtifactTime'})
			% for backwards compatibility, don't do artifact ignoring for TESA_DDWiener and TESA_DDWiener_PerTrial
			% methods unless explicitly suffixed with '_IgnoreArtifactTime'
			tmpEEG = c_EEG_ReplaceEpochTimeSegment(EEG,...
				'timespanToReplace', s.artifactTimespan,...
				'method', 'delete');
		elseif ismember(s.detectionMethod, {'TESA_DDWiener_PerTrial_BaselineOnly'})
			tmpEEG = pop_select(EEG, 'notime', [s.artifactTimespan(1), EEG.xmax]); 
		else
			error('not implemented')
		end
	else
		tmpEEG = EEG;
	end
else
	if ~isempty(s.artifactTimespan)
		warning('Artifact timespan argument is ignored for method %s', s.detectionMethod)
	end
	tmpEEG = EEG;
end


switch(s.detectionMethod)
	case '__multiple__'
		% handled above, do nothing here
	case 'fromASR'
		% if ASR was previously run on EEG, bad channels are recorded in EEG struct
		% (requires that chanlocs prior to ASR were saved as EEG.urchanlocs)
		c_say('Determining bad channels from ASR results');
		
		assert(isempty(s.threshold), 'Threshold not used for channels previously marked for rejection by ASR');
		
		if ~c_isFieldAndNonEmpty(EEG.etc, 'clean_channel_mask')
			goodChannels = 1:EEG.nbchan;
			badChannels = [];
			assert(length(EEG.chanlocs)==length(EEG.urchanlocs));
		else
			goodChannels = find(EEG.etc.clean_channel_mask);
			badChannels = find(~EEG.etc.clean_channel_mask);
		end
		
		if ~isempty(badChannels)
			if ~ismember(s.replaceMethod, {'interpolate', 'NaN'})
				error('Detection without rejection not implemented for fromASR method, since "bad" indices are already removed by ASR')
			end
			
			c_say('Inserting NaNs for bad channels prior to interpolation');
			nbchan = length(goodChannels)+length(badChannels);
			assert(length(EEG.urchanlocs)==nbchan);
			tmpData = nan(nbchan, EEG.pnts, EEG.trials);
			tmpData(goodChannels, :, :) = EEG.data;
			EEG.data = tmpData;
			EEG.chanlocs = EEG.urchanlocs;
			EEG.nbchan = nbchan;
			c_sayDone();
			% will be interpolated below
		end
		
		if s.doPlot
			keyboard % TODO
		end
		
	case 'PREP_deviation'
		c_say('Detecting bad channels based on PREP deviation scores');
		% Note: only catches very obvious bad channels that may degrade 1st stage ICA performance
		% (method adapted from part of PREP pipeline)
		bad = struct();

		if isempty(s.threshold)
			s.threshold = 9;
			c_saySingle('Using default rejection threshold of %s', c_toString(s.threshold));
		else
			c_saySingle('Using specified rejection threshold of %s', c_toString(s.threshold));
		end

		tmpData = reshape(tmpEEG.data, [EEG.nbchan, EEG.pnts*EEG.trials]);

		% detect nan channels
		bad.nan = any(isnan(tmpData),2);

		% detect constant channels
		bad.constant = mad(tmpData, 1, 2) < 10e-10;

		% unusually high or low amplitude
		chanDeviation = 0.7413 * iqr(tmpData, 2);
		chanDeviationSD = 0.7413 * iqr(chanDeviation);
		chanDeviationMedian = nanmedian(chanDeviation);

		robustChanDeviation = (chanDeviation - chanDeviationMedian) / chanDeviationSD;
		bad.deviation = abs(robustChanDeviation) > s.threshold;
		
		misc.channelScores = robustChanDeviation;
		misc.scoreThreshold = [-1 1]*s.threshold;

		badChannels = find(bad.nan | bad.constant | bad.deviation);
		
		if s.doPlot
			misc.hf = figure; 
			topoplot(misc.channelScores, EEG.chanlocs, 'electrodes', 'on',...
				'emarker2',{badChannels,'x','k',10,2});
			hc = colorbar; 
			caxis([-1 1]*s.threshold); 
			ylabel(hc,'Channel deviation');
		end
		
	case {'TESA_DDWiener', 'TESA_DDWiener_PerTrial',...
			'TESA_DDWiener_IgnoreArtifactTime', 'TESA_DDWiener_PerTrial_IgnoreArtifactTime',...
			'TESA_DDWiener_PerTrial_BaselineOnly'}
		
		c_say('Detecting bad channels based on DDWiener noise estimates');
		
		if isempty(s.threshold)
			s.threshold = 20;
			c_saySingle('Using default rejection threshold of %s', c_toString(s.threshold));
		else
			c_saySingle('Using specified rejection threshold of %s', c_toString(s.threshold));
		end
		
		switch(s.detectionMethod)
			case {'TESA_DDWiener', 'TESA_DDWiener_IgnoreArtifactTime'}
				tmp = mean(tmpEEG.data,3);
				[~, sigmas] = DDWiener(tmp);
			case {'TESA_DDWiener_PerTrial', 'TESA_DDWiener_PerTrial_IgnoreArtifactTime', 'TESA_DDWiener_PerTrial_BaselineOnly'}
				[~, sigmas] = DDWiener(reshape(tmpEEG.data, [tmpEEG.nbchan, tmpEEG.pnts*tmpEEG.trials]));
			otherwise
				error('Not implemented');
		end
		
		misc.channelScores = sigmas; 
		misc.scoreThreshold = median(sigmas) + s.threshold*mad(sigmas,1);
		
		badChannels = sigmas > misc.scoreThreshold;
		
		if true
			% also reject channels with sigma=0 (indicating channel was const throughout)
			badChannels = badChannels | sigmas==0;
		end
		
		badChannels = find(badChannels);
		
		if s.doPlot
			misc.hf = figure; 
			topoplot(misc.channelScores, EEG.chanlocs,...
				'electrodes', 'on',...
				'emarker2',{badChannels,'x','k',10,2});
			hc = colorbar; 
			caxis([0 misc.scoreThreshold]); 
			ylabel(hc,'Channel noise');
		end
		
	otherwise
		if iscellstr(s.detectionMethod)
			% processed above, do nothing here
		else
			error('Not implemented');
		end
end

assert(isempty(badChannels) || isnumeric(badChannels)); % should not be logical indices

misc.badChannelIndices = badChannels;

if isempty(badChannels)
	c_sayDone('No bad channels detected');
else
	c_sayDone('%d bad channel%s detected: %s', ...
		length(badChannels),...
		c_strIfNumIsPlural(length(badChannels)),...
		c_toString({EEG.chanlocs(badChannels).labels}));
end

switch(s.replaceMethod)
	case 'interpolate'
		if length(badChannels) == EEG.nbchan
			error('All channels marked as bad, cannot interpolate');
		end
		c_say('Interpolating %d bad channel%s', length(badChannels), c_strIfNumIsPlural(length(badChannels)));
		EEG = eeg_interp(EEG, badChannels);
		c_sayDone();
	case 'NaN'
		if ismember(s.detectionMethod, 'fromASR')
			% bad channels already replaced with NaNs above
		else
			EEG.data(badChannels,: ,:) = NaN;
		end
	case {'remove', 'delete'}
		c_say('Removing %d bad channel%s', length(badChannels), c_strIfNumIsPlural(length(badChannels)));
		fn = @() pop_select(EEG, 'nochannel', badChannels);
		if true
			[~, EEG] = evalc('fn()');
		else
			EEG = fn();
		end
	case 'none'
		% do not change input data
		c_saySingle('Not interpolating, replacing, or removing bad channels.');
	otherwise
		error('Not implemented');		
end

end

function [y_solved, sigmas] = DDWiener(data)  
% This function computes the data-driven Wiener estimate (DDWiener),
% providing the estimated signals and the estimated noise-amplitudes
%
% .........................................................................
% From TESA toolbox
% 24 September 2017: Tuomas Mutanen, NBE, Aalto university  
% .........................................................................

% Compute the sample covariance matrix
C = data*data';

gamma = mean(diag(C));

% Compute the DDWiener estimates in each channel
chanN = size(data,1);
for i=1:chanN
    idiff = setdiff(1:chanN,i);
    y_solved(i,:) = C(i,idiff)*((C(idiff,idiff)+gamma*eye(chanN-1))\data(idiff,:));
end

% Compute the noise estimates in all channels 
sigmas = sqrt(diag((data-y_solved)*(data-y_solved)'))/sqrt(size(data,2));

end
