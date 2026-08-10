% mrTools preferences
setpref('mrLoadRet','mrDefaultsFilename',fullfile(derivativePath,'mrTools','.mrDefaults'));
mrSetPref('volumeDirectory',fullfile(derivativePath,'freesurfer'));
mrSetPref('magnet',{'Nottingham Philips 7T', 'Nottingham  Philips 3T','UNF Siemens 3T'});
mrSetPref('coil',{'Sense Head 32 Channels' 'Sense Head 16 Channels' 'Sense 8 Channels' 'Flex S'});
mrSetPref('pulseSequence',{'2D Gradient Echo' '3D Gradient Echo' 'Spin Echo' '3D Flash'});
mrSetPref('defaultPrecision','single');
mrSetPref('graphWindow','Make new');
mrSetPref('niftiFileExtension','.nii.gz');
mrSetPref('checkParamsConsistency','no');
mrSetPref('verbose','no');
mrSetPref('pluginPaths',[fullfile(mlrRootPath,'/mrLoadRet/PluginAltNottingham') ',' ...
                        fullfile(mlrRootPath,'/mrLoadRet/PluginAlt')]); 
mrSetPref('statisticalTestOutput','-log10(P) value');
mrSetPref('maxBlocksize',2500000000);
mrSetPref('site','Nottingham');
mrSetPref('overlayRangeBehaviour','New');
mrSetPref('colorBlending','Alpha blend');
mrSetPref('colormapPaths',fileparts(which('inferno'))); % Matplotlib color scales

% Select mrTools plugins
warndlg('In the next pop-up window, select plugins ''Default'',''GLM_v2'',''mlrAnatomy'' and ''viewGUI''.');
disp('In the next pop-up window, select ''Default'',''GLM_v2'',''mlrAnatomy'' and ''viewGUI''');
mlrPlugin;

sides = {'left','right'};
Sides = {'Left','Right'};

nSubjects = 20;
for subj = 1:nSubjects
  subject{subj} = sprintf('sub-%02d',subj);
end

subj = 1;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '92_141_158_Rad60';
flatName{subj,2} = '250_165_153_Rad60';
flatRotation(subj,1) = 300;
flatRotation(subj,2) = 330;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 2;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '84_151_168_Rad60';
flatName{subj,2} = '257_143_176_Rad60';
flatRotation(subj,1) = 340;
flatRotation(subj,2) = 100;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 3;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '74_143_171_Rad60';
flatName{subj,2} = '264_156_165_Rad60';
flatRotation(subj,1) = 320;
flatRotation(subj,2) = 290;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 4;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '82_143_158_Rad60';
flatName{subj,2} = '247_153_165_Rad60';
flatRotation(subj,1) = 240;
flatRotation(subj,2) = 10;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 5;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '89_141_170_Rad60';
flatName{subj,2} = '250_160_176_Rad60';
flatRotation(subj,1) = 170;
flatRotation(subj,2) = 20;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 6;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '91_138_173_Rad60';
flatName{subj,2} = '260_158_158_Rad60';
flatRotation(subj,1) = 280;
flatRotation(subj,2) = 100;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 7;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '96_136_158_Rad60';
flatName{subj,2} = '247_155_166_Rad60';
flatRotation(subj,1) = 210;
flatRotation(subj,2) = 0;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 8;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '92_150_153_Rad60';
flatName{subj,2} = '247_146_171_Rad60';
flatRotation(subj,1) = 260;
flatRotation(subj,2) = 20;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 9;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '84_153_155_Rad60';
flatName{subj,2} = '257_133_166_Rad60';
flatRotation(subj,1) = 190;
flatRotation(subj,2) = 340;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 10;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '96_153_155_Rad60';
flatName{subj,2} = '250_175_151_Rad60';
flatRotation(subj,1) = 230;
flatRotation(subj,2) = 310;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 11;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '104_138_143_Rad60';
flatName{subj,2} = '257_170_155_Rad60';
flatRotation(subj,1) = 240;
flatRotation(subj,2) = 0;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 12;
operator{subj} = 'jb';
volumeCropSize(subj,:) = [336 336 336];
flatName{subj,1} = '89_146_150_Rad60';
flatName{subj,2} = '262_163_153_Rad60';
flatRotation(subj,1) = 290;
flatRotation(subj,2) = 40;
startFreqKHz(subj) = .25;
endFreqKHz(subj) = 6;
nFreqs(subj) = 7;

