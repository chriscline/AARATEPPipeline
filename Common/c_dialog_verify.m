function resp = c_dialog_verify(varargin)
% c_dialog_verify - Show a dialog with a yes/no true/false response
% 
% Example:
%	if c_dialog_verify('Continue?')
%		c_saySingle('Continued')
%	end

	p = inputParser();
	p.addOptional('msg','Are you sure?',@ischar);
	p.addParameter('defaultAnswer','No',@ischar);
	p.parse(varargin{:});
	s = p.Results;
	
	% change default answer case to match as needed
	if strcmp(s.defaultAnswer,'no')
		s.defaultAnswer = 'No';
	elseif strcmp(s.defaultAnswer,'yes')
		s.defaultAnswer = 'Yes';
	end
	
	c_say('Waiting for user input: %s',s.msg);
	resp = questdlg(s.msg,s.msg,'Yes','No',s.defaultAnswer);
	c_sayDone();
	
	if isempty(resp)
		error('Dialog cancelled by user');
	end
	
	if strcmp(resp,'Yes')
		resp = true;
	else
		resp = false;
	end
end