function h = c_EEG_plotERPImage(varargin)
p = inputParser();
p.addRequired('EEG',@isstruct);
p.addParameter('data',[],@isnumeric);
p.addParameter('COI','',@(x) isvector(x) || ischar(x) || iscellstr(x));
p.addParameter('epochIndices',[],@islogical);
p.addParameter('doGroupByEpochGroup','auto',@islogical);
p.addParameter('plotSubsetOfGroups',{},@(x) iscellstr(x) || isnumeric(x) || islogical(x));
p.addParameter('axis',[],@isgraphics);
p.addParameter('smoothWidth',1,@isscalar);
p.addParameter('clim','auto',@(x) c_isSpan(x) || (ischar(x) && ismember(x, {'auto', 'autoPos'})));
p.addParameter('plotMethod','auto',@ischar);
p.addParameter('YDir','reverse',@(x) ismember(x,{'normal','reverse'}));
p.parse(varargin{:});
s = p.Results;

EEG = s.EEG;

assert(c_EEG_isEpoched(EEG));

if strcmpi(s.plotMethod,'auto')
	%if isempty(s.axis)
	%	s.plotMethod = 'erpimage';
	%else
		s.plotMethod = 'imagesc';
	%end
end

prevAxis = [];
if isempty(s.axis)
	s.axis = gca;
else
	if strcmpi(s.plotMethod,'erpimage')
		warning('EEGLab erpimage deletes axis before replotting');
		prevAxis = gca;
		axes(s.axis);
	end
end

if strcmpi(s.doGroupByEpochGroup,'auto')
	s.doGroupByEpochGroup = isempty(s.epochIndices) && c_isFieldAndNonEmpty(EEG,'epochGroups');
elseif s.doGroupByEpochGroup
	assert(isempty(s.epochIndices));
end

if ~s.doGroupByEpochGroup
	assert(isempty(s.plotSubsetOfGroups),'Group subset not supported when not grouping by epoch groups');
end

if ~isempty(s.data)
	data = s.data;
else
	data = EEG.data;
end

if isempty(s.COI)
	s.COI = 1;
	if size(data,1) > 1
		warning('No COI specified. Using first channel by default');
	end
end

if iscellstr(s.COI) || ischar(s.COI)
	chanIndex = c_EEG_getChannelIndex(EEG,s.COI);
else
	chanIndex = s.COI;
end
assert(isscalar(chanIndex)); % could average multiple channels, but for now assume one channel
data = data(chanIndex,:,:);


if strcmpi(s.clim,'auto')
	s.clim = [-1 1]*max(abs(extrema(data(:))));
elseif strcmpi(s.clim, 'autoPos')
	s.clim = [0 max(data(:))];
end

if s.doGroupByEpochGroup
	assert(s.smoothWidth==1,'Smoothing not currently supported when grouping by epoch groups');
	
	if ~isempty(s.plotSubsetOfGroups)
		if iscellstr(s.plotSubsetOfGroups)
			assert(all(ismember(s.plotSubsetOfGroups,EEG.epochGroupLabels)));
			groupIndices = c_cell_findMatchingIndices(s.plotSubsetOfGroups,EEG.epochGroupLabels);
		else
			groupIndices = s.plotSubsetOfGroups;
		end
		EEG.epochGroups = EEG.epochGroups(groupIndices);
		EEG.epochGroupLabels = EEG.epochGroupLabels(groupIndices);
	end
		
	numGroups = length(EEG.epochGroups);
	dataForGroup = cell(1,numGroups);
	for iG = 1:numGroups
		dataForGroup{iG} = data(:,:,EEG.epochGroups{iG});
	end
	numBlankTrialsBetweenGroups = max(ceil(min(EEG.trials/50/10,EEG.trials/numGroups/3)),1)
	groupedData = nan(size(data,1),size(data,2),sum(cellfun(@(x) size(x,3),dataForGroup))+numBlankTrialsBetweenGroups*(numGroups-1));
	blankEpochIndices = false(1,size(groupedData,3));
	groupCenterNumbers = nan(1,numGroups);
	numEpochs = 0;
	for iG = 1:numGroups
		numEpochsInGroup = size(dataForGroup{iG},3);
		groupedData(:,:,numEpochs+(1:numEpochsInGroup)) = dataForGroup{iG};
		groupCenterNumbers(iG)= numEpochs + 1 + floor(numEpochsInGroup/2);
		numEpochs = numEpochs + numEpochsInGroup;
		if iG ~= numGroups
			blankEpochIndices(numEpochs + (1:numBlankTrialsBetweenGroups)) = true;
			numEpochs = numEpochs + numBlankTrialsBetweenGroups;
		end
	end
	data = groupedData;
else
	if ~isempty(s.epochIndices)
		data = data(:, :, s.epochIndices);
	end
end


switch(s.plotMethod)
	case 'erpimage'
		
		assert(ismember('YDir',p.UsingDefaults));
		
		%TODO: wrap in eval to suppress output
		erpimage(data,...	% data
			[],...			% sortvar
			EEG.times,...	% times
			upper(s.COI),... % title
			s.smoothWidth,...
			1,...			% decimate (1=no decimation)
			'limits',[nan nan s.clim nan nan nan nan],...
			'caxis',s.clim,...
			'erp','off',...
			'cbar','off'...
		);
	
		assert(nargout==0); % returning h not supported for erpimage plotting
	
	case 'imagesc'
		
		assert(s.smoothWidth==1); % smoothing not currently supported in custom plotting
		
		x = EEG.times;
		y = 1:size(data,3);
		
		prevHold = ishold(s.axis);
		if ~prevHold
			cla(s.axis);
		end
		
		h = imagesc('XData',x,'YData',y,'CData',squeeze(data)',...
			'parent',s.axis);
		s.axis.YDir = s.YDir;
		xlim(s.axis,c_limits_multiply(extrema(x),size(data,2)/(size(data,2)-1)))
		ylim(s.axis,c_limits_multiply(extrema(y),size(data,3)/(size(data,3)-1)))
		xlabel(s.axis,'Time (ms)');
		ylabel(s.axis,'Trials');
		caxis(s.axis,s.clim);
		
		
		hold(s.axis,'on');
		h(2) = line([0 0],extrema(y)+[-1 1]/2,'Color',[0 0 0],'LineWidth',2,'Parent',s.axis);
		if ~prevHold
			hold(s.axis,'off');
		end
	otherwise
		error('Unsupported plotMethod: %s',s.plotMethod);
end

if s.doGroupByEpochGroup
	if ismember(s.plotMethod,{'erpimage'})
		hf = gcf;
		ha = hf.Children(2); %TODO: dynamically find correct axis rather than hardcoding
		ha.YDir = s.YDir;
		himg = ha.Children(2);
	else
		ha = s.axis;
		himg = h(1);
	end
	ha.YTick = groupCenterNumbers;
	ha.YTickLabel = c_str_truncate(EEG.epochGroupLabels,'toLength',20);
	
	himg.AlphaData = repmat(~blankEpochIndices',[1 EEG.pnts]); % make borders between groups transparent
end

if ~isempty(prevAxis)
	axes(prevAxis);
end

end