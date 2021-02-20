function hasAuxData = c_EEG_hasAuxData(EEG)
	hasAuxData = c_isFieldAndNonEmpty(EEG,'auxData');
end