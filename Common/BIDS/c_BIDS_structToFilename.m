function filename = c_BIDS_structToFilename(p, varargin)
% assumes input format similar to output of c_BID_parseFilename

ip = inputParser();
ip.addRequired('p',@isstruct);
ip.addParameter('type','',@ischar);
ip.addParameter('ext','',@ischar);
ip.addParameter('ignoreFields',{},@iscellstr);
ip.addParameter('replaceSpacesInValuesWith', '-', @ischar);  % set to ' ' to not replace spaces
															 % note that this it is not BIDS standard to have hyphens in values
ip.parse(p, varargin{:});
s = ip.Results;

if ~ismember('type',ip.UsingDefaults)
	s.p.type = s.type;
end

if ~ismember('ext',ip.UsingDefaults)
	s.p.ext = s.ext;
end

if ~isempty(s.ignoreFields)
	s.ignoreFields = intersect(s.ignoreFields, fieldnames(s.p));
	if ~isempty(s.ignoreFields)
		s.p = rmfield(s.p, s.ignoreFields);
	end
end

filename = '';

fields = fieldnames(s.p);
for iF = 1:length(fields)
	key = fields{iF};
	if ismember(key,{'filename','type','ext'})
		continue % skip
	end
	value = s.p.(key);
	if ~ischar(value)
		if isnumeric(value) && isscalar(value)
			value = num2str(value);
			if ~c_str_matchRegex(value, '^[0-9]*$')
				error('Only strings or scalar non-negative integer values supported')
			end
		elseif islogical(value) && isscalar(value)
			if value
				value = 'true';
			else
				value = 'false';
			end
		else
			error('Only strings or scalar non-negative integer values supported')
		end
	else
		value = strrep(value, ' ', s.replaceSpacesInValuesWith); 
	end
	assert(~contains(key,'-'),'Hyphens not allow in key');
	filename = [filename '_' key '-' value];
end

if c_isFieldAndNonEmpty(s.p,'type')
	filename = [filename '_' s.p.type];
end

filename = filename(2:end); % remove leading underscore

assert(~contains(filename,'.'),'Filename without ext should not include ''.''');

if c_isFieldAndNonEmpty(s.p,'ext')
	assert(s.p.ext(1)=='.','Extension should include leading ''.''');
	filename = [filename s.p.ext];
end

if ~isequal(s.replaceSpacesInValuesWith, ' ')
	assert(~contains(filename,' '),'Spaces not allowed in filename');
end

end