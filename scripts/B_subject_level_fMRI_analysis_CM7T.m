defaultOverwritePolicy = mrGetPref('Overwrite');
mrSetPref('overwritePolicy','Overwrite'); % this is set back to the default policy at the end of the script

% Subject-level fMRI analysis parameters
smoothingValues = [0 4 8 12 16 20]; % smoothing values in flat pixels (~0.33 mm)
smoothingIndices = 1:2; % which of the above smoothing value(s) to use
% smoothingIndices = []; % set this to empty to do all the initial analysis steps (up to GLM fitting and indexMax) across all participants without fitting Gaussians
frequencyScaleTypes = {'LOG','ERB','ERB','DLF','DLF'}; % frequency scales to use for estimation of preferred frequency and tuning width
frequencyScales = {'log','G&M90','O&S03','N83','M12'}; % frequency scales to use for estimation of preferred frequency and tuning width
scaleIndices = 1:5; % which of the above frequency scales to use
minFreqKHz = 0.02; % frequency range for PF estimation 
maxFreqKHz = 20;   %
maxFitTypes = 1; % if 1, fits Gaussian to smoothed tuning curves without re-centring, if 2, fits both without and with recentring (including cross-recentred). See plotMapTWtype setting below to further explanation.
plotMapSmoothingValue = 4; % level of smoothing for the flat map figures 
plotMapScale = 'G&M90'; % frequency scale for flat map figures
plotMapTWtype = 'Not recentred';  % what type of voxelwise frequency tuning width to plot (only applies if plotMapSmoothingLevel > 0)
                                  % options are: 'Not recentred', 'Recentred' or 'Cross-recentred'
                                  % "Not recentred": tuning curves are simply averaged across voxels within the Gaussian kernel
                                  % "Recentred": tuning curves are aligned according to their apparent centre frequency (max across frequencies)  (not reported in article)
                                  % "Cross-recentered": preferred frequency is computed on half of the data and tuning curves from the other half are recentred using the estimated preferred frequency (not reported in article)
computeCMonSurface = true; % if true, compute PF (and TW) after sampling all frequency responses on the surfaces within corticalMagnificationAuditory (including averaging across cortical depths).

nGradientROIs = 2; % posterior and anterior
nScales = length(frequencyScales);
nSmoothings = length(smoothingValues);

% load previously saved data
if exportCMdata && exist(cmFile,'file')
  cmData = load(cmFile);
else
  cmData.distanceBetweenReversals = nan(nGradientROIs,2,nSmoothings,nScales,nSubjects);
end
if saveROIgaussianFits && exist(gaussianFitsFile,'file')
  gFits = load(gaussianFitsFile);
end

