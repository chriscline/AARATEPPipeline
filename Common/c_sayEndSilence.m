function c_sayEndSilence()

global sayNestLevel;
global saySilenceLevel;
global saySilenceStack;

if ~isempty(saySilenceStack)
	saySilenceLevel = saySilenceStack(end);
	saySilenceStack(end) = [];
else
	saySilenceLevel = [];
end
end
	
	