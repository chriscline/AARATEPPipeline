function srcData = c_EEG_applySrcKernel(EEG,varargin)
	p = inputParser();
	p.addOptional('data',[],@isnumeric);
	p.addParameter('srcKernel',[], @(x) ismatrix(x) || iscell(x)); % if not specified, will use EEG.src.kernel
	p.addParameter('aggDims',[],@isvector); % dimensions along which to average (or otherwise aggregate); applied in sensor space
	p.addParameter('aggFn', {@nanmean, @nanmean, @nanmean}, @(x) iscell(x) && all(cellfun(@(fn) isa(fn, 'function_handle'), x)));  % one agg function per dimension
	p.addParameter('aggTrialsInSpace', 'sensor', @(x) ismember(x, {'sensor', 'source'}));  % if aggregating 3rd dimension, whether to do it in sensor space or source space
	p.addParameter('SOI',[],@isvector); % subset of source indices to calculate
	p.addParameter('epochIndices',[],@isvector); % subset of epochs
	p.addParameter('times',[],@(x) islogical(x) || c_isSpan(x)); % indices or time limits (in s)
	p.parse(varargin{:});
	s = p.Results;
	
	if ismember('data',p.UsingDefaults)
		s.data = EEG.data;
	end
	
	if isempty(s.times)
		s.times = true(1,size(s.data,2));
	elseif ~islogical(s.times)
		assert(c_isSpan(s.times));
		s.times = EEG.times >= s.times(1)*1e3 & EEG.times <= s.times(2)*1e3;
	end
	assert(islogical(s.times) && length(s.times)==size(s.data,2));
	
	if ~isempty(s.aggDims)
		assert(all(ismember(s.aggDims,2:3)));
		assert(length(unique(s.aggDims))==length(s.aggDims),'Repeated agg dims');
		if ismember(2,s.aggDims)
			s.data = s.aggFn{2}(s.data(:,s.times,:),2);
			s.times = true;
		end
	end
	
	if ~ismember('SOI',p.UsingDefaults)
		if islogical(s.SOI)
			s.SOI = find(s.SOI);
		end
	end
	
	
	if ~ismember('epochIndices',p.UsingDefaults)
		assert(islogical(s.epochIndices));
	else
		s.epochIndices = true(1,EEG.trials);
	end
			
	if isempty(s.srcKernel)
		assert(c_isFieldAndNonEmpty(EEG,'src.kernel'),'Missing requisite source kernel metadata in EEG');
		s.srcKernel = EEG.src.kernel;
	end
	
	if iscell(s.srcKernel)
		% multi-kernel metadata, where each kernel should be applied to a subset of EEG trials
		assert(c_isFieldAndNonEmpty(EEG,'src.sessionGroupLabels'));
		assert(length(EEG.src.sessionGroupLabels)==length(s.srcKernel));
		
		if ismember('SOI',p.UsingDefaults)
			s.SOI = 1:size(s.srcKernel{1},1);
		end
		
		assert(size(s.data,3)==EEG.trials); % to determine corresponding kernels, data must match number of expected epochs
		
		assert(ndims(s.data)<=3);
		if ismember(3,s.aggDims)
			if isequal(s.aggTrialsInSpace, 'source')
				error('Not implemented')
			end
			srcData = nan(length(s.SOI),sum(s.times),length(s.srcKernel));
		else
			srcData = nan(length(s.SOI),sum(s.times),sum(s.epochIndices));
		end
		epochsConverted = false(1,EEG.trials);
		for iK = 1:length(s.srcKernel)
			if ismember(EEG.src.sessionGroupLabels(iK),EEG.epochGroupLabels)
				epochGroupIndex = c_cell_findMatchingIndices(EEG.src.sessionGroupLabels(iK),EEG.epochGroupLabels);
				epochIndices = EEG.epochGroups{epochGroupIndex};
			elseif c_isFieldAndNonEmpty(EEG,'inactiveEpochGroupLabels') && ismember(EEG.src.sessionGroupLabels(iK),EEG.inactiveEpochGroupLabels)
				epochGroupIndex = c_cell_findMatchingIndices(EEG.src.sessionGroupLabels(iK),EEG.inactiveEpochGroupLabels);
				epochIndices = EEG.inactiveEpochGroups{epochGroupIndex};
			else
				warning('Missing kernel-specific session group %s',EEG.src.sessionGroupLabels{iK});
				continue;
			end
			assert(islogical(epochIndices));
			
			assert(all(~epochsConverted(epochIndices)),'Overlap between kernel epoch groups');
			epochsConverted(epochIndices) = true;
			
			if ismember(3,s.aggDims)
				numEpochsInGroup = sum(epochIndices & s.epochIndices);
				srcData(:,:,iK) = c_mtimes(s.srcKernel{iK}(s.SOI,:), s.aggFn{3}(s.data(:,s.times,epochIndices & s.epochIndices),3))*numEpochsInGroup; 
				% (note that this is weighted by num epochs in this group for averaging to work out on per-epoch level below)
			else
				srcData(:,:,epochIndices(s.epochIndices)) = c_mtimes(s.srcKernel{iK}(s.SOI,:),s.data(:,s.times,epochIndices & s.epochIndices));
			end
		end
		assert(all(epochsConverted(s.epochIndices)),'Not all epochs were members of kernel epoch groups');
		if ismember(3,s.aggDims)
			if ~isequal(s.aggFn{3}, @nanmean)
				keyboard  % TODO: update this weighting code to work with more generic agg function
			end
			srcData = sum(srcData,3) / sum(s.epochIndices);
		end
		if ~isempty(s.srcAggDims)
			error('Not implemented')
		end
	else
		if ismember(3,s.aggDims) && isequal(s.aggTrialsInSpace, 'sensor')
			s.data = s.aggFn{3}(s.data(:,:,s.epochIndices),3);
			s.epochIndices = true;
		end
		if ismember('SOI',p.UsingDefaults)
			s.SOI = true(1,size(s.srcKernel,1));
		end
		
		if ismember(3,s.aggDims) && isequal(s.aggTrialsInSpace, 'source')
			% to reduce memory usage, apply kernel to each timepoint and aggregate
			timeIndices = find(s.times);
			srcData = nan(sum(s.SOI), length(timeIndices), 1);
			for iT = 1:length(timeIndices)
				iiT = timeIndices(iT);
				srcData(:, iT) = s.aggFn{3}(c_mtimes(s.srcKernel(s.SOI, :), s.data(:, timeIndices(iiT), s.epochIndices)), 3);
			end
		else
			srcData = c_mtimes(s.srcKernel(s.SOI,:),s.data(:,s.times,s.epochIndices));
		end
	end	
end