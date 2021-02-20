function traceColors = c_EEG_getButterflyTraceColors(EEG,varargin)
p = inputParser();
p.addParameter('seedColors',[0 0 1], @ismatrix);
p.addParameter('XYZ', [], @ismatrix); % if not specified, will be taken from EEG.chanlocs
p.addParameter('luminanceSpan', 'auto', @(x) (ischar(x) && ismember(x, {'auto', 'none'})) || c_isSpan(x));
p.addParameter('doPlot', false, @islogical);
p.parse(varargin{:});
s = p.Results;


% use single common color, but fade from dark to light going from anterior to posterior electrodes

if isempty(s.XYZ)
	s.XYZ = c_struct_mapToArray(EEG.chanlocs, {'X', 'Y', 'Z'});
else
	assert(size(s.XYZ,2)==3);
end
numChan = size(s.XYZ, 1);

if ~isequal(s.luminanceSpan, 'none')
	if isvector(s.seedColors)

		tmp = rgb2ntsc(s.seedColors/2);
		tmp = repmat(tmp,numChan,1);
		if isequal(s.luminanceSpan, 'auto')
			s.luminanceSpan = [-0.3 0.5];
		end
		tmp(:,1) = linspace(s.luminanceSpan(1), s.luminanceSpan(2), numChan);
		tmp = ntsc2rgb(tmp);

		[~,sortOrder] = sort(s.XYZ(:,1),'descend');

		traceColors(sortOrder,:) = tmp;
	else
		% assume seedColor is two colors to vary along left/right axis
		assert(ismember(size(s.seedColors, 1), [2 3]));
		assert(size(s.seedColors, 2) == 3);

		tmp = rgb2ntsc(s.seedColors/2);

		traceColors = nan(size(s.XYZ));

		if isequal(s.luminanceSpan, 'auto')
			s.luminanceSpan = [0.1 0.8];
		end

		luminanceVals = linspace(s.luminanceSpan(1), s.luminanceSpan(2), numChan);
		[~, sortOrder] = sort(s.XYZ(:, 1), 'descend');
		traceColors(sortOrder, 1) = luminanceVals;

		[~, sortOrder] = sort(s.XYZ(:, 2), 'descend');
		if size(s.seedColors,1)==2
			% blend between two color extremes left to right
			IQWeights = linspace(0, 1, numChan)';
			traceColors(sortOrder, 2:3) = tmp(2,2:3).*IQWeights + tmp(1, 2:3).*(1-IQWeights);
		elseif size(s.seedColors,1)==3
			% blend between three color extremes from left to center to right
			numFirstHalf = floor(numChan/2);
			IQWeights = linspace(0, 1, numFirstHalf)'.^(1.5);
			traceColors(sortOrder(1:numFirstHalf), 2:3) = tmp(2,2:3).*IQWeights + tmp(1, 2:3).*(1-IQWeights);
			numSecondHalf = numChan - numFirstHalf;
			IQWeights = (1-(1-linspace(0, 1, numSecondHalf)').^1.5);
			traceColors(sortOrder(end-numSecondHalf+1:end), 2:3) = tmp(3,2:3).*IQWeights + tmp(2, 2:3).*(1-IQWeights);
		else
			error('Not implemented');
		end

		traceColors = ntsc2rgb(traceColors);
	end
	
else
	% vary color along x and y axes
	
	assert(ismember('seedColors', p.UsingDefaults), 'Seed colors not supported when not varying luminance');
	
	traceColors = ones(numChan, 3)*0.5;
	
	vals = linspace(-0.7, 0.7, numChan);
	[~, sortOrder] = sort(s.XYZ(:, 1), 'descend');
	traceColors(sortOrder, 2) = vals;
	[~, sortOrder] = sort(s.XYZ(:, 2), 'descend');
	traceColors(sortOrder, 3) = vals;
	
	traceColors = ntsc2rgb(traceColors);
end
	
if s.doPlot
	figure;
	topoplot(1:numChan, EEG.chanlocs,...
		'style', 'blank',...
		'emarkercolors', c_mat_sliceToCell(traceColors, 1),...
		'plotdisk', 'off')
end


if 0
	figure; topoplot(c_getOutputSubset(2,@() sort(sortOrder)),EEG.chanlocs);
	colormap(tmp)
	caxis([0 numChan])
	c_plot_colorSwatches(tmp,'labels',{EEG.chanlocs.labels})
end
end