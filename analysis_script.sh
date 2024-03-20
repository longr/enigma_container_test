#!/bin/bash
## May need to add subjid to output log.

# FSL Setup
FSLDIR=/usr/local/fsl
PATH=${FSLDIR}/share/fsl/bin:${PATH}
export FSLDIR PATH
. ${FSLDIR}/etc/fslconf/fsl.sh
set -exo

# assign paths for code and input data directories
#export code_dir=/mnt/bmh01-rds/Hamied_Haroon_doc/ENIGMA-VascPD/UNets-pgs
export code_dir=/code
#export data_path=/scratch/${USER}/ENIGMA-PD-Vasc_manual_seg/Sarah_WML_man_seg/Controls+PD
export data_path=/data
echo code_dir  : ${code_dir} >> ${code_dir}/logs.txt 2>&1
echo data_path : ${data_path} >> ${code_dir}/logs.txt 2>&1
echo   >> ${code_dir}/logs.txt 2>&1

# assign path and filename of the list of subject IDs saved as a text file
export subjids_list=${data_path}/subjects.txt
echo subjids_list : ${subjids_list} >> ${code_dir}/logs.txt 2>&1

# read one line from the list of subject IDs
# Get the line in the file subkids_list whose line
# number is equal to the SGE_TASK_ID#
#export subjid=`awk "NR==$SGE_TASK_ID" ${subjids_list}`

# replace with 1 to test
export subjid=`awk "NR==1" ${subjids_list}`
echo subjid : ${subjid} >> ${code_dir}/logs.txt 2>&1
echo   >> ${code_dir}/logs.txt 2>&1

# search full paths and filenames for input T1 and FLAIR images in compressed NIfTI format
export t1_fn=`find ${data_path}/${subjid}/niftis/*[Tt]1*.nii.gz`
export flair_fn=`find ${data_path}/${subjid}/niftis/*[Ff][Ll][Aa][Ii][Rr]*.nii.gz`
echo t1_fn    : ${t1_fn} >> ${code_dir}/logs.txt 2>&1
echo flair_fn : ${flair_fn} >> ${code_dir}/logs.txt 2>&1
echo   >> ${code_dir}/logs.txt 2>&1

# assign path for output data directory and create it (if it doesn't exist)
export data_outpath=${data_path}/UNet-pgs/${subjid}
mkdir -p ${data_outpath} >> ${code_dir}/logs.txt 2>&1
echo data_outpath : ${data_outpath}  >> ${code_dir}/logs.txt 2>&1

# REL # Why under code dir?
# assign path for a temporary data directory under the code directory and create it
export temp_dir=${code_dir}/Controls+PD/${subjid}
mkdir -p ${temp_dir} >> ${code_dir}/logs.txt 2>&1
echo temp_dir     : ${temp_dir}  >> ${code_dir}/logs.txt 2>&1
echo   >> ${code_dir}/logs.txt 2>&1

# change into temporary data directory and create input and output subdirectories
# directories are required by flair
cd ${temp_dir}
mkdir -p ${temp_dir}/input >> ${code_dir}/logs.txt 2>&1
mkdir -p ${temp_dir}/output >> ${code_dir}/logs.txt 2>&1

# change into input directory ${temp_dir}/input
# flirt expects to be ran in the same fir (maybe able to do this
# outside of dir, but paths would be long)
cd ${temp_dir}/input

# copy input T1 and FLAIR images here, renaming them
## files need to be renamed otherwise overwritten when fslroi is called.
## also need to keep orginal file for flirt command
cp ${t1_fn}    t1vol_orig.nii.gz >> ${code_dir}/logs.txt 2>&1
cp ${flair_fn} flairvol_orig.nii.gz >> ${code_dir}/logs.txt 2>&1

# run FSL's fsl_anat tool on the input T1 image, with outputs saved to a new subdirectory ${temp_dir}/input/t1-mni.anat
echo running fsl_anat on t1 in ${temp_dir}/input/t1-mni.anat/  >> ${code_dir}/logs.txt 2>&1
# flags this will stop fsl_anat going through unnecessary steps and generating outputs we don’t use.
# fsl_anat -o t1-mni -i ./t1vol_orig.nii.gz --nononlinreg --noseg --nosubcortseg >> ${code_dir}/logs.txt 2>&1
# fsl_anat -o t1-mni -i ./t1vol_orig.nii.gz --nononlinreg --nosubcortseg >> ${code_dir}/logs.txt 2>&1
fsl_anat -o t1-mni -i ./t1vol_orig.nii.gz --nosubcortseg >> ${code_dir}/logs.txt 2>&1



