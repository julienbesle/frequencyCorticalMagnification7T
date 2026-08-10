%     usage : logToMylog(<samplePeriod>,<filenames>,<actualTR>,<conditionName>,<delay>)
%    author : julien besle
%      date : 01/2013
%      goal : to convert log file output by tdtMRI to mrLoadRet mylog files
%             Only takes the time of the first stimulus of each trial (TR)
%             and sets its duration to the rest of the TR
%             log files output by tdtMRI normally have a .txt extension, but 
%             they may have been converted to .tsv file for BIDS compatibility
%             (in which case they've lost their header)
%     input :  samplePeriod : desired sampling period (in s). Default: 0.001
%              filenames :cell array of filenames
%              actualTR: use this value (in ms) instead of the one read from the log file (needs to be specified for converted .tsv file)
%              conditionName: append this string at the end of each condition name
%              delay: add this delay to all stim times

function tsvToMylog(samplePeriod,filenames,actualTR,conditionName,delay)

if ieNotDefined('filenames')
  [filenames,pathname]=uigetfile('*.*','Choose log file(s) to convert','Multiselect','on');
  if isnumeric(filenames)
    return;
  end
else
  pathname='';
end

if ischar(filenames)
  filenames={filenames};
end

if ieNotDefined('samplePeriod')
  samplePeriod = .001;
  fileSuffix='';
else
  fileSuffix=sprintf('_%.3fsec',samplePeriod);
end

if ieNotDefined('delay')
  delay = 0;
end

if delay~=0
  fileSuffix=sprintf('%s_%.1fsec',fileSuffix,delay);
end

if ieNotDefined('conditionName')
  conditionName = '';
else
  conditionName = ['_' conditionName];
end

timingTolerance = 100; % discrepancy allowed between desired times (calculated by cumulating stimulus duration)
                       % and actual (approximate) times

for iFile=filenames
  
  fid = fopen([pathname iFile{1}]);
  
  
  % determine whether this is a tsv, tdtMRI or tdtMRIvision log file
  functionType = {[],[]};
  line=0;
  maxHeaderLines = 50;
  while ~strcmp(functionType{2},'function:') && line <= maxHeaderLines
    functionType = textscan(fid,'%s %s: %s',1,'headerlines',1);
    line = line + 1;
  end
  if line > maxHeaderLines
    expType = 'tsv';
  else
    switch(functionType{1}{1})
      case 'Parameter'
        expType = 'tdtMRI'; % time unit of the TR
        timeUnits = 'ms';
      case 'Experiment'
        expType = 'tdtMRIvision';
        timeUnits = 's';
    end
  end
  
  if strcmp(expType,'tsv')
    fclose(fid);

    if ieNotDefined('actualTR')
      disp('For .tsv files, ''actualTR'' must be specified. Aborting...');
      return
    end
    TR = actualTR;
    T = readtable([pathname iFile{1}],'FileType','delimitedtext','Delimiter','\t');
    stimOnset = T{:,"onset"}*1000;
    duration = T{:,"duration"}*1000;
    name = T{:,"trial_type"};
    
    % add three variables for compatibility with the original .txt -> .mylog conversion code
    [~,~,condition] = unique(name); % condition (trial type) number (conversion from original .txt log did not conserve the original condition number and therefore the original ordering of conditions; the new ordering instead depends on the alphabetical ordering of the trial type names)
    scan = ceil(stimOnset/TR); % scan/frame number during which the stimulus was presented (or, stricly speaking, started); note that this was a field of the original log, which I kept in the converted tsv, but is not a required field of the BIDS tsv, which is why I'm recreating it here from the osnet field)
    trialEnd = scan*TR; % this is the end of a stimulus block, which we assume lasts until the end of each TR. Since we'll only keep the stimulus in each TR, each block will encompass all stimuli with the TR

    %create condition/scan pairs
    stim = [condition scan];
    % find the first stimulus of each scan
    [uniqueTrials,whichStim] = unique(stim,'rows','first'); %get only the first stimulus in a given condition and trial

  else
    if strcmp(expType,'tdtMRI')
      % Get onset value
      onset = {[]};
      while isempty(onset{1})
        onset = textscan(fid,'onset = %f',1,'headerlines',1);
      end
      onset = onset{1};
    else
      onset = 0;
    end
    
    % get TR value
    TR = {[]};
    while isempty(TR{1})
      TR = textscan(fid,sprintf('Dynamic scan duration (%s): %%f',timeUnits),1,'headerlines',1);
    end 
    TR = TR{1}; 
    
    if ~isnumeric(TR)
      disp('(logToMylog) Unexpected non-numerical value while trying to read TR. Has something changed in the log header ?');
      keyboard
    end
    
    if strcmp(expType,'tdtMRIvision')
      TR = TR*1000;
    end
    
    if ~ieNotDefined('actualTR')
      TR = actualTR;
    end
    
    %read log values
    switch(expType)
      case 'tdtMRI'
        values=textscan(fid,'%d %d %f %f %f %f %q %2d:%2d.%3d','headerlines',4,'collectOutput',true); %skip header plus first line
      case 'tdtMRIvision'
        values=textscan(fid,'%d %d %s %s %f %2d:%2d.%3d','headerlines',3,'collectOutput',true); %skip header
    end
    
    %check that we read things correctly
    if size(values{1},1)==0 || ...
        size(values{1},1)~=size(values{2},1) || ...
        size(values{1},1)~=size(values{3},1) || ...
        size(values{1},1)~=size(values{4},1)
      disp('(logToMyLog) Unexpected character while trying to read values. Has something changed in the log header ?');
      keyboard
    end
    
    scan      = double(values{1}(:,1));
    condition = double(values{1}(:,2));
    switch(expType)
      case 'tdtMRI'
        frequency = values{2}(:,1);
        duration  = values{2}(:,4);
    %   level = values{2}(:,2);
    %   bandwidth = values{2}(:,3);
        name      = values{3};
      case 'tdtMRIvision'
        name = values{2}(:,1);
        stimName  = values{2}(:,2);
        duration = values{3}*1000; % convert to milliseconds
    end
  
    time      = double(values{4});
    time      = (time(:,1)*60+time(:,2))*1000+time(:,3); %convert time to milliseconds
    
    %check if run has been completed
    completed = textscan(fid,'%s %s','headerlines',2,'collectOutput',true);
    
    if isempty(completed{1}) || ~strcmp(completed{1}{2},'COMPLETED')
      disp(['(logToMylog) Warning: Run ' iFile{1} ' may not have completed']);
    end
    
    fclose(fid);
    
    % Compute stim times under the assumption that stimuli do not overlap (i.e.: onset time = end of previous stimulus)
    if nnz(isnan(duration)) % Set NaN duration values to TR (null stim had NaN values for duration by mistake on 30/08/2013)
      disp(['(logToMylog) Warning: Run ' iFile{1} ': some durations had NaN values, setting them to TR (' num2str(TR) 'ms)']);
      duration(isnan(duration))=TR;
    end
    
    stimOnset    = [0;cumsum(duration)];
    stimOnset    = stimOnset(1:end-1);
    
    if strcmp(expType,'tdtMRI')
      %if actual TR was different from the one set in tdtMRI, there will be mismatch between the summed duration and the times
      % so go through each scan and compute summed durations separately for each
      for i = 1:scan(end)
        thisStimTime = (i-1)*TR + [0;cumsum(duration(scan==i))];
        thisStimTime = thisStimTime(1:end-1);
        stimOnset(scan==i) = thisStimTime;
      end
    end
    
    if abs(time(end)-stimOnset(end))>timingTolerance
      disp(['(logToMylog) Warning: Run ' iFile{1} ': total stimulus times derived from duration and log times differ by ' num2str(abs(time(end)-stimOnset(end))) ' ms']);
    end
    
    switch(expType)
      case 'tdtMRI'
        
        approximateTime = unique(time,'stable');
        % Check for discrepancies between duration-derived times and approximate time
        for iStim = 1:length(approximateTime)-1
          if approximateTime(iStim+1)-approximateTime(iStim)<0 || ...
              approximateTime(iStim+1)-approximateTime(iStim)>TR+timingTolerance || ...
              approximateTime(iStim+1)-approximateTime(iStim)<TR-timingTolerance
  
            error(['(logToMylog) Error: Run ' iFile{1} ': time discrepancy found between scans ' num2str(iStim)...
              ' and ' num2str(iStim+1) ': ' num2str(approximateTime(iStim+1)-approximateTime(iStim)) 'ms']);
  
          end
        end
        
        % replace NaNs by Inf because set operations don't work with NaNs
        frequency(isnan(frequency)) = Inf;
      %   bandwidth(isnan(bandwidth))=-Inf;  %using -Inf here because Inf is taken by broadband noises (?)
      %   level(isnan(level))=Inf;
  
        % remove stimuli NaN/Inf
        condition   = condition(~isinf(frequency),:);
        scan        = scan(~isinf(frequency),:);
        stimOnset   = stimOnset(~isinf(frequency));
        time        = time(~isinf(frequency));
        name        = name(~isinf(frequency));
        trialEnd    = stimOnset+TR-onset;% -onset is to account for the fact that we're using 'duration' instead of 'approximate time'
                                        % 'approximate time' starts at a value = 0ms. Using provided TR instead of the calculated TR
                                        % based on 'approximate time' (stimTR)
  
        %find all corresponding trials (scan) and corresponding conditions
        stim = [condition scan time];
  
        [uniqueTrials,whichStim] = unique(stim,'rows','first'); %get only the first stimulus in a given condition and trial
  
      case 'tdtMRIvision'
        
        % check for discrepancies between duration-derived and approximate times
        if any(abs(time-stimOnset) > timingTolerance)
          message = ['(logToMylog) Warning: Run ' iFile{1} ': time discrepancy found at scans ' mat2str(unique(scan(time-stimOnset > timingTolerance)))];
          if all(abs(time-stimOnset) < 200)
            mrWarnDlg(message); % only issue a warning if delay is reasonable
          else
            mrErrorDlg(message);
          end
        end
        
        %find all block onsets
        whichStim = find(diff([-1; condition])); % find the start of each block (change in condition number)
        % compute the end time of each block
        trialEnd = nan(size(condition));
  %       stimOnset = [stimOnset; stimOnset(end)+duration(end)]; % append the end
  %       whichStim = [whichStim; length(stimOnset)]; % append its index
  %       trialEnd(whichStim(1:end-1)) = stimOnset(whichStim(2:end)) - stimOnset(whichStim(1:end-1)); % to compute block durations
        % a block ends where the next block starts. For the last block, use the end of the last stimulus
        trialEnd(whichStim) = [stimOnset(whichStim(2:end)); stimOnset(end)+duration(end)];
        
        % remove baseline blocks
  %       scan        = scan(condition > 0);
  %       time        = time(condition > 0);
  %       stimName    = stimName(condition > 0);
        stimOnset   = stimOnset(condition > 0);
        name        = name(condition > 0);
        trialEnd    = trialEnd(condition > 0);
        duration    = duration(condition > 0);
        condition   = condition(condition > 0);
        
        %find all blocks and corresponding conditions
        whichStim = find(diff([-1; condition]));
        uniqueTrials = condition(whichStim);
        
    end
  end
  
  %find set of unique conditions
  [uniqueConditions,whichCond] = unique(uniqueTrials(:,1));
  
  stimNames = cell(1,length(uniqueConditions));
  mylog     = struct('stimtimes_s',{cell(1,length(uniqueConditions))},'stimdurations_s',{cell(1,length(uniqueConditions))});
  
  cCond       = 0;
  for iCond=uniqueConditions'
    cCond = cCond + 1;
    stimNames{cCond} = sprintf('%s%s',name{whichStim(whichCond(cCond))},conditionName);
    indices = whichStim(uniqueTrials(:,1)==iCond);
    mylog.stimtimes_s{cCond} = round(stimOnset(indices)/1000/samplePeriod)*samplePeriod+delay;
    mylog.stimdurations_s{cCond}=round((trialEnd(indices) - stimOnset(indices))/1000 /samplePeriod)*samplePeriod;
  end
  
  % if some conditions have the same name, append a number
  if ~isequal(unique(stimNames),sort(stimNames))
    for i = 1:length(stimNames)
      stimNames{i} = [stimNames{i} '_' num2str(i)];
    end
  end

  [~,outputfile] = fileparts(iFile{1});
  saveName = [pathname outputfile fileSuffix '.mylog.mat'];
  save(saveName,'mylog','stimNames');
  disp(['Wrote ' saveName]);
  
end


