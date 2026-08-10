% function [preferredStimulus,tuningWidth, scaling, offset, adjustedR2, r2, varargout] = overlayPSandTW(varargin)
%
% Estimates preferred stimulus and tuning width at each voxel for set of
% ordered overlays (e.g. parameter estimates for different frequencies or
% different fingertip stimulations), assuming equal stimulus distance
% between consecutive overlays
% 
%   Inputs: - set of N overlays
%           - method (optional): 'max','humphries','centroid','debiased centroid','fit gaussian' (default = 'debiased centroid')
%                                 if set to 'none', the tuning curves will be computed but no parameters will be calculated/fitted
%           - psRange (optional): allowed range for the preferred stimulus (default = 30% below and above overlay stimulus range,
%                                 unless recentring is used)
%           - twMax (optional): maximum value for the tuning width (default = maximum overlay stimulus value). Minimum is set to 0.
%                               Only relevant for 'debiased centroid' and 'fit gaussian'.
%           - fitOffset (optional): whether to fit an offset parameter (default = false). Only relevant for 'fit gaussian'
%           - offsetRange (optional): lower/upper bounds for the offset (default = [min(tuning curve) inf]). If only one value is provided, it is taken as the upper bound.
%           - FWHM (optional): full-width at half maximum of 3D Gaussian kernel for spatial smooth (default: no smoothing)
%           - recentre (optional): whether to recentre the tuning curves based on estimated preferred stimulus for smoothing (default = false)
%           - scanPartition (optional): which scans should be used for cross-validated tuning width estimation. E.g. {1;[2 3]} will process the first scan
%                                       without cross-validation and [2 3] will process scans 2 and 3 with cross validation (use a semi-colon, not a comma).
%                                       Cross-validation requires the inputOutputType option to be set to '4D Array (multiple scans)' in transformCombineOverlays.
%                                       Scan numbers are specified as index into the fourth overlay dimension (default = each scan computed separately, no cross validation).
%           - stimLevels (optional): stimulus level of each input overlay (default: 1:nOverlays). If stimulus levels are not equidistant tuning width estimates
%                                    may be inaccurate when smoothing and recentering
%
% optionally outputs the tuning curves on which parameter estimation/fitting is (or would have been) based

function [preferredStimulus,tuningWidth, scaling, offset, adjustedR2, r2, varargout] = overlayPSandTW(varargin)

verbose = true; % only used for fitting gaussians
recentreOnSmoothedPF = false; % when smoothing and recentering, recenter on the smoothed rather than unsmoothed tuning curves
for i = 1:4
  overlayDims(i) = size(varargin{1},i);
end
nScans = overlayDims(4); % 4th dimension is the scan dimension
array = varargin{1};
nOverlays = nargin;
for i = 2:nargin
  % check that all inputs have the same size
  for j = 1:4
    thisOverlayDims(j) = size(varargin{i},j);
  end
  if ~isequal(thisOverlayDims,overlayDims)
    nOverlays = i-1;
    fprintf('(overlayPSandTW) Detected %d overlay inputs\n',nOverlays);
    break;
  else
    % concatenate
    array=cat(5,array,varargin{i});
  end
end
for i = 1:nargin-nOverlays
  switch(i)
    case 1
      method = varargin{nOverlays+i};
    case 2
      psRange = varargin{nOverlays+i};
    case 3
      twMax = varargin{nOverlays+i};
    case 4
      fitOffset = varargin{nOverlays+i};
    case 5
      offsetRange = varargin{nOverlays+i};
    case 6
      FWHM = varargin{nOverlays+i};
    case 7
      recentre = varargin{nOverlays+i};
    case 8
      scanPartition = varargin{nOverlays+i};
      % check that scans are only used once across all partitions
      % and that all the necessary scans have been passed in
      scans = [];
      for iPart = 1:length(scanPartition)
        scans = [scans scanPartition{iPart}];
      end
      if length(scans) > nScans || any(~ismember(scans,1:nScans))
        error('(overlayPSandTW) Each scan must be used only once across all partitions')
      end
    case 9
      stimLevels = varargin{nOverlays+i};
  end
end
if ieNotDefined('method')
  method = []; % default set in estimatePSandTW.m
end
if ieNotDefined('psRange')
  psRange = []; % default set in estimatePSandTW.m
end
if ieNotDefined('twMax')
  twMax = []; % default set in estimatePSandTW.m
end
if ieNotDefined('fitOffset')
  fitOffset = []; % default set in estimatePSandTW.m
end
if ieNotDefined('offsetRange')
  offsetRange = []; % default set in fitGaussian.m
end
if ieNotDefined('FWHM')
  FWHM = []; % No smoothing
end
if ieNotDefined('recentre')
  recentre = false; % No recentring
end
if ieNotDefined('scanPartition')
  scanPartition = {1:size(array,4)}; % No cross validation
end
if ieNotDefined('stimLevels')
  stimLevels = 1:nOverlays;
end

if recentre && (isempty(FWHM) || all(~nnz(FWHM)))
  recentre = false; % no point using recentring if no smoothing
  mrWarnDlg('(overlayPSandTW) Not recentring because no smoothing is being applied')
end

% smooth (except if recentring on unsmoothed tuning curves first)
if ~isempty(FWHM) && (~recentre || recentreOnSmoothedPF)
  for iOverlay = 1:nOverlays
    for iScan  = 1:nScans
      array(:,:,:,iScan, iOverlay) = spatialSmooth(array(:,:,:,iScan,iOverlay),FWHM);
    end
  end