echo fsl_anat done  >> ${code_dir}/logs.txt 2>&1
echo   >> ${code_dir}/logs.txt 2>&1
# fsl_anat -o t1-mni -i ./t1vol_orig.nii.gz --nocrop

# create new subdirectory to pre-process input FLAIR image, change into it ${temp_dir}/input/flair-bet
mkdir ${temp_dir}/input/flair-bet >> ${code_dir}/logs.txt 2>&1
cd ${temp_dir}/input/flair-bet

# run FSL's tools on input FLAIR image to ensure mni orientation followed by brain extraction
echo preparing flair in ${temp_dir}/input/flair-bet/  >> ${code_dir}/logs.txt 2>&1
fslreorient2std -m flair_orig2std.mat ../flairvol_orig.nii.gz flairvol
bet flairvol.nii.gz flairvol_brain -m -R -S -B -Z -v >> ${code_dir}/logs.txt 2>&1

# run FSL's flirt tool to register/align FLAIR brain with T1 brain
flirt -in flairvol_brain.nii.gz -omat flairbrain2t1brain.mat \
   -out flairbrain2t1brain \
   -bins 256 -cost normmi -searchrx 0 0 -searchry 0 0 -searchrz 0 0 -dof 6 \
   -interp trilinear -ref ../t1-mni.anat/T1_biascorr_brain.nii.gz >> ${code_dir}/logs.txt 2>&1

# run FSL's flirt tool to transform/align input FLAIR image (whole head) with T1 brain
flirt -in flairvol.nii.gz -applyxfm -init flairbrain2t1brain.mat \
   -out flairvol2t1brain \
   -paddingsize 0.0 -interp trilinear -ref ../t1-mni.anat/T1_biascorr_brain.nii.gz >> ${code_dir}/logs.txt 2>&1

# run FSL's convert_xfm to invert FLAIR to T1 transformation matrix
convert_xfm -omat flairbrain2t1brain_inv.mat -inverse flairbrain2t1brain.mat >> ${code_dir}/logs.txt 2>&1
echo flair prep done  >> ${code_dir}/logs.txt 2>&1
echo    >> ${code_dir}/logs.txt 2>&1

# change one directory up to ${temp_dir}/input
cd ${temp_dir}/input

# run FSL's fslroi tool to crop correctly-oriented T1 and co-registered FLAIR, ready for UNets-pgs
t1size=`fslsize ./t1-mni.anat/T1.nii.gz`
if [ ${t1size[1]} -ge 500 ] | [ ${t1size[3]} -ge 500 ]
then
 fslroi ./t1-mni.anat/T1.nii.gz                     T1    20 472 8 496 0 -1 >> ${code_dir}/logs.txt 2>&1
 fslroi ./flair-bet/flairvol_trans2_t1brain.nii.gz  FLAIR 20 472 8 496 0 -1 >> ${code_dir}/logs.txt 2>&1
else
 cp ./t1-mni.anat/T1.nii.gz                     T1.nii.gz >> ${code_dir}/logs.txt 2>&1
 cp ./flair-bet/flairvol2t1brain.nii.gz         FLAIR.nii.gz >> ${code_dir}/logs.txt 2>&1
fi

# run FSL's flirt tool to register/align cropped T1 with full-fov T1
flirt -in T1.nii.gz -omat T1_croppedmore2roi.mat \
   -out T1_croppedmore2roi \
   -bins 256 -cost normmi -searchrx 0 0 -searchry 0 0 -searchrz 0 0 -dof 6 \
   -interp trilinear -ref ./t1-mni.anat/T1.nii.gz >> ${code_dir}/logs.txt 2>&1

# change one directory up to ${temp_dir}
cd ${temp_dir}

# run UNets-pgs in Singularity
echo running UNets-pgs Singularity in ${temp_dir}  >> ${code_dir}/logs.txt 2>&1
#singularity exec --cleanenv ${code_dir}/pgs_cvriend.sif sh /WMHs_segmentation_PGS.sh T1.nii.gz FLAIR.nii.gz results.nii.gz ./input ./output
#Container contains code naturally now, no need to build.

/WMHs_segmentation_PGS.sh T1.nii.gz FLAIR.nii.gz results.nii.gz ./input ./output >> ${code_dir}/logs.txt 2>&1

echo UNets-pgs done!  >> ${code_dir}/logs.txt 2>&1
echo   >> ${code_dir}/logs.txt 2>&1

# change into output directory ${temp_dir}/output
cd ${temp_dir}/output

echo processing outputs in ${temp_dir}/output/  >> ${code_dir}/logs.txt 2>&1

