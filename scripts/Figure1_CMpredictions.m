figurePath = 'C:\Users\jbesle\OneDrive - University of Plymouth\Papers\Cortical magnification\Figures\SVGs from Matlab';
exportFigure = false;

nFreqs = 100; % number frequency steps
xScale = 'log'; % 'log' or 'linear'
integrationZeroFreqHz = 40; % set ERB/DLF number functions to 0 at 40 Hz
magnificationUnit = 'Hz'; % 'Hz' or 'octaves': whether the predicted magnification function is expressed in ERB/DLF per Hz or per octave
scaleDistance = true; % scale cortical magnification and mapping functions so they approximatly match our empirical fMRI estimates (see distanceScaling variable below

stimStartFreqKHz = .25;    %
stimEndFreqKHz = 6;        %
stimulusScale = 'ERB'; % this is only used to compute the start and end frequencies of the plots (to be the same as when using cmPlot.m)
nStimFreqs = 7;            %
freqStimMargin = 1.2;  %
% function to transform stimulus scale to kHz scale
switch(stimulusScale)
  case 'ERB'
    stim2kHz = @(nStims) invNErb( nErb(stimStartFreqKHz) + (nStims-1) / (nStimFreqs-1) * (nErb(stimEndFreqKHz)-nErb(stimStartFreqKHz)));
    kHz2stim = @(fKHz) (nErb(fKHz) -  nErb(stimStartFreqKHz)) * (nStimFreqs-1) / (nErb(stimEndFreqKHz)-nErb(stimStartFreqKHz)) + 1;
  case 'log'
    stim2kHz = @(nStims) exp( log(stimStartFreqKHz) + (nStims-1) / (nStimFreqs-1) * (log(stimEndFreqKHz)-log(stimStartFreqKHz)));
    kHz2stim = @(fKHz) (log(fKHz) -  log(stimStartFreqKHz)) * (nStimFreqs-1) / (log(stimEndFreqKHz)-log(stimStartFreqKHz)) + 1;
end

% logFrequenciesKHz = [log2(stimStartFreqKHz) log2(stimEndFreqKHz)];
% stimSep = diff(logFrequenciesKHz)/(nStims-1);
% logFrequenciesKHz = linspace(logFrequenciesKHz(1)-freqStimMargin*stimSep,logFrequenciesKHz(2)+freqStimMargin*stimSep,nFreqs);

startFreqKHz = stim2kHz(kHz2stim(stimStartFreqKHz) - freqStimMargin); % lowest binning PF in stimulus space
if startFreqKHz < 0 % check that the lowest frequency is positive. If not,
  freqStimMargin = floor(2*(kHz2stim(stimStartFreqKHz) - kHz2stim(0)))/2; % find the largest margin resulting in a positive starting frequency
  startFreqKHz = stim2kHz(kHz2stim(stimStartFreqKHz) - freqStimMargin); % recalculate bin start
  fprintf('(Figure1_CMpredictions) Resetting binMarginStim parameter to %.1f to avoid negative frequencies\n',params.binMarginStim);
end
endFreqKHz = stim2kHz(kHz2stim(stimEndFreqKHz) + freqStimMargin); % highest binning PF in stimulus space

logFrequenciesKHz = linspace(log2(startFreqKHz),log2(endFreqKHz),nFreqs);
linFrequenciesHz = 2.^logFrequenciesKHz*1000;

equationNames = cell(0);
equations = cell(0);
distEquations = cell(0);
colorOrder = zeros(0,3);
lineStyles = cell(0);
distanceScaling = zeros(0,1); % these constants were chosen based both on the observed constant (e.g. 0.008 mm/DLF) and also finte-tuned so that all distance functions end at 10 mm at 10 kHz
equationNames{end+1} = 'Weber''s law (10%)';
equations{end+1} = @(fHz)0.1*(fHz);
distEquations{end+1} = @(fHz)10*log(fHz) - 10*log(integrationZeroFreqHz); % integral of 1/(0.1*(f+1)) = 10/(f+1) -> 10*log(f+1)
colorOrder(end+1,:) = [0 0 0];
lineStyles{end+1} = '--';
distanceScaling(end+1) = 2.48 * log(2) / 10; % scaling factor in mm/octave,  multiplied by log(2)/10 to first convert from 10 * natural log to log of base 2 (i.e. octaves)
equationNames{end+1} = 'ERB (G&M90)';
equations{end+1} = @(fHz)1000*erb(fHz/1000,'G&M90');
distEquations{end+1} = @(fHz)nErb(fHz/1000,'G&M90') - nErb(integrationZeroFreqHz/1000,'G&M90'); 
colorOrder(end+1,:) = [0.4416    0.7490    0.4322];
lineStyles{end+1} = ':';
distanceScaling(end+1) = 0.275; % mm/ERB
equationNames{end+1} = 'ERB (O&S03)';
equations{end+1} = @(fHz)1000*erb(fHz/1000,'O&S03');
distEquations{end+1} = @(fHz)nErb(fHz/1000,'O&S03') - nErb(integrationZeroFreqHz/1000,'O&S03');
colorOrder(end+1,:) = [0.4416    0.7490    0.4322];
lineStyles{end+1} = '-';
distanceScaling(end+1) = 0.155; % mm/ERB
equationNames{end+1} = 'DLF (N83)';
equations{end+1} = @(fHz)1000*dlf(fHz/1000,'N83');
distEquations{end+1} = @(fHz)nDlf(fHz/1000,'N83') - nDlf(integrationZeroFreqHz/1000,'N83');
colorOrder(end+1,:) = [1.0000    0.5984    0.2000];
lineStyles{end+1} = ':';
distanceScaling(end+1) = 0.012; % mm/DLF
equationNames{end+1} = 'DLF (M12)';
equations{end+1} = @(fHz)1000*dlf(fHz/1000,'M12');
distEquations{end+1} = @(fHz)nDlf(fHz/1000,'M12') - nDlf(integrationZeroFreqHz/1000,'M12');
colorOrder(end+1,:) = [1.0000    0.5984    0.2000];
lineStyles{end+1} = '-';
distanceScaling(end+1) = 0.008; % mm/DLF
nEquations = length(equations);

hFigure = figure('defaultLineLineWidth',2,'color',[1 1 1],'unit','normalized','position',[0 0 0.45 0.6]);
tiledLayout = tiledlayout(2,2,"TileSpacing","compact");
for iPlot = 1:4 % Create all the tiles so we don't have to use nextTile later (because
  hTile(iPlot) = nexttile(iPlot); % it's not compatible with using multiple axes per tile)
  title({'',''}); % add titles here so that it's taken into acount in the axes position
end
% colorOrder = [0 0 0; linspecer(nEquations-1)];
% lineStyles = num2cell([':',repmat('-',1,nEquations-1)]);
% set(gca,,'xScale',xScale,'ColorOrder',colorOrder);
dataToPlot = zeros(nFreqs,nEquations);
normData = dataToPlot;
for iPlot  =1:4
  for iEq = 1:nEquations
    switch(iPlot)
      case 1 % ERB/DLF
        axisTitle = {'A. Psychophysical estimates','(\Deltaf)'};
        axisTitle = {'A. Psychophysical estimates','(df)'};
        yLabel = {'ERB/DLF (Hz)'};
        dataToPlot(:,iEq) = equations{iEq}(linFrequenciesHz);
        yScale = 'log';
        yLim = [1 1000;1 1000]; % Y axes limits for ERB and Weber/DLF respectively (should be the same if sameYaxis is true)
        sameYaxis = true;
      case 2 % ERB/DLF as a proportion of frequency
        axisTitle = {'B. Psychophysical estimates','(\Deltaf/f)'}; % not using delta symbol, because all fonts then get exported as lines instead of text in the svg file
        axisTitle = {'B. Psychophysical estimates','(df/f)'};
        yLabel = {'ERB/DLF as a proportion','of frequency (%)'};
        dataToPlot(:,iEq) = equations{iEq}(linFrequenciesHz)./linFrequenciesHz*100;
        yScale = 'log';
        yLim = [0.1 100;0.1 100];
        sameYaxis = true;
      case 3 % inverse ERB/DLF = shape of the cortical magnification function
        axisTitle = {'C. Predicted frequency magnification','function'};
        switch(magnificationUnit)
          case 'Hz'
            dataToPlot(:,iEq) = 1./equations{iEq}(linFrequenciesHz);
            yLim = repmat([0.0005 1],2,1);
    %         yLim = [1 1000;1 1000];
          case 'oct.'
            dataToPlot(:,iEq) = linFrequenciesHz/sqrt(2)./equations{iEq}(linFrequenciesHz); % I know the sqrt(2) is correct, but I'm not sure how to get this analytically
            yLim = repmat([1 1000],2,1);
        end
        if scaleDistance
          dataToPlot(:,iEq) = dataToPlot(:,iEq) * distanceScaling(iEq);
          yLabel = sprintf('Cortical magnification (mm/%s)',magnificationUnit);
          yLim = repmat([0.00002 0.03],2,1);
        else
          yLabel = {sprintf('ERB/DLF rate (ERB/%s or DLF/%s,',magnificationUnit,magnificationUnit),...
                    'proportional to cortical magnification)'};
        end
        yScale = 'log';
        sameYaxis = true;
      case 4 % integral  of 1/ERB/DLF = cortical distance function
        axisTitle = {'D. Predicted frequency mapping ','function'};
        if strcmp(magnificationUnit,'oct.') % if reciprocal was calculated in ERB/DLF per octave, we can also calculate the frequency mapping function by numerical integration of the magnification function
          dataToPlot(:,iEq) = cumsum(dataToPlot(:,iEq))*mean(diff(logFrequenciesKHz)); % - integrationZeroFreqHz./equations{iEq}(integrationZeroFreqHz)*sqrt(2);  % (since frequencies are equidistant on a log scale)
        else
          dataToPlot(:,iEq) = distEquations{iEq}(linFrequenciesHz);
        end
        if scaleDistance
          dataToPlot(:,iEq) = dataToPlot(:,iEq) * distanceScaling(iEq);
          yLabel = {'Cortical position along','tonotopic gradient (mm)'};
          yLim = [];
          sameYaxis = true;
        else
          yLabel = {'ERB number (proportional to cortical','position along the tonotopic gradient)'; ...
                  'DLF number (proportional to cortical','position along the tonotopic gradient)'};
          % yLim = [1 100;100 2000];
          yLim = [0 65;0 1300];
          sameYaxis = false;
        end
        % yScale = 'log';
        yScale = 'lin';
    end
    if size(yLabel,1)==1
      yLabel = repmat(yLabel,2,1); % if only one Y-axis label, duplicate
    end
    normData(:,iEq) = dataToPlot(:,iEq);
%     minData(iEq) = min(data(:,iEq));
%     maxData(iEq) = max(data(:,iEq));
%     if minData(iEq)<0
%       normData(:,iEq) = normData(:,iEq) - minData(iEq);
%       normFactor = maxData(iEq) - minData(iEq);
%     else
%       normFactor = maxData(iEq);
%     end
%     normData(:,iEq) = normData(:,iEq) / normFactor;
    normFactor = 1;

    if sameYaxis || iEq == 1
      hAxes(iEq) = hTile(iPlot); % use pre-existing axes
      axes(hAxes(iEq));
    else
      hAxes(iEq) = axes('position',get(hTile(iPlot),'position')); % create new axes at the same location as this tile
    end
    hAxes(iEq).NextPlot = 'add';
    hLine(iEq) = plot(linFrequenciesHz, normData(:,iEq),lineStyles{iEq},'color',colorOrder(iEq,:));
    if ~sameYaxis
      if contains(equationNames{iEq},'ERB (O&S03)') % changing the axes properties must be done after calling plot because it changes these properties
        hAxes(iEq).YAxisLocation = 'left';
      elseif contains(equationNames{iEq},'DLF (M12)')
        hAxes(iEq).YAxisLocation = 'right';
        hAxes(iEq).YLabel.Rotation = -90;
        hAxes(iEq).YLabel.VerticalAlignment = 'bottom';
      else
        hAxes(iEq).YAxis.Visible = 'off';
      end
      if iEq > 1
        hAxes(iEq).XAxis.Visible = 'off';
      end
    end
    hAxes(iEq).Box = 'off';
    hAxes(iEq).Color = 'none';
    hAxes(iEq).XScale = xScale;
    hAxes(iEq).YScale = yScale;
    hAxes(iEq).XLim = [50 20000];
    switch(equationNames{iEq})
      case {'Weber''s law (10%)','ERB (O&S03)','ERB (G&M90)'}
        ylabel(yLabel(1,:));
        if ~isempty(yLim)
          hAxes(iEq).YLim = yLim(1,:);
        end
      case {'DLF (M12)','DLF (N83)',}
        ylabel(yLabel(2,:));
        if ~isempty(yLim)
          hAxes(iEq).YLim = yLim(2,:);
        end
    end        
  end
  xlabel('Frequency (Hz)');
  title(axisTitle);
  if iPlot == 1
    hLegend = legend(hLine,equationNames);
    hLegend.Layout.Tile = 'East';
  end
end


if exportFigure
  figureFileName = fullfile(figurePath,sprintf('Figure1_%s_.svg',magnificationUnit));
  fprintf('Exporting figure to %s\n',figureFileName)
  print(hFigure,figureFileName,'-dsvg','-vector');
end