end

if recentre && ismember(method,{'none'})
  thisMethod = 'debiased centroid'; % if recentring but not estimating, calculate preferred stimulus using debiased centroid method
else
  thisMethod = method;
end
if recentre
  thisPsRange = [stimLevels(1) - 0.5*mean(diff(stimLevels)) stimLevels(end) + 0.5*mean(diff(stimLevels))]; % limit estimated range of preferred stimuli for simplicity when recentring
  thisTwMax = []; % must use a reasonable TW range for debiased centroid
else
  thisPsRange = psRange;
  thisTwMax = twMax;
end

% reshape input data
array = reshape(array,[],nOverlays);

if ~strcmp(method,'none') || recentre
  [preferredStimulus, tuningWidth, scaling, offset, adjustedR2, r2] = ...
    estimatePSandTW(stimLevels, array, thisMethod, [], thisPsRange, thisTwMax, fitOffset, offsetRange, verbose);
end

if recentre  %recentre tuning curves (using cross-validation if scanPartition is correctly specified)
  
  array = reshape(array,prod(overlayDims(1:3)),nScans,nOverlays);
  preferredStimulus = reshape(preferredStimulus,prod(overlayDims(1:3)),nScans);
  recentredArray = nan(prod(overlayDims(1:3)),nScans, nOverlays*2-1);
  
  for iPart = 1:length(scanPartition)
    
    % Randomly permute scans within this partition
    nScansPart = length(scanPartition{iPart});
    randomPermutation = 1:nScansPart;
    if length(scanPartition{iPart})>1
      while any(randomPermutation==1:nScansPart) % make sure no scan is in its original position
        randomPermutation = randperm(nScansPart);
      end
    end
    permutedPartition = scanPartition{iPart}(randomPermutation);
    for iScan = 1:length(scanPartition{iPart})
      % recenter tuning curves in each scan using preferred preferency estimate on another scan
      for iPS = 1:length(stimLevels)
        % find which voxels have preferred stimuli closest to each stimulus level
        whichVoxels = true(size(preferredStimulus(:,permutedPartition(iScan))));
        if iPS < length(stimLevels) % for all levels except the last, which PSs are closer to a given level than to the next one
          whichVoxels = abs(preferredStimulus(:,permutedPartition(iScan)) - stimLevels(iPS)) < ...
                          abs(preferredStimulus(:,permutedPartition(iScan)) - stimLevels(iPS+1));
        end
        if iPS > 1 % for all levels except the first, which PSs are also closer to a given level than to the previous one
          whichVoxels = whichVoxels & abs(preferredStimulus(:,permutedPartition(iScan)) - stimLevels(iPS)) < ...
                          abs(preferredStimulus(:,permutedPartition(iScan)) - stimLevels(iPS-1));
        end
        recentredArray(whichVoxels, scanPartition{iPart}(iScan), nOverlays+1-iPS:nOverlays*2-iPS) = array(whichVoxels,scanPartition{iPart}(iScan),:);
      end
    end
  end
  
  %smooth
  recentredArray = reshape(recentredArray,[overlayDims nOverlays*2-1]);
  for iScan  = 1:nScans
    for iOverlay = 1:nOverlays*2-1
      recentredArray(:,:,:,iScan,iOverlay) = spatialSmooth(recentredArray(:,:,:,iScan,iOverlay),FWHM,false);
    end
  end
  
  % average cross-validated tuning curves and put them on the first scan of each partition
  for iPart = 1:length(scanPartition)
    recentredArray(:,:,:,scanPartition{iPart}(1),:) = nanmean(recentredArray(:,:,:,scanPartition{iPart},:),4);
    % set other tuning curves to NaN for other scans
    recentredArray(:,:,:,scanPartition{iPart}(2:end),:) = NaN;
  end
  
  recentredArray = reshape(recentredArray,[],nOverlays*2-1);
  
  if ~strcmp(method,'none')
    thisStimLevels = (-nOverlays+1:nOverlays-1) * mean(diff(stimLevels));
    [~, tuningWidth, scaling, offset, adjustedR2, r2] = estimatePSandTW(thisStimLevels, recentredArray, method, [], [0 0], twMax, fitOffset, offsetRange, verbose);
  end
  
end

if ~strcmp(method,'none')
  preferredStimulus = reshape(preferredStimulus,overlayDims);
  if recentre && ~recentreOnSmoothedPF
    for iScan  = 1:nScans
      preferredStimulus(:,:,:,iScan) = spatialSmooth(preferredStimulus(:,:,:,iScan),FWHM); % if recentring was used, need to smooth the estimated voxelwise PSs
    end
  end
  tuningWidth = reshape(tuningWidth,overlayDims);
  scaling = reshape(scaling,overlayDims);
  offset = reshape(offset,overlayDims);
  adjustedR2 = reshape(adjustedR2,overlayDims);
  r2 = reshape(r2,overlayDims);
else
  preferredStimulus = [];
  tuningWidth = [];
  scaling = [];
  offset = [];
  adjustedR2 = [];
  r2 = [];
end

if nargout>6
  if recentre
    array = recentredArray;
  end
  for iArg = 1:size(array,2)
    varargout{iArg} = reshape(array(:,iArg),overlayDims);
  end
end
