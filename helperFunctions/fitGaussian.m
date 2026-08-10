% 
% [params,gaussFunction] = fitGaussian(x,y,fixedCentre,fitOffset,meanRange,stdRange,offsetRange,verbose)
%

function [params, adjustedR2, gaussFunction, r2] = fitGaussian(varargin) % have to use variable input arguments because of the parfor loop

for i = 1:nargin
  switch(i)
    case 1
      x = varargin{i};
    case 2
      y = varargin{i};
    case 3
      fitOffset = varargin{i};
    case 4
      meanRange = varargin{i};
    case 5
      stdRange = varargin{i};
    case 6
      offsetRange = varargin{i};
    case 7
      verbose = varargin{i};
  end
end
debug = false; % set this to true to skip parallel computing in order to debug (still need to replace parfor by for to debug within the loop)

nMinFitsParallel = 5000; % minimum number of fits to use parallel computing (below this number, starting the parallel pool is likely to take more time than the gain from parallel computing)
if ieNotDefined('fitOffset')
  fitOffset = false;
end
if ieNotDefined('verbose')
  verbose = false;
end
if ieNotDefined('meanRange')
  meanRange = [-inf inf];
end
if ieNotDefined('stdRange')
  stdRange = [0 inf];
end
if ieNotDefined('offsetRange')
  offsetRange = [NaN inf];
elseif numel(offsetRange)==1 % this argument used to be offsetMax only
  offsetRange = [NaN offsetRange];
end

%Gaussian function
if fitOffset
  gaussFunction = @(params,x) params(4) + params(3) * exp(-(x-params(1)).^2/2/params(2)^2);
  nParams = 4;
else
  gaussFunction = @(params,x) params(3) * exp(-(x-params(1)).^2/2/params(2)^2);
  nParams = 3;
end
%params(1) is the mean
%params(2) is the std-deviation
%params(3) is a scaling  factor
%params(4) is a constant term and is set to 0

if numel(meanRange)==1
  meanRange = [meanRange meanRange];
end
if diff(meanRange)==0
  nParams = nParams-1;
end

y = double(y);
x = double(x);

% collapse first and third dimension
sizeY = size(y);
if length(sizeY)==2
  sizeY(3) = 1;
end
y = reshape(permute(y,[1 3 2]),sizeY(3)*sizeY(1),sizeY(2));
% remove rows with only NaNs
isNaN = all(isnan(y),2);
y(isNaN,:) = [];

%normalize values before fitting (otherwise fitting fails with small values)
maxValues = max(abs(max(y,[],2)),abs(min(y,[],2)));
y = y./repmat(maxValues,[1 size(y,2)]);

nFits = size(y,1);
if nFits<nMinFitsParallel || debug
  numWorkers = 0; % if number of fits is reasonably small, do not start the parallel pool
else
  numWorkers = inf; % otherwise use maximum available number of workers
  parallelPool = parpool; % start the parallel pool
end

% create data queue to receive data from the parallel workers (somehow this is needed even if verbose is false, when the parallel pool is running)
dataQueue = parallel.pool.DataQueue; % this requires Matlab version 9.2 and above
if verbose
  hWaitBar = mrWaitBar(-inf,'(fitGaussian) fitting Gaussians...');
  afterEach(dataQueue, @nUpdateWaitbar); % each time data is received, update the waitbar
  counter = 0;
end
  % function to update the waitbar
  function nUpdateWaitbar(~)
    counter = counter + 1;
    mrWaitBar( counter/nFits, hWaitBar);
  end

params = nan(nFits,4);
rss = nan(nFits,1);
fitErrors = false(nFits,1);
errorMessages = cell(nFits,1);
options = optimset('Display','off');
if debug
  h=figure;
else
  h=gobjects(1);
end
parfor(i=1:nFits,numWorkers)
% for i=1:nFits
  if verbose %(I'm not sure this logical flag is actually taken into account when running the parallel pool)
    send(dataQueue,i); % send data to update the waitbar
  end
  initialParams = [meanRange(1) mean(diff(x)) 1 0];
  if meanRange(1)~=meanRange(2) %initialize center parameter using centroid
    thisY = y(i,:);
    thisY(thisY<0 | isnan(thisY)) = 0; %make sure there are no negative values
    initialParams(1) = sum(thisY.*x,2)./sum(thisY,2);
  end
  offsetMax = offsetRange(2)/maxValues(i); % scale offset fitting bounds
  if isnan(offsetRange(1))
    offsetMin = min(0,min(y(i,:)));
  else
    offsetMin = offsetRange(1)/maxValues(i);
  end
  notNans = ~isnan(y(i,:));
  if nnz(notNans)>=length(initialParams)
    try
      [params(i,:),rss(i)] = lsqcurvefit(gaussFunction,initialParams,x(notNans),y(i,notNans),[meanRange(1) stdRange(1) 0 offsetMin],[meanRange(2) stdRange(2) inf offsetMax],options);
    catch errorID
      fitErrors(i) = i;
      errorMessages{i} = errorID.message;
      params(i,:) = NaN;
      rss(i) = NaN;
    end
    % replace the parfor loop by a for loop to use the following:
    if debug && false % set some conditions for which we want to display the fit [e.g. params(i,2)>1000 && any(y(i,6:8)==1)]
      hold off;
      xHiRes = x(1)-.5*mean(diff(x)):.1*mean(diff(x)):x(end)+.5*mean(diff(x));
      plot(xHiRes([1 end]),[0 0],':k');
      hold on;
      plot(xHiRes,gaussFunction(params(i,:),xHiRes),'lineWidth',2);
      plot(x(notNans),y(i,notNans),'o','lineWidth',2);
      ylim([-1 1]);
      if strcmp(input('Enter debug mode? (n) ','s'),'y')
        keyboard
      end
      cla(h)
    end
  end
end
if debug
  close(h);
end
if verbose
  mrCloseDlg(hWaitBar);
end
if nFits>=nMinFitsParallel  && ~debug
  delete(parallelPool);
end
if nnz(fitErrors)
  mrWarnDlg(sprintf('(fitGaussian) There were %d/%d fitting errors (%.2f%%)',nnz(fitErrors),nFits,nnz(fitErrors)/nFits*100));
  for i = find(fitErrors)'
    fprintf('\tVoxel #%i/%i: %s\n',i,nFits,errorMessages{i});
  end
end

params(:,3) = params(:,3).*maxValues; %de-normalize scaling parameter
params(:,4) = params(:,4).*maxValues; %de-normalize constant parameter (unused for the moment)

% put back the NaNs
paramsWithNaNs = nan(sizeY(1)*sizeY(3),4);
paramsWithNaNs(~isNaN,:) = params;
params = paramsWithNaNs;

%compute r2
r2 = nan(sizeY(1)*sizeY(3),1);
r2(~isNaN) = 1 - (rss ./ nansum( (y - nanmean(y,2) ).^2 ,2) );
n = sum(~isnan(y),2);
adjustedR2 = nan(sizeY(1)*sizeY(3),1);
adjustedR2(~isNaN) = 1 - (1 - r2(~isNaN)).* ( n - 1) ./ (n - nParams - 1);

% reshape output
params = permute(reshape(params,sizeY(1),sizeY(3),4),[1 3 2]);
r2 = permute(reshape(r2,sizeY(1),sizeY(3)),[1 3 2]);
adjustedR2 = permute(reshape(adjustedR2,sizeY(1),sizeY(3)),[1 3 2]);

end
