function s = c_struct_getSubset(s, varargin)
	p = inputParser();
	p.addRequired('struct', @isstruct);
	p.addOptional('toKeep', {}, @iscellstr);
	p.addParameter('doReorder', false, @islogical);  % if true, will reorder to match 'toKeep' arg
	p.addParameter('fillMissing', '<errorOnMissing>');
	p.parse(s, varargin{:});
	is = p.Results;
	
	allFields = fieldnames(s);
	if strcmpi(is.fillMissing, '<errorOnMissing>')
		assert(all(ismember(is.toKeep,allFields)));
	else
		for iF = 1:length(is.toKeep)
			if ~isfield(s, is.toKeep{iF})
				s.(is.toKeep{iF}) = is.fillMissing;
			end
		end
	end
	s = rmfield(s, setdiff(allFields,is.toKeep));
	if is.doReorder
		s = orderfields(s, is.toKeep);
	end
end