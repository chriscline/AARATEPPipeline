function EEG = c_EEG_addEvents(varargin)
p = inputParser();
p.addRequired('EEG',@isstruct);
p.addParameter('events',struct(),@isstruct); 
p.addParameter('eventLatencies',[],@c_isinteger); % in indices (assume non fractional indices, though could remove this restriction)
p.addParameter('eventPositions',[],@isnumeric);
p.addParameter('eventTimes',[],@isnumeric); % in s
p.addParameter('eventTimeDurations',[],@isnumeric); % in s
p.addParameter('eventDurations',[],@c_isinteger); % in indices
p.addParameter('eventTypes','',@(x) ischar(x) || iscellstr(x));
p.addParameter('eventUrevents',[],@isempty); % should not actually be specified, just here for consistent structure with other fields
p.addParameter('onUnspecifiedFields','error',@ischar);
p.addParameter('onExtraFields','error',@ischar);
%TODO: add a 'ureventLatencies' option to specify original (e.g. non-epoched) event latency separate from epoched event latency
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;

inputFields = {'eventLatencies','eventPositions','eventTimes','eventTimeDurations','eventDurations','eventTypes','eventUrevents'};

if ~c_isEmptyStruct(s.events)
	% events specified
	structFields = fieldnames(EEG.event);
	if any(~ismember(inputFields,p.UsingDefaults))
		error('If specifying ''events'' struct, should not specify any individual event fields separately');
	end
	if ~isempty(setdiff(structFields,fieldnames(s.events))) && strcmpi(s.onUnspecifiedFields,'error')
		error('Missing fields in specified ''events'' struct: %s',c_toString(setdiff(structFields,fieldnames(s.events))));
	end
	fieldsToDiscard = setdiff(fieldnames(s.events),structFields);
	if ~isempty(fieldsToDiscard)
		c_saySingle('Discarding event fields: %s',c_toString(fieldsToDiscard));
		s.events = rmfield(s.events,setdiff(fieldnames(s.events),structFields));
	end
else
	% construct events from individual fields
	
	mapToOutputFields = {'latency','position','','','duration','type','urevent'};
	assert(length(inputFields)==length(mapToOutputFields));

	indicesToRemove = ~ismember(mapToOutputFields,fieldnames(EEG.event)) & ...
		~cellfun(@isempty,mapToOutputFields) & ...
		cellfun(@(inputField) isempty(s.(inputField)),inputFields);

	inputFields(indicesToRemove) = [];
	mapToOutputFields(indicesToRemove) = [];

	if ischar(s.eventTypes)
		s.eventTypes = {s.eventTypes};
	end

	structFields = mapToOutputFields(~cellfun(@isempty,mapToOutputFields))';
	
	lengths = cellfun(@(x) length(s.(x)), inputFields);
	
	numEvents = max(lengths);
	
	if numEvents == 0
		% no events specified
		warning('No events to add');
		% return EEG unmodified
		return;
	end
	
	assert(all(lengths==0 | lengths==1 | lengths==numEvents)); 
	
	indicesToRep = find(lengths==1);
	for iF = indicesToRep
		s.(inputFields{iF}) = repmat(s.(inputFields{iF}),1,numEvents);
	end
	
	if ~isempty(s.eventLatencies) && ~isempty(s.eventTimes)
		error('Should not specify both eventLatencies and eventTimes')
	elseif ~isempty(s.eventTimes)
		% convert times to latencies
		s.eventLatencies = round(s.eventTimes * EEG.srate);
		s.eventTimes = [];
	end
	
	if ~isempty(s.eventDurations) && ~isempty(s.eventTimeDurations)
		error('Should not specify both eventDurations and eventTimeDurations')
	elseif ~isempty(s.eventTimeDurations)
		% convert time durations to latency durations
		s.eventDurations = s.eventTimeDurations * EEG.srate; %TODO: determine whether durations must be integers
		s.eventTimeDurations = [];
	end
	
	args = cell(1,length(structFields)*2);
	args(1:2:end) = structFields;
	args(2:2:end) = {repmat({},1,length(structFields))};
	s.events = struct(args{:});
	
	for iE = 1:numEvents
		newEvent = struct();
		for iF = 1:length(inputFields)
			if isempty(mapToOutputFields{iF})
				continue; % skip
			end
			if isempty(s.(inputFields{iF}))
				val = NaN;
			else
				val = s.(inputFields{iF})(iE);
			end
			if iscell(val) && length(val)==1
				val = val{1};
			end
			newEvent.(mapToOutputFields{iF}) = val;
		end
		s.events(iE) = newEvent;
	end
end

if ~c_isEmptyStruct(EEG.event)
	extraFields = setdiff(fieldnames(s.events),fieldnames(EEG.event));
	if ~isempty(extraFields)
		switch(lower(s.onExtraFields))
			case 'error'
				error('Fields in new events do not exist in original events: %s',c_toString(extraFields));
			case lower('warnAndRemove')
				warning('Fields in new events do not exist in original events. Removing: %s',c_toString(extraFields));
				s.events = rmfield(s.events,extraFields);
			case lower('silentlyRemove')
				s.events = rmfield(s.events,extraFields);
			case lower('insertNaN')
				% add extra fields to original events and set values to NaN
				for iF = 1:length(extraFields)
					[EEG.event.(extraFields{iF})] = deal(NaN);
					[EEG.urevent.(extraFields{iF})] = deal(NaN);
				end
			otherwise
				error('Invalid onExtraFields: %s',s.onExtraFields);
		end
	end
	
	unspecifiedFields = setdiff(fieldnames(EEG.event),fieldnames(s.events));
	if ~isempty(unspecifiedFields)
		switch(lower(s.onUnspecifiedFields))
			case 'error'
				error('New events do not specify fields: %s',c_toString(unspecifiedFields));
			case lower('insertNaN')
				for iF = 1:length(unspecifiedFields)
					[s.events.(unspecifiedFields{iF})] = deal(NaN);
				end
			case lower('insertEmpty')
				for iF = 1:length(unspecifiedFields)
					[s.events.(unspecifiedFields{iF})] = deal([]);
				end
			otherwise
				error('Invalid onUnspecifiedFields: %s',s.onUnspecifiedFields);
		end
	end
end

% make sure that new events are sorted by latency
s.events = c_struct_sortByField(s.events,'latency');

% insert events into existing EEG struct, sorting by latency
numEvents = length(s.events);
for iE = 1:numEvents
	% note that this overwrites any previously specified urevent values
	s.events(iE).urevent = length(EEG.urevent) + iE;
end
if ~isempty(EEG.urevent)
	fieldsToRemove = setdiff(fieldnames(s.events), fieldnames(EEG.urevent));
else
	fieldsToRemove = {'urevent'};
end
EEG.urevent = [EEG.urevent, rmfield(s.events,fieldsToRemove)];
iOE = 1;
for iE = 1:length(s.events) % assumes events are ordered by increased latency
	while iOE <= length(EEG.event) && EEG.event(iOE).latency < s.events(iE).latency
		iOE = iOE + 1;
	end
	EEG.event = [EEG.event(1:iOE-1), s.events(iE), EEG.event(iOE:end)];
	iOE = iOE + 1;
end

end
