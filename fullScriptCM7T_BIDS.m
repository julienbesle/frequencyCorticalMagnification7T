% This script analyses the data provided in OpenNeuro dataset https://openneuro.org/datasets/ds008460 (Frequency Cortical Magnification in Human Auditory Cortex at 7 Tesla)
% to replicate the analyses described in Gurer et al. (2026) https://doi.org/10.64898/2026.06.17.732895
%
% The script performs:
%   - a number of pre-processing steps, using various processing tools (PSIR processing, surface reconstruction). This is disabled by default because the pre-processed data are already provided (see below)
%   - the main subject-level fMRI analysis, using mrTools
%
% The data provided in the BIDS dataset have already been pre-processed (see details in details in Besle et al. (2019) https://doi.org/10.1093/cercor/bhy267), including:
%     - importing from scanner and conversion to NIFTI format (ptoa)
%     - correction for dynamic distortions
%     - non-linear (FNIRT) and linear (mrAlign) alignmnents
%     - motion-compensation (mrTools)
%     - applying the FNIRT warp coefficients to the motion-compensated functional scans
%     - reconstructing high-resolution cortical surfaces using Freesurfer 7.2 for subjects 1-12 and 7.4 for subjects 13-20
%
% Pre-requisites:
%  - mrTools should be cloned from https://github.com/julienbesle/mrTools and added to the Matlab path
%
% Author: Julien Besle
% Date: July-August 2026

clearvars
tscript = tic;
addpath(genpath(fileparts(mfilename('fullpath')))); % add the folder containing this script, as well as all its subfolders to the path

bidsPath = 'C:\Users\julien\data\CM7T_OpenNeuro_ds008460'; % set this to the BIDS folder downloaded from OpenNeuro
derivativePath =  fullfile(bidsPath,'derivatives'); % where analysis results will be written
cmDataFolder = fullfile(derivativePath,'Matlab'); % where the final mrTools outcomes will be saved for further analysis using custom Matlab functions
cmFiguresFolder = fullfile(derivativePath,'Figures','3D Mesh ROI gradient figures');
mapsFolder = fullfile(derivativePath,'Figures','Flat map figures for Figure 2 supplement 1-2');
cmFile = fullfile(cmDataFolder,'corticalMagnificationDataSurf.mat'); % file where CM data will be saved
cmFileMax = fullfile(cmDataFolder,'corticalMagnificationDataMaxSurf.mat'); % file where CM data will be saved
gaussianFitsFile = fullfile(cmDataFolder,'gaussianFitDataSurf.mat'); % file where gaussian Fits will be saved

initializeScriptCM7T_BIDS; % sets mrTools defaults and a number of participant-specific variables

% Preprocessing flags
processPSIR = false; % this is set to false because the processed PSIR images are provided with the dataset
runFreesurfer = false; % this is set to false because the surfaces are provided with the dataset
convertSurfaces = false; % this is set to false because the surfaces are already provided in surfRelax format
checkForSurfaceDefects = false; % this is set to false because the provided surfaces have already been checked

% subject-level fMRI analysis flags
noGUIstring = 'No GUI'; % set this to 'No GUI' to run the script without GUI, leave empty otherwise
noGUIstring = ''; % set this to 'No GUI' to run the script without GUI, leave empty otherwise
saveViewAndAnalyses = true; % set this to false to run the script without saving the mrLoadRet View and fMRI analysis results
recomputePSandTWoverlays = false; % force re-compute, even if overlays already exist
drawReversalROIs = true; % whether to draw the ROIs following the automatically identified tonotopic reversals. This should only be set to true if PF overlays with smoothing = 4 have been computed (although I really should have used the unsmoothed map, since the reversal detection algorithm smoothes the maps anyway)
recomputeSurfaceGradientROIS = false; % reconvert flat volume ROIs (based on reversals) to surface coordinates even if they already exist (drawReversalROIs should also be true)
plotFlatMapsAndROIs = true; % plot preferred frequency and tuning width maps of both hemispheres of all 20 participants (Figure 2 supplement 1-2)
plotCMSurfaceFigures = true; % plots and saves a 3D mesh view of each gradient ROI with identified reversal vertices (As in Fig. 3A-C)
CMmethodDepiction = 'none';  % what cortical magnification method illustration to add to the 3D mesh plot. Options are 'none','gradient' (Figure 3A), 'vertex number', 'surface' (Figure 3B) and 'distance' (Figure 3C). Note that this is run only once per participant/ROI, so script needs to be run multiple times (or modified) to produce the three types of illustrations (Left posterior gradient of sub-01 in Fig. 3)
recomputeCM = false; % if true, recompute CM even if it already exists in the saved CM data
exportCMdata = true; % export the cortical magnification data for plotting and statistical group analysis 
saveROIgaussianFits = false; % saves the full frequency tuning curves Gaussian fits at each vertex

% create folders/load previously saved data
if ~exist(derivativePath,'dir')
  mkdir(derivativePath);
end
if exportCMdata && ~exist(cmDataFolder,'dir')
  mkdir(cmDataFolder)
end

% Analysis scripts
subjectsToProcess = 1:nSubjects;

A_preProcessing_CM7T

B_subject_level_fMRI_analysis_CM7T

% Group analysis scripts to come...

% Figure scripts to come ....