echo "copy required images" >> ${code_dir}/logs.txt 2>&1
# copy required images and transformation/warp coefficients from ${temp_dir}/input here, renaming T1 and FLAIR
cp ${temp_dir}/input/T1_croppedmore2roi.mat                     . >> ${code_dir}/logs.txt 2>&1
cp ${temp_dir}/input/t1-mni.anat/T1.nii.gz                      T1_roi.nii.gz >> ${code_dir}/logs.txt 2>&1
cp  ${temp_dir}/input/t1-mni.anat/T1_fullfov.nii.gz              . >> ${code_dir}/logs.txt 2>&1
cp ${temp_dir}/input/t1-mni.anat/T1_to_MNI_lin.mat              . >> ${code_dir}/logs.txt 2>&1
#cp ${temp_dir}/input/t1-mni.anat/T1_to_MNI_nonlin_coeff.nii.gz  . >> ${code_dir}/logs.txt 2>&1
cp ${temp_dir}/input/t1-mni.anat/T1_roi2nonroi.mat              . >> ${code_dir}/logs.txt 2>&1
cp ${temp_dir}/input/flair-bet/flairbrain2t1brain_inv.mat       . >> ${code_dir}/logs.txt 2>&1
cp ${temp_dir}/input/flair-bet/flairvol.nii.gz                  FLAIR_orig.nii.gz >> ${code_dir}/logs.txt 2>&1

tree ${temp_dir}/input/ >> ${code_dir}/logs.txt 2>&1

# copy MNI T1 template images here
cp ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz        . >> ${code_dir}/logs.txt 2>&1
cp ${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz  . >> ${code_dir}/logs.txt 2>&1

echo "STEP 01" >> ${code_dir}/logs.txt 2>&1
# run FSL's flirt tool to transform/align WML segmentations from UNets-pgs with roi-cropped T1
flirt -in results.nii.gz -applyxfm -init T1_croppedmore2roi.mat \
   -out results2t1roi \
   -paddingsize 0.0 -interp nearestneighbour -ref T1_roi.nii.gz >> ${code_dir}/logs.txt 2>&1

echo "STEP 02" >> ${code_dir}/logs.txt 2>&1
# run FSL's flirt tool to transform/align WML segmentations from UNets-pgs with full-fov T1
flirt -in results2t1roi.nii.gz -applyxfm -init T1_roi2nonroi.mat \
   -out results2t1fullfov \
   -paddingsize 0.0 -interp nearestneighbour -ref T1_fullfov.nii.gz >> ${code_dir}/logs.txt 2>&1

echo "STEP 03" >> ${code_dir}/logs.txt 2>&1
# run FSL's flirt tool to transform/align WML segmentations with full-fov FLAIR
flirt -in results2t1roi.nii.gz -applyxfm -init flairbrain2t1brain_inv.mat \
   -out results2flairfullfov \
   -paddingsize 0.0 -interp nearestneighbour -ref FLAIR_orig.nii.gz >> ${code_dir}/logs.txt 2>&1

echo "STEP 04" >> ${code_dir}/logs.txt 2>&1
# run FSL's flirt tool to linearly transform/align WML segmentations with MNI T1
flirt -in results2t1roi.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
   -out results2mni_lin \
   -paddingsize 0.0 -interp nearestneighbour -ref MNI152_T1_1mm_brain.nii.gz >>   ${code_dir}/logs.txt 2>&1

echo "STEP 06" >> ${code_dir}/logs.txt 2>&1
# run FSL's applywarp tool to nonlinearly warp WML segmentations with MNI T1
#applywarp --in=results2t1roi.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
#   --out=results2mni_nonlin \
#   --interp=nn --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz >> ${code_dir}/logs.txt 2>&1

# copy all contents of temporary data directory to output data directory, and delete temporary data directory
echo copying all contents   >> ${code_dir}/logs.txt 2>&1
echo  from ${temp_dir}   >> ${code_dir}/logs.txt 2>&1
echo  to ${data_outpath}  >> ${code_dir}/logs.txt 2>&1
cp -r ${temp_dir}/* ${data_outpath}  >> ${code_dir}/logs.txt 2>&1
# echo deleting ${temp_dir} 
# rm -r ${temp_dir}

echo all done!  >> ${code_dir}/logs.txt 2>&1
echo    >> ${code_dir}/logs.txt 2>&1

# change to ${data_outpath}
cd ${data_outpath}

## ==> zip up results2mni_lin.nii.gz and results2mni_nonlin.nii.gz,
##     using site_study_${subjid} as zip filename,
##     and upload to ENIGMA-PD-Vasc group
##
