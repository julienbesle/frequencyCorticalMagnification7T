%
% [preferredStimulus, tuningWidth, scaling, offset, adjustedR2, r2, gaussFunction] = estimatePSandTW(stimuli, responses, <method, negativeMethod, psRange, twMax, fitOffset, offsetRange,verbose>)
%
%
function [preferredStimulus, tuningWidth, scaling, offset, adjustedR2, r2, gaussFunction] = ...
         estimatePSandTW(stimuli, responses, method, negativeMethod, psRange, twMax, fitOffset, offsetRange,verbose)

if ieNotDefined('negativeMethod') % method to deal with negative values
  if nargout==1
    negativeMethod = 'Subtract minimum';
  else
    negativeMethod = 'Subtract negative minimum';% if estimating sigma, offset the curves to only remove negative values
  end
end
gaussFunction = [];
if ieNotDefined('method')
    method = 'debiased centroid';
end
if ieNotDefined('fitOffset')
    fitOffset = false;
end
if ieNotDefined('offsetRange')
    offsetRange = [];
end
if ieNotDefined('verbose')
    verbose = [];
end

nStimuli = size(responses,2);
% nVoxels = size(responses,1);
if ismember(lower(method),{'debiased centroid','fit gaussian'})
  if ieNotDefined('psRange') 
    stimulusRange = stimuli(end)-stimuli(1);
    psRange = [stimuli(1)-stimulusRange*.3 stimuli(end)+stimulusRange*.3];
  end
  if numel(psRange)==1
    psRange = [psRange psRange];
  end
  if ieNotDefined('twMax') 
    twMax = stimuli(end);
  end
  populationPS = linspace(psRange(1),psRange(2),100);
  populationTW = linspace(0,twMax,51);
  populationTW = populationTW(2:end);
end

switch(lower(method))
  case 'max'
    [~, preferredStimulus] = max(responses,[],2);
    preferredStimulus = stimuli(preferredStimulus)';
    tuningWidth = nan(size(preferredStimulus));
    scaling = nan(size(preferredStimulus));
    offset = nan(size(preferredStimulus));
    adjustedR2 = nan(size(preferredStimulus));
    r2 = nan(size(preferredStimulus));
    
  case {'humphries','centroid','debiased centroid'}
    
    if strcmpi(method,'humphries')
      responses(responses<repmat(nanmean(responses,2),1,nStimuli)) = NaN;
    end
    
    [preferredStimulus, tuningWidth] = weightedMeanStdModel(stimuli,responses,negativeMethod);
    
    if strcmpi(method,'debiased centroid')
      if verbose
        fprintf('(estimatePSandTW) Correcting for bias ...');
      end
      [sampleAverages,sampleStddevs] = meanEstimationBias(populationPS,populationTW,stimuli);
      [preferredStimulus, tuningWidth] = debiasCentroidSpread(preferredStimulus,tuningWidth, populationPS, populationTW,sampleAverages,sampleStddevs);
      if verbose
        fprintf('Done\n');
      end
    end
    
    scaling = nan(size(preferredStimulus));
    offset = nan(size(preferredStimulus));
    adjustedR2 = nan(size(preferredStimulus));
    r2 = nan(size(preferredStimulus));

  case 'fit gaussian'
    [params, adjustedR2, gaussFunction, r2] = fitGaussian(stimuli,responses,fitOffset,psRange,[0 twMax],offsetRange,verbose);
    preferredStimulus = params(:,1);
    tuningWidth = params(:,2);
    scaling = params(:,3);
    offset = params(:,4);

end