% Main participant loop
for iSubj = subjectsToProcess

  fprintf("\n----------------------------------------------\n")
  fprintf("|   Processing fMRI for participant  %s  |\n",subject{iSubj})
  fprintf("----------------------------------------------\n\n")
  processThisSubject = true;
  
  % Source data for this participant
  bidsAnatPath = fullfile(bidsPath,subject{iSubj},'anat');
  bidsFuncPath = fullfile(bidsPath,subject{iSubj},'func');
  
  % Pre-processed PSIR volumes and Freesurfer surfaces for this participant
  psirBaseName = sprintf('sub-%02d_PSIR',iSubj);
  surfRelaxPath = fullfile(derivativePath,'surfRelax',subject{iSubj});
  processedPSIR = sprintf('%s_mprage_pp.nii',subject{iSubj});
  
  % Subject-level fMRI analysis
  mrToolsPath = fullfile(derivativePath,'mrTools',subject{iSubj});
  if ~exist(mrToolsPath,'dir')
    mkdir(mrToolsPath);
  end
  if ~exist(fullfile(mrToolsPath,'mrSession.mat'),'file') % Create mrTools folder structure
    makeEmptyMLRDir(mrToolsPath,'description=Cortical Magnification 7T',sprintf('subject=%s',subject{iSubj}),...
                    sprintf('operator=%s',operator{iSubj}),'defaultParams=1','defaultGroup=MotionComp','noPrompt=1');
  end
  mrToolsFuncPath = fullfile(mrToolsPath,'MotionComp','TSeries');
  mrToolsLogPath = fullfile(mrToolsPath,'Etc');
  funcFiles = dir(fullfile(bidsFuncPath,'*.nii.gz'));
  if isempty(dir(fullfile(mrToolsFuncPath,'*.nii.gz')))
    % copy data from BIDS func folder to MotionComp folder
    for iFile = 1:length(funcFiles)
      copyfile(fullfile(bidsFuncPath,funcFiles(iFile).name),mrToolsFuncPath)
    end
  end
  
  % Convert events files to mrTools format (.mylog.mat)
  if isempty(dir(fullfile(mrToolsLogPath,'*.mylog.mat')))
    eventFiles = dir(fullfile(bidsFuncPath,'*.tsv'));
    cd(mrToolsLogPath); % moving to the Etc folder because this is where converted log files will be written
    % convert to mrTools log file format, keeping only one event per scan, starting at the first stimulus in each train, until the end of the TR (just before the next fMRI acquisition)
    tsvToMylog([],fullfile(bidsFuncPath, {eventFiles.name}')',7500);
  end
  eventFiles = dir(fullfile(mrToolsLogPath,'*.mylog.mat'));

  if length(funcFiles)~=length(eventFiles)
    keyboard % different numbers of functional and events files
  end

  cd(mrToolsPath); % mrTools expect the current directory to be the subject's mrTools base folder
  
  % initialise mrTools structure
  if ~exist(fullfile(mrToolsPath,'mrLastView.mat'),'file') % mrLastView.mat is not created at this step, but if it exists, then mrLoadRet has run (and closed properly) at least once
    % Initialize mrLoadRet
    [sessionParams, groupParams] = mrInit([],[],'justGetParams=1','defaultParams=1');
    sessionParams.subject = subject{iSubj};
    nScans = length(groupParams.name);
    for iScan = 1:nScans
     groupParams.description{iScan} = ['Run ' num2str(iScan)];
    end
    mrInit(sessionParams,groupParams,'makeReadme=0','noPrompt=1');
  end
  
  % Open the structure in an mrLoadRet "View", without or without GUI
  thisView = mrLoadRet([],noGUIstring);
  
  %load base anatomies
  if isempty(viewGet(thisView,'baseNum','averageBOLD_run1'))  %load average of func run 1 as anatomy
    thisView = loadAnat(thisView,funcFiles(1).name,mrToolsFuncPath,0);
    thisView = viewSet(thisView,'baseName','averageBOLD_run1',viewGet(thisView,'baseNum',stripext(funcFiles(1).name))); % change to a better base name
  end
  if isempty(viewGet(thisView,'baseNum',stripext(processedPSIR)))  %load processed PSIR as anatomy
    thisView = loadAnat(thisView,processedPSIR,surfRelaxPath);
    thisView = viewSet(thisView,'basesliceindex',3); %set to axial view
    thisView = viewSet(thisView,'rotate',90);
  end
  %import surfaces
  importSurfParams.path = surfRelaxPath;
  for iSide=1:2
    if isempty(viewGet(thisView,'baseNum',[subject{iSubj} '_' sides{iSide} '_GM.off']))
      importSurfParams.outerSurface = [subject{iSubj} '_' sides{iSide} '_Inf.off']; % in order to view half-inflated surfaces, set the outer surface coordinates (outerCoords) to be the GM surface
      importSurfParams.outerCoords = [subject{iSubj} '_' sides{iSide} '_GM.off']; % and the outer surface (outerSurface) to be the inflated surface
      importSurfParams.innerSurface = [subject{iSubj} '_' sides{iSide} '_WM.off'];
      importSurfParams.innerCoords = [subject{iSubj} '_' sides{iSide} '_WM.off'];
      importSurfParams.anatomy = [subject{iSubj} '_mprage_pp.nii'];
      importSurfParams.curv = [subject{iSubj} '_' sides{iSide} '_Curv.vff'];
      base = importSurfaceOFF(importSurfParams);
      thisView = viewSet(thisView, 'newbase', base); %once the base has been imported into matlab, set it in the view
      thisView = viewSet(thisView,'corticalDepth',[0.2 0.8]); %set the range of of cortical depths used for displaying the overlays
    end
  end
  thisView = viewSet(thisView,'curBase',viewGet(thisView,'baseNum',[subject{iSubj} '_left_GM.off']));
  
  refreshMLRDisplay(thisView); % first check if the surfaces have defects (skipped by default, since the manually-corrected surfaces are provided)
  if ~isempty(flatName{iSubj,iSide}) || ...
      (checkForSurfaceDefects && strcmp(input('Check left and right surfaces for defects. Process this subject further? (y/n) ','s'),'y'))
    
    %Concatenate all functional sacns
    thisView = viewSet(thisView,'curGroup','MotionComp');
    nScans = viewGet(thisView,'nScans');
    if isempty(viewGet(thisView,'groupNum','Concatenation'))
      thisView = concatTSeries(thisView,[],'defaultParams=1',['scanList=' mat2str(1:nScans)]);
    end
    if viewGet(thisView,'nScans',viewGet(thisView,'groupNum','Concatenation')) == 1 && maxFitTypes > 1
      % concatenate half of the scans for cross-recentring
      thisView = concatTSeries(thisView,[],'defaultParams=1',['scanList=' mat2str(1:round(nScans/2))]);
      thisView = concatTSeries(thisView,[],'defaultParams=1',['scanList=' mat2str(round(nScans/2)+1:nScans)]);
    end
    
    % link event files to scans
    for iFile = 1:length(eventFiles)
      fprintf(1,['Linking ' eventFiles(iFile).name ' to Group MotionComp, scan ' num2str(viewGet(thisView,'tseriesFile',iFile,1)) '\n']);
      thisView = viewSet(thisView,'stimfilename',eventFiles(iFile).name, iFile,1);
    end
    
    % Whole-head GLM analysis
    thisView = viewSet(thisView,'curGroup','Concatenation');
    if isempty(viewGet(thisView,'analysisNum','GLM_wh'))
      [thisView, glmParams] = glmAnalysis(thisView,[],'justGetParams=1','defaultParams=1');
      glmParams.hrfModel = 'hrfBoxcar';
      [thisView, glmParams] = glmAnalysis(thisView,glmParams,'justGetParams=1','defaultParams=1');
      glmParams.saveName = 'GLM_wh';
      glmParams.hrfParams.description = 'Box Car';
      glmParams.hrfParams.delayS =  2.5;
      glmParams.hrfParams.durationS = 2.5;
      if iSubj <= 12
        % Re-order the EVs so adaptor-only conditions appear first and in order of increasing frequency
        isAdapter = startsWith(glmParams.EVnames', 'Adapter'); % will put adapter conditions first
        isProbe   = contains(glmParams.EVnames', 'Probe'); % will put probe-only conditions last (and therefore adapter-probe in the middle)
        adapterHz = nan(size(glmParams.EVnames')); % will sort by adapter frequency for each stimulus category
        adapterHz(isAdapter) = cellfun(@(s) sscanf(s,'Adapter %dHz',1), glmParams.EVnames(isAdapter)');  % extract adapter frequency
        [~, conditionsOrder] = sortrows([~isAdapter isProbe adapterHz], [1 2 3]); % sort based on stimulus category and adapter frequency
      else
        [~, conditionsOrder] = sort(cellfun(@(s) sscanf(s,'Tone %dHz',1), glmParams.EVnames')); % sort based on tone frequency
      end
      glmParams.scanParams{1}.stimToEVmatrix = zeros(glmParams.numberEVs);
      for iEV = 1:glmParams.numberEVs
        glmParams.scanParams{1}.stimToEVmatrix(conditionsOrder(iEV),iEV) = 1;
      end
      if iSubj==1
        glmParams.EVnames = {'A251Hz','A507Hz','A899Hz','A1501Hz','A2423Hz','A3839Hz','A6009Hz','A507P3839Hz','A1501P3839Hz','A3839P3839Hz'};
        glmParams.restrictions{1} = zeros(9,10);
        glmParams.restrictions{1}([1 11 21 31 41 51 61])=1;
      elseif iSubj < 13
        glmParams.EVnames = {'A251Hz','A507Hz','A899Hz','A1501Hz','A2423Hz','A3839Hz','A6009Hz','A507P3839Hz','A899P3839Hz','A1501P3839Hz','A2423P3839Hz','A3839P3839Hz','P3839Hz'};
        glmParams.restrictions{1} = zeros(12,13);
        glmParams.restrictions{1}([1 14 27 40 53 66 79])=1;
      else % Ben's data
        glmParams.EVnames = glmParams.EVnames(conditionsOrder);
        glmParams.restrictions{1} = eye(glmParams.numberEVs);
      end
      glmParams.numberContrasts = nFreqs(iSubj);
      glmParams.contrasts = glmParams.contrasts(1:nFreqs(iSubj),:);
      for iScan = 1:length(glmParams.scanNum)
        glmParams.scanParams{iScan}.stimDurationMode = 'fromFile';
        glmParams.scanParams{iScan}.supersamplingMode =  'Set value';
        glmParams.scanParams{iScan}.designSupersampling = 3;
        glmParams.scanParams{iScan}.acquisitionDelay = .75;
      end
      glmParams.numberFtests = 1;
      glmParams.fTestNames{1} = 'F(any frequency)';
      [thisView, glmParams] = glmAnalysis(thisView,glmParams);
    end
    
    % flatten cortical patch around supratemporal plane (this is skipped by default because the flat maps are provided)
    if isstrprop(subject{iSubj}(1),'digit') % if the freesurfer name starts with a number, makeFlat would have appended an x to the flat name
      flatPrefix = 'x';
    else
      flatPrefix = '';
    end
    if ~isempty(flatName{iSubj,1}) && ~isempty(flatName{iSubj,2})
      % import the existing flat maps
      importFlatParams.path = surfRelaxPath;
      for iSide=1:2
        if isempty(viewGet(thisView,'baseNum',[flatPrefix subject{iSubj} '_' sides{iSide} '_WM_Flat_' flatName{iSubj,iSide}])) %import flat maps
          importFlatParams.anatFileName = [subject{iSubj} '_mprage_pp.nii'];
          importFlatParams.flatRes=3;
          importFlatParams.threshold = 1;
          importFlatParams.baseValues = 'curvature';
          importFlatParams.flatFileName = [flatPrefix subject{iSubj} '_' sides{iSide} '_WM_Flat_' flatName{iSubj,iSide} '.off'];
          importFlatParams.outerCoordsFileName = [subject{iSubj} '_' sides{iSide} '_GM.off'];
          importFlatParams.innerCoordsFileName = [subject{iSubj} '_' sides{iSide} '_WM.off'];
          importFlatParams.curvFileName = [subject{iSubj} '_' sides{iSide} '_Curv.vff'];
          base = importFlatOFF(importFlatParams);
          thisView = viewSet(thisView, 'newbase', base);
          thisView = viewSet(thisView,'rotate',flatRotation(iSubj,iSide));
          thisView = viewSet(thisView,'corticalDepth',[0.2 0.8]);
        end
      end
      
    else % create the flat maps (involves manual intervention, but skipped by default)
      
      disp('Create left and right flat maps using makeFlat and run dbcont when done.')
      refreshMLRDisplay(thisView);
      keyboard

    % create flat maps centered on Heschl's gyrus (if not done already):
    % - menu: Plots/Interrogate Overlay
    % - at the bottom left of the GUI, enter interrogator function 'makeFlat'
    % - click on the surface at the desired centre of the flat map
    % - in the pop-up menu, set the radius to 60 mm
    % - press Ok
    % - in the next pop-up menu, set flatRes to 3 and press OK
    % - when flat map is made, set rotate value
    % - report the flat map name and rotation in initializeScriptCM7T.m
    % do the same for the other side

      thisView = getMLRView;  %this will copy the view from the graphical window to variable thisView
      initializeScriptCM7T; % run initializeScriptCM7T to get the name of the flat maps and rotate values
      for iSide = 1:2
        if isempty(flatName{iSubj,iSide}) || isnan(flatRotation(iSubj,iSide))
          keyboard; % make sure you enter the name of the flat map in initializeScriptCM7T.m
          initializeScriptCM7T;
        end
        thisView = viewSet(thisView,'corticalDepth',[0.2 0.8],viewGet(thisView,'baseNum',[flatPrefix subject{iSubj} '_' sides{iSide} '_WM_Flat_' flatName{iSubj,iSide}]));
      end

      % Delete any extra flat maps drawn in the process
      for iBase = viewGet(thisView,'numbase'):-1:1 %(going backwards because everytime a base is deleted, the number of bases decreases)
        baseName = viewGet(thisView,'baseName',iBase);
        if contains(baseName,'Flat') && ~ismember(extractAfter(baseName,'Flat_'),flatName(iSubj,:))
          thisView = viewSet(thisView,'deleteBase',iBase);
          delete(fullfile(dataDir,'Anatomy/freesurfer/subjects/',subject{iSubj},'surfRelax',[baseName '.off']));
        end
      end

    end
    
    % Set ROI display defaults
    thisView = viewSet(thisView,'labelROIs',0); % do not show ROI labels
    thisView = viewSet(thisView,'showROIs','selected perimeter');
    
    % Create Auditory cortex ROIs (skipped by default since the ROIs are provided)
    for iSide = 1:2
      roiName = [sides{iSide} 'AuditoryCortex'];
      flatBaseName{iSide} = [flatPrefix subject{iSubj} '_' sides{iSide} '_WM_Flat_' flatName{iSubj,iSide}];
      if exist(fullfile(mrToolsPath,'ROIs',[roiName '.mat']),'file')
        if isempty(viewGet(thisView,'roiNum',roiName))
          thisView = loadROI(thisView,[roiName '.mat']);
        end
      else
        thisView = viewSet(thisView,'curBase',viewGet(thisView,'baseNum',flatBaseName{iSide}));
        refreshMLRDisplay(thisView);
        thisView = newROI(thisView,roiName);
        % Manually draw polygon around activated voxels (set the color to magenta)
        thisView = drawROI(thisView,'polygon',1);
        % extend to all cortical depths
        [~, params] = convertROICorticalDepth(thisView,[],'justGetParams=1','defaultParams=1');
        params.conversionType = 'Project through depth';
        params.referenceDepth = .5;
        params.minDepth = 0;
        params.maxDepth = 1;
        params.allowProjectionThroughSulci = false;
        thisView = convertROICorticalDepth(thisView,params);
        %save the ROI
        saveROI(thisView,roiName);
      end
      % expand ROI by 2 base voxels to avoid holes when using linear interpolation or smoothing later on
      expandedROI = false;
      expRoiName = [roiName 'ExpWMGM'];
      if exist(fullfile(mrToolsPath,'ROIs',[expRoiName '.mat']),'file')
        if isempty(viewGet(thisView,'roiNum',expRoiName))
          thisView = loadROI(thisView,[expRoiName '.mat']);
        end
      else
        expandedROI = true;
        % first duplicate the ROI
        thisROI = viewGet(thisView,'roi',roiName);
        thisROI.name = expRoiName;
        thisView = viewSet(thisView,'newROI',thisROI);
        % then extend it beyond cortical depths
        [~, params] = convertROICorticalDepth(thisView,[],'justGetParams=1','defaultParams=1');
        params.conversionType = 'Project through depth';
        params.referenceDepth = .5;
        params.minDepth = -0.3;
        params.maxDepth = 1.3;
        params.allowProjectionThroughSulci = false;
        params.roiList = viewGet(thisView,'roiNum',expRoiName);
        thisView = convertROICorticalDepth(thisView,params);
        %save the ROI
        saveROI(thisView,expRoiName);
      end
      
    end
    
    % re-run GLM fit in auditory cortex ROIs
    thisView = viewSet(thisView,'curroi',find(contains(viewGet(thisView,'roiNames'),'ExpWMGM'))); % Display both expanded ROIs
    if isempty(viewGet(thisView,'analysisNum','GLM_AudCx')) || expandedROI 
      thisView = viewSet(thisView,'currentAnalysis',viewGet(thisView,'analysisNum','GLM_wh')); 
      glmParams = viewGet(thisView,'analysisParams');
      glmParams.saveName = 'GLM_AudCx';
      glmParams.analysisVolume = 'Visible ROI(s)';
      [thisView, glmParams] = glmAnalysis(thisView,glmParams);
      if saveViewAndAnalyses
        mrSaveView(thisView);
      end
    end
      
    % Get a map of which frequency condition gives the largest response at each voxel
    thisView = viewSet(thisView,'currentAnalysis',viewGet(thisView,'analysisNum','GLM_AudCx'));
    overlayListString = sprintf('overlayList=[2:%d]',nFreqs(iSubj)+1); %these are the input overlays (the beta weights for the 7/32 frequencies)
    indexMaxOverlay = find(contains(viewGet(thisView,'overlaynames'),'Output 2 - indexMax'));
    if isempty(indexMaxOverlay)
      [thisView,params]      = combineTransformOverlays(thisView,[],'justGetParams=1','defaultParams=1',overlayListString);  % get the default parameters for the combineTransformOverlays fucntion
      params.combineFunction = 'indexMax'; %this sets which matlab function will process the input overlays
      params.nOutputOverlays = 2; % the indexMax function give two outputs: the first is the index of the maximum at each voxel
      % and the second is the maximum value across the all the input overlays at each voxel
      thisView = combineTransformOverlays(thisView,params); %run indexMax
      indexMaxOverlay = viewGet(thisView,'curOverlay'); %retrieve the current overlay number (should be the last output of indexMax)
      thisView   = viewSet(thisView,'overlayCmap','parula',indexMaxOverlay-1);
      thisView   = viewSet(thisView,'overlaycolorrange',[0 nFreqs(iSubj)+1],indexMaxOverlay-1); % sets the color range for the first output
      thisView   = viewSet(thisView,'alphaOverlay',indexMaxOverlay,indexMaxOverlay-1); % masks the first output (curOverlay-1) by the second output (curOverlay) (in fact the second output overlay is used to set the alpha value of the first)
      thisView   = viewSet(thisView,'alphaOverlayExponent',0,indexMaxOverlay-1); % sets the alpha exponent (0 means that any non-zero value of the mask will be shown with alpha = 1)
      thisView   = viewSet(thisView,'overlayColorRange',[-3 3]); % sets the color range for the second output
      thisView   = viewSet(thisView,'overlayMin',0.7); % sets the minimum range for the second output
      if saveViewAndAnalyses
        mrSaveView(thisView);
      end
    end

    % Estimate preferred frequency and (re-centered) tuning width for five frequency scales
    tic
    if computeCMonSurface % if CM is computed on the meshes, then we only need to check that we have flat maps for smoothing = 4 and the ERB scale, which are the ones used for ROI definition
      thisSmoothingIndices = intersect(smoothingIndices,find(smoothingValues==plotMapSmoothingValue));
      thisScaleIndices = intersect(scaleIndices,find(strcmp(frequencyScales,plotMapScale)));
    else
      thisSmoothingIndices = smoothingIndices;
      thisScaleIndices = scaleIndices;
    end
    stimLevelsERBs = nErb(startFreqKHz(iSubj)) + ((1:nFreqs(iSubj))-1) / (nFreqs(iSubj)-1) * (nErb(endFreqKHz(iSubj))-nErb(startFreqKHz(iSubj)));
    pfRangeERBs = nErb([minFreqKHz maxFreqKHz]); % set allowed PF range to hearing range
    [thisView,overlayParams] = combineTransformOverlays(thisView,[],'justGetParams=1','defaultParams=1',overlayListString); % the first overlay is (r^2)
    overlayParams.combineFunction='overlayPSandTW';
    overlayParams.nOutputOverlays = 3;
    for iSmooth = thisSmoothingIndices
      smoothing = smoothingValues(iSmooth);
      overlayParams.baseSpace = smoothing > 0;
      if smoothing == 0
        overlayParams.nOutputOverlays = 3;
        nSides = 1;
        sideString = '';
        FWHMstring = '[]';
        recentre = 0;
        recentreString = '';
        overlayParams.inputOutputType = '3D Array';
        overlayParams.scanList = 1:3;
        partitionString = '[]';
        nFitTypes = 1; % not recentred
      else
        nSides = 2; % not recentred and recentred (includind cross-recentred)
        FWHMstring = sprintf('[%d %d 0]',smoothing,smoothing);
        nFitTypes = maxFitTypes; % if maxFitTypes = 1, then recentred tuning curves won't be fitted
      end
      
      for iSide = 1:nSides
        thisView = viewSet(thisView,'curbase',viewGet(thisView,'baseNum',[flatPrefix subject{iSubj} '_' sides{iSide} '_WM_Flat_' flatName{iSubj,iSide}]));
        if smoothing>0
            sideString = [sides{iSide} ' '];
        end

        for iScale = thisScaleIndices
          switch(frequencyScaleTypes{iScale})
            case 'LIN'
              stimLevels = invNErb(stimLevelsERBs); % frequencies on linear kHz scale
              pfRange = invNErb(pfRangeERBs);
            case 'LOG'
              stimLevels = log2(invNErb(stimLevelsERBs)); % frequencies on octave scale
              pfRange = log2(invNErb(pfRangeERBs));
            case 'ERB'
              stimLevels = nErb(invNErb(stimLevelsERBs),frequencyScales{iScale}); % frequencies on NERB scale (Glasberg & Moore, 1990 or Oxenham & Shera, 2003)
              pfRange = nErb(invNErb(pfRangeERBs),frequencyScales{iScale});
            case 'DLF'
              stimLevels = nDlf(invNErb(stimLevelsERBs),frequencyScales{iScale}); % frequencies on NDLF scale (Nelson et al., 1983 or Micheyl et al., 2012)
              pfRange = nDlf(invNErb(pfRangeERBs),frequencyScales{iScale});
          end
          twMax = (stimLevels(end)-stimLevels(1))*2; % THIS IS SOMEWHAT DIFFERENT FROM WHAT I USED IN ThE SIMULATIONS IN pfTwEstimationBias.m: ~9.17 (adaptation) or ~12.64 (Ben) vs 10 octaves
          
          for iType = 1:nFitTypes
            computedNewOverlays = false;
            if smoothing>0
              switch(iType)
                case 1 % estimate preferred frequency by fitting Gaussians to non-recentred tuning curves
                  recentre = 0;
                  recentreString = '';
                  overlayParams.inputOutputType = '3D Array';
                  overlayParams.scanList = 1;
                  partitionString = '[]';
                case 2 % estimate tuning width by recentering tuning curves before smoothing and fitting Gaussians
                  recentre = 1;
                  recentreString = 'recentre ';
                  overlayParams.inputOutputType = '4D Array (multiple scans)';
                  overlayParams.scanList = [1 2 3];
                  partitionString = '{1;[2 3]}'; % compute biased (non-cross-recentred) TW from scan 1 and cross-recentred TW from scans 2 and 3
              end
            end
            
            overlayParams.additionalArgs = sprintf('fit gaussian,%s,%f,[],[],%s,%d,%s,%s',...
                mat2str(pfRange),twMax,FWHMstring,recentre,partitionString,mat2str(stimLevels));
            overlayParams.outputName = sprintf('%sPSandTW %s ss%d %s',sideString,frequencyScales{iScale},smoothing,recentreString);
            pfOverlayNum = find(contains(viewGet(thisView,'overlaynames'),overlayParams.outputName));
            if isempty(pfOverlayNum) || recomputePSandTWoverlays
              computedNewOverlays = true;
              fprintf('\n (Re)Computing overlay %s with parameters %s\n\n',overlayParams.outputName,overlayParams.additionalArgs);
              thisView = combineTransformOverlays(thisView,overlayParams);
              pfOverlayNum = viewGet(thisView,'curOverlay')-overlayParams.nOutputOverlays+1;
            elseif numel(pfOverlayNum)
              pfOverlayNum = pfOverlayNum(1);
            end
            maskedOverlayList = pfOverlayNum+(0:overlayParams.nOutputOverlays-1);
            thisView   = viewSet(thisView,'alphaOverlay',pfOverlayNum+2,maskedOverlayList);
            thisView   = viewSet(thisView,'alphaOverlayExponent',0,maskedOverlayList); % set the alpha exponent
            thisView   = viewSet(thisView,'overlayCmap','parula',pfOverlayNum);
            thisView   = viewSet(thisView,'overlayColorRange',pfRange,pfOverlayNum); % set the color range for the preferred frequency parameter
            thisView   = viewSet(thisView,'overlayCmap','inferno',pfOverlayNum+1);
            thisView   = viewSet(thisView,'overlayColorRange',[0 stimLevels(end)-stimLevels(1)],pfOverlayNum+1); % set the color range for for the tuning width parameter
            thisView   = viewSet(thisView,'overlayColorRange',[-3 3],pfOverlayNum+2); % sets the color range for the scale parameter output
            if overlayParams.nOutputOverlays > 3
              thisView   = viewSet(thisView,'overlayColorRange',[-3 3],pfOverlayNum+3); % sets the color range for the offset parameter output
            end
            thisView   = viewSet(thisView,'overlayMin',0.7,pfOverlayNum+2); % set the threshold for the scale parameter

            if computedNewOverlays && saveViewAndAnalyses
              mrSaveView(thisView); % save every so often in case there is an issue (like an electricity cut or a disconnection)
            end
          end
        end
      end
    end
    toc
    refreshMLRDisplay(thisView);
  
  end
  
  % Tonotopic reversals detection (Schoenwiesner et al., 2015)
  if drawReversalROIs
    flatVolumeGroupNum  = viewGet(thisView,'groupNum',[flatBaseName{iSide} 'Volume']);
    for iSide = 1:2
      if isempty(flatVolumeGroupNum) || isempty(viewGet(thisView,'analysisNum','combineTransformOverlays',flatVolumeGroupNum))
        thisView = viewSet(thisView,'curbase',viewGet(thisView,'baseNum',flatBaseName{iSide}));
        thisView = viewSet(thisView,'curGroup','Concatenation');
        thisView = viewSet(thisView,'curAnalysis',viewGet(thisView,'analysisNum','GLM_AudCx'));
  
        overlayNum      = find(contains(viewGet(thisView,'overlaynames'),['Output 1 - ' sides{iSide} ' PSandTW ' plotMapScale ' ss' num2str(plotMapSmoothingValue) ' (']));
  
        [thisView,params]       = combineTransformOverlays(thisView,[],'justGetParams=1','defaultParams=1',['overlayList=' mat2str(overlayNum)]);
        params.combineFunction  = 'gradientReversal';
        params.additionalArgs   = '[14 14 21], ''Canny''' ;
        params.baseSpaceInterp  = 'linear';
        params.nOutputOverlays  = 7;
        params.baseSpace        = 1;
        params.exportToNewGroup = 1;
        thisView                = combineTransformOverlays(thisView,params);
  
        %Alpha overlay and settings
        curOverlay = viewGet(thisView,'curOverlay');
        thisView = viewSet(thisView,'curOverlay',curOverlay-[3 1]);
        thisView = viewSet(thisView,'overlayMin',10,curOverlay-1);
      end
    end
      
    % Draw tonotopic reversal line ROIs and gradient ROIs (skipped by default since they are provided
    for iSide = 1:2
      thisView = viewSet(thisView,'curbase',viewGet(thisView,'baseNum',[flatBaseName{iSide} 'Volume']));
      thisView = viewSet(thisView,'curGroup',[flatBaseName{iSide} 'Volume']);
      refreshMLRDisplay(thisView);
      
      drewROI = false;
      lineROInames = {'AnteriorLine', 'MidLine', 'PosteriorLine'};
      for iRoi = 1:3
        roiName = [sides{iSide} lineROInames{iRoi}];
        if exist(fullfile(mrToolsPath,'ROIs',[roiName '.mat']),'file')
          if isempty(viewGet(thisView,'roiNum',roiName))
            thisView = loadROI(thisView,[roiName '.mat']);
            lineROIlist(iSide,iRoi) = viewGet(thisView,'curRoi');
          else
            lineROIlist(iSide,iRoi) = viewGet(thisView,'roiNum',roiName);
          end
        else
          drewROI = true;
          thisView = newROI(thisView,roiName);
          thisView = drawROI(thisView,'line',1);
          saveROI(thisView,roiName);
          refreshMLRDisplay(thisView);
          lineROIlist(iSide,iRoi) = viewGet(thisView,'curRoi');
        end
      end
      
      if drewROI
        thisView = viewSet(thisView,'curRoi',lineROIlist(iSide,:));
        refreshMLRDisplay(thisView);
      end
      
      gradientROInames = {'AnteriorGradient','PosteriorGradient'};
      for iRoi = 1:2
        roiName = [sides{iSide} gradientROInames{iRoi}];
        if exist(fullfile(mrToolsPath,'ROIs',[roiName '.mat']),'file')
          if isempty(viewGet(thisView,'roiNum',roiName))
            thisView = loadROI(thisView,[roiName '.mat']);
            gradientROIlist(iSide,iRoi) = viewGet(thisView,'curRoi');
          else
            gradientROIlist(iSide,iRoi) = viewGet(thisView,'roiNum',roiName);
          end
        else
          drewROI = true;
          thisView = newROI(thisView,roiName);
          thisView = drawROI(thisView,'polygon',1);
          saveROI(thisView,roiName);
          refreshMLRDisplay(thisView);
          gradientROIlist(iSide,iRoi) = viewGet(thisView,'curRoi');
        end
      end
      if drewROI
        thisView = viewSet(thisView,'curRoi',gradientROIlist(iSide,:));
        refreshMLRDisplay(thisView);
      
        keyboard; % fix any issue if necessary
        thisView = getMLRView;
      end
      
      % Eliminate overlap between gradient ROIs
      thisView = combineROIs(thisView, gradientROIlist(iSide,1), gradientROIlist(iSide,2), 'A not B');
  
      % Expand line and gradient ROIs to all depths
      [~,params]                = transformROIs(thisView, [],'justGetParams=1','defaultParams=1');
      params.transformFunction  = 'expandROI';
      params.additionalArgs     = '[1 1 6]';
      params.roiNameSuffix      = 'Exp';
      if isempty(viewGet(thisView,'roiNum',[sides{iSide} gradientROInames{1} 'Exp'])) % assume that if one is missing, both are
        params.roiList          = gradientROIlist(iSide,:);
        thisView                = transformROIs(thisView, params);
      end
      if isempty(viewGet(thisView,'roiNum',[sides{iSide} lineROInames{1} 'Exp'])) % assume that if one is missing, both are
        params.roiList          = lineROIlist(iSide,:);
        thisView                = transformROIs(thisView, params);
      end
  
      % Convert to original base space
      [~,params]                = transformROIs(thisView, [],'justGetParams=1','defaultParams=1');
      params.transformFunction  = 'convertFromFlatVolumeToBase';
      params.roiNameSuffix      = 'Surface';
      if isempty(viewGet(thisView,'roiNum',[sides{iSide} gradientROInames{1} 'ExpSurface'])) || recomputeSurfaceGradientROIS % assume that if one is missing, both are
        params.roiList            = [];
        for i = 1:length(gradientROInames)
          params.roiList          = [params.roiList, viewGet(thisView, 'roiNum', [sides{iSide} gradientROInames{i} 'Exp'])];
        end
        thisView                  = transformROIs(thisView, params,'noPrompt');
      end
      if isempty(viewGet(thisView,'roiNum',[sides{iSide} lineROInames{1} 'ExpSurface'])) || recomputeSurfaceGradientROIS % assume that if one is missing, both are
        params.roiList            = [];
        for i = 1:length(lineROInames)
          params.roiList          = [params.roiList, viewGet(thisView, 'roiNum', [sides{iSide} lineROInames{i} 'Exp'])];
        end
        thisView                  = transformROIs(thisView, params,'noPrompt');
      end
  
      % Make ROIs exactly contiguous
      if isempty(viewGet(thisView,'roiNum',[sides{iSide} gradientROInames{1} 'ExpSurfaceContig'])) || recomputeSurfaceGradientROIS % assume that if one is missing, both are
        [~,params]               = transformROIs(thisView,[],'justGetParams=1','defaultParams=1');
        params.transformFunction = 'makeROIsExactlyContiguous';
        params.passRoiMode       = 'All ROIs at once';
        params.roiNameSuffix     = 'Contig';
        params.roiSpace          = 'Native';
        params.roiList = [viewGet(thisView, 'roiNum', [sides{iSide} 'AnteriorGradientExpSurface']) ...
          viewGet(thisView, 'roiNum', [sides{iSide} 'PosteriorGradientExpSurface'])];
        thisView = transformROIs(thisView,params,'noPrompt');
      end
  
    end

    if saveViewAndAnalyses
      mrSaveView(thisView);
    end

  end
  
  % display preferred-frequency and tuning width flap maps for both hemispheres and save as a figure
  if plotFlatMapsAndROIs
    if ~exist(mapsFolder,'dir')
      mkdir(mapsFolder)
    end
    thisView = viewSet(thisView,'displayGyrusSulcusBoundary',1);
    thisView = viewSet(thisView,'curgroup','Concatenation');
    thisView = viewSet(thisView,'curAnalysis',viewGet(thisView,'analysisNum','GLM_AudCx'));
    for iSide = 1:2
      figureFileName = sprintf('Participant%02d_PF_TW_%s_ss%d_%s.svg',iSubj,sides{iSide},plotMapSmoothingValue,plotMapTWtype);

      if ~exist(fullfile(mapsFolder,figureFileName),'file')
        overlayNameString = sprintf('PSandTW %s ss%d',plotMapScale,plotMapSmoothingValue);
        scanNum = 1;
        recentreString = '';
        if plotMapSmoothingValue > 0
          overlayNameString = sprintf('%s %s',sides{iSide},overlayNameString);
          switch(plotMapTWtype)
            case 'Recentred'
              recentreString = 'recentre ';
            case 'Cross-recentred'
              recentreString = 'recentre ';
              scanNum = 2;
          end
        end
        overlayNameString = sprintf('%s %s(',overlayNameString,recentreString);
        overlayList = find(contains(viewGet(thisView,'overlaynames'),overlayNameString));
      
        if ~isempty(overlayList)
          thisView = viewSet(thisView,'curScan',scanNum);
          thisView = viewSet(thisView,'curOverlay',overlayList(1:2));
          thisView = viewSet(thisView,'overlayCmap','parula',overlayList(1));
          thisView = viewSet(thisView,'overlayCmap','inferno',overlayList(2));
          thisView = viewSet(thisView,'curbase',viewGet(thisView,'baseNum',flatBaseName{iSide}));
          thisView = viewSet(thisView,'baseGamma',0.6);
  
          roiList(1) = viewGet(thisView, 'roinum', [sides{iSide} 'AnteriorGradientExpSurfaceContig']);
          roiList(2) = viewGet(thisView, 'roinum', [sides{iSide} 'PosteriorGradientExpSurfaceContig']);
          thisView = viewSet(thisView,'curROI', roiList);
          thisView = viewSet(thisView,'roiColor','magenta');
          refreshMLRDisplay(thisView);
      
          [~,printParams] = mrPrint(thisView,'justGetParams=1','useDefault=1');
          printParams.imageTitle = sprintf('Participant %d',iSubj);
          printParams.figurePosition = [0 0 1 1];
          printParams.mosaic = true;
          printParams.cropX = [40 280];
          printParams.cropY = [90 180];
          printParams.colorbarLoc = 'outsideSN';
          printParams.colorbarTitle = {'Preferred frequency (ERB)','Tuning FWHM (ERB)'};
          printParams.interpreter = 'tex';
          printParams.imageTitleLoc = 'North';
          printParams.colorbarTickNumber = 0;
          mrPrint(thisView,'params',printParams);
  
          print(fullfile(mapsFolder,figureFileName),'-dsvg','-vector');
          close (gcf)
        end

      end
    end

    thisView = viewSet(thisView,'displayGyrusSulcusBoundary',0);
  end
  
  % Measure cortical mapping, magnification and gradient at each surface vertex in each gradient ROI (calling corticalMagnificationAuditory.m)
  % This will be done separately for each frequency scale estimation and each level of smoothing
  runCorticalMagnificationAuditory = exportCMdata || plotCMSurfaceFigures || saveROIgaussianFits;
  if runCorticalMagnificationAuditory
    
    gradients = {'posterior','anterior'};
    roiNames(:,:,1) = {'leftPosteriorLineExpSurface', 'leftMidLineExpSurface', 'leftPosteriorGradientExpSurfaceContig';...
                       'leftAnteriorLineExpSurface',  'leftMidLineExpSurface', 'leftAnteriorGradientExpSurfaceContig'};
    roiNames(:,:,2) = {'rightPosteriorLineExpSurface','rightMidLineExpSurface','rightPosteriorGradientExpSurfaceContig';...
                       'rightAnteriorLineExpSurface', 'rightMidLineExpSurface','rightAnteriorGradientExpSurfaceContig'};
    
    [~,params] = corticalMagnificationAuditory([],[],'justGetParams');
    params.invFnirt       = 0;
    params.corticalDepths = [0.2, 0.8];
    params.startFreqKHz   = startFreqKHz(iSubj);
    params.endFreqKHz     = endFreqKHz(iSubj);
    params.nFreqs         = nFreqs(iSubj);
    params.overlayInterpMethod = 'linear'; % used linear interpolation to collect the data  %% THIS RESULTS IN A LOT OF MISSING DATA WHEN USING THE GLM_AudCx ANALYSIS, so will use GLM_wh instead
    params.plotCMfigures  = false;
    params.plotSurface    = plotCMSurfaceFigures;
    params.showRemovedAddedVertices = false;
    params.stimulusScale  = 'ERB'; % This isn't used if computeCMonSurface is false, because the input overlays are already expressed on a frequency scale
    params.CMmethodDepiction = CMmethodDepiction;  % possible values are 'none','gradient', 'vertex number', 'surface' and 'distance'
 
    thisView = viewSet(thisView,'curgroup','Concatenation');
    if computeCMonSurface
      thisView = viewSet(thisView,'currentAnalysis',viewGet(thisView,'analysisNum','GLM_wh')); % We get the data from the whole brain analysis to avoid missing data when using linear interpolation
      params.pfRangeKHz = [0.02 20]; % used when estimatePFandTW is 'centroid','debiasedCentroid' or 'fit gaussian'
      params.twMaxOct = 10; % used when estimatePFandTW is 'centroid','debiasedCentroid' or 'fit gaussian'
    else
      thisView = viewSet(thisView,'curAnalysis',viewGet(thisView,'analysisNum','GLM_AudCx')); % in this case we have to use the Auditory Cortex restricted analysis because that's where we estimated PF and TW
      params.estimatePFandTW = 'given';
    end

    figTypes = {};
    if plotCMSurfaceFigures
      figTypes = [figTypes {'corticalPatch_withPathExample'}];
    end
    
    for iSide = 1:2
      
      thisView = viewSet(thisView,'curbase',viewGet(thisView,'baseNum',flatBaseName{iSide}));
      thisView = viewSet(thisView,'curAnalysis',viewGet(thisView,'analysisNum','GLM_AudCx'));
      thisView = viewSet(thisView,'curOverlay',find(startsWith(viewGet(thisView,'overlaynames'),sprintf('Output 1 - %s PSandTW',sides{iSide})),1,'first'));

      for iSmooth = smoothingIndices
        smoothing = smoothingValues(iSmooth);
        if smoothing == 0
          sideString = '';
          FWHMstring = '[]';
          partitionString = '[]';
        else
          FWHMstring = sprintf('[%d %d 0]',smoothing,smoothing);
          sideString = [sides{iSide} ' '];
        end
        
        if runCorticalMagnificationAuditory
          for iScale = scaleIndices
            params.overlayUnits   = frequencyScales{iScale}; % this tells corticalMagnificationAuditory that the input overlay follows a given frequency scale (if computeCMonSurface is false) or that the PF/TW should be computed in that scale (if computeCMonSurface is true)
            if computeCMonSurface
              params.overlayScanNum = 1;
              params.overlayList = 2:nFreqs(iSubj)+1;
              params.fwhm = smoothing/3; % smoothing value must be specified in mm. We assume that 1 pixel on the flat map is 1/3 mm
            else
              for iOverlay = 1:2*maxFitTypes % 1 = PF (always non-recentred), 2 = non-recentered TW, 3 = cross-recentred TW, 4 = recentered TW
                outputNumber = min(iOverlay,2); % PS or TW
                if iOverlay ==  3 && smoothing > 0
                  recentreString = 'recentre '; % TW calculated by cross-validated recentring
                  params.overlayScanNum(iOverlay) = 2; % is on scan 2 (because cross-validated with scans 2 and 3)
                elseif iOverlay ==  4 && smoothing > 0
                  recentreString = 'recentre '; % TW calculated by recentring without cross-validation
                  params.overlayScanNum(iOverlay) = 1; % is on scan 1
                else
                  recentreString = ''; % PF/TW calculated without recentring (even for recentred TW, we use the non-recentered, smoothed PFs)
                  params.overlayScanNum(iOverlay) = 1; % They're all on scan 1
                end
                overlayName = sprintf('Output %d - %sPSandTW %s ss%d %s(',outputNumber,sideString,frequencyScales{iScale},smoothing,recentreString);
                params.overlayList(iOverlay) = find(contains(viewGet(thisView,'overlaynames'),overlayName));
              end
              thisView = viewSet(thisView,'curScan',params.overlayScanNum(1)); % this shouldn't be needed
              thisView = viewSet(thisView,'curOverlay', params.overlayList);   % but helps to see what's going on
              thisView = viewSet(thisView,'overlayCmap','parula',params.overlayList(1));
              thisView = viewSet(thisView,'overlayCmap','inferno',params.overlayList(2:2*maxFitTypes));
            end
            
            % need to get a local copy of the view from the global MLR variable, because refreshMLRDisplay updates the view field 'curslicebasecoords',
            [~, ~, ~, ~, ~, thisView] = refreshMLRDisplay(thisView); % which is needed by the corticalmagnification script, but does not return a local copy of the view
            
            for iPA = 1:2 % for posterior or anterior gradient ROI
              
              if isnan(cmData.distanceBetweenReversals(iPA,iSide,iSmooth,iScale,iSubj)) || recomputeCM

                fprintf('\nEstimating CM for %s %s gradient ROI, %.2g-mm smoothing, %s PF estimation scale (participant %s)\n', ...
                        sides{iSide}, gradients{iPA}, params.fwhm, frequencyScales{iScale}, subject{iSubj});

                for iRoi = 1:3
                  roiList(iRoi) = viewGet(thisView, 'roinum', roiNames{iPA, iRoi,iSide});
                end
                thisView = viewSet(thisView,'curROI', roiList);
                
                refreshMLRDisplay(thisView); % just to see which ROI is currently being processed
                
                if computeCMonSurface
                  params.estimatePFandTW = 'fit gaussian';
                end
              
                [output, ~] = corticalMagnificationAuditory(thisView,params);
              
                cmData.vertexPFs(iPA,iSide,iSmooth,iScale,iSubj)                  = {output.pfOverlayScale};
                cmData.pathDistances(iPA,iSide,iSmooth,iScale,iSubj)              = {output.pathDistancesToReversals};
                cmData.relativeDistances(iPA,iSide,iSmooth,iScale,iSubj)          = {output.relativeDistancesToReversals};
                cmData.distanceBetweenReversals(iPA,iSide,iSmooth,iScale,iSubj)   = output.meanPathDistanceBetweenReversals;
                cmData.pfAllRoisAllScales(iPA,iSide,iSmooth,iScale,iSubj)         = {output.pfAllRoisAllScalesFaces};
                cmData.pfGradientAllRoisAllScales(iPA,iSide,iSmooth,iScale,iSubj) = {output.pfGradientAllRoisAllScalesFaces};
                cmData.extraOverlaysVertices(iPA,iSide,iSmooth,iScale,iSubj)      = {output.extraOverlaysVertices};
                cmData.extraOverlaysAllRoisFaces(iPA,iSide,iSmooth,iScale,iSubj)  = {output.extraOverlaysAllRoisFaces};
                cmData.vertexAreas(iPA,iSide,iSmooth,iScale,iSubj)                = {output.vertexAreas};
                cmData.correctedVertexAreas(iPA,iSide,iSmooth,iScale,iSubj)       = {output.correctedVertexAreas};
                cmData.faceAreas(iPA,iSide,iSmooth,iScale,iSubj)                  = {output.faceAreas};
                cmData.correctedFaceAreas(iPA,iSide,iSmooth,iScale,iSubj)         = {output.correctedFaceAreas};
                
                if exportCMdata
                  save(cmFile,'-struct','cmData');
                end

                if saveROIgaussianFits
                  if computeCMonSurface && strcmp(params.estimatePFandTW,'fit gaussian')
                    % get fitting parameters and tuning curves at each vertex within the gradient ROI
                    gFits.preferredStimuli(iPA,iSide,iSmooth,iScale,iSubj) = {output.pfOverlayScale{3}'};
                    gFits.tuningWidths(iPA,iSide,iSmooth,iScale,iSubj) = {output.extraOverlaysVertices{3}'};
                    gFits.scalings(iPA,iSide,iSmooth,iScale,iSubj) = {output.scalingVertices{3}'};
                    gFits.tuningCurves(iPA,iSide,iSmooth,iScale,iSubj) = {output.tuningCurvesVertices{3}'};
                    gFits.stimulusLevels(iPA,iSide,iSmooth,iScale,iSubj) = {output.stimulusLevels};
                    % and also at each face
                    gFits.preferredStimuliFaces(iPA,iSide,iSmooth,iScale,iSubj) = {output.pfAllRoisAllScalesFaces(iScale+1,:)'};
                    gFits.tuningWidthsFaces(iPA,iSide,iSmooth,iScale,iSubj) = {output.extraOverlaysAllRoisFaces'};
                    gFits.scalingsFaces(iPA,iSide,iSmooth,iScale,iSubj) = {output.scalingFaces'};
                    gFits.tuningCurvesFaces(iPA,iSide,iSmooth,iScale,iSubj) = {output.tuningCurvesFaces'};
                  elseif ~computeCMonSurface
                    [gFits.preferredStimuli(iPA,iSide,iSmooth,iScale,iSubj), ...
                      gFits.tuningWidths(iPA,iSide,iSmooth,iScale,iSubj), ...
                      gFits.scalings(iPA,iSide,iSmooth,iScale,iSubj), ~, ...
                      gFits.tuningCurves(iPA,iSide,iSmooth,iScale,iSubj), ...
                      gFitsStimulusLevels,...
                      gFits.roiScanCoords(iPA,iSide,(smoothing > 0) + 1,iSubj), ...
                      gFits.roiBaseCoords(iPA,iSide,(smoothing > 0) + 1,iSubj)] = ...
                      plotOverlayPSandTW(thisView,params.overlayList(1),params.overlayScanNum(1),[],[],[],roiList(3)); % here we're only getting the non-recentred parameters when smoothing > 0. Will have to change the overlay number if we want the parameters for the recentered tuning curves
                      gFits.stimulusLevels(iPA,iSide,iSmooth,iScale,iSubj) = {gFitsStimulusLevels};
                  end
                end
              
                if plotCMSurfaceFigures
                  if ~exist(cmFiguresFolder,'dir')
                    mkdir(cmFiguresFolder)
                  end
                  
                  for figType = figTypes
                    savefig(fullfile(cmFiguresFolder,sprintf('%s - %s_%s_s%dmm_%s',subject{iSubj},roiNames{iPA,3,iSide},figType{1},smoothing,frequencyScales{iScale})));
                    close (gcf)
                  end
                end
              end
            end

          end
          
          if saveROIgaussianFits
            save(gaussianFitsFile,'-struct','gFits','-v7.3');
          end
        end
      end
    end
  end
  
  mrQuit(0);
  toc(tscript)
end

mrSetPref('overwritePolicy',defaultOverwritePolicy);
