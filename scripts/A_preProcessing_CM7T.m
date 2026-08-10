runPreProcessing = processPSIR || runFreesurfer || convertSurfaces;

% Main participant loop
for iSubj = subjectsToProcess
  
  if runPreProcessing
    fprintf("\n-----------------------------------------\n");
    fprintf("|   Pre-processing participant  %s  |\n",subject{iSubj});
    fprintf("-----------------------------------------\n\n");
  else
    fprintf("Skipping pre-processing for participant %s\n",subject{iSubj});
  end
  
  % Source data for this participant
  bidsAnatPath = fullfile(bidsPath,subject{iSubj},'anat');
  bidsFuncPath = fullfile(bidsPath,subject{iSubj},'func');
  
  % Process PSIR volumes
  psirBaseName = sprintf('sub-%02d_PSIR',iSubj);
  processedPSIR = sprintf('%s_pos_-.7_thr_200.nii',psirBaseName);
  if processPSIR 
    psirPath = fullfile(derivativePath,'PSIR',subject{iSubj});
    if ~exist(psirPath,'dir')
      mkdir(psirPath);
    end
    for inversion = 1:2
      magPSIR_BIDS = sprintf('sub-%02d_inv-%d_part-mag_MP2RAGE.nii.gz',iSubj,inversion);
      phasePSIR_BIDS = sprintf('sub-%02d_inv-%d_part-phase_MP2RAGE.nii.gz',iSubj,inversion);

      % copy/rename file because PSIR_script.sh expects the mag/phase suffix to be just before the extension 
      % and the inversion times to be coded as 00 and 01, respectively
      magPSIR = sprintf('%s_modulus_cphase%02d.nii.gz',psirBaseName,inversion-1);
      phasePSIR = sprintf('%s_phase_cphase%02d.nii.gz',psirBaseName,inversion-1);
  
      if ~exist(magPSIR,'file')
        copyfile(fullfile(bidsAnatPath,magPSIR_BIDS),fullfile(psirPath,magPSIR)); % may need to gunzip for PSIR_script.sh to work?
        copyfile(fullfile(bidsAnatPath,phasePSIR_BIDS),fullfile(psirPath,phasePSIR)); % may need to gunzip for PSIR_script.sh to work?
      end
    end
    
    if ~exist(processedPSIR,'file')% Process PSIR
      cmd = sprintf('PSIR_script.sh %s %s %s',psirPath,psirBaseName,subject{iSubj}); % assume this is on the system path
      disp(cmd);
      system(cmd);
    end
  end

  if runFreesurfer  % run Freesurfer's recon-all

    freesurferPath = fullfile(derivativePath,'freesurfer',subject{iSubj});
    if ~exist(freesurferPath,'dir')
      mkdir(freesurferPath)
    end

    highresOptionsFile = fullfile(derivativePath,'freesurfer','high_res_options.txt');
    if ~exist(highresOptionsFile,'file')
      highresOptionsFid = fopen(highresOptionsFile,'w');
      fprintf(highresOptionsFid,'mris_inflate -n 18');
      fclose(highresOptionsFid);
    end

    if ~exist(fullfile(freesurferPath,'surf'),'dir')
      fprintf('Running recon-all for subject %s\n', subject{iSubj});
      disp ('-------------------------------------------------');
      cmd = sprintf('recon-all -all -s %s -i %s -hires -expert %s', ...
                    subject{iSubj}, ...
                    fullfile(psirPath,processedPSIR), ...
                    highresOptionsFile); % somehow, this didn't do high-resolution surfaces
      disp(cmd);
      system(cmd);

      % display the resulting surfaces
      cmd = sprintf('freeview %s %s %s %s:colormap=lut:opacity=0.2 -f %s:edgecolor=blue %s:edgecolor=red %s:edgecolor=blue %s:edgecolor=red', ...
              fullfile(freesurferPath,'mri','T1.mgz'), ...
              fullfile(freesurferPath,'mri','wm.mgz'), ...
              fullfile(freesurferPath,'mri','brainmask.mgz'), ...
              fullfile(freesurferPath,'mri','aseg.mgz'), ...
              fullfile(freesurferPath,'surf','lh.white'), ...
              fullfile(freesurferPath,'surf','lh.pial'), ...
              fullfile(freesurferPath,'surf','rh.white'), ...
              fullfile(freesurferPath,'surf','rh.pial'));
      disp(cmd);
      system(cmd);
    else
      fprintf('Freesurfer subject %s already exists',subject{iSubj});
    end
  end
  
  % Import Freesurfer surfaces and T1w into mrTools (convert to surfRelax format)
  surfRelaxPath = fullfile(derivativePath,'surfRelax',subject{iSubj});
  processedPSIR = sprintf('%s_mprage_pp.nii',subject{iSubj});
  if convertSurfaces     %IMPORT  FREESURFER SURFACE 
    if ~exist(surfRelaxPath,'dir')
      mkdir(surfRelaxPath);
    end
    % Convert Freesurfer processed PSIR volume from .mgz to .nii
    if ~exist(fullfile(surfRelaxPath,processedPSIR),'file')
      disp('Convert Freesurfer processed PSIR volume from .mgz to .nii');
      disp('----------------------------------------------------------');
      cmd = sprintf('mri_convert --out_type nii --out_orientation RAS %s %s', ...
             fullfile(freesurferPath,'mri','T1.mgz'), ...
             fullfile(surfRelaxPath,processedPSIR));
      disp(cmd);
      system(cmd);
    end        
    % Convert Freesurfer surfaces to surRelax format
    if ~exist(fullfile(surfRelaxPath,[subject{iSubj} '_left_GM.off']),'file')
      mlrImportFreeSurfer('defaultParams=1',...
        sprintf('volumeCropSize=%s',mat2str(volumeCropSize(iSubj,:))), ...
        sprintf('freeSurferDir=%s',freesurferPath),...
        sprintf('outDir=%s',surfRelaxPath));
    end

  end
  
  if runPreProcessing
    toc(tscript);
  end
end

