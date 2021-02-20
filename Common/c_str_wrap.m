function str = c_str_wrap(varargin)
if nargin==0, testfn(); return; end;
p = inputParser();
p.addRequired('str',@(x) ischar(x) || iscellstr(x));
p.addParameter('toLength',inf,@isscalar);
p.addParameter('doPreferWrapBetweenWords',true,@islogical);
p.addParameter('nonSpaceDelimiters',{',','-','.',';'});
p.parse(varargin{:});
s = p.Results;

if iscellstr(s.str)
	str = cellfun(@(str) c_str_wrap(str,varargin{2:end}),s.str,'UniformOutput',false);
	return;
end

strLines = strsplit(s.str,'\n');

lineCounter = 0;

while lineCounter < length(strLines)
	lineCounter = lineCounter+1;
	strLine = strLines{lineCounter};
	if length(strLine) > s.toLength
		
		strToKeep = strLine(1:s.toLength);
		if s.doPreferWrapBetweenWords
			indices = isspace(strToKeep) | ismember(strToKeep,s.nonSpaceDelimiters);
			index = find(indices,1,'last');
			if isempty(index) || all(indices(1:index))
				index = length(strToKeep)+1;
			end
			strToKeep = strLine(1:index-1);
		end
		
		strToPush = strLine(length(strToKeep)+1:end);
		strLines{lineCounter} = strtrim(strToKeep);
		strLines = [strLines(1:lineCounter), strToPush, strLines(lineCounter+1:end)];
	end
end

str = strjoin(strLines,'\n');

end




function testfn()

%testStr = '1234567890abcdefghijABCDEFGHIJ';
% testStr = sprintf('12345\n67890abcdefghijABCDEFGHIJ');
testStr = sprintf('12345\n5678 abcd efg hijklmnopqrstuv');	    

wrappedStr = c_str_wrap(testStr,'toLength',10);

c_say('Starting string:');
c_saySingleMultiline('%s',testStr');
c_sayDone();
c_say('wrapped to:');
c_saySingleMultiline('%s',wrappedStr);
c_sayDone();

end


