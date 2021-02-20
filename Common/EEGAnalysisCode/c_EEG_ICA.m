function EEG = c_EEG_ICA(varargin)
p = inputParser;
p.addRequired('EEG',@isstruct);
p.addParameter('method','amica',@ischar);
p.addParameter('tempDir','',@ischar); % if empty will use tempname to generate
p.addParameter('sortMethod','none',@ischar); % 'none' for no sorting. 'auto' only applies a sort for methods that return unsorted weights (fastica)
p.parse(varargin{:});
s = p.Results;

persistent fastICAOnPath;
persistent amicaOnPath;

EEG = p.Results.EEG;

didReshape = false;
if length(size(EEG.data))>2
	originalSize = size(EEG.data);
	EEG.data = reshape(EEG.data,size(EEG.data,1),[]); % collapse later dimensions
	didReshape = true;
end

if isempty(s.tempDir), s.tempDir = tempname; end;
if ~exist(s.tempDir,'dir') mkdir(s.tempDir); end;

switch(s.method)
	case 'amica'
		if isempty(amicaOnPath) || ~amicaOnPath
			mfilepath=fileparts(which(mfilename));
			addpath(genpath(fullfile(mfilepath,'../ThirdParty/amica')));
			amicaOnPath = true;
		end
		c_say('Running amica');
		[weights, sphere, mods] = runamica15(EEG.data,...
			'outdir',[s.tempDir filesep 'amicaouttmp' filesep],...
			'max_threads',feature('numCores'));
		c_sayDone();
		
		EEG.icaweights = weights;
		EEG.icasphere = sphere(1:size(weights,1),:);
		EEG.icawinv = mods.A(:,:,1);
		EEG.mods = mods;
		EEG.icachansind = 1:EEG.nbchan;
		
	case 'fastica'
		if isempty(fastICAOnPath) || ~fastICAOnPath
			mfilepath=fileparts(which(mfilename));
			addpath(genpath(fullfile(mfilepath,'../ThirdParty/FastICA')));
			assert(exist('fastica.m','file')>0);
			fastICAOnPath = true;
		end
		c_say('Running FastICA');
		EEG = pop_runica(EEG,'icatype','fastica','approach','symm','g','tanh');
		c_sayDone();
		
	case 'runica'
		%TODO: check if binica available and if so use that instead of runica
		c_say('Running infomax ICA via runica');
		EEG = pop_runica(EEG,'icatype', 'runica', 'extended', 0, 'pca', EEG.nbchan - 1, 'interupt', 'off');
		c_sayDone();
	otherwise
		error('invalid method');
end

if strcmpi(s.sortMethod,'auto')
	switch(s.method)
		case 'amica'
			s.sortMethod = 'none';
		case 'fastica'
			s.sortMethod = 'pvaf';
		otherwise
			error('invalid method');
	end
end
switch(s.sortMethod)
	case 'pvaf'
		keyboard %TODO: call eeg_pvaf() to get sort metric
	case 'spatial'
		keyboard %TODO: sort by center of gravity of component topo
	case 'none'
		% do nothing
	otherwise
		error('invalid sort method');
end

if didReshape
	EEG.data = reshape(EEG.data,originalSize);
end

end
