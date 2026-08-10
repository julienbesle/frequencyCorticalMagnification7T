% convertFromFlatVolumeToBase.m
%
%        $Id: convertFromFlatVolumeToBase.m 1969 2010-12-19 19:14:32Z julien $ 
%      usage: transformedRoi = convertFromFlatVolumeToBase(roi,<rotate>)
%         by: julien besle
%       date: 14/04/2014
%
%    purpose: 
%      input:   

function outputRoi = convertFromFlatVolumeToBase(roi,rotate)

if ~ismember(nargin,[1 2])
  help convertFromVolumeToFlat;
  return
end
  

thisView=getMLRView;
flatVolName = viewGet(thisView,'groupName'); % Flat volume group/base name (we assume this is the current group)
flatVolNum = viewGet(thisView,'baseNum',flatVolName);

% ROI coordinates must be converted to the flat volume space
% (I had originally assumed they were in that space by default, but that's not necessarily the case, apparently, not sur why)
% This is adapted from function getROIBaseCoords (in refreshMLRDisplay.m)
% find the ROI number
[~,roiNum] = ismember(roi.name,viewGet(thisView,'roiNames'));
if numel(roiNum) ~= 1
  keyboard % can't find the ROI, or there are several ROI with the same name (this shouldn't happen, but who knows?)
end
base2roi = viewGet(thisView,'base2roi',roiNum,flatVolNum);
baseVoxelSize = viewGet(thisView,'baseVoxelSize',flatVolNum);
if ~isempty(base2roi)
  % Use xformROI to supersample the coordinates
  roiFlatVolCoords = round(xformROIcoords(roi.coords,inv(base2roi),roi.voxelSize,baseVoxelSize));
end

flatName=flatVolName(1:end-6); % That's the original flat map name
flatNum=viewGet(thisView,'basenum',flatName);

if ieNotDefined('rotate')
  rotate = viewGet(thisView,'baserotate',flatNum);
end

baseCoordMap = viewGet(thisView,'baseCoordmap',flatNum);
baseCoordMapIndices = reshape(permute(baseCoordMap.coords,[1 2 5 3 4]),[numel(baseCoordMap.coords)/3 3]);
flatVolDims = [size(baseCoordMap.coords,1) size(baseCoordMap.coords,2) size(baseCoordMap.coords,5)];
outsideVoxels = find(roiFlatVolCoords(1,:)>flatVolDims(1)|roiFlatVolCoords(2,:)>flatVolDims(2)|roiFlatVolCoords(3,:)>flatVolDims(3));
if ~isempty(outsideVoxels)
  mrWarnDlg(sprintf('(convertFromFlatVolumeToBase) there are %d ROI voxels outside the flat volume (%.1f%%), removing...',numel(outsideVoxels),numel(outsideVoxels)/size(roiFlatVolCoords,2)*100));
  roiFlatVolCoords(:,outsideVoxels)=[];
%   roiFlatVolCoords(3,:) = roiFlatVolCoords(3,:)-3;
end
% roiFlatVolCoords(3,:)=roiFlatVolCoords(3,:)+1;
roiCoordsIndices=sub2ind([size(baseCoordMap.coords,1) size(baseCoordMap.coords,2) size(baseCoordMap.coords,5)],roiFlatVolCoords(1,:)',roiFlatVolCoords(2,:)',roiFlatVolCoords(3,:)');

if rotate~=0 % rotate coordinates so that they match the unrotated flat map
  roiMask=zeros([size(baseCoordMap.coords,1) size(baseCoordMap.coords,2) size(baseCoordMap.coords,5)]);
  roiMask(roiCoordsIndices)=1;
  for iDepth = 1:size(baseCoordMap.coords,5) 
    roiMask(:,:,iDepth) = imrotate(roiMask(:,:,iDepth),rotate*-1,'bilinear','crop');
  end
  roiCoordsIndices = find(roiMask);
end

outputRoi=roi;
outputRoi.coords = baseCoordMapIndices(roiCoordsIndices,:)';
outputRoi.coords = [outputRoi.coords; ones(1,size(outputRoi.coords,2))];
outputRoi.xform = viewGet(thisView,'basexform',flatNum);
outputRoi.voxelSize = viewGet(thisView,'basevoxelsize',flatNum);

