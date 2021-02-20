function c_sayStartSilence(offset)

if nargin == 0
	offset = 0;
end

global sayNestLevel;
global saySilenceLevel;
global saySilenceStack;

saySilenceStack = [saySilenceStack saySilenceLevel];

saySilenceLevel = sayNestLevel + offset;

end
	
	