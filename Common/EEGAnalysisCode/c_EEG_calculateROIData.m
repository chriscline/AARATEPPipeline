function [roiData, EEG, ROISrc] = c_EEG_calculateROIData(varargin)
	p = inputParser();
	p.addRequired('EEG',@isstruct);
	p.addParameter('srcKernel', [], @ismatrix); % if empty, try to pull from EEG.src.kernel
	p.addParameter('srcSurf', [], @c_mesh_isValid); % if empty, try to pull from EEG.src.meshCortex
	p.addParameter('srcData',[], @isnumeric); % if empty, calculate from srcKernel*EEG.data
	p.addParameter('ROIs',[],@(x) isstruct(x) || isempty(x)); % if empty, try to pull from EEG.src.ROIs
	p.addParameter('timeIndices',[],@(x) islogical(x) && isvector(x)); % for calculating only a subset of data (to minimize memory demands)
	p.addParameter('fn','mean',@ischar); % function for combining points within ROI
	p.addParameter('RAMLimit',32,@isscalar); % in GB
	p.addParameter('doMinimizeMemUse',true,@islogical);
	p.parse(varargin{:});
	s = p.Results;
	
	EEG = s.EEG;
	
	if nargout > 1
		assert(all(ismember({'srcKernel', 'srcSurf', 'srcData'}, p.UsingDefaults)));
		% behavior would not be well defined if saving output EEG and ROISrc when
		% prespecifying srcKernel/srcSurf/srcData
	end
	
	if isempty(s.srcSurf)
		assert(c_isFieldAndNonEmpty(EEG, 'src.meshCortex'));
		s.srcSurf = EEG.src.meshCortex;
	end
	
	if isempty(s.srcData)
		if c_isFieldAndNonEmpty(EEG, 'src.data')
			s.srcData = EEG.src.data;
		elseif isempty(s.srcKernel)
			assert(c_isFieldAndNonEmpty(EEG, 'src.kernel'));
			s.srcKernel = EEG.src.kernel;
		end
	end

	assert(~isempty(s.srcSurf) && (~isempty(s.srcData) || ~isempty(s.srcKernel)));
	
	if isempty(s.ROIs)
		ROIs = EEG.src.ROIs;
	else
		ROIs = s.ROIs;
	end
	
	numROIs = length(ROIs);
	
	if isempty(s.timeIndices)
		s.timeIndices = true(1,EEG.pnts);
	else
		assert(length(s.timeIndices)==EEG.pnts);
	end
	
	doUseSparseMatrix = false;
	if isempty(s.srcData) || nargout >= 3
		doUseSparseMatrix = s.doMinimizeMemUse || nargout >= 3;
		c_say('No source data found, calculating from sensor data');
		if ~doUseSparseMatrix
			EEG.src.data = nan([size(s.srcKernel,1),c_size(EEG.data,[2 3])]);
			EEG.src.data(:,s.timeIndices,:) = c_EEG_applySrcKernel(EEG,EEG.data(:,s.timeIndices,:), 'srcKernel', s.srcKernel);
			s.srcData = EEG.src.data;
		else
			% optimization to only compute dipoles that are needed in specified ROIs (could be a small subset of entire data)
			tmp = {ROIs.Vertices};
			ROISrc.Vertices = c_union(tmp{:});
			RAMNeeded = length(ROISrc.Vertices)*(sum(s.timeIndices)*EEG.trials)*4/1e9; % approx RAM in GB needed for this operation
			if RAMNeeded > s.RAMLimit
				if RAMNeeded / numROIs < s.RAMLimit
					% calculate individual dipole data and then mean (or other fn) for each ROI separately to conserve memory
					% (this will be slower)
					roiData = nan(numROIs,sum(s.timeIndices),EEG.trials);
					prog = c_progress(numROIs,'ROI %d/%d','waitToPrint',10);
					prog.start('Calculating srcs separately for each ROI due to memory constraints');
					for iR = 1:numROIs
						prog.updateStart(iR);
						%c_sayStartSilence();
						roiData(iR,:,:) = c_EEG_calculateROIData(EEG,varargin{2:end},'ROIs',ROIs(iR),'timeIndices',s.timeIndices);
						%c_sayEndSilence();
						prog.updateEnd();
					end
					prog.stop();
				else
					% still too large even if just one ROI. So split up into time chunks
					assert(all(s.timeIndices)); % for simplicity, require that we were not already splitting into time chunks
					numTimesPerChunk = ceil(EEG.pnts*s.RAMLimit*0.9/RAMNeeded); % make RAM limit slightly smaller to avoid going over limit in recursive call
					numChunks = ceil(EEG.pnts/numTimesPerChunk);
					roiData = nan(numROIs,EEG.pnts,EEG.trials);
					prog = c_progress(numChunks,'Chunk %d/%d','waitToPrint',10);
					prog.start('Calculating srcs in time chunks due to memory constraints');
					for iC = 1:numChunks
						prog.updateStart(iC);
						timeIndices = false(1,EEG.pnts);
						timeIndices((iC-1)*numTimesPerChunk+1 : min(iC*numTimesPerChunk,EEG.pnts)) = true;
						roiData(:,timeIndices,:) = c_EEG_calculateROIData(EEG,varargin{2:end},'timeIndices',timeIndices);
						prog.updateEnd();
					end
					prog.stop();
				end
				if nargout >= 2
					EEG.src.ROIData = nan(numROIs,EEG.pnts,EEG.trials);
					EEG.src.ROIData(:,s.timeIndices,:) = roiData;
				end
				ROISrc = [];
				return;
			else
				ROISrc.data = c_EEG_applySrcKernel(EEG,EEG.data(:,s.timeIndices,:),'SOI',ROISrc.Vertices, 'srcKernel', s.srcKernel);
			end
		end
		c_sayDone();
	end
	
	
	% collapse extra dimensions
	if ~doUseSparseMatrix
		assert(all(s.timeIndices),'Subset of times not currently supported when not using sparse matrix');
		origSize = size(s.srcData);
		s.srcData = reshape(s.srcData,[origSize(1) prod(origSize(2:end))]);
	else
		origSize = size(ROISrc.data);
		ROISrc.data = reshape(ROISrc.data,[origSize(1) prod(origSize(2:end))]);
	end
	
	switch(s.fn)
		case 'mean'
			roiData = nan(numROIs,prod(origSize(2:end)));
			for r=1:numROIs
				if ~doUseSparseMatrix
					memberIndices = ROIs(r).Vertices;
					roiData(r,:) = mean(s.srcData(memberIndices,:),1);
				else
					memberIndices = ROIs(r).Vertices;
					roiData(r,:) = mean(ROISrc.data(ismember(ROISrc.Vertices,memberIndices),:),1);
				end
			end
			
		%TODO: try using BST function that corrects orientations instead
		otherwise
			error('unsupported: %s',s.fn);
	end	
	
	% restore extra dimensions
	roiData = reshape(roiData,[numROIs, origSize(2:end)]);
	
	if nargout >= 2	
		EEG.src.ROIData = roiData;
	end
	
	if nargout >= 3
		% allow optional output of individual source data calculated only within ROIs
		assert(all(s.timeIndices),'outputing ROISrc not supported for subset of times');
		ROISrc.data = reshape(ROISrc.data,origSize);
	end
end