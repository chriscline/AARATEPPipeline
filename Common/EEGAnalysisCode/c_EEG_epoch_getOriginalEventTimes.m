function t = c_EEG_epoch_getOriginalEventTimes(varargin)
	p = inputParser;
	p.addRequired('EEG',@isstruct);
	p.addParameter('eventType','',@ischar); % used if data is not already epoched
	p.addParameter('outputUnits', '', @ischar); % due to past versions being ambiguous about this, must specify manually
	p.parse(varargin{:});
	s = p.Results;
	
	EEG = s.EEG;
	
	assert(~isempty(s.outputUnits), 'Previous behavior deprecated, must now specify output units');
	
	if c_EEG_isEpoched(EEG)
		% return the absolute times for each epoch's time 0
		tmp = {EEG.epoch.eventurevent};
		for i=1:length(tmp)
			if length(tmp{i})==1
				if iscell(tmp{i})
					epochUreventIndices(i) = cell2mat(tmp{i});
				else
					epochUreventIndices(i) = tmp{i};
				end
			else
				% multiple events in epoch. Need to find which corresponds to time 0
				epochUreventIndices(i) = NaN;
				for j=1:length(tmp{i})
					if EEG.epoch(i).eventlatency{j}==0
						epochUreventIndices(i) = tmp{i}{j};
						break;
					end
				end
				if isnan(epochUreventIndices(i))
					error('Could not find event corresponding to latency 0 for epoch %d',i);
				end
			end
		end

		originalLatencies = cell2mat({EEG.urevent(epochUreventIndices).latency});

		t = originalLatencies / EEG.srate;
		
		t = c_convertValuesFromUnitToUnit(t, 's', s.outputUnits);
	else
		% data is not already epoched
		if isempty(p.Results.eventType)
			error('Data not epoched. Event type must be specified.');
		end
		
		trialEventIndices = strcmp({EEG.event.type},p.Results.eventType);
		trialDataStartIndices = round([EEG.event(trialEventIndices).latency]);
		t = EEG.times(trialDataStartIndices);
		
		t = c_convertValuesFromUnitToUnit(t, 'ms', s.outputUnits);
	end
	
end