function EEG = c_TMSEEG_handleBurstEvents(varargin)
p = inputParser();
p.addRequired('EEG', @isstruct);
p.addParameter('pulseEvent', '', @ischar);
p.addParameter('pulseEvents', {}, @iscellstr);  % can specify multiple pulse event types to be treated as the same
p.addParameter('method', 'error', @ischar);
p.addParameter('burstMaxIPI', 0.3, @isfloat); % if pulses closes together than this (in s), will be treated as a single burst
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;

if ~isempty(s.pulseEvents)
	assert(ismember(p.UsingDefaults, 'pulseEvent'), 'Should not specify both pulseEvent and pulseEvents');
	pulseEvents = s.pulseEvents;
else
	assert(~isempty(s.pulseEvent));
	pulseEvents = {s.pulseEvent};
end

pulseEventIndices = find(ismember({EEG.event.type}, pulseEvents));
pulseTimes = [EEG.event(pulseEventIndices).latency] / EEG.srate;
diffPulseTimes = diff(pulseTimes);
switch(s.method)
	case 'error'
		if any(diffPulseTimes <= s.burstMaxIPI)
			error('Some pulses <= %0.3f s apart but expected single pulses only', s.burstMaxIPI)
		end
	case {'cutIPI', 'cutIPIKeepFirst', 'cutIPIKeepLast', 'cutIPIKeepFirstAndLast'}
		% cut out segments of data between consecutive pulses in a burst
		
		mergePulses = diffPulseTimes <= s.burstMaxIPI;
		if any(mergePulses)
			burstIndices = [1 1+cumsum(1-mergePulses)];
			numEpochs = burstIndices(end);
			latenciesToCut = nan(numEpochs, 2);
			noRemove = [];
			for iEp = 1:numEpochs
				iEv_start = find(burstIndices==iEp, 1, 'first');
				iEv_end = find(burstIndices==iEp, 1, 'last');
				if iEv_start == iEv_end
					% nothing to collapse for this epoch
					noRemove(end+1) = iEp;
					continue
				end
				switch(s.method)
					case {'cutIPI', 'cutIPIKeepFirst'}
						% remove all but first event, so that later epoching code can expect just one event per epoch
						latenciesToCut(iEp, 1) = EEG.event(pulseEventIndices(iEv_start)).latency + 1;
						latenciesToCut(iEp, 2) = EEG.event(pulseEventIndices(iEv_end)).latency + 1;
					case 'cutIPIKeepLast'
						latenciesToCut(iEp, 1) = EEG.event(pulseEventIndices(iEv_start)).latency - 1;
						latenciesToCut(iEp, 2) = EEG.event(pulseEventIndices(iEv_end)).latency - 1;
					case 'cutIPIKeepFirstAndLast'
						latenciesToCut(iEp, 1) = EEG.event(pulseEventIndices(iEv_start)).latency + 1;
						latenciesToCut(iEp, 2) = EEG.event(pulseEventIndices(iEv_end)).latency - 1;
						% note: these boundaries are set so that the first and last events are on consecutive samples (not overlapping)
						%  at low sampling rates, this offset could effect some primary artifact rejection pipelines that specify small 
						%  time cut-off values. 
					otherwise
						error('Not implemented');
				end
			end
			if ~isempty(noRemove)
				latenciesToCut(noRemove, :) = [];
			end
			
			if true
				% don't count boundaries within bursts since they'll be removed anyways
				eventIndices = ismember({EEG.event.type}, {'boundary'});
				toRemove = false(sum(eventIndices), 1);
				for iL = 1:size(latenciesToCut, 1)
					eventLatencies = [EEG.event(eventIndices).latency]';
					toRemove = toRemove | (eventLatencies > latenciesToCut(iL, 1) & eventLatencies <= latenciesToCut(iL, 2));
				end
				if any(toRemove)
					eventIndices(paren(find(eventIndices), toRemove)) = false; 
				end
				numOrigBoundaryEvents = sum(eventIndices);
			else
				numOrigBoundaryEvents = sum(ismember({EEG.event.type}, {'boundary'}));
			end
			
			c_say('Collapsing bursts for %d epochs', size(latenciesToCut, 1));
			
			fn = @() pop_select(EEG, 'nopoint', latenciesToCut);
			if false
				EEG = fn();
			else
				[~, EEG] = evalc('fn()');
			end
			
			c_sayDone();
			
			if true
				% remove resulting boundary events so they don't interfere with later processing
				boundaryEventIndices = find(ismember({EEG.event.type}, {'boundary'}));
				numBoundaryEvents = length(boundaryEventIndices);
				doRemoveBoundaryEvent = false(size(boundaryEventIndices));
				for iiB = 1:length(boundaryEventIndices)
					iB = boundaryEventIndices(iiB);
					switch(s.method)
						case {'cutIPI', 'cutIPIKeepFirst', 'cutIPIKeepFirstAndLast'}
							if iB > 1 && EEG.event(iB).latency - EEG.event(iB-1).latency < 1.5 && ~ismember({EEG.event(iB-1).type}, {'boundary'})
								doRemoveBoundaryEvent(iiB) = true;
							end
						case 'cutIPIKeepLast'
							if iB < length(EEG.event) && EEG.event(iB+1).latency - EEG.event(iB).latency < 1.5 && ~ismember({EEG.event(iB+1).type}, {'boundary'})
								doRemoveBoundaryEvent(iiB) = true;
							end
						otherwise
							error('Not implemented');
					end
				end
				
				numToRemove = sum(doRemoveBoundaryEvent);
				assert(numToRemove == numBoundaryEvents - numOrigBoundaryEvents);
				
				EEG.event(boundaryEventIndices(doRemoveBoundaryEvent)) = [];
				
				c_saySingle('Removed %d boundary events added by pop_select', numToRemove);
			end
		end		
		
	otherwise
		error('Unexpected method: %s', s.method);
end


end