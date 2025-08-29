function p = c_BIDS_parseFilename(varargin)
% adapted from https://github.com/bids-standard/bids-matlab/blob/master/%2Bbids/private/parse_filename.m
%
% Modified to allow hyphenated values 
% (e.g. key-long-value gets set to key: 'long-value' instead of key: 'long'
%
% Modified to only extract a "type" if there is an item after an underscore without a corresponding key
%
% Modified to group all underscored items without keys as a single type
% (e.g. key1-value1_key2-value2_a_very_long_type results in type: 'a_very_long_type' instead of splitting into empty keys

ip = inputParser();
ip.addRequired('filename',@ischar);
ip.addParameter('tryToConvertNumericValues', false, @islogical);
ip.addParameter('doMinimalOutput', false, @islogical);  % if true, will omit type if empty, ext if empty, and filename
ip.addParameter('doBracketMatching', true, @islogical);
ip.addParameter('doAllowSpaces', false, @islogical);  % if allowed, will be passed unmodified (i.e. not treated as a delimiter)
ip.parse(varargin{:});
s = ip.Results;

% strip out any parent directories (i.e. convert path to filename)
[~,filename, ext] = fileparts(s.filename);
s.filename = [filename ext]; % re-add extension


if ~s.doAllowSpaces
	assert(~contains(s.filename,' '),sprintf('Spaces not allowed in BIDS filenames (%s)', ip.Results.filename));
end

[parts, dummy] = regexp(s.filename,'(?:_)+','split','match');


if s.doBracketMatching && any(ismember('()[]{}<>', s.filename))
	% merge any parts that are within balanced brackets
	startingSymbols = '([{<';
	endingSymbols = ')]}>';
	unbalancedStack = struct('startSymbol', {}, 'iPart', {});
	mergeBetweenParts = {};
	for iP = 1:length(parts)
		part = parts{iP};
		for iC = 1:length(part)
			if ismember(part(iC), startingSymbols)
				unbalancedStack(end+1) = struct('startSymbol', part(iC), 'iPart', iP);
			elseif ismember(part(iC), endingSymbols)
				if isempty(unbalancedStack) || ~any((ismember(startingSymbols, unbalancedStack(end).startSymbol) & ismember(endingSymbols, part(iC))))
					error('Unmatched bracket in %s', s.filename);
				else
					if length(unbalancedStack) > 1
						% don't actually do this merge, because we should find another superceding match to merge later
					else
						mergeBetweenParts{end+1} = [unbalancedStack(end).iPart, iP];
					end
					unbalancedStack(end) = [];
				end
			end				
		end
	end
	
	if ~isempty(unbalancedStack)
		error('Unmatched bracket in %s', s.filename);
	end
	if ~isempty(mergeBetweenParts)
		for iM = length(mergeBetweenParts):-1:1
			parts{mergeBetweenParts{iM}(1)} = strjoin(parts(mergeBetweenParts{iM}(1):mergeBetweenParts{iM}(2)), '_');
			parts(mergeBetweenParts{iM}(1)+1:mergeBetweenParts{iM}(2)) = [];
		end
	end
end

[parts{end}, p.ext] = strtok(parts{end},'.');
if ~s.doMinimalOutput
	p.filename = s.filename;
	p.type = '';
else
	if isempty(p.ext)
		p = rmfield(p, 'ext');
	end
end
for i=1:numel(parts)
	[key, value] = strtok(parts{i},'-');
	if isempty(value)
		p.type = strjoin(parts(i:end),'_');
		break;
	else
		assert(~strcmp(key,'type'),'Key ''type'' not allowed'); % could be allowed, but currently would override any type value
		p.(key) = value(2:end);
		
		if s.tryToConvertNumericValues
			tmp = str2double(p.(key));
			if ~isnan(tmp)
				p.(key) = tmp;
			end
		end
		
	end
end
end