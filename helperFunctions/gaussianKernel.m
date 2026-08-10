% function kernel = gaussianKernel(FWHM)
%
% returns 2D/3D Gaussian kernel
% The number of dimensions of the returned kernel matches the number of dimensions in the input FWHM
% (unless FWHM is a scalar, in which case a 3D kernel is returned with the same FWHM in all 3 dimensions)
% A zero in one of the dimensions means that the kernel will be padded with 0s in that dimension
% Kernel coefficients are normalized such that they sum to 1
% Kernel size is twice the FHWM + 1


function kernel = gaussianKernel(FWHM)

sigma_d = FWHM/2.35482;
w = ceil(FWHM); % deals with resolutions that are not integer
% make the gaussian kernel large enough for FWHM
if length(w)==1
  w = [w w w];
  sigma_d = [sigma_d sigma_d sigma_d];
elseif length(w) == 2
  w = [w 0];
end
% if FWHM is 0 on any dimension, set sigma_d to some arbitrary value
sigma_d(w==0)=1;
kernelDims = 2*w+1;
kernelCenter = ceil(kernelDims/2);
[X,Y,Z] = meshgrid(1:kernelDims(1),1:kernelDims(2),1:kernelDims(3));
kernel = exp(-((X-kernelCenter(1)).^2/(2*sigma_d(1)^2)+(Y-kernelCenter(2)).^2/(2*sigma_d(2)^2)+(Z-kernelCenter(3)).^2/(2*sigma_d(3)^2))); %Gaussian function
kernel = kernel./sum(kernel(:));
if any(kernelDims<2) && length(FWHM) ~= 2
  % any singleton dimension (meaning FWHM=0 in that dimension) is flanked with zeroes
  % which results in no convolution in that dimension
  kernel2Dims = max(kernelDims,3);
  kernel2 = zeros(kernel2Dims);
  kernel2Start = (kernel2Dims-kernelDims)/2+1;
  kernel2Stop = kernel2Start+kernelDims-1;
  kernel2(kernel2Start(1):kernel2Stop(1),kernel2Start(2):kernel2Stop(2),kernel2Start(3):kernel2Stop(3)) = kernel;
  kernel = kernel2;
end
