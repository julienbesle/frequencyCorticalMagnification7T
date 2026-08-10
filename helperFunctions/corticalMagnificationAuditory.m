% corticalMagnificationAuditory.m
%
%      usage: [output, params] = corticalMagnificationAuditory(<view>, <params>)
%         by: Julien Besle
%             based on calcDist by eli merriam, denis schluppeck, etc...
%
%       date: 2014
%    purpose: estimates cortical magnification from preferred frequency maps
%             by plotting preferred frequency (in stimulus space or converted to kHz) 
%             as a function of relative distance between each vertex in gradient ROI 
%             and low and high-frequency line ROIs
%
%             Input:
%               - (optional) mrLoadRet view. If no view is provided the first open view will be used
%               - (optional) parameter structure. If no parameter structure is provided, default values will be used.
%                            To get the default parameter structure, run: [~,params] = corticalMagnificationAuditory([],[],'justGetParams')
%                            See code for the meaning of the parameters.
%             
%             Output:
%               - pfOverlayScale                  : vertexwise preferred frequencies (in original frequency scale of the overlay),
%                                                   averaged across specified cortical depths (default: 0.5 depth), for all 3 ROIs
%                                                   after ensuring no overlap between them and attempting to fill holes
%               - pathDistancesToReversals        : corresponding cortical distances between each vertex and low/high-frequency reverals (in mm)
%               - relativeDistancesToReversals    : corresponding normalized cortical distances
%               - meanPathDistanceBetweenReversals: average cortical distance between the two reversals (in mm)
%               - pfAllRoisAllScalesFaces         : facewise preferred frequency, averaged across specified cortical depths, across all 3 ROIs,
%                                                   converted to 6 different frequency scales (linear, Weber fraction, ERB (Glasberg & Moore 1990 or
%                                                   Oxenham & Sheera 2003), DLF (Nelson et al. (1983) or Micheyl et al. (2012))
%               - pfGradientAllRoisAllScalesFaces : corresponding facewise frequency gradients (in frequency units/mm) in each of the scales
%               - faceAreas                       : the surface areas of all mesh triangles/faces, in the same order as the above
%               - correctedFaceAreas              : the surface areas of all mesh triangles/faces, corrected for piecewise flatness of the mesh (i.e. including curvature information)
%               - vertexAreas                     : the contribution of each vertex to the uncorrected surface area
%               - correctedVertexAreas            : the contribution of each vertex to the uncorrected surface area
%               - extraOverlaysVertices (optional): if PF were given and additional overlays were loaded/provided, this contains the vertexwise, depth-averaged
%                                                   overlay values for each of the 3 ROIs and each of the additional overlays. If PFs were not given but calculated
%                                                   from responses to different frequencies, this will contain the estimated TWs
%               - extraOverlaysAllRoisFaces (opt.): corresponding facewise, depth-averaged additional overlay values
%               - tuningCurvesVertices (opt.)     : Tuning curves at each vertex (if PFs were not given but calculated from responses to different frequencies, i.e. estimatePFandTW ~= 'given')
%               - scalingVertices (opt.)          : Scaling parameter at each vertex (if estimatePFandTW = 'fit gaussian')
%               - stimulusLevels (opt.)           : Stimulus frequencies used to estimate PF, TW and other parameters.
%               - tuningCurvesFaces (opt.)        : Tuning curves at each face (if PFs were not given but calculated from responses to different frequencies)
%               - scalingFaces (opt.)             : Scaling parameter at each face (if estimatePFandTW = 'fit gaussian')
%
%             How to use:
%               - load a flat map 
%               - define two line ROIs representing low and high-frequency reversals
%               - define an ROI for the target cortical area (tonotopic gradient between the two reversals)
%               - load preferred frequency overlay (and optional additional overlays) OR overlays corresponding to the response to different frequency (in ascending order)
%               - (optionally run [~,params] = corticalMagnificationAuditory([],[],'justGetParams') to get default parameters and modify them)
%               - run: output = corticalMagnificationAuditory(<view>,params)
%

function [output, params] = corticalMagnificationAuditory(thisView,params,varargin)

% check arguments
if ~any(nargin == [0 1 2 3])
    help corticalMagnificationAuditory
    return
end

eval(evalargs(varargin));
if ieNotDefined('justGetParams'),justGetParams = 0;end

% allow this to be run from command line
%  pick the first mrLoadRet view that exists
if ieNotDefined('thisView')
    vnums = viewGet([],'viewnums');
    if isempty(vnums)
        disp('uhoh - no views. just returning')
        return
    elseif numel(vnums) > 1
        disp('uhoh - more than one view open. check that everything is ok')
    end
    thisView = viewGet([],'view',vnums(1));
end

% set default parameters
if ieNotDefined('params')
  params = struct;
elseif ischar(params) %for backward compatibility
  saveName = params;
  params = struct;
  params.saveName = saveName;
end
if fieldIsNotDefined(params,'overlayList')
  params.overlayList = viewGet(thisView,'curOverlay');
end
if fieldIsNotDefined(params,'overlayScanNum')
  params.overlayScanNum = viewGet(thisView,'curscan');
end
if fieldIsNotDefined(params,'estimatePFandTW')
  params.estimatePFandTW = 'given'; % options are 'given' (PF is given as 1st overlay and TW as additional overlays), 'max','centroid','debiasedCentroid'
  % or 'fit gaussian' (each input overlay correspond to the response to a given stimulus, and PF and TW are estimated using the corresponding method)
end
if fieldIsNotDefined(params,'pfRangeKHz')
  params.pfRangeKHz = [0.02 20]; % used when estimatePFandTW is 'centroid','debiasedCentroid' or 'fit gaussian'
end
if fieldIsNotDefined(params,'twMaxOct')
  params.twMaxOct = 10; % used when estimatePFandTW is 'centroid','debiasedCentroid' or 'fit gaussian'
end
if fieldIsNotDefined(params,'overlayUnits')
  % if estimatePFandTW = ']given', whether the overlay is expressed in stim units or in actual units of one of the available scales (log, ERB or DLF)
  % if estimatePFandTW = 'centroid','debiasedCentroid' or 'fit gaussian', which scale should be used to estimate PF and TW
  % if estimatePFandTW = 'max', this can be anything and the result will be the same
  params.overlayUnits='stim'; %options are 'stim', 'log','G&M90','O&S03','N83' or 'M12'
end
if fieldIsNotDefined(params,'stimulusScale') % if params.overlayUnits is set to stim, what scale was used to present the stimuli. Fields startFreqKHz, endFreqKHz and nFreqs must also be defined.
  params.stimulusScale='ERB'; %options are 'log' or 'ERB'/'G&M90'
end
if fieldIsNotDefined(params,'startFreqKHz') % this field and the following two will be used to convert from stimulus units to 
  params.startFreqKHz=.25;
end
if fieldIsNotDefined(params,'endFreqKHz')
  params.endFreqKHz=6;
end
if fieldIsNotDefined(params,'nFreqs')
  params.nFreqs=7;
end
if fieldIsNotDefined(params,'corticalDepths')
  params.corticalDepths=viewGet(thisView, 'corticalDepth');
end
if fieldIsNotDefined(params,'overlayInterpMethod')
  params.overlayInterpMethod = mrGetPref('interpMethod');
end
if fieldIsNotDefined(params,'fwhm') % smooth along the cortical mesh (using Dijkstra distance) with a radially symmetrical 2D Gaussian kernel of this FWHM
  params.fwhm=0; % default: no smoothing
end
if fieldIsNotDefined(params,'invFnirt')
  params.invFnirt=1;
end
if fieldIsNotDefined(params,'undistortedInnerSurfPath')
  params.undistortedInnerSurfPath=[];
end
if fieldIsNotDefined(params,'undistortedOuterSurfPath')
  params.undistortedOuterSurfPath=[];
end
if fieldIsNotDefined(params,'plotCMfigures')
  params.plotCMfigures=false;
end
if fieldIsNotDefined(params,'cmPlotSyle')
  params.cmPlotSyle='histogram';  %options are: 'scatter','histogram'
end
if fieldIsNotDefined(params,'plotSurface')
  params.plotSurface=false;
end
if fieldIsNotDefined(params,'showRemovedAddedVertices') % when plotting surface, show removed and added vertices as larger points
  params.showRemovedAddedVertices=false;
end
if fieldIsNotDefined(params,'CMmethodDepiction') % when plotting surface, show an illustration of how the estimates of PF gradient strength, PF surface or cortical distance are computed
  params.CMmethodDepiction='none';  % possible values are 'none','gradient', 'vertex number', 'surface' and 'distance'
end
altFigures = false;

output = struct;

if justGetParams
  return;
end

nOverlays = length(params.overlayList);
if nOverlays<1
  mrWarnDlg('(corticalMagnificationAuditory) There should be at least one input overlay (PF)');
  return;
elseif nOverlays > 1 && length(params.overlayScanNum) == 1
  params.overlayScanNum = repmat(params.overlayScanNum,1,nOverlays);
elseif nOverlays > length(params.overlayScanNum)
  mrWarnDlg('(corticalMagnificationAuditory) There are more scan numbers than overlays, ignoring extra scan numbers');
elseif nOverlays < length(params.overlayScanNum)
  mrWarnDlg(sprintf('(corticalMagnificationAuditory) Number of overlays and scans do not match (%d vs %d), aborting.',nOverlays,length(params.overlayScanNum)));
  return;
end

%----------------------------------------------------------------------------------------------- conversion between stimulus/frequency scales
% functions to convert frequencies from kHz to 6 different scales
kHz2scale{1} = @(x)x; scaleName{1} = 'kHz';
kHz2scale{2} = @(x)log2(x); scaleName{2} = 'log';
kHz2scale{3} = @(x)nErb(x,'G&M90'); scaleName{3} = 'ERB (Glasberg & Moore, 1990)';
kHz2scale{4} = @(x)nErb(x,'O&S03'); scaleName{4} = 'ERB (Oxenham & Sheera, 2003)';
kHz2scale{5} = @(x)nDlf(x,'N83'); scaleName{5} = 'DLF (Nelson et al., 1983)';
kHz2scale{6} = @(x)nDlf(x,'M12'); scaleName{6} = 'DLF (Micheyl et al., 2012)';
nScales = length(kHz2scale);

% function to convert frequencies from scale used in the overlay to kHz
switch(params.stimulusScale)  % convert from stimulus units to actual scale units
  case 'log' % There were nFreqs frequencies, equally spaced on a log scale between startFreqKHz and endFreqKHz
    stim2kHz = @(nStims) 2.^( log2(params.startFreqKHz) + (nStims-1) / (params.nFreqs-1) * (log2(params.endFreqKHz)-log2(params.startFreqKHz)));
    kHz2stim = @(x) (log2(x) - log2(params.startFreqKHz)) * (params.nFreqs-1) / (log2(params.endFreqKHz)-log2(params.startFreqKHz)) + 1;
  case 'ERB' % There were nFreqs frequencies, equally spaced on an ERB scale (Glasberg &Moore, 1990) between startFreqKHz and endFreqKHz
    stim2kHz = @(nStims) erbStimSpace2Freq(nStims,params.startFreqKHz,params.endFreqKHz,params.nFreqs); % although this is slightly more accurate because it takes the bandwidth of the stimuli into account,
    stim2kHz = @(nStims) invNErb( nErb(params.startFreqKHz) + (nStims-1) / (params.nFreqs-1) * (nErb(params.endFreqKHz)-nErb(params.startFreqKHz)) ); % the difference with this alternative is negligible
    kHz2stim = @(x) (nErb(x) - nErb(params.startFreqKHz)) * (params.nFreqs-1) / (nErb(params.endFreqKHz)-nErb(params.startFreqKHz)) + 1; % but this is the exact inverse of the alternative
  otherwise
    keyboard; % unknown stimulus frequency scale
end

% function to convert from a given scale to kHz
switch(params.overlayUnits)
  case 'stim'
    psTwScale2kHz = stim2kHz;
    kHz2psTwScale = kHz2stim;
  case 'log'
    psTwScale2kHz = @(x) 2.^(x);
    kHz2psTwScale = kHz2scale{2};
  case 'G&M90'
    psTwScale2kHz = @(x) invNErb(x,'G&M90');
    kHz2psTwScale = kHz2scale{3};
  case 'O&S03'
    kHz2psTwScale = kHz2scale{4};
    psTwScale2kHz = @(x) invNErb(x,'O&S03');
  case 'N83'
    psTwScale2kHz = @(x) invNDlf(x,'N83');
    kHz2psTwScale = kHz2scale{5};
  case 'M12'
    psTwScale2kHz = @(x) invNDlf(x,'M12');
    kHz2psTwScale = kHz2scale{6};
  otherwise
    keyboard % unknown frequency scale
end

%----------------------------------------------------------------------------------------------- Load ROIs
roiList = viewGet(thisView,'curroi');
%choose ROIs
nRois = 3;
while length(roiList)~=nRois
  roiList = selectInList(thisView,'roi','Select 2 reversal and 1 gradient ROIs');
  if isempty(roiList)
    disp('User pressed cancel');
    return;
  elseif  length(roiList)~=nRois
    mrWarnDlg('Please only select three ROIs')
  end
end
rois = viewGet(thisView,'roi',roiList);

%----------------------------------------------------------------------------------------------- Load surface coordinates
% baseCoords contains the mapping from pixels in the displayed slice to
%  voxels in the current base volume.
baseCoords = viewGet(thisView,'curslicebasecoords');
if isempty(baseCoords)
  mrWarnDlg('(corticalMagnificationAuditory) Load base anatomy before drawing an ROI');
  return;
end


% get the base CoordMap for the current flat patch
corticaDepthStep = mean(diff(linspace(0,1,mrGetPref('corticalDepthBins'))));
corticalDepths = params.corticalDepths(1):corticaDepthStep:params.corticalDepths(end);
[~,midDepthIndex] = ismember(round(mean(params.corticalDepths)/corticaDepthStep),corticalDepths/corticaDepthStep);
midCorticalDepth = corticalDepths(midDepthIndex);
baseCoordMap = viewGet(thisView,'baseCoordMap');
if isempty(baseCoordMap)
  mrWarnDlg('(corticalMagnificationAuditory) You cannot use this function unless you are viewing a flat patch with a baseCoordMap');
  return;
end
baseHdr = viewGet(thisView, 'basehdr');
%load the flat patch 
flat = loadSurfOFF(fullfile(baseCoordMap.path, baseCoordMap.flatFileName));

% load the appropriate surface files            
fprintf('Loading %s\n', baseCoordMap.innerCoordsFileName);
surface.inner = loadSurfOFF(fullfile(baseCoordMap.path, baseCoordMap.innerCoordsFileName)); % "world" coordinates of the inner surface
if isempty(surface.inner)
  mrWarnDlg(sprintf('(corticalMagnificationAuditory) Could not find surface file %s',fullfile(baseCoordMap.path, baseCoordMap.innerCoordsFileName)));
  return
end
fprintf('Loading %s\n', baseCoordMap.outerCoordsFileName);
surface.outer = loadSurfOFF(fullfile(baseCoordMap.path, baseCoordMap.outerCoordsFileName)); % "world" coordinates of the outer surface
if isempty(surface.outer)
  mrWarnDlg(sprintf('(corticalMagnificationAuditory) Could not find surface file %s',fullfile(baseCoordMap.path, baseCoordMap.outerCoordsFileName)));
  return
end
surface.inner = xformSurfaceWorld2Array(surface.inner, baseHdr); % convert surface coordinates from world to index into the base
surface.outer = xformSurfaceWorld2Array(surface.outer, baseHdr); % (the world coordinates get copied into originalVtcs)
surface.filename = baseCoordMap.outerCoordsFileName;

% %restrict surface to flat patch
% flatInnerCoords = reshape(baseCoordMap.innerCoords,size(baseCoordMap.innerCoords,1)*size(baseCoordMap.innerCoords,2),3); %take flat patch coordinates (indices into the canonical base volume?)
% flatInnerCoords(any(flatInnerCoords==0,2),:)=[]; %remove any zeroes
% 
% %find vertices of the surface corresponding to the flat map
% nnz(ismember(round(flatInnerCoords),round(surface.inner.vtcs),'rows'))

% build up a mrMesh-style structure, taking account of the current corticalDepth
% use both world and based coordinates because we want to both select vertices based on ROI coordinates (needs base coordinates) and take measurements in physical units (needs world coordinates)
nDepths = length(corticalDepths);
restrictToPatch=1;
if ~restrictToPatch
  m.verticesBase = surface.inner.vtcs+midCorticalDepth*(surface.outer.vtcs-surface.inner.vtcs);
  m.vertices = surface.inner.originalVtcs+midCorticalDepth*(surface.outer.originalVtcs-surface.inner.originalVtcs);
  for iDepth = 1:nDepths
    m.verticesBaseAllDepths(:,:,iDepth) = surface.inner.vtcs+corticalDepths(iDepth)*(surface.outer.vtcs-surface.inner.vtcs);
  end
  m.faceIndexList  = surface.inner.tris;
else
% %(restricting to flat patch)
  %re-order face vertices in patch to match that of the original surface
  %(this is only necessary for displaying the patch, as apparently, the
  %orientation of the faces matters and the order of vertices (for each face) 
  %differs between the OFF flat patch and the surface)
  patch2parent=flat.patch2parent(:,2);
  flatTrisSurf = patch2parent(flat.tris); %patch faces with surface vertices
  permutations = perms(1:3);
  flatTris = flat.tris;
  for i=1:size(permutations,1)
    whichTris = ismember(flatTrisSurf(:,permutations(i,:)),surface.inner.tris,'rows');
    flatTris(whichTris,:) = flatTris(whichTris,permutations(i,:));
  end
  m.verticesBase = surface.inner.vtcs( flat.patch2parent(:,2),:) + midCorticalDepth * (surface.outer.vtcs(flat.patch2parent(:,2),:) - surface.inner.vtcs(flat.patch2parent(:,2),:) );
  m.vertices = surface.inner.originalVtcs( flat.patch2parent(:,2),:) + midCorticalDepth * (surface.outer.originalVtcs(flat.patch2parent(:,2),:) - surface.inner.originalVtcs(flat.patch2parent(:,2),:) );
  for iDepth = 1:nDepths
    m.verticesBaseAllDepths(:,:,iDepth) =  surface.inner.vtcs( flat.patch2parent(:,2),:) + corticalDepths(iDepth) * (surface.outer.vtcs(flat.patch2parent(:,2),:) - surface.inner.vtcs(flat.patch2parent(:,2),:) );
  end
  m.faceIndexList  = flatTris;
end
[m.uniqueVertices,m.vertsToUnique,m.UniqueToVerts] = unique(m.vertices,'rows','stable'); % The code should also work without the 'stable' option. However, because there usually aren't any duplicate vertices,
                                                                                            % using this option will avoid re-ordering and we won't have to worry too much about the difference between m.vertices and m.uniqueVertices
m.uniqueVerticesBase = m.verticesBase(m.vertsToUnique,:);
if ~isequal(m.vertsToUnique',1:length(m.vertsToUnique))
  keyboard % so far there has never been a case in which there were duplicate vertices. Just curious whether it ever happens...
end


% Find vertices in the middle of the current cortical depth range that are in the ROIs
% First, check that both the vertices and the ROI coordinates are in the canonical base space
if any(any(abs(viewGet(thisView,'base2roi',roiList(1))-eye(4))>1e-8)) ...
    || any(any(abs(viewGet(thisView,'base2roi',roiList(2))-eye(4))>1e-8)) ...
    || any(any(abs(viewGet(thisView,'base2roi',roiList(3))-eye(4))>1e-8))
  keyboard % need to convert roi coords to base space
elseif any(any(abs(viewGet(thisView,'basexform')-baseHdr.sform44)>1e-8))
  keyboard % the wrong base is loaded, or this code needs to be modified to allow non-canonical bases
end

%find all vertices in each ROI (in the middle of the cortical depth range)
for i=1:nRois
  m.roiVertices{i} = find(ismember(round(m.uniqueVerticesBase),round(rois(i).coords(1:3,:))','rows'));
  m.nRoiVertices(i) = size(m.roiVertices{i},1);
end
%put gradient ROI last (assuming it is the largest)
[~,gradientRoi] = max(m.nRoiVertices);
m.roiVertices = m.roiVertices([setdiff(1:3,gradientRoi) gradientRoi]);
m.nRoiVertices = m.nRoiVertices([setdiff(1:3,gradientRoi) gradientRoi]);
rois = rois([setdiff(1:3,gradientRoi) gradientRoi]);

%----------------------------------------------------------------------------------------------- Find overlay values for areal ROI vertices

% convert vertices coords to scan coords (we assume that the current base is a surface of flat map)
% and get ROI overlay data (only for the two reversal line ROIs for now)
for iOverlay=1:nOverlays
  surf2scan{iOverlay} = viewGet(thisView,'base2scan',params.overlayScanNum(iOverlay));
  scanNames{iOverlay} = viewGet(thisView,'description',params.overlayScanNum(iOverlay));
  overlayData{iOverlay} = double(viewGet(thisView,'overlaydata',params.overlayScanNum(iOverlay),params.overlayList(iOverlay)));
end
for iOverlay=1:nOverlays
  for iRoi = 1:2
    vertexData = zeros(1,m.nRoiVertices(iRoi));
    nNonNans = zeros(1,m.nRoiVertices(iRoi));
    for iDepth = 1:nDepths
      verticesScanCoords = surf2scan{iOverlay}*[m.verticesBaseAllDepths(m.vertsToUnique(m.roiVertices{iRoi}),:,iDepth) ones(m.nRoiVertices(iRoi),1)]';
      % add values sampled at each cortical depth (linearly interpolated)
      % note: we use interpn here instead of interp3 because this avoids having to swap X and Y coordinates
      interpData = interpn(overlayData{iOverlay},verticesScanCoords(1,:),verticesScanCoords(2,:),verticesScanCoords(3,:),params.overlayInterpMethod);
      vertexData(~isnan(interpData)) = vertexData(~isnan(interpData)) + interpData(~isnan(interpData));
      nNonNans = nNonNans + ~isnan(interpData);
    end
    vertexData = vertexData./nNonNans; % average preferred stimulus across cortical depths
    vertexData(~nNonNans) = NaN;
    switch(params.estimatePFandTW)
      case 'given' % the input overlays already represent PF and TW
        if iOverlay == 1
          output.pfOverlayScale{iRoi} = vertexData;
        else
          output.extraOverlaysVertices{iRoi}(iOverlay-1,:) = vertexData;
        end
      otherwise % the input overlays correspond to voxelwise tuning curves (response to each stimulus frequency)
        roiOverlayData{iRoi}(iOverlay,:) = vertexData;
    end
  end
end

if ~strcmp(params.estimatePFandTW,'given')
  % compute PF using the max function as a quick estimate to re-order frequency reversals
  for iRoi = 1:2
    [~,output.pfOverlayScale{iRoi}] = max(roiOverlayData{iRoi});
  end
end

% reorder so low frequency and high frequency reversals are first and second respectively
[~,lowFrequencyBorder] = min([nanmean(output.pfOverlayScale{1}) nanmean(output.pfOverlayScale{2})]);
highFrequencyBorder = 3 - lowFrequencyBorder;
output.pfOverlayScale = output.pfOverlayScale([lowFrequencyBorder highFrequencyBorder]);
if strcmp(params.estimatePFandTW,'given') && nOverlays > 1
  output.extraOverlaysVertices = output.extraOverlaysVertices([lowFrequencyBorder highFrequencyBorder]);
elseif ~strcmp(params.estimatePFandTW,'given')
  roiOverlayData = roiOverlayData([lowFrequencyBorder highFrequencyBorder]);
end
m.roiVertices = m.roiVertices([lowFrequencyBorder highFrequencyBorder 3]);


%----------------------------------------------------------------------------------------------- Compute Dijkstra distance from fovea vertex to roi vertices
if params.invFnirt%load the non-fnirted surface
  %get the undistorted surface files
  if fieldIsNotDefined(params,'undistortedInnerSurfPath')
    [filename,pathname] = uigetfile([baseCoordMap.path '/*.off'],'Select undistorted inner surface file');
    % load the appropriate surface files
    fprintf('Loading %s\n', filename);
    params.undistortedInnerSurfPath = fullfile(pathname, filename);
  end
  surface.inner = loadSurfOFF(params.undistortedInnerSurfPath);
  if isempty(surface.inner)
    mrWarnDlg(sprintf('(corticalMagnificationAuditory) Could not find surface file %s',params.undistortedInnerSurfPath));
    return
  end
  surface.inner = xformSurfaceWorld2Array(surface.inner, baseHdr); %we assume they're in the same whole-head anatomy space

  if fieldIsNotDefined(params,'undistortedOuterSurfPath')
    [filename,pathname] = uigetfile([pathname '/*.off'],'Select undistorted outer surface file');
    fprintf('Loading %s\n', filename);
    params.undistortedOuterSurfPath = fullfile(pathname, filename);
    surface.filename = filename;
  else
    [~,filename,extension] = fileparts(params.undistortedOuterSurfPath);
    surface.filename = [filename extension];
  end
  surface.outer = loadSurfOFF(params.undistortedOuterSurfPath);
  if isempty(surface.outer)
    mrWarnDlg(sprintf('(corticalMagnificationAuditory) Could not find surface file %s',params.undistortedOuterSurfPath));
    return
  end
  surface.outer = xformSurfaceWorld2Array(surface.outer, baseHdr);
  % replace the old vertices by the undistorted ones
  m.distortedVertices = m.vertices;
  m.vertices = surface.inner.originalVtcs(flat.patch2parent(:,2),:)+midCorticalDepth*(surface.outer.originalVtcs(flat.patch2parent(:,2),:)-surface.inner.originalVtcs(flat.patch2parent(:,2),:));
  m.uniqueVertices = m.vertices(m.vertsToUnique,:); % select unique vertices using indices found from the distorted mesh (usually there are no duplicate vertices, so this does nothing)
end

% calculate mesh surface area and correct it for element-wise flatness of the mesh
[m.totalArea, m.correctedTotalArea, m.faceArea, m.correctedFaceArea, m.vertexArea, m.correctedVertexArea] = meshSurfaceArea(m.uniqueVertices, m.faceIndexList);

% calculate the connection matrix
m.uniqueFaceIndexList = findUniqueFaceIndexList(m);
m.connectionMatrix = findConnectionMatrix(m);

% find the distance of all vertices from their neighbours
% D matrix contains all the distances from vertex i to j in one big sparse matrix (with a zero if i and j are not neighbors).
disp('(corticalMagnificationAuditory) Calculating distances between neighbour nodes...')
D = find3DNeighbourDists(m);

% using the D matrix for the graph calculated above, find path between each reversal vertex and _all_ other vertices in the mesh
% then use these paths to fill holes in the reversals
disp('(corticalMagnificationAuditory) Getting shortest paths between ROIs w/ dijkstra ...')
for i=1:2 %do this from either the low-frequency (1) or the high frequency (2) reversals ROIs.
  % use dijkstrap to spit out the predecessor matrix that will allow use to define the actual paths.
  [m.dist{i}, m.pred{i}] = dijkstrap( D, m.roiVertices{i} );
  m.pred{i}(~isinf(m.dist{i})&m.pred{i} == -1) = 0; % set self-distances to 0 (JB: not sure if m.dist shouldn't be used as an input to pred2path instead)
  pathDistancesWithin = m.dist{i}(:, m.roiVertices{i});   % distance to all vertices within the ROI

  % get the details of the paths rte will be a cell array numel(src) by numel(trg);
  % each entry in the cell array contains a vector of vertices
  % that define the path from the corresponding vertex in src to trg
  paths = pred2path(m.pred{i}, m.roiVertices{i}, m.roiVertices{i}); %JB: note that this requires a modified version of pre2path that DOES NOT reorder the sources
  
  % now go through each vertex along the main direction of the reversal,
  % find the path to its closest vertex and add any missing vertices to the reversal ROI
  coords = m.uniqueVertices(m.roiVertices{i},:);
  coords = coords-repmat(mean(coords),size(coords,1),1); %center vertices coordinates
  [~,~,V] = svd(coords,0); %get main direction of reversal by PCA
  %project vertices long that direction
  [~,orderAlongMainDirection] = sort(coords*V(:,1)); %find the order of vertices along that direction
  newRoiVertices{i} = [];
  j=1;
  while j<length(orderAlongMainDirection) %for each vertex, starting on one end
    [~,closestVertexIndex] = min(pathDistancesWithin(orderAlongMainDirection(j+1:end),orderAlongMainDirection(j))); %find the closest vertex in the main direction
    nextJ=j+closestVertexIndex;
    closestVertex = orderAlongMainDirection(nextJ);
    if length(paths{j,closestVertex})<8
      newRoiVertices{i} = union(newRoiVertices{i}, paths{j,closestVertex}); % add any vertex on the path (it if is less than a certain length)
    else
      newRoiVertices{i} = union(newRoiVertices{i}, paths{j,closestVertex}([1 end]));
    end
    j=nextJ;
  end
  % because of inconsistencies in the behaviour of function union, newRoiVertices might be a row or column vector
  if size(newRoiVertices{i},1)==1 % if row, transpose
    newRoiVertices{i} = newRoiVertices{i}';
  end
  if ~isequal(m.roiVertices{i},newRoiVertices{i})
    recomputeDijkstra(i) = true;
    reversalVerticesRemoved{i} = setdiff(m.roiVertices{i},newRoiVertices{i});
    reversalVerticesAdded{i} = setdiff(newRoiVertices{i},m.roiVertices{i});
    m.roiVertices{i} = union(m.roiVertices{i},newRoiVertices{i}); % keep the vertices to remove for now because we want to get the overlay value for plotting
    reversalVerticesToKeep{i} = ismember(m.roiVertices{i},newRoiVertices{i});
    m.nRoiVertices(i) = length(m.roiVertices{i});
  else
    recomputeDijkstra(i) = false;
  end
end

% remove gradient ROI vertices that are in either reversal ROI
m.roiVertices{3} = setdiff(m.roiVertices{3},union(m.roiVertices{1}(reversalVerticesToKeep{1}),m.roiVertices{2}(reversalVerticesToKeep{2})));
m.nRoiVertices(3) = size(m.roiVertices{3},1);

% get the overlay data for the two reversal ROIs again (since we may have added vertices), and for the gradient ROI
if params.fwhm > 0 % if we're smoothing, we need to get the distance from each ROI vertex to all other vertices on the cortical patch
  gaussianFunction = @(x)exp(-(x.^2/(2*( params.fwhm/(2*sqrt(2*log(2))) )^2))); % Gaussian function centered on 0 expressed as a function of fwhm
  gaussianFunction = @(x)exp(-(x/params.fwhm).^2 *4*log(2) ); % same, but simplified
  for i=1:3 %do this from either the low-frequency (1) or the high frequency (2) reversals ROIs. If we're smoothing, get the path distances for the ROI gradient as well
    if i == 3 || recomputeDijkstra(i)
      % use dijkstrap to spit out the predecessor matrix that will allow use to define the actual paths.
      [m.dist{i}, m.pred{i}] = dijkstrap( D, m.roiVertices{i} );
    end
  end
end

for iRoi = 1:3
  if iRoi == 3 || recomputeDijkstra(iRoi)
    if ~strcmp(params.estimatePFandTW,'given')
      roiOverlayData{iRoi} = nan(nOverlays,m.nRoiVertices(iRoi));
    end
    for iOverlay=1:nOverlays
      vertexData = zeros(1,m.nRoiVertices(iRoi));
      nNonNans = zeros(1,m.nRoiVertices(iRoi));

      for iDepth = 1:nDepths
        if params.fwhm
          interpData = nan(1,m.nRoiVertices(iRoi));
          for iVertex = 1:m.nRoiVertices(iRoi)
            % find all vertices within 3 FWHMs of the ROI
            vertices = find(m.dist{iRoi}(iVertex,:) < 3*params.fwhm);
            verticesScanCoords = surf2scan{iOverlay}*[m.verticesBaseAllDepths(m.vertsToUnique(vertices),:,iDepth) ones(length(vertices),1)]';
            %note: we use interpn here instead of interp3 because this avoids having to swap X and Y coordinates
            thisInterpData = interpn(overlayData{iOverlay},verticesScanCoords(1,:),verticesScanCoords(2,:),verticesScanCoords(3,:),params.overlayInterpMethod);
            interpData(iVertex) = sum( thisInterpData .* gaussianFunction(m.dist{iRoi}(iVertex,vertices)), 'omitnan') / sum(~isnan(thisInterpData) .* gaussianFunction(m.dist{iRoi}(iVertex,vertices)));
          end
        else
          verticesScanCoords = surf2scan{iOverlay}*[m.verticesBaseAllDepths(m.vertsToUnique(m.roiVertices{iRoi}),:,iDepth) ones(m.nRoiVertices(iRoi),1)]';
          %note: we use interpn here instead of interp3 because this avoids having to swap X and Y coordinates
          interpData = interpn(overlayData{iOverlay},verticesScanCoords(1,:),verticesScanCoords(2,:),verticesScanCoords(3,:),params.overlayInterpMethod);
        end
        vertexData(~isnan(interpData)) = vertexData(~isnan(interpData)) + interpData(~isnan(interpData));
        nNonNans = nNonNans + ~isnan(interpData);
      end

      vertexData = vertexData./nNonNans; % average preferred stimulus across cortical depths
      vertexData(~nNonNans) = NaN;
      
      switch(params.estimatePFandTW)
        case 'given' % the input overlays already represent PF and TW
          if iOverlay == 1
            output.pfOverlayScale{iRoi} = vertexData;
            if nOverlays > 1
              output.extraOverlaysVertices{iRoi} =  zeros(nOverlays-1,m.nRoiVertices(iRoi));
            end
          else
            output.extraOverlaysVertices{iRoi}(iOverlay-1,:) = vertexData;
          end

        otherwise % the input overlays correspond to voxelwise tuning curves (response to each stimulus frequency)
          roiOverlayData{iRoi}(iOverlay,:) = vertexData;
          
      end
    end
  end

end

% calculate PFs and TW if they are not given
if ~strcmp(params.estimatePFandTW,'given')
  
  %concatenate data from the 3 ROIs
  tuningCurves = [roiOverlayData{1} roiOverlayData{2} roiOverlayData{3}];
  %estimate PF and TW
  stimLevels = kHz2psTwScale(stim2kHz(1:nOverlays)); % stim frequencies in the scale chosen for the estimation (given by params.overlayUnits)
  pfRange = kHz2psTwScale(params.pfRangeKHz); % convert PF estimation range from kHz to destination frequency scale
  twMax = params.twMaxOct/log2(20/0.02)*(kHz2psTwScale(20) - kHz2psTwScale(0.02)); % convert max estimation TW from octaves to destination frequency scale
  [pf, tw, scaling] = ...
    estimatePSandTW(stimLevels, tuningCurves', params.estimatePFandTW, [], pfRange, twMax, [], [], true);
  
  cVertex = 0;
  for iRoi = 1:nRois
    output.pfOverlayScale{iRoi} = pf(cVertex+(1:m.nRoiVertices(iRoi)))';
    if ~strcmp(params.estimatePFandTW,'max')
      output.extraOverlaysVertices{iRoi} = tw(cVertex+(1:m.nRoiVertices(iRoi)))';
    end
    if strcmp(params.estimatePFandTW,'fit gaussian')
      % need to output the tuning curves and scaling parameters so that the level of noise can be computed
      output.tuningCurvesVertices{iRoi} = tuningCurves(:,cVertex+(1:m.nRoiVertices(iRoi)));
      output.scalingVertices{iRoi} = scaling(cVertex+(1:m.nRoiVertices(iRoi)))';
      output.stimulusLevels = stimLevels;
    end
    cVertex = cVertex + m.nRoiVertices(iRoi);
  end

end

% copy ROI surface area info to output
for i = 1:3
  output.vertexAreas{i} = m.vertexArea(m.roiVertices{i});
  output.correctedVertexAreas{i} = m.correctedVertexArea(m.roiVertices{i});
end

% Now that we got the PF/TW data for all vertices, exclude the removed vertices, while keeping a copy of everything for plotting
for iRoi = 1:2
  if recomputeDijkstra(iRoi)
    roiVerticesBeforeExclusion{iRoi} = m.roiVertices{iRoi};
    m.roiVertices{iRoi} = m.roiVertices{iRoi}(reversalVerticesToKeep{iRoi});
    m.nRoiVertices(iRoi) = length(m.roiVertices{iRoi});
    pfOverlayScaleBeforeExclusion{iRoi} = output.pfOverlayScale{iRoi};
    output.pfOverlayScale{iRoi} = output.pfOverlayScale{iRoi}(reversalVerticesToKeep{iRoi});
    roiOverlayData{iRoi} = roiOverlayData{iRoi}(:,reversalVerticesToKeep{iRoi});
    output.vertexAreas{iRoi} = output.vertexAreas{iRoi}(reversalVerticesToKeep{iRoi});
    output.correctedVertexAreas{iRoi} = output.correctedVertexAreas{iRoi}(reversalVerticesToKeep{iRoi});
    if nOverlays > 1 && ~strcmp(params.estimatePFandTW,'max')
      output.extraOverlaysVertices{iRoi} =  output.extraOverlaysVertices{iRoi}(:,reversalVerticesToKeep{iRoi});
    end
    if strcmp(params.estimatePFandTW,'fit gaussian')
      output.tuningCurvesVertices{iRoi} = output.tuningCurvesVertices{iRoi}(:,(reversalVerticesToKeep{iRoi}));
      output.scalingVertices{iRoi} = output.scalingVertices{iRoi}(reversalVerticesToKeep{iRoi});
    end
  end
end


% Now find paths between each reversal's vertex and both the other reversal and the gradient ROI
for i=1:2 %do this from either the low-frequency (1) or the high frequency (2) reversals ROIs.
  if recomputeDijkstra(i)
    % use dijkstrap to spit out the predecessor matrix that will allow us to define the actual paths.
    [m.dist{i}, m.pred{i}] = dijkstrap( D, m.roiVertices{i} );
    m.pred{i}(~isinf(m.dist{i})&m.pred{i} == -1) = 0; % set self-distances to 0 (JB: not sure if m.dist shouldn't be used as an input to pred2path instead)
  end
  % get the actual paths to the other 2 ROIs
  for j = 1:3 % (1: low-frequency reversals ROI 2: high-frequency reversal ROI, 3: gradient ROI)
    if i ~= j
      pathDistances{i,j} = m.dist{i}(:,m.roiVertices{j});   % distance to all vertices of the other ROI 

      %only keep shortest distance from each vertex of the end ROI to start ROI
      [shortestPathDistances{i,j}, whichStartVertex{i,j}] = min(pathDistances{i,j});

      %this is needed only to get the details of the paths and can be skipped if only the distances are needed
      % rte will be a cell array numel(src) by numel(trg); each entry in the cell array contains a vector of 
      % vertices that define the path from the corresponding vertex in src to trg
      m.rte{i,j} = pred2path(m.pred{i}, m.roiVertices{i}, m.roiVertices{j}); %JB: note that this requires a modified version of pre2path that DOES NOT reorder the sources
    end
  end
end
output.pathDistancesToReversals = [shortestPathDistances{1,3};shortestPathDistances{2,3}]; % Shortest distance from all vertices in the gradient to any vertex of each of the two reversals
whichReversalStartVertex = [whichStartVertex{1,3};whichStartVertex{2,3}]; %Which reversal vertex is closest to each gradient vertex
pathDistancesHFtoLF = shortestPathDistances{1,2}; % Shortest distance from each vertex of HF reversal to any vertex of the LF reversal
pathDistancesLFtoHF = shortestPathDistances{2,1}; % Shortest distance from each vertex of LF reversal to any vertex of the HF reversal

% Remove any gradient ROI vertex whose shortest path to one reversal goes through the other reversal
% (this would include gradient vertices that are on the wrong side of the reversal, but also
% vertices located on a bump near a reversal and whose shortest path start by going towards
% the wrong reversal, which would overestimate cortical distance)
gradientVerticesToKeep = false(m.nRoiVertices(3),2);
for j =1:2 %for each reversal
  for i = 1:m.nRoiVertices(3) % for each gradient vertex
    % see if its path to one of the reversals includes any vertex of the other reversal
    gradientVerticesToKeep(i,j) = all(~ismember(m.rte{j,3}{whichReversalStartVertex(j,i),i}(2:end), m.roiVertices{3-j}));
  end
  gradientVerticesToRemove{j} = m.roiVertices{3}(~gradientVerticesToKeep(:,j));
end
gradientVerticesToKeep = all(gradientVerticesToKeep,2);
roiVerticesBeforeExclusion{3} = m.roiVertices{3};
m.roiVertices{3} = m.roiVertices{3}(gradientVerticesToKeep);
m.nRoiVertices(3) = nnz(gradientVerticesToKeep);
pfOverlayScaleBeforeExclusion{3} = output.pfOverlayScale{3};
output.pfOverlayScale{3} = output.pfOverlayScale{3}(gradientVerticesToKeep);
roiOverlayData{3} = roiOverlayData{3}(:,gradientVerticesToKeep);
output.vertexAreas{3} = output.vertexAreas{3}(gradientVerticesToKeep);
output.correctedVertexAreas{3} = output.correctedVertexAreas{3}(gradientVerticesToKeep);
if nOverlays > 1 && ~strcmp(params.estimatePFandTW,'max')
  output.extraOverlaysVertices{3} = output.extraOverlaysVertices{3}(:,gradientVerticesToKeep);
end
whichReversalStartVertex = whichReversalStartVertex(:,gradientVerticesToKeep);
output.pathDistancesToReversals = output.pathDistancesToReversals(:,gradientVerticesToKeep);
for j = 1:2 % also remove the paths from the removed gradient vertices
  m.rte{j,3} = m.rte{j,3}(:,gradientVerticesToKeep);
end
if strcmp(params.estimatePFandTW,'fit gaussian')
  output.tuningCurvesVertices{3} = output.tuningCurvesVertices{3}(:,gradientVerticesToKeep);
  output.scalingVertices{3} = output.scalingVertices{3}(gradientVerticesToKeep);
end

%calculate relative distance from each vertex in the gradient ROI to closest points in the 2 reversal ROIs
output.relativeDistancesToReversals = output.pathDistancesToReversals./repmat(sum(output.pathDistancesToReversals),2,1);
output.meanPathDistanceBetweenReversals = mean([mean(pathDistancesHFtoLF),mean(pathDistancesLFtoHF)]);

%combine all roi vertices
allRoisVertices = [m.roiVertices{1};m.roiVertices{2};m.roiVertices{3}]';
allRoisOverlayData = [roiOverlayData{1} roiOverlayData{2} roiOverlayData{3}];
pfAllRoisStimScaleVertices = [output.pfOverlayScale{1} output.pfOverlayScale{2} output.pfOverlayScale{3}];
% convert frequencies from stimulus scale to 6 different scales
pfAllRoisAllScalesVerticeskHz = psTwScale2kHz(pfAllRoisStimScaleVertices); % do the actual conversion
for iScale = 1:nScales
  pfAllRoisAllScalesVertices(iScale,:) = kHz2scale{iScale}(pfAllRoisAllScalesVerticeskHz);
end

% for each vertex, compute the local cortical magnification factor in mm/unit frequency
disp('(corticalMagnificationAuditory) Calculating local preferred-frequency gradients...')

% Compute face-based preferred frequency gradient:
% select only faces containing vertices in the 3 ROIs
allRoisVertices = m.vertsToUnique(allRoisVertices); % here we need to get the vertex numbers in the original ordering of the mesh, which matches the face indices
[whichFaces,allRoisFacesVertexIndices] = ismember(m.faceIndexList,allRoisVertices);
whichFaces = all(whichFaces,2);
allRoisFacesVertexIndices = allRoisFacesVertexIndices(whichFaces,:); % these are the face vertex indices into the list of vertices across all 3 ROIs
allRoisFaces  = m.faceIndexList(whichFaces,:); % these are the face vertex indices into the original mesh vertex list
nFaces = size(allRoisFaces,1);

% copy face area information to output
output.faceAreas = m.faceArea(whichFaces);
output.correctedFaceAreas = m.correctedFaceArea(whichFaces);

% get overlay data at the center of mass of each face (averaged across cortical depths)
interpolateFromVertices = true;
if interpolateFromVertices || params.fwhm % we interpolate the faces' center values from the values at the vertices
  faceRoiOverlayData = mean(reshape(allRoisOverlayData(:,allRoisFacesVertexIndices),[nOverlays nFaces 3]),3,'omitnan');
  if strcmp(params.estimatePFandTW,'given')
    pfAllRoisAllScalesFaceskHz = psTwScale2kHz(faceRoiOverlayData(1,:));
    output.extraOverlaysAllRoisFaces = faceRoiOverlayData(2:end,:);
  end
else % or we directly re-interpolate the faces' center values from the full overlay data. This gives slightly different values,
     % but I can't think why it would matter, and the previous option makes smoothing much easier. (It also doesn't affect the PF gradient, which is calculated from the vertex values).
  if ~strcmp(params.estimatePFandTW,'given')
    faceRoiOverlayData = nan(nOverlays,nFaces);
  end
  for iOverlay=1:nOverlays
    % compute centre of mass of faces at each depth
    faceData = zeros(1,nFaces);
    nNonNans = zeros(1,nFaces);
    for iDepth = 1:nDepths
      allRoisCOMs = squeeze(mean(reshape(m.verticesBaseAllDepths(allRoisFaces(:),:,iDepth),nFaces,3,3),2)); % face centroids at each depth on (distorted) surface
      allRoisCOMscanCoords = surf2scan{iOverlay}*[allRoisCOMs ones(nFaces,1)]';
      % interpolate values at center of mass from overlay
      % note: we use interpn here instead of interp3 because this avoids having to swap X and Y coordinates
      interpData = interpn(overlayData{iOverlay},allRoisCOMscanCoords(1,:),allRoisCOMscanCoords(2,:),allRoisCOMscanCoords(3,:),params.overlayInterpMethod);
      faceData(~isnan(interpData)) = faceData(~isnan(interpData)) + interpData(~isnan(interpData));
      nNonNans = nNonNans + ~isnan(interpData);
    end
    faceData = faceData./nNonNans;
    faceData(~nNonNans) = NaN;
    
    switch(params.estimatePFandTW)
      case 'given' % the input overays already represent PF and TW
        if iOverlay == 1
          pfAllRoisAllScalesFaceskHz = psTwScale2kHz(faceData); % convert to kHz
        else
          output.extraOverlaysAllRoisFaces(iOverlay-1,:) = faceData;
        end
        
      otherwise % the input overlays correspond to voxelwise tuning curves (response to each stimulus frequency)
        faceRoiOverlayData(iOverlay,:) = faceData;
    end
  end
end
allRoisCOMs = squeeze(mean(reshape(m.vertices(allRoisFaces(:),:),nFaces,3,3),2)); %compute face centroids at mid depth on undistorted surface

% calculate PFs and TW if they are not given
if ~strcmp(params.estimatePFandTW,'given')
  
  %estimate PF and TW
  stimLevels = kHz2psTwScale(stim2kHz(1:nOverlays)); % stim frequencies in the scale chosen for the estimation (given by params.overlayUnits)
  [pfFaceOverlayScale, tw, scaling] = ...
    estimatePSandTW(stimLevels, faceRoiOverlayData', params.estimatePFandTW, [], pfRange, twMax, [], [], true);
  
  pfAllRoisAllScalesFaceskHz = psTwScale2kHz(pfFaceOverlayScale'); % convert to kHz
  if ~strcmp(params.estimatePFandTW,'max')
    output.extraOverlaysAllRoisFaces = tw';
  end
  if strcmp(params.estimatePFandTW,'fit gaussian')
    % need to output the tuning curves and scaling parameters so that the level of noise can be computed
    output.tuningCurvesFaces = faceRoiOverlayData;
    output.scalingFaces = scaling';
    output.stimulusLevels = stimLevels;
  end

end


for iScale = 1:nScales
  output.pfAllRoisAllScalesFaces(iScale,:) = kHz2scale{iScale}(pfAllRoisAllScalesFaceskHz);
end

% Compute face-based preferred frequency gradient (inverse of cortical magnification)
% according to equation 1 of Mancinelli et al. (2019)
% 1. compute vector normal to face
faceNormals = cross(m.vertices(allRoisFaces(:,2),:)-m.vertices(allRoisFaces(:,1),:),m.vertices(allRoisFaces(:,3),:)-m.vertices(allRoisFaces(:,1),:),2);
% 2. rotate two edges vector by 90 deg around normal vector
rotatedEdges = rodrigues_rot(m.vertices(allRoisFaces(:,1),:)-m.vertices(allRoisFaces(:,3),:),faceNormals,pi/2);
rotatedEdges2 = rodrigues_rot(m.vertices(allRoisFaces(:,2),:)-m.vertices(allRoisFaces(:,1),:),faceNormals,pi/2);
% 3. compute area of each face
faceAreas = sqrt(sum(faceNormals.^2,2))/2;
% 4. apply equation
for iScale = 1:nScales
  frequencyGradient{iScale} = ...
      repmat(pfAllRoisAllScalesVertices(iScale,allRoisFacesVertexIndices(:,2)) - pfAllRoisAllScalesVertices(iScale,allRoisFacesVertexIndices(:,1)),3, 1)' .* rotatedEdges + ...
      repmat(pfAllRoisAllScalesVertices(iScale,allRoisFacesVertexIndices(:,3)) - pfAllRoisAllScalesVertices(iScale,allRoisFacesVertexIndices(:,1)),3, 1)' .* rotatedEdges2;
  frequencyGradient{iScale} = frequencyGradient{iScale} ./ repmat(2 * faceAreas,1,3);
  % take norm of the gradient (in frequency units/mm)
  output.pfGradientAllRoisAllScalesFaces(iScale,:) = sqrt(sum(frequencyGradient{iScale}.^2,2));
%   % Compute cortical magnification gradient by taking the inverse of preferred frequency gradient (in mm/unit frequency)
%   cmAllRoisAllScalesFaces(iScale,:) = 1./output.pfGradientAllRoisAllScalesFaces(iScale,:);
end

% % Compute interpolated values at the centre of each face (to check that approximately equal to value sampled directly from the overlay using the centroids)
% % % Calculate barycentric coordinates (not needed because weights for the centroids are 1/3, 1/3, 1/3)
% % barycentricCoords = [sqrt( sum(cross(m.vertices(allRoisFaces(:,2),:) - allRoisCOMs, m.vertices(allRoisFaces(:,3),:) - allRoisCOMs).^2,2))/2 ...
% %                      sqrt( sum(cross(m.vertices(allRoisFaces(:,3),:) - allRoisCOMs, m.vertices(allRoisFaces(:,1),:) - allRoisCOMs).^2,2))/2 ...
% %                      sqrt( sum(cross(m.vertices(allRoisFaces(:,1),:) - allRoisCOMs, m.vertices(allRoisFaces(:,2),:) - allRoisCOMs).^2,2))/2 ...
% %                      ]./repmat(faceAreas,1,3);
% % % Use barycentric coordinates to compute interpolated values at the centre of each face
% % pfAllRoisStimScaleFaces2 = sum(pfAllRoisStimScaleVertices(allRoisFacesVertexIndices).* barycentricCoords,2);
% pfAllRoisStimScaleFaces2 = mean(pfAllRoisStimScaleVertices(allRoisFacesVertexIndices),2);  % they do approximatly correspond

if altFigures
  % approximate face-based cortical magnification averaging vectors between vertices and centroid
  cmAllRoisAllScalesFaces2 = nan(nScales,nFaces);
  for iScale = 1:nScales
    cmAllRoisAllScalesFaces2(iScale,:) = sqrt(sum( squeeze( mean( reshape( (repmat(allRoisCOMs,3,1) - m.vertices(allRoisFaces(:),:)) ./ ...
    (repmat(output.pfAllRoisAllScalesFaces(iScale,:)',3,1) - repmat(pfAllRoisAllScalesVertices(iScale,allRoisFacesVertexIndices(:))',1,3)),[nFaces 3 3] ), 2 )).^2, 2));
  %   figure;
  %   scatter(output.pfGradientAllRoisAllScalesFaces(iScale,:),output.pfGradientAllRoisAllScalesFaces2(iScale,:));
  end

  % Compute approximate vertex-based preferred frequency gradient (to check)
  cmAllRoisAllScalesVertices = nan(nScales,length(allRoisVertices));
  for i = 1:length(allRoisVertices)
    %find all immediate neighbors
    neighbors = unique(m.faceIndexList(any(m.faceIndexList == allRoisVertices(i),2),:));
    neighbors = setdiff(neighbors,allRoisVertices(i));
    [~,neighborsIndices] = ismember(neighbors,allRoisVertices);
    if all(neighborsIndices) % if they're all within the ROI (maybe this can be relaxed)
      %add frequency gradient vectors between the current vertex and all of its neighbors,
      %weighted by their respective cortical magnification in a given scale
      nNeighbors = nnz(neighborsIndices);
      for iScale = 1:nScales
        cmAllRoisAllScalesVertices(iScale,i) = sqrt(sum( mean( (repmat(m.vertices(allRoisVertices(i),:),nNeighbors,1) - m.vertices(neighbors,:)) ./ ...
        (repmat(pfAllRoisAllScalesVertices(iScale,i),nNeighbors,3) - repmat(pfAllRoisAllScalesVertices(iScale,neighborsIndices)',1,3)) ) .^2));
      end
    end
  end
end

if ~fieldIsNotDefined(params,'saveName')
  save(params.saveName,'-struct','output');
end

if ~fieldIsNotDefined(params,'saveName')
  figureName = params.saveName;
else
  figureName = sprintf('%s - %s',viewGet(thisView,'subject'),rois(3).name);
end

polyOrder = 2;

if params.plotCMfigures
  figure('name',['Reverse normalized cortical distance function (vertices) - ' figureName],'units','normalized','position',[0 0 1 1]);
  for iScale = 1:nScales
    subplot(2,3,iScale)
    PF = kHz2scale{iScale}(psTwScale2kHz(output.pfOverlayScale{3}));
    distance = output.relativeDistancesToReversals(1,:);
    [p,~,mu]=polyfit(distance(~isnan(PF)),PF(~isnan(PF)),polyOrder);
    switch(params.cmPlotSyle)
      case 'scatter'
        plot(distance,PF,'ok');
      case 'histogram'
        histogram2(distance,PF,50,'XBinLimits',[-0.05 1.05],'YBinLimits',[min(PF) max(PF)],'displayStyle','tile');
        colorbar;
    end
    hold on
    d = 0:0.01:1;
    plot(d,polyval(p,d,[],mu),'m','linewidth',2);
    plot(zeros(size(output.pfOverlayScale{1})),kHz2scale{iScale}(psTwScale2kHz(output.pfOverlayScale{1})),'ob');
    plot(ones(size(output.pfOverlayScale{2})),kHz2scale{iScale}(psTwScale2kHz(output.pfOverlayScale{2})),'or');
    xlabel('Normalized cortical distance');
    ylabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
    colorbar;
  end
  
  figure('name',['Cortical distance function (normalized) - ' figureName],'units','normalized','position',[0 0 1 1]);
  for iScale = 1:nScales
    subplot(2,3,iScale)
    PF = kHz2scale{iScale}(psTwScale2kHz(output.pfOverlayScale{3}));
    distance = output.relativeDistancesToReversals(1,:);
    [p,~,mu] = polyfit(PF(~isnan(PF)),distance(~isnan(PF)),polyOrder);
    switch(params.cmPlotSyle)
      case 'scatter'
        plot(PF,distance,'ok');
      case 'histogram'
        histogram2(PF,distance,50,'XBinLimits',[min(PF) max(PF)],'YBinLimits',[-0.05 1.05],'displayStyle','tile');
        colorbar;
    end
    hold on
    f = linspace(min(PF),max(PF),100);
    plot(f,polyval(p,f,[],mu),'m','linewidth',2);
    plot(kHz2scale{iScale}(psTwScale2kHz(output.pfOverlayScale{1})),zeros(size(output.pfOverlayScale{1})),'ob');
    plot(kHz2scale{iScale}(psTwScale2kHz(output.pfOverlayScale{2})),ones(size(output.pfOverlayScale{2})),'or');
    ylim([-0.05 1.05]);
    xlabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
    ylabel('Normalized cortical distance');
  end

  if altFigures  % non-normalized cortical distance functions
    figure('name',['Reverse cortical distance function (vertices) - ' figureName],'units','normalized','position',[0 0 1 1]);
    for iScale = 1:nScales
      subplot(2,3,iScale)
      PF = kHz2scale{iScale}(psTwScale2kHz(output.pfOverlayScale{3}));
      distance = output.pathDistancesToReversals(1,:);
      [p,~,mu]=polyfit(distance(~isnan(PF)),PF(~isnan(PF)),polyOrder);
      switch(params.cmPlotSyle)
        case 'scatter'
          plot(distance,PF,'ok');
        case 'histogram'
          histogram2(distance,PF,50,'XBinLimits',[0 max(distance)*1.05],'YBinLimits',[min(PF) max(PF)],'displayStyle','tile');
          colorbar;
      end
      hold on
      d = linspace(min(distance),max(distance),100);
      plot(d,polyval(p,d,[],mu),'m','linewidth',2);
      xlabel('Cortical distance (mm)');
      ylabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
      colorbar;
    end
    
    figure('name',['Cortical distance function (vertices) - ' figureName],'units','normalized','position',[0 0 1 1]);
    for iScale = 1:nScales
      subplot(2,3,iScale)
      PF = kHz2scale{iScale}(psTwScale2kHz(output.pfOverlayScale{3}));
      distance = output.pathDistancesToReversals(1,:);
      [p,~,mu] = polyfit(PF(~isnan(PF)),distance(~isnan(PF)),polyOrder);
      switch(params.cmPlotSyle)
        case 'scatter'
          plot(PF,distance,'ok');
        case 'histogram'
          histogram2(PF,distance,50,'XBinLimits',[min(PF) max(PF)],'YBinLimits',[0 max(distance)*1.05],'displayStyle','tile');
          colorbar;
      end
      hold on
      f = linspace(min(PF),max(PF),100);
      plot(f,polyval(p,f,[],mu),'m','linewidth',2);
      xlabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
      ylabel('Cortical distance (mm)');
      colorbar;
    end
  end
  
  figure('name',['Gradient function (faces) - ' figureName],'units','normalized','position',[0 0 1 1]);
  for iScale = 1:nScales
    PF = output.pfAllRoisAllScalesFaces(iScale,:);
    PFgradient = output.pfGradientAllRoisAllScalesFaces(iScale,:);
%     PFgradient = 1./cmAllRoisAllScalesFaces(iScale,:);
    PF = PF(~isnan(PFgradient));
    PFgradient = PFgradient(~isnan(PFgradient));
    subplot(2,3,iScale)
    [p,~,mu] = polyfit(PF(~isnan(PF)),PFgradient(~isnan(PF)),polyOrder);
    switch(params.cmPlotSyle)
      case 'scatter'
        plot(PF,PFgradient,'ok');
      case 'histogram'
        histogram2(PF,PFgradient,50,'XBinLimits',[min(PF) max(PF)],'YBinLimits',[0 prctile(PFgradient,99)],'displayStyle','tile');
        colorbar;
    end
    hold on
    f = linspace(min(PF),max(PF),100);
    ylim([0 prctile(PFgradient,99)]);
    plot(f,polyval(p,f,[],mu),'m','linewidth',2);
    xlabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
    ylabel('Preferred frequency gradient (frequency units/mm)');
  end

  if altFigures
    figure('name',['Gradient function (vertices) - ' figureName],'units','normalized','position',[0 0 1 1]);
    for iScale = 1:nScales
      PF = pfAllRoisAllScalesVertices(iScale,:);
      PFgradient = 1./cmAllRoisAllScalesVertices(iScale,:);
      PF = PF(~isnan(PFgradient));
      PFgradient = PFgradient(~isnan(PFgradient));
      subplot(2,3,iScale)
      [p,~,mu] = polyfit(PF(~isnan(PF)),PFgradient(~isnan(PF)),polyOrder);
      switch(params.cmPlotSyle)
        case 'scatter'
          plot(PF,PFgradient,'ok');
        case 'histogram'
          histogram2(PF,PFgradient,50,'XBinLimits',[min(PF) max(PF)],'YBinLimits',[0 prctile(PFgradient,99)],'displayStyle','tile');
          colorbar;
      end
      hold on
      f = linspace(min(PF),max(PF),100);
      ylim([0 prctile(PFgradient,99)]);
      plot(f,polyval(p,f,[],mu),'m','linewidth',2);
      xlabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
      ylabel('Preferred frequency gradient (frequency units/mm)');
    end

    figure('name',['Gradient function (faces alt) - ' figureName],'units','normalized','position',[0 0 1 1]);
    for iScale = 1:nScales
      PF = output.pfAllRoisAllScalesFaces(iScale,:);
      PFgradient = 1./cmAllRoisAllScalesFaces2(iScale,:);
      PF = PF(~isnan(PFgradient));
      PFgradient = PFgradient(~isnan(PFgradient));
      subplot(2,3,iScale)
      [p,~,mu] = polyfit(PF(~isnan(PF)),PFgradient(~isnan(PF)),polyOrder);
      switch(params.cmPlotSyle)
        case 'scatter'
          plot(PF,PFgradient,'ok');
        case 'histogram'
          histogram2(PF,PFgradient,50,'XBinLimits',[min(PF) max(PF)],'YBinLimits',[0 prctile(PFgradient,99)],'displayStyle','tile');
          colorbar;
      end
      hold on
      f = linspace(min(PF),max(PF),100);
      ylim([0 prctile(PFgradient,99)]);
      plot(f,polyval(p,f,[],mu),'m','linewidth',2);
      xlabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
      ylabel('Preferred frequency gradient (frequency units/mm)');
    end
  end
  
  if altFigures
    figure('name',['Cortical magnification function (faces) - ' figureName],'units','normalized','position',[0 0 1 1]);
    for iScale = 1:nScales
      PF = output.pfAllRoisAllScalesFaces(iScale,:);
      CM = 1./output.pfGradientAllRoisAllScalesFaces(iScale,:);
%       CM = cmAllRoisAllScalesFaces(iScale,:);
      PF = PF(~isnan(CM));
      CM = CM(~isnan(CM));
      subplot(2,3,iScale)
      [p,~,mu] = polyfit(PF(~isnan(PF)),CM(~isnan(PF)),polyOrder);
      switch(params.cmPlotSyle)
        case 'scatter'
          plot(PF,CM,'ok');
        case 'histogram'
          histogram2(PF,CM,50,'XBinLimits',[min(PF) max(PF)],'YBinLimits',[0 prctile(CM,95)],'displayStyle','tile');
          colorbar;
      end
      hold on
      hold on
      f = linspace(min(PF),max(PF),100);
      ylim([0 prctile(CM,95)]);
      plot(f,polyval(p,f,[],mu),'m','linewidth',2);
      xlabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
      ylabel('Cortical magnification factor (mm/unit frequency)');
    end

    figure('name',['Cortical magnification function (vertices) - ' figureName],'units','normalized','position',[0 0 1 1]);
    for iScale = 1:nScales
      PF = pfAllRoisAllScalesVertices(iScale,:);
%       CM = 1./pfGradientAllRoisAllScalesVertices(iScale,:);
      CM = cmAllRoisAllScalesVertices(iScale,:);
      PF = PF(~isnan(CM));
      CM = CM(~isnan(CM));
      subplot(2,3,iScale)
      [p,~,mu] = polyfit(PF(~isnan(PF)),CM(~isnan(PF)),polyOrder);
      switch(params.cmPlotSyle)
        case 'scatter'
          plot(PF,CM,'ok');
        case 'histogram'
          histogram2(PF,CM,50,'XBinLimits',[min(PF) max(PF)],'YBinLimits',[0 prctile(CM,95)],'displayStyle','tile');
          colorbar;
      end
      hold on
      f = linspace(min(PF),max(PF),100);
      ylim([0 prctile(CM,95)]);
      plot(f,polyval(p,f,[],mu),'m','linewidth',2);
      xlabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
      ylabel('Cortical magnification factor (mm/unit frequency)');
    end

    figure('name',['Cortical magnification function (faces alt) - ' figureName],'units','normalized','position',[0 0 1 1]);
    for iScale = 1:nScales
      PF = output.pfAllRoisAllScalesFaces(iScale,:);
      CM = cmAllRoisAllScalesFaces2(iScale,:);
      PF = PF(~isnan(CM));
      CM = CM(~isnan(CM));
      subplot(2,3,iScale)
      [p,~,mu] = polyfit(PF(~isnan(PF)),CM(~isnan(PF)),polyOrder);
      switch(params.cmPlotSyle)
        case 'scatter'
          plot(PF,CM,'ok');
        case 'histogram'
          histogram2(PF,CM,50,'XBinLimits',[min(PF) max(PF)],'YBinLimits',[0 prctile(CM,95)],'displayStyle','tile');
          colorbar;
      end
      hold on
      hold on
      f = linspace(min(PF),max(PF),100);
      ylim([0 prctile(CM,95)]);
      plot(f,polyval(p,f,[],mu),'m','linewidth',2);
      xlabel(sprintf('Preferred frequency (%s)',scaleName{iScale}));
      ylabel('Cortical magnification factor (mm/unit frequency)');
    end
  end

end

if params.plotSurface
  %-------------------------- Plot reversal ROIs' locations on cortical patch
  m.verticesBase(:,2) = -1*m.verticesBase(:,2); %change orientation for display
  m.uniqueVerticesBase(:,2) = -1*m.uniqueVerticesBase(:,2); %change orientation for display

  % ROI patch
  % roiVertices = m.vertsToUnique(m.roiVertices{3});
  % roiFaces = m.faceIndexList((all(ismember(m.faceIndexList,roiVertices),2)),:);

  %guess what side of the brain we're on
  if ~isempty(strfind(baseCoordMap.outerCoordsFileName,'eft'))
    azimuth = -50;
  elseif ~isempty(strfind(baseCoordMap.outerCoordsFileName,'ight'))
    azimuth = 50;
  else
    azimuth = 0;
  end
  edgeColor = 'none';
  % edgeColor = 0.3*[1 1 1]; % uncomment this line to show dark grey edges on surface
  % first, reduce cortical patch to vertices within a certain distance of the gradient ROI
  maxDistance = 1.8;
  [reducedVertices,reducedFaces] = subsetMesh(m.verticesBase,m.faceIndexList,m.UniqueToVerts( union( find(any([m.dist{1};m.dist{2}]<maxDistance))', m.roiVertices{3}) ));
  [hSurfaceFigure,hSurface] = myMrPrintSurf(reducedVertices,reducedFaces, '', -40, azimuth, edgeColor);
  set(hSurfaceFigure,'name',figureName,'units','normalized','position',[0 0 1 1]);

  % highlight vertices belonging to the reversal ROIs
  hold on
  roiVertices1 = m.uniqueVerticesBase(m.roiVertices{1},:);
  roiVertices2 = m.uniqueVerticesBase(m.roiVertices{2},:);
  roiVertices3 = m.uniqueVerticesBase(m.roiVertices{3},:);
  % [lowFreqVertices,lowFreqFaces] = subsetMesh(m.verticesBase,m.faceIndexList,m.vertsToUnique(m.roiVertices{1}));
  % [highFreqVertices,highFreqFaces] = subsetMesh(m.verticesBase,m.faceIndexList,m.vertsToUnique(m.roiVertices{2}));
  [gradientVertices] = subsetMesh(m.verticesBase,m.faceIndexList,m.UniqueToVerts(m.roiVertices{3}));

%   [allROIvertices,allROIFaces] = subsetMesh(m.verticesBase,m.faceIndexList,m.vertsToUnique([m.roiVertices{1};m.roiVertices{2};m.roiVertices{3}]));
%   allROIsPFoverlay = [output.pfOverlayScale{1} output.pfOverlayScale{2} output.pfOverlayScale{3}]';
  [allROIvertices,allROIFaces] = subsetMesh(m.verticesBase,m.faceIndexList,m.UniqueToVerts([roiVerticesBeforeExclusion{1};roiVerticesBeforeExclusion{2};roiVerticesBeforeExclusion{3}]));
  allROIsPFoverlay = [pfOverlayScaleBeforeExclusion{1} pfOverlayScaleBeforeExclusion{2} pfOverlayScaleBeforeExclusion{3}]';

  % patch('vertices', lowFreqVertices, 'faces', lowFreqFaces,'FaceVertexCData', repmat([0 0 1],size(lowFreqVertices,1),1),'facecolor','interp','edgecolor','none','facealpha',.2);
  % patch('vertices', highFreqVertices, 'faces', highFreqFaces,'FaceVertexCData', repmat([1 0 0],size(highFreqVertices,1),1),'facecolor','interp','edgecolor','none','facvertsToUniqueealpha',.2);
  % patch('vertices', gradientVertices, 'faces', gradientFaces,'FaceVertexCData', output.pfOverlayScale{3}','facecolor','interp','edgecolor','none','facealpha',.4);
  hPF = patch('vertices', allROIvertices, 'faces', allROIFaces,'FaceVertexCData', allROIsPFoverlay,'facecolor','interp','edgecolor',0.3*[1 1 1],'facealpha',.8);
  if strcmp(params.estimatePFandTW,'given')
    colormap(viewGet(thisView,'overlayCmap',params.overlayList(1)));
  else
    colormap(parula(256));
  end
  material dull % shiny metal
  lighting phong % smoother map
  if ~ismember(params.CMmethodDepiction,{'vertex number','gradient','surface'})
    hLegend(1) = plot3(roiVertices1(:,1),roiVertices1(:,2),roiVertices1(:,3),'.b','markerSize',30);
    hLegend(2) = plot3(roiVertices2(:,1),roiVertices2(:,2),roiVertices2(:,3),'.r','markerSize',30);
    % hLegend(3) = plot3(gradientVertices(:,1),gradientVertices(:,2),gradientVertices(:,3),'.g');
    % legendsToPlot = true(1,3);
    legendsToPlot = logical([1 1 0]);
  else
    legendsToPlot = false;
  end
  nLegendsSoFar = size(legendsToPlot,2);
  
  if params.showRemovedAddedVertices   % display removed/added vertices
    legendStrings = {'Low-frequency vertex (kept)','High-frequency vertex (kept)','Gradient vertex (kept)',...
              'Low-frequency vertex (added)','Low-frequency vertex (removed)',...
              'High-frequency vertex (added)','High-frequency vertex (removed)','Gradient vertex (removed)'};
    legendsToPlot = [legendsToPlot false(1,5)];
    reversalColor = [0 0 1;1 0 0];
    for i = 1:2
      if ~isempty(gradientVerticesToRemove{i})
        hLegend(nLegendsSoFar + 5) = plot3(m.uniqueVerticesBase(gradientVerticesToRemove{i},1),m.uniqueVerticesBase(gradientVerticesToRemove{i},2),m.uniqueVerticesBase(gradientVerticesToRemove{i},3),'.','color',[0 1 0]*0.3,'markerSize',30);
        legendsToPlot(nLegendsSoFar + 5) = true;
      end
      if ~isempty(reversalVerticesRemoved{i})
        hLegend(nLegendsSoFar + 2+(i-1)*2) = plot3(m.uniqueVerticesBase(reversalVerticesRemoved{i},1),m.uniqueVerticesBase(reversalVerticesRemoved{i},2),m.uniqueVerticesBase(reversalVerticesRemoved{i},3),'.','color',reversalColor(i,:)*0.3,'markerSize',30);
        legendsToPlot(nLegendsSoFar + 2+(i-1)*2) = true;
      end
      if ~isempty(reversalVerticesAdded{i})
        hLegend(nLegendsSoFar + 1+(i-1)*2) = plot3(m.uniqueVerticesBase(reversalVerticesAdded{i},1),m.uniqueVerticesBase(reversalVerticesAdded{i},2),m.uniqueVerticesBase(reversalVerticesAdded{i},3),'.','color',reversalColor(i,:),'markerSize',30);
        legendsToPlot(nLegendsSoFar + 1+(i-1)*2) = true;
      end
    end
  else
    legendStrings = {'Low-frequency reversal','High-frequency reversal','Gradient'};
  end
  nLegendsSoFar = size(legendsToPlot,2);
  
  % cortical magnification computation illustrations
  switch(params.CMmethodDepiction)
    case {'vertex number','surface','distance'}
      % choose vertex/face 3/5 of the distance between low and high frequency reversal
      % but close to the middle of the ROI
      normalizedDistance = 3/5;
      roiCOM = mean(m.uniqueVerticesBase(m.roiVertices{3},:));
      % find point that is both close to the center of the ROI and a certain distance from low-frequency reversal
      [~,sortingDistanceToCOM] = sort(sqrt(sum((m.uniqueVerticesBase(m.roiVertices{3},:)-roiCOM)'.^2)));
      tolerance = 0.01;
      point = sortingDistanceToCOM(find(abs(output.relativeDistancesToReversals(1,sortingDistanceToCOM)-normalizedDistance)<tolerance,1,'first'));
      if isempty(point)
        keyboard; % if stopped here, didn't find a point that is close enough to the desired normalized distance,
        % so need to change the tolerance or implement an adaptive version of the above line (increase tolerance until a point is found)
      end
      % [~, point] = min( abs(output.relativeDistancesToReversals(1,:)-normalizedDistance)*output.meanPathDistanceBetweenReversals + sqrt(sum((m.uniqueVerticesBase(m.roiVertices{3},:)-roiCOM)'.^2)) ); % previous version
      thisPoint = m.uniqueVerticesBase(m.roiVertices{3}(point),:);
  end

  if ismember(params.CMmethodDepiction,{'vertex number','surface'})
      % First we calculate the frequency bin in the units of the PF data displayed on the patch
      % we assume there are 24 bins between 0.1 and 8 kHz, equidistant on an octave scale
      binEdges = kHz2psTwScale(2.^linspace(log2(0.1),log2(8),25));
      % choose the bin that's equivalent to the normalized distance defined above, but on the frequency range between average low- and high-frequency reversal's PF
      targetPF = mean(output.pfOverlayScale{1}) + normalizedDistance*(mean(output.pfOverlayScale{2}) - mean(output.pfOverlayScale{1}));
      whichBin = find(binEdges<targetPF,1,'last');
  end

  switch(params.CMmethodDepiction)
    case 'distance'
      % highlight the chosen vertex
      plot3(thisPoint(:,1),thisPoint(:,2),thisPoint(:,3),'.g','markerSize',60);
      % highlight shortest path from LF and HF reversal to highlighted point
      thisPath = m.uniqueVerticesBase(m.rte{1,3}{whichReversalStartVertex(1,point),point},:);
      plot3(thisPath(:,1),thisPath(:,2),thisPath(:,3),'k','linewidth',5);
      thisPath = m.uniqueVerticesBase(m.rte{2,3}{whichReversalStartVertex(2,point),point},:);
      plot3(thisPath(:,1),thisPath(:,2),thisPath(:,3),'k','linewidth',5);

    case 'vertex number' % Highlight all vertices in the mesh that belong to the same frequency bin
      whichVertices = allROIsPFoverlay > binEdges(whichBin) & allROIsPFoverlay < binEdges(whichBin+1);
      legendsToPlot = [legendsToPlot true];
      hLegend(nLegendsSoFar+1) = plot3(allROIvertices(whichVertices,1),allROIvertices(whichVertices,2),allROIvertices(whichVertices,3),'.m','markerSize',40);
      legendStrings{nLegendsSoFar+1} = sprintf('%3g-%3g kHz PF bin',psTwScale2kHz(binEdges(whichBin)),psTwScale2kHz(binEdges(whichBin+1)));

    case 'surface' % Highlight all faces belonging to the same frequency bin
      legendsToPlot = [legendsToPlot true];
      whichFaces = pfFaceOverlayScale > binEdges(whichBin) & pfFaceOverlayScale < binEdges(whichBin+1);
      hLegend(nLegendsSoFar+1) = patch('vertices', m.uniqueVerticesBase, 'faces', allRoisFaces(whichFaces,:),'FaceVertexCData', pfFaceOverlayScale(whichFaces),'FaceColor','flat','edgecolor',[1 1 1],'linewidth',2);
      set(hPF,'facealpha',.8);

    case 'gradient' % display gradient vector at the center of each mesh triangle
      faceCenters = reshape(mean(reshape(m.uniqueVerticesBase(allRoisFaces,:),[],3,3),2),[],3); % coordinates of the centers of each face
      whichScale = find(ismember(scaleName,params.overlayUnits),1); % on which scale PFs are plotted in the figure
      pfGradient = frequencyGradient{whichScale};
      pfGradient(:,2) = -1*pfGradient(:,2); % change orientation for display
      gradientScaling = 3*median(sqrt(output.faceAreas))./median(sqrt(sum(pfGradient.^2,2))); % find a good scaling factor for the gradient vectors
      legendsToPlot = [legendsToPlot true];
      hLegend(nLegendsSoFar+1) = quiver3(faceCenters(:,1),faceCenters(:,2),faceCenters(:,3), ...
        pfGradient(:,1),pfGradient(:,2),pfGradient(:,3),gradientScaling,'k','LineWidth',3);
      legendStrings{nLegendsSoFar+1} = 'Local frequency gradient';
      set(hPF,'facealpha',.6);
      % set(hSurface,'facealpha',.5) % If I try setting the alpha of the grey patch ot anything other than 0 or 1, than the PF patch stops showing
      % set(hSurface,'Visible','off'); % so hiding it fully
  end

  legend(hLegend(legendsToPlot),legendStrings(legendsToPlot),'location','EastOutside')

  % nColors=length(paths);
  % cmap = hsv(nColors);
  % for i=1:length(paths)
  %   thisPath = m.uniqueVerticesBase(paths{i},:);
  %   plot3(thisPath(:,1),thisPath(:,2),thisPath(:,3),'color',cmap(rem(i,nColors)+1,:),'linewidth',2);
  % end
  %
end

%%%%%%%%%%%%%%%% Modified pred2path function %%%%%%%%%%%%%%%%%%%%
% does not reorder the source vertices in the output

function rte = pred2path(P,s,t)
%PRED2PATH Convert predecessor indices to shortest paths from 's' to 't'.
%   rte = pred2path(P,s,t)
%     P = |s| x n matrix of predecessor indices (from DIJK)
%     s = FROM node indices
%       = [] (default), paths from all nodes
%     t = TO node indices
%       = [] (default), paths to all nodes
%   rte = |s| x |t| cell array of paths (or routes) from 's' to 't', where
%         rte{i,j} = path from s(i) to t(j)
%                  = [], if no path exists from s(i) to t(j)
%
% (Used with output of DIJK)

% Copyright (c) 1994-2006 by Michael G. Kay
% Matlog Version 9 13-Jan-2006 (http://www.ie.ncsu.edu/kay/matlog)

% Input Error Checking ****************************************************
error(nargchk(1,3,nargin));

[rP,n] = size(P);

if nargin < 2 || isempty(s), s = (1:n)'; else s = s(:); end
if nargin < 3 || isempty(t), t = (1:n)'; else t = t(:); end

if any(P < 0 | P > n)
   error(['Elements of P must be integers between 1 and ',num2str(n)]);
elseif any(s < 1 | s > n)
   error(['"s" must be an integer between 1 and ',num2str(n)]);
elseif any(t < 1 | t > n)
   error(['"t" must be an integer between 1 and ',num2str(n)]);
end
% End (Input Error Checking) **********************************************

rte = cell(length(s),length(t));

[idx_i,idxs] = find(P==0);
idxs(idx_i) = idxs;   %JB: Matlab returns i and j indices sorted along the second dimension (j)
                      %    in order to keep the ordering of the input, need to re-order j indices by i indices

for i = 1:length(s)
%    if rP == 1
%       si = 1;
%    else
%       si = s(i);
%       if si < 1 | si > rP
%          error('Invalid P matrix.')
%       end
%    end
   si = find(idxs == s(i));
   for j = 1:length(t)
      tj = t(j);
      if tj == s(i)
         r = tj;
      elseif P(si,tj) == 0
         r = [];
      else
         r = tj;
         while tj ~= 0
            if tj < 1 || tj > n
               error('Invalid element of P matrix found.')
            end
            r = [P(si,tj) r];
            tj = P(si,tj);
         end
         r(1) = [];
      end
      rte{i,j} = r;
   end
end

if length(s) == 1 && length(t) == 1
   rte = rte{:};
end

%rte = t;
while 0%t ~= s
   if t < 1 || t > n || round(t) ~= t
      error('Invalid "pred" element found prior to reaching "s"');
   end
   rte = [P(t) rte];
   t = P(t);
end
