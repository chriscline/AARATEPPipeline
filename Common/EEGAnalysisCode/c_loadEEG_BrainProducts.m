function EEG = c_loadEEG_BrainProducts(datPath, hdrFilename)

if nargin == 1
	% assume single input is full path to hdr file
	[datPath, hdrFilename, ext] = fileparts(datPath);
	hdrFilename = [hdrFilename ext];
end

if 0
	EEG = pop_loadbv(datPath, hdrFilename);
else
	% wrap command in evalc to suppress text output
	[strOutput, EEG] = evalc('pop_loadbv(datPath,hdrFilename)');
	% remove specific messages that seem to always be printed
	strOutput = strrep(strOutput,...
		'pop_loadbv(): reading header file',...
		'');
	strOutput = strrep(strOutput,...
		'pop_loadbv(): reading EEG data',...
		'');
	strOutput = strrep(strOutput,...
		'pop_loadbv(): scaling EEG data',...
		'');
	strOutput = strrep(strOutput,...
		'pop_loadbv(): reading marker file',...
		'');
	% print anything that still remains
	strOutput = strtrim(strOutput);
	if ~isempty(strOutput)
		disp(strOutput);
	end
end