subj = 13; % Same subject as subject 2. Had to manually rename log files because they were in an incorrect order (first scan's log didn't have a can # and was last)
operator{subj} = 'bg';
volumeCropSize(subj,:) = [256 256 256];
flatName{subj,1} = '83_123_133_Rad60';
flatName{subj,2} = '184_122_133_Rad60';
flatRotation(subj,1) = 255;
flatRotation(subj,2) = 350;
startFreqKHz(subj) = .1;
endFreqKHz(subj) = 8;
nFreqs(subj) = 32;

subj = 14; % Had to manually rename the log files because motion-compensated timeseries were in the wrong order in the original study (3-4-1-2)
operator{subj} = 'bg';
volumeCropSize(subj,:) = [256 256 256];
flatName{subj,1} = '66_114_111_Rad60';
flatName{subj,2} = '189_126_110_Rad60';
flatRotation(subj,1) = 260;
flatRotation(subj,2) = 120;
startFreqKHz(subj) = .1;
endFreqKHz(subj) = 8;
nFreqs(subj) = 32;

subj = 15;
operator{subj} = 'bg';
volumeCropSize(subj,:) = [256 256 256];
flatName{subj,1} = '80_115_124_Rad60';
flatName{subj,2} = '197_120_126_Rad60';
flatRotation(subj,1) = 240;
flatRotation(subj,2) = 0;
startFreqKHz(subj) = .1;
endFreqKHz(subj) = 8;
nFreqs(subj) = 32;

subj = 16;
operator{subj} = 'bg';
volumeCropSize(subj,:) = [256 256 256];
flatName{subj,1} = '70_126_111_Rad60';
flatName{subj,2} = '206_137_114_Rad60';
flatRotation(subj,1) = 40;
flatRotation(subj,2) = 80;
startFreqKHz(subj) = .1;
endFreqKHz(subj) = 8;
nFreqs(subj) = 32;

subj = 17;
operator{subj} = 'bg';
volumeCropSize(subj,:) = [256 256 256];
flatName{subj,1} = '67_117_115_Rad60';
flatName{subj,2} = '192_132_111_Rad60';
flatRotation(subj,1) = 170;
flatRotation(subj,2) = 70;
startFreqKHz(subj) = .1;
endFreqKHz(subj) = 8;
nFreqs(subj) = 32;

subj = 18;
operator{subj} = 'bg';
volumeCropSize(subj,:) = [256 256 256];
flatName{subj,1} = '82_117_102_Rad60';
flatName{subj,2} = '186_126_112_Rad60';
flatRotation(subj,1) = 0;
flatRotation(subj,2) = 60;
startFreqKHz(subj) = .1;
endFreqKHz(subj) = 8;
nFreqs(subj) = 32;

subj = 19;
operator{subj} = 'bg';
volumeCropSize(subj,:) = [256 256 256];
flatName{subj,1} = '82_107_124_Rad60';
flatName{subj,2} = '185_110_131_Rad60';
flatRotation(subj,1) = 95;
flatRotation(subj,2) = 85;
startFreqKHz(subj) = .1;
endFreqKHz(subj) = 8;
nFreqs(subj) = 32;

subj = 20;
operator{subj} = 'bg';
volumeCropSize(subj,:) = [256 256 256];
flatName{subj,1} = '76_110_119_Rad60';
flatName{subj,2} = '186_112_132_Rad60';
flatRotation(subj,1) = 270;
flatRotation(subj,2) = 350;
startFreqKHz(subj) = .1;
endFreqKHz(subj) = 8;
nFreqs(subj) = 32;

concatenationGroup = 'Concatenation';
functionalAnalysis = 'GLM_AudCx';
  
