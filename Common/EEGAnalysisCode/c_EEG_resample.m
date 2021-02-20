function EEG = c_EEG_resample(varargin)
p = inputParser();
p.addRequired('EEG',@isstruct);
p.addRequired('newFs',@isscalar);
p.addParameter('method','eeglab');
p.addParameter('doResampleAuxData',true,@islogical);
p.parse(varargin{:});
EEG = p.Results.EEG;

if p.Results.newFs == EEG.srate
	c_saySingle('New sampling rate is the same as old. Not resampling.');
	return;
end

didMergeAuxData = false;
if p.Results.doResampleAuxData && c_EEG_hasAuxData(EEG)
	EEG = c_EEG_mergeAuxData(EEG);
	didMergeAuxData = true;
end

switch(p.Results.method)
	case 'eeglab'
		EEG = pop_resample(EEG,p.Results.newFs);
	case 'nofilt'
		% no anti-aliasing filter applied, assuming energy in higher frequencies is already negligible
		Fs = p.Results.newFs;
		doUpsample = Fs > EEG.srate;
		if doUpsample
			ratio = Fs / EEG.srate;
			assert(mod(ratio,1)==0); % only integer upsampling ratios supported
			origSize = size(EEG.data);
			if length(origSize)==2
				origSize(3) = 1;
			end
			EEG.data = permute(EEG.data,[1 3 2]); % swap time and trial dims
			EEG.data = reshape(EEG.data,[],size(EEG.data,3)); % combine channel and trial dims
			didConvertFromSingle = false;
			if isa(EEG.data,'single')
				c_say('Temporarily converting EEG.data from single to double');
				EEG.data = double(EEG.data);
				c_sayDone();
				didConvertFromSingle = true;
			end
			EEG.data = double(EEG.data);
			newData = nan(size(EEG.data,1),size(EEG.data,2)*ratio);
			for i=1:size(EEG.data,1)
				newData(i,:) = interp(EEG.data(i,:),ratio);
			end
			EEG.data = newData;
			if didConvertFromSingle
				c_say('Converting EEG.data back from double to single');
				EEG.data = single(EEG.data);
				c_sayDone();
			end
			newTimeLength = origSize(2)*ratio-(ratio-1); % remove extrapolated points at tail end of time series
			EEG.data = EEG.data(:,1:newTimeLength); 
			EEG.data = reshape(EEG.data,origSize(1),origSize(3),newTimeLength);
			EEG.data = ipermute(EEG.data,[1 3 2]);
			assert(size(EEG.data,1)==origSize(1) && size(EEG.data,2) == newTimeLength && size(EEG.data,3)==origSize(3)); %TODO: debug, delete
			EEG.srate = Fs;
			EEG.times = (EEG.xmin:1/Fs:EEG.xmax)*1e3;
			EEG.pnts = length(EEG.times);
			if EEG.pnts-1 == size(EEG.data,2)
				% correct for off-by-one error
				EEG.pnts = EEG.pnts-1;
			end
			assert(EEG.pnts==size(EEG.data,2));
		else
			ratio = EEG.srate / Fs;
			assert(mod(ratio,1)==0); % only integer downsampling ratios supported
			
			if c_EEG_isEpoched(EEG)
				doHandleBoundaryEvents = false; % boundary code below doesn't fully support epoched data
				assert(~any(ismember({EEG.event.type}, {'boundary'})));
			else 
				doHandleBoundaryEvents = true;
			end
			
			EEG.srate = Fs;
			if doHandleBoundaryEvents
				% handle boundary events (adapted from pop_resample)
				bounds = find(ismember({EEG.event.type}, {'boundary'}));
				if ~isempty(bounds)
					bounds = [ EEG.event(bounds).latency ];
					bounds(bounds <= 0 | bounds > size(EEG.data,2)) = []; % Remove out of range boundaries
					bounds(mod(bounds, 1) ~= 0) = round(bounds(mod(bounds, 1) ~= 0) + 0.5); % Round non-integer boundary latencies
				end
				bounds = [1 bounds size(EEG.data, 2) + 1]; % Add initial and final boundary event
				bounds = unique(bounds); % Sort (!) and remove doublets

				dsData = [];
				for iB = 1:length(bounds)-1
					iStart = bounds(iB);
					iEnd = bounds(iB+1)-1;
					dsData = [dsData, EEG.data(:,iStart:ratio:iEnd,:)];
				end
				EEG.data = dsData;
				EEG.pnts = size(EEG.data, 2);
				EEG.xmax = EEG.xmin + (EEG.pnts-1)/EEG.srate; % recompute to correct for possible loss of samples above
				EEG.times = linspace(EEG.xmin*1e3, EEG.xmax*1e3, EEG.pnts);
			else
				% don't handle boundary events
				EEG.data = EEG.data(:,1:ratio:end,:);
				EEG.times = EEG.times(1:ratio:end);
				EEG.pnts = length(EEG.times);
				EEG.xmin = min(EEG.times/1e3);
				EEG.xmax = max(EEG.times/1e3);
			end
		end
		
		% fix event latencies
		if 0
			fieldStrs = {'event','urevent'};
			for i=1:length(fieldStrs)
				fieldStr = fieldStrs{i};
				doContinue = false;
				for e=1:length(EEG.(fieldStr))
					% note: this code may miss some corner cases. Check out pop_resample if having issues.

					if strcmp(EEG.(fieldStr)(e).type,'boundary') 
						if strcmp(fieldStr,'urevent') 
							% this gets more complicated (see pop_resample if need to implement). Just delete urevents instead of fixing latencies
							keyboard
							c_saySingle('Deleting EEG.urevent rather than trying to fix latencies');
							EEG = rmfield(EEG,'urevent');
							doContinue = true;
							break;
						else
							error('Boundary events in EEG.event not supported here');
						end
					end

					% this assumes there are no boundaries, and that event isn't at first latency
					assert(EEG.(fieldStr)(e).latency>1);

					EEG.(fieldStr)(e).latency = (EEG.(fieldStr)(e).latency - 1) / ratio + 1;
				end
				if doContinue
					continue;
				end
			end
		else
			% inefficient, but resample with EEGLab function (with filter) just to get correct event times
			tmpEEG = p.Results.EEG;
			tmpEEG.data = tmpEEG.data(1,:,:);
			tmpEEG.nbchan = 1;
			prevState = warning('off','EEGLab:ResamplingEpochedData'); % suppress warning
			tmp = pop_resample_mod(tmpEEG,p.Results.newFs);
			%tmp = pop_resample(tmpEEG,p.Results.newFs); %newer EEGLab pop_resample clears urevent struct at this stage, which can be undesirable
			%tmp = pop_resample_old(tmpEEG,p.Results.newFs); % so use from older version instead (may have bugs!?)
			warning(prevState);
			assert(tmp.pnts==EEG.pnts)
			EEG.event = tmp.event;
			EEG.urevent = tmp.urevent;
		end
	otherwise
		error('Unsupported method: %s',p.Results.method);
end

if didMergeAuxData
	EEG = c_EEG_splitAuxData(EEG);
end


end