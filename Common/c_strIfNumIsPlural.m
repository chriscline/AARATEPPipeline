function str = c_strIfNumIsPlural(varargin)
p = inputParser();
p.addRequired('num',@isscalar);
p.addOptional('strIfPlural','s',@ischar);
p.addParameter('elseStr','',@ischar);
p.parse(varargin{:});
s = p.Results;

if abs(s.num)~=1
	str = s.strIfPlural;
else
	str = s.elseStr;
end
end