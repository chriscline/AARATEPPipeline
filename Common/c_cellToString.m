function s = c_cellToString(c,varargin)
	if nargin == 0
		% test
		c_cellToString({'test',[1 2 3],'a1',{'test inner', 5}})
		return
	end
	
	doPreferMultiline = false;
	doQuoteStrings = true;
	precision = [];
	indentation = 0;
	
	if nargin > 1
		p = inputParser();
		p.addParameter('doPreferMultiline',doPreferMultiline,@islogical);
		p.addParameter('doQuoteStrings',doQuoteStrings,@islogical);
		p.addParameter('printLimit',[],@isscalar);
		p.addParameter('precision',precision,@isscalar);
		p.addParameter('indentation',indentation,@isscalar);
		p.parse(varargin{:});
		doPreferMultiline = p.Results.doPreferMultiline;
		doQuoteStrings = p.Results.doQuoteStrings;
		precision = p.Results.precision;
		indentation = p.Results.indentation;
	end

	assert(iscell(c));
	
	if isempty(c)
		s = '{}';
		return;
	end
	
	num2strArgs = {};
	if ~isempty(precision)
		num2strArgs = {precision};
	end
	
	s = '{';
	if doPreferMultiline
		s = [s sprintf('\t')];
	end
	assert(ndims(c)==2);
	for i=1:size(c,1)
		for j=1:size(c,2)
			if iscell(c{i,j})
				s = [s c_cellToString(c{i,j},varargin{:},'indentation',indentation+1) ','];
			elseif ischar(c{i,j})
				if doQuoteStrings
					s = [s '''' c{i,j} '''' ','];
				else
					s = [s c{i,j} ','];
				end
			else
				s = [s c_toString(c{i,j},varargin{:}) ','];
			end
		end
		s = s(1:end-1); % remove comma
		if i ~= size(c,1)
			s = [s ';'];
			if doPreferMultiline
				s = [s,sprintf('\n ')];
				for ii = 1:indentation
					s = [s,sprintf('\t')];
				end
			end
		end
	end
	s = [s '}'];
end