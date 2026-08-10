
% returns frequency (in kHz) corresponding to a number of DLFs above 0 kHz
% after either Nelson et al. (1983) or Micheyl et al. (2012) (see nDlf.m for explanations)
%
% This is done by numerically inverting (interpolating) the corresponding nDLF functions (rather than algebraically like invNErb.m)
% in a given range (expressed in nDLFs)

function f = invNDlf(dlf,equation,fkHzRange,nSteps)

if ~exist('equation','var') || isempty(equation)
  equation = 'M12';
end
if ~exist('fkHzRange','var') || isempty(fkHzRange)
  fkHzRange = [0.02 20];
end
if ~exist('nSteps','var') || isempty(nSteps)
  nSteps = 10000; % this is the number of steps necessary to get an accurate conversion to the 4-5th decimal for high frequencies
end

switch(equation)
  case {'N83','M12'}
    
    frequencies = logspace(log10(fkHzRange(1)),log10(fkHzRange(end)),nSteps);
    nDLFs = nDlf(frequencies,equation);

    f = interp1(nDLFs,frequencies,dlf,'linear','extrap');
    
  otherwise
    error('(invNErb) Unknown equation ''%s''\n',equation);

end
