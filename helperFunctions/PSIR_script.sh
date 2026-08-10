#! /bin/bash

# This script combines data acquired with the PSIR / MP2RAGE protocol on the 7T to give
# images that look T1-weighted and can be passed to freesurfer for segmentation
#
# written by Julien Besle, based on code by Olivier Mougin and Emma at SPMMRC
#
# see also van de Moortele et al (2009) Neuroimage
#
# $Id: PSIR_script.sh 1280 2014-05-02 09:15:47Z lpzds1 $

if [ $# -lt 3 ] ; then
     echo 
     echo "Usage: sh PSIR_script.sh path basename outputbasename <lower_threshold>"
     echo "       path is the folder where the NIFTI files are located"
     echo "       basename is the common base to all file names (before _modulus_ and _phase_)"
     echo "       outputbasename is the common base to all output file names"
     echo "	  lower_threshold is the value (usually negative) of voxels in the PSIR image that will become 0 (default=-.7)" 	
     exit 1;
else
	if [ $# -eq 3 ] ; then
		LOWER_THRESHOLD=-.7
	else
		LOWER_THRESHOLD=$4
	fi	
fi

CWD=`pwd`
echo cd $1
cd $1

PHASE='_phase_cphase0'
MOD='_modulus_cphase0'

# corresponding matlab script:
#matlab -nodesktop -nosplash -nodisplay -r "try, PSIR_mine('$1','$2'); end ; quit"

echo
echo ==== Subtract phase 2 from phase 1 ====
echo fslmaths $2${PHASE}0 -sub $2${PHASE}1 $3_phaseDiff
fslmaths $2${PHASE}0 -sub $2${PHASE}1 $3_phaseDiff

echo
echo ==== Add 2*pi to negative phase difference ====

# create mask of negative phase and multiply by 2*pi
echo fslmaths $3_phaseDiff -mul -1 -bin -mul 6.2832 $3_phaseDiff_lt_0
fslmaths $3_phaseDiff -mul -1 -bin -mul 6.2832 $3_phaseDiff_lt_0

# add 2*pi to negative phase difference
echo fslmaths $3_phaseDiff -add $3_phaseDiff_lt_0 $3_phaseDiff
fslmaths $3_phaseDiff -add $3_phaseDiff_lt_0 $3_phaseDiff

echo
echo ==== Change sign of modulus image with phase difference around pi ====

# find phases around pi
echo fslmaths $3_phaseDiff -thr 1.5708 -uthr 4.7124 -bin $3_phaseDiff
fslmaths $3_phaseDiff -thr 1.5708 -uthr 4.7124 -bin $3_phaseDiff

# isolate corresponding magnitude values and change sign
echo fslmaths $2${MOD}0 -mas $3_phaseDiff -mul -1 $3_negMagnitude
fslmaths $2${MOD}0 -mas $3_phaseDiff -mul -1 $3_negMagnitude

# find phases around 0 and 2*pi
echo fslmaths $3_phaseDiff -mul -1 -add 1 $3_phaseDiff
fslmaths $3_phaseDiff -mul -1 -add 1 $3_phaseDiff

# isolate corresponding magnitude values
echo fslmaths $2${MOD}0 -mas $3_phaseDiff $3_PSIR
fslmaths $2${MOD}0 -mas $3_phaseDiff $3_PSIR

# add positive and negative magnitude values
echo fslmaths $3_PSIR -add $3_negMagnitude $3_PSIR
fslmaths $3_PSIR -add $3_negMagnitude $3_PSIR

echo
echo ==== Correct B1 inhomogeneity ====

# sum both magnitude images
echo fslmaths $2${MOD}0 -add $2${MOD}1 $3_sumMagnitudes
fslmaths $2${MOD}0 -add $2${MOD}1 $3_sumMagnitudes

# smooth result
#echo fslmaths $3_sumMagnitudes -s 5 $3_PD_smooth
#fslmaths $3_sumMagnitudes -s 5 $3_PD_smooth
BOXSIZE=7
echo fslmaths $3_sumMagnitudes -kernel box $BOXSIZE -fmean $3_PD_smooth$BOXSIZE
fslmaths $3_sumMagnitudes -kernel box $BOXSIZE -fmean $3_PD_smooth$BOXSIZE

# divide PSIR by smoothed magnitudes
echo fslmaths $3_PSIR -div $3_PD_smooth$BOXSIZE $3_PSIR
fslmaths $3_PSIR -div $3_PD_smooth$BOXSIZE $3_PSIR

echo
echo ==== Make positive PSIR image ====

# select voxels that are less than LOWER_THRESHOLD and set them to that value
echo fslmaths $3_PSIR -uthr $LOWER_THRESHOLD -mul -1 -bin -mul $LOWER_THRESHOLD $3_PSIR_lt_$LOWER_THRESHOLD
fslmaths $3_PSIR -uthr $LOWER_THRESHOLD -mul -1 -bin -mul $LOWER_THRESHOLD $3_PSIR_lt_$LOWER_THRESHOLD

# select voxels that are greater than 1 and set them to 1
#echo fslmaths $3_PSIR -thr 1 -bin $3_PSIR_gt_1
#fslmaths $3_PSIR -thr 1 -bin $3_PSIR_gt_1

# mask voxels that are less than LOWER_THRESHOLD
echo fslmaths $3_PSIR -thr $LOWER_THRESHOLD $3_PSIR_pos_$LOWER_THRESHOLD
fslmaths $3_PSIR -thr $LOWER_THRESHOLD $3_PSIR_pos_$LOWER_THRESHOLD

# add the three and add 1 to make it positive
#echo fslmaths $3_PSIR_pos_$LOWER_THRESHOLD -add $3_PSIR_lt_$LOWER_THRESHOLD -add $3_PSIR_gt_1 -add 1 $3_PSIR_pos_$LOWER_THRESHOLD
#fslmaths $3_PSIR_pos_$LOWER_THRESHOLD -add $3_PSIR_lt_$LOWER_THRESHOLD -add $3_PSIR_gt_1 -add 1 $3_PSIR_pos_$LOWER_THRESHOLD

# add the two and add -LOWERTHRESHOLD to make everything positive
echo fslmaths $3_PSIR_pos_$LOWER_THRESHOLD -add $3_PSIR_lt_$LOWER_THRESHOLD -sub $LOWER_THRESHOLD $3_PSIR_pos_$LOWER_THRESHOLD
fslmaths $3_PSIR_pos_$LOWER_THRESHOLD -add $3_PSIR_lt_$LOWER_THRESHOLD  -sub $LOWER_THRESHOLD $3_PSIR_pos_$LOWER_THRESHOLD

echo
echo ==== Mask with outer skin mask ====
#echo ==== Mask with smoothed magnitudes ====

# threshold smoothed magnitude
THRESHOLD=20000
#echo fslmaths $3_PD_smooth$BOXSIZE -thr $THRESHOLD $3_PD_smooth${BOXSIZE}_thr$THRESHOLD
#fslmaths $3_PD_smooth$BOXSIZE -thr $THRESHOLD $3_PD_smooth${BOXSIZE}_thr$THRESHOLD

# use bet to get skin mask if it doesn't exist
if [ `ls $3_sumMagnitudes_brain_outskin_mask.* | wc -l` -eq 0 ] ; then
	echo bet $3_sumMagnitudes $3_sumMagnitudes_brain -f .1 -g .2 -A -m
	bet $3_sumMagnitudes $3_sumMagnitudes_brain -f .1 -g .2 -A -m
fi

# apply mask
#echo fslmaths $3_PSIR_pos_$LOWER_THRESHOLD -mas $3_PD_smooth${BOXSIZE}_thr$THRESHOLD $3_PSIR_pos_${LOWER_THRESHOLD}_thr
echo fslmaths $3_PSIR_pos_$LOWER_THRESHOLD -mas $3_sumMagnitudes_brain_outskin_mask $3_PSIR_pos_${LOWER_THRESHOLD}_thr
#fslmaths $3_PSIR_pos_${LOWER_THRESHOLD} -mas $3_PD_smooth${BOXSIZE}_thr$THRESHOLD $3_PSIR_pos_${LOWER_THRESHOLD}_thr
fslmaths $3_PSIR_pos_${LOWER_THRESHOLD} -mas $3_sumMagnitudes_brain_outskin_mask $3_PSIR_pos_${LOWER_THRESHOLD}_thr

# downsample to 1 mm
echo flirt -in $3_PSIR_pos_${LOWER_THRESHOLD}_thr -ref $3_PSIR_pos_${LOWER_THRESHOLD}_thr -out $3_PSIR_pos_${LOWER_THRESHOLD}_thr_1mm -applyisoxfm 1
flirt -in $3_PSIR_pos_${LOWER_THRESHOLD}_thr -ref $3_PSIR_pos_${LOWER_THRESHOLD}_thr -out $3_PSIR_pos_${LOWER_THRESHOLD}_thr_1mm -applyisoxfm 1

echo 
echo ==== Remove temporary files ====
echo rm $3_phaseDiff.* $3_phaseDiff_lt_0.* $3_negMagnitude.* $3_sumMagnitudes.* $3_PSIR_lt_$LOWER_THRESHOLD.*
rm $3_phaseDiff.* $3_phaseDiff_lt_0.* $3_negMagnitude.* $3_sumMagnitudes.* $3_PSIR_lt_$LOWER_THRESHOLD.*
#echo rm $3_PSIR_gt_1.* $3_PD_smooth${BOXSIZE}_thr$THRESHOLD.*
#rm $3_PSIR_gt_1.* $3_PD_smooth${BOXSIZE}_thr$THRESHOLD.*


echo cd $CWD
cd $CWD

echo Done.

