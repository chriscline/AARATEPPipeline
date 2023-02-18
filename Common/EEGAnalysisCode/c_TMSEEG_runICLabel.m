function [EEG, misc] = c_TMSEEG_runICLabel(varargin)
%
% Note: assumes ICA has already been run prior to calling this

p = inputParser();
p.addRequired('EEG', @isstruct);
p.addParameter('eyeComponentThreshold', 0.08, @isscalar);
p.addParameter('muscleComponentThreshold', 0.2, @isscalar);
p.addParameter('brainComponentThreshold', 0.3, @isscalar);
p.addParameter('otherComponentThreshold', NaN, @isscalar);
p.addParameter('doPlot', false, @islogical);
p.addParameter('doRejection', true, @islogical);
p.parse(varargin{:});
s = p.Results;
EEG = s.EEG;

misc = struct();

%%
c_say('Classifying ICs with ICLabel');
EEG = iclabel(EEG);
c_sayDone();

%%
scores = EEG.etc.ic_classification.ICLabel.classifications;
rejectComponents = false(size(scores, 1), 1);

if any(isnan(scores(:)))
	error('NaN in ICLabel classification scores. Problem with input data?')
end

if ~isnan(s.eyeComponentThreshold)
	iEye = c_cell_findMatchingIndices({'Eye'}, EEG.etc.ic_classification.ICLabel.classes);
	rejectComponents = rejectComponents | scores(:, iEye) > s.eyeComponentThreshold;
end

if ~isnan(s.muscleComponentThreshold)
	iMuscle = c_cell_findMatchingIndices({'Muscle'}, EEG.etc.ic_classification.ICLabel.classes);
	rejectComponents = rejectComponents | scores(:, iMuscle) > s.muscleComponentThreshold;
end

if ~isnan(s.otherComponentThreshold)
	iOther = c_cell_findMatchingIndices({'Other'}, EEG.etc.ic_classification.ICLabel.classes);
	rejectComponents = rejectComponents | scores(:, iOther) > s.otherComponentThreshold;
end

if ~isnan(s.brainComponentThreshold)
	iBrain = c_cell_findMatchingIndices({'Brain'}, EEG.etc.ic_classification.ICLabel.classes);
	rejectComponents = rejectComponents | scores(:, iBrain) < s.brainComponentThreshold; % note inverted test compared to other thresholds
end

if all(rejectComponents)
	% all components marked for rejection
	keyboard %TODO: decide how to handle this
end

misc.rejectComponents = rejectComponents;

EEG.reject.gcompreject = rejectComponents;

if s.doPlot
	%TODO: make sure to plot such that all components will fit in a single window
	pop_viewprops(EEG, 0, 1:size(EEG.icawinv, 2), {}, {}, 0, 'ICLabel');
	misc.hf = gcf;
end

if s.doRejection
	c_say('Rejecting %d/%d components', md.ICA_numRejComp, md.ICA_numComp);
	EEG = pop_subcomp(EEG, find(rejectComponents));
	c_sayDone();
end

end