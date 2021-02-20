function str = c_str_truncate(varargin)
p = inputParser();
p.addRequired('str',@(x) ischar(x) || iscellstr(x));
p.addParameter('toLength',inf,@isscalar);
p.addParameter('truncationSuffix','...',@ischar);
p.addParameter('doPreferWordBoundaries',true,@islogical);
p.addParameter('nonSpaceDelimiters',{',','-','.',';'});
p.addParameter('countTabsAsXSpaces',4,@isscalar);
p.addParameter('byLine',false,@islogical);
p.parse(varargin{:});
s = p.Results;

if iscellstr(s.str)
	str = cellfun(@(str) c_str_truncate(str,varargin{2:end}),s.str,'UniformOutput',false);
	return;
end

strLength = @(str) lengthWithTabs(str,s.countTabsAsXSpaces);

if strLength(s.str)<=s.toLength
	str = s.str;
	return;
end

if s.byLine
	% truncate each line independently
	strLines = strsplit(s.str,'\n');
	if length(strLines) > 1
		str = c_str_truncate(strLines,varargin{2:end});
		str = strjoin(str,'\n');
		return
	end
end

if s.countTabsAsXSpaces > 1
	tabChar = sprintf('\t');
	tabIndices = s.str==tabChar;
	
	numericTabIndices = find(tabIndices);
	numTabs = length(numericTabIndices);
	
	tabIndicesInNew = false(1,length(s.str)+numTabs*(s.countTabsAsXSpaces-1));
	numericTabStartIndicesInNew = numericTabIndices + (0:numTabs-1)*(s.countTabsAsXSpaces-1);
	for iS = 0:s.countTabsAsXSpaces-1
		tabIndicesInNew(numericTabStartIndicesInNew+iS) = true;
	end
	
	newStr = strrep(s.str,tabChar,repmat(' ',1,s.countTabsAsXSpaces));
	assert(all(newStr(tabIndicesInNew)==' ')); %TODO: debug, delete
	
	s.str = newStr;
end
		

s.str = s.str(1:s.toLength-length(s.truncationSuffix));

if s.doPreferWordBoundaries
	indices = isspace(s.str) | ismember(s.str,s.nonSpaceDelimiters);
	index = find(indices,1,'last');
	if isempty(index)
		index = strLength(s.str)+1;
	end
	s.str = s.str(1:index-1);
end

if s.countTabsAsXSpaces > 1 && ~isempty(s.str)
	tabIndicesInNew = tabIndicesInNew(1:length(s.str));
	doesEndInTab = tabIndicesInNew(end);
	if doesEndInTab
		% handle partial tab cut-off
		numTrailingTabSpaces = find(tabIndicesInNew~=' ',1,'last');
		if isempty(numTrailingTabSpaces)
			numTrailingTabSpaces = length(s.str);
		end
		numToRemove = mod(numTrailingTabSpaces,s.countTabsAsXSpaces);
		s.str = s.str(1:end-numToRemove);
		tabIndicesInNew = tabIndicesInNew(1:end-numToRemove);
	end
	% re-convert all spaces that were originally tabs back to tabs
	numericTabIndicesInNew = find(tabIndicesInNew);
	numericTabStartIndicesInNew = numericTabIndicesInNew(1:s.countTabsAsXSpaces:end);
	s.str(numericTabStartIndicesInNew) = tabChar;
	s.str(~c_unfind(numericTabStartIndicesInNew,length(s.str)) & tabIndicesInNew) = [];
end

str = [s.str, s.truncationSuffix];
	

end

function len = lengthWithTabs(str,spacesPerTab)
	len = length(str) + (spacesPerTab-1)*sum(str==sprintf('\t'));
end