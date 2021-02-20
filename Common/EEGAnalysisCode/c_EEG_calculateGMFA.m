function gmfa = c_EEG_calculateGMFA(EEG)
	if isstruct(EEG)
		data = EEG.data;
	else
		assert(isnumeric(EEG));
		data = EEG; 
	end
	
	gmfa = sqrt(mean(data.^2,1));
end