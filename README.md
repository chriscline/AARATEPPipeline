# AARATEP Pipeline
This repo contains the code for the TMS-EEG preprocessing pipeline originally described in:

C.C. Cline, M.V. Lucas, Y. Sun, M. Menezes, A. Etkin. "Advanced Artifact Removal for Automated TMS-EEG Data Processing," 2021 10th International IEEE/EMBS Conference on Neural Engineering (NER), 2021, doi: [10.1109/NER49283.2021.9441147](https://doi.org/10.1109/NER49283.2021.9441147).

In brief, this pipeline consists of the following stages:
- Epoching
- Artifact interpolation (with custom autoregressive blending)
- Downsampling
- Baseline correction
- High-pass filtering
- Bad-channel identification
- Early eye-related IC rejection (added in v2.0.0)
- SOUND
- Decay component removal
- Artifact interpolation
- Line noise filtering
- ICA
- IC rejection with ICLabel and additional TMS-specific rejection rules
- Low-pass filtering
- Average rereferencing

## Usage
This code assumes you have `EEGLab` installed at `~/Documents/MATLAB/eeglab` on Windows or Mac, or `~/matlab/eeglab` on Linux. It also assumes you have installed the [ICLabel](https://sccn.ucsd.edu/wiki/ICLabel) and [TESA](https://nigelrogasch.github.io/TESA/) extensions in EEGLab.

Assuming you have downloaded this whole repo to a folder called `AARATEPPipeline`, add dependencies to your MATLAB path with

    addpath('AARATEPPipeline');
    addpath('AARATEPPipeline/Common');
    addpath('AARATEPPipeline/Common/EEGAnalysisCode');

Load your data as an EEGLab struct `EEG`. For example:

    [EEG, misc] = c_TMSEEG_prepareForPreprocessing(...
        'inputFilePath', 'MyStudy/rawdata/RecordingName.vhdr',...
        'epochTimespan', [-1 2]);

Then call the main preprocessing pipeline script:

    EEG = c_TMSEEG_Preprocess_AARATEPPipeline(EEG,...
        'pulseEvent', misc.pulseEvent,...
        'epochTimespan', misc.epochTimespan,...
        'outputDir', 'MyStudy/derivatives/RecordingName',...
        'outputFilePrefix', 'RecordingName')

See individual scripts for additional available parameters.
