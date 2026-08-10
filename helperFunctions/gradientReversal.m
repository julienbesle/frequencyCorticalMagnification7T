% gradientReversal.m: finds gradient reversals in (optionally smoothed) 2D map (input overlay is averaged in 3rd dimension). 
%                     Sign maps are computed and passed through an edge detector for 180 directions. 
%                     Outputs are - the (smoothed) map (repeated in the 3rd dimension)
%                                 - the number of directions in which an edge is found (see Schoenwiesner, Cerebral Cortex, 2015)
%                                 - the difference between the average direction of the reversal and the local gradient direction minus 90 deg
%                                 - gradient direction
%                                 - gradient magnitude
%                     Additional input argument (optional): - 3D smoothing factor
%                                                           - method for detecting edges (default: 'sobel', see edge.m)
%
%        $Id: gradientReversal.m 2733 2013-05-13 11:47:54Z julien $
%           

function [gradientMag,gradientDir,gradientAngle,smoothed,reversalDir,angleRange,angleDiff]=gradientReversal(overlay,FWHM,edgeMethod)

corticalDepths = 3:9;

%create mask by excluding pixels with data in none of the cortical depths
singleDepthMask = all(isnan(overlay(:,:,corticalDepths)),3);

if ~ieNotDefined('FWHM')
  smoothed = nanconvn(overlay,gaussianKernel(FWHM),'same');
else
  smoothed = overlay;
end
if ieNotDefined('edgeMethod')
  edgeMethod = 'sobel';
end
averagedOverlay=nanmean(smoothed(:,:,corticalDepths),3);

[gradientMag,gradientDir] = imgradient(averagedOverlay);

nAngles=180;
angles=linspace(0,180,nAngles+1);
angles = angles(1:end-1);
signMaps=NaN([size(averagedOverlay) nAngles]);
edges=NaN([size(averagedOverlay) nAngles]);
cAngle=0;
hWaitBar = mrWaitBar(-inf,sprintf('(gradientReversal) Computing sign maps for %d angles',nAngles));
for iAngle=angles
  cAngle=cAngle+1;
  %the sign map for a given gradient angle is a binary map of all gradient 
  %angles that are within 90 deg of this angle
  signMaps(:,:,cAngle)=floor(mod( (gradientDir-iAngle+90)/180 ,2));
  thisSignMap=signMaps(:,:,cAngle);
  thisSignMap(isnan(thisSignMap))=0;
  edges(:,:,cAngle)=edge(thisSignMap,edgeMethod);
  mrWaitBar( cAngle/numel(angles), hWaitBar);
end
mrCloseDlg(hWaitBar);

%compute the range of gradient angles that give edges at each (flat map) voxel
angleRange = nansum(edges,3)*180/nAngles;
% %exclude voxels that have non-contiguous ranges
% angleRange(sum(logical(diff(edges,1,3)),3)~=2)=0;
angleRange(singleDepthMask)=NaN;

%transform direction into angle between 0 and 180
gradientAngle = gradientDir;
gradientAngle(gradientAngle<0)=gradientAngle(gradientAngle<0)+180;

%The reversal direction is the average of all angles used weighted by the edge found at each angle
%first we multiply the angle by 2 and convert it to radians so that it
%spreads from -pi to pi, then sum in the complex plane using the
%detected edges as amplitudes (weights), take the angle of the vector sum
%and convert it back to degrees
reversalDir = rad2deg(angle(sum(edges.*exp(i.*deg2rad(repmat(permute(angles*2,[1 3 2]),[size(gradientDir) 1]))),3)));
%reconvert negative angles to angles between 180 and 360 
reversalDir(reversalDir<0) = reversalDir(reversalDir<0)+360;
% and divide by 2 to get the reversal direction
reversalDir = reversalDir/2;
reversalDir(~any(edges,3))=NaN;
% reversalDir=nansum(edges.*repmat(permute(angles,[1 3 2]),[size(averagedOverlay) 1]),3)./nansum(edges,3);
% reversalDir(isnan(reversalDir))=gradientAngle(isnan(reversalDir))-90;
reversalDir(singleDepthMask)=NaN;
angleDiff=abs(reversalDir-gradientAngle);

% arrayviewer(angleRange);
% arrayviewer(abs(reversalDir-gradientAngle));

angleDiff = repmat(angleDiff,[1 1 11]);
angleRange = repmat(angleRange,[1 1 11]);

gradientMag = repmat(gradientMag,[1 1 11]);
gradientDir = repmat(gradientDir,[1 1 11]);
gradientAngle = repmat(gradientAngle,[1 1 11]);
reversalDir = repmat(reversalDir,[1 1 11]);

smoothed(isnan(overlay))=NaN;
gradientMag(isnan(overlay))=NaN;
gradientDir(isnan(overlay))=NaN;
gradientAngle(isnan(overlay))=NaN;


%%%%%%%%%%%%%%%%%
%    deg2rad    %
%%%%%%%%%%%%%%%%%
function radians = deg2rad(angle)

radians = (angle/180)*pi;

%%%%%%%%%%%%%%%%%
%    rad2deg    %
%%%%%%%%%%%%%%%%%
function degrees = rad2deg(angle)

degrees = (angle*180)/pi;

