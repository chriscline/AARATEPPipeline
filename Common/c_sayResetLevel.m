function c_sayResetLevel()
% c_sayResetLevel - Reset nesting level of c_say* print statements
%
% See also: c_say

	global sayNestLevel;
	sayNestLevel = 0;
	global saySilenceLevel;
	saySilenceLevel = [];
	global saySilenceStack;
	saySilenceStack = [];
end