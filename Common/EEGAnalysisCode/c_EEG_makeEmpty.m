function EEG = c_EEG_makeEmpty(EEG)
% remove all time-specific data from EEG struct
% 
% To be used, for example, in cases where selecting a subset of epochs / time periods actually results in an empty dataset
% (since pop_select returns an error in these cases)

fieldsToClear = {'xmin','xmax','times','data','event','epoch'};

for iF = 1:length(fieldsToClear)
	if isfield(EEG,fieldsToClear{iF})
		if isstruct(EEG.(fieldsToClear{iF}))
			EEG.(fieldsToClear{iF}) = struct();
		else
			EEG.(fieldsToClear{iF}) = [];
		end
	end
end

EEG.trials = 0;
EEG.pnts = 0;

end