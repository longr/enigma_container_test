#!/bin/bash --login

#$ -cwd
#$ -N SingularityRunPGSCVriend_WMLsegs_in_mni
#$ -pe smp.pe 32
#$ -t 1-3

# Dr Hamied Haroon
# hamied.haroon@manchester.ac.uk
# 15th March 2023

# load FSL module
module load apps/binapps/fsl/6.0.5

# assign paths for code and input data directories
export code_dir=/mnt/bmh01-rds/Hamied_Haroon_doc/ENIGMA-VascPD/UNets-pgs
export data_path=/scratch/${USER}/ENIGMA-PD-Vasc_manual_seg/Sarah_WML_man_seg/Controls+PD
echo code_dir  : ${code_dir}
echo data_path : ${data_path}
echo  

# assign path and filename of the list of subject IDs saved as a text file
export subjids_list=${data_path}/subjects.txt
echo subjids_list : ${subjids_list}

# read one line from the list of subject IDs
export subjid=`awk "NR==$SGE_TASK_ID" ${subjids_list}`
echo subjid : ${subjid}
echo  

# search full paths and filenames for input T1 and FLAIR images in compressed NIfTI format
export t1_fn=`find ${data_path}/${subjid}/niftis/*[Tt]1*.nii.gz`
export flair_fn=`find ${data_path}/${subjid}/niftis/*[Ff][Ll][Aa][Ii][Rr]*.nii.gz`
echo t1_fn    : ${t1_fn}
echo flair_fn : ${flair_fn}
echo  

# assign path for output data directory and create it (if it doesn't exist)
export data_outpath=${data_path}/UNet-pgs/${subjid}
mkdir -p ${data_outpath}
echo data_outpath : ${data_outpath}

# assign path for a temporary data directory under the code directory and create it
export temp_dir=${code_dir}/Controls+PD/${subjid}
mkdir -p ${temp_dir}
echo temp_dir     : ${temp_dir}
echo  

# change into temporary data directory and create input and output subdirectories
cd ${temp_dir}
mkdir -p ./input
mkdir -p ./output

# change into input directory ${temp_dir}/input
cd ./input

# copy input T1 and FLAIR images here, renaming them
cp ${t1_fn}    t1vol_orig.nii.gz
cp ${flair_fn} flairvol_orig.nii.gz

# run FSL's fsl_anat tool on the input T1 image, with outputs saved to a new subdirectory ${temp_dir}/input/t1-mni.anat
echo running fsl_anat on t1 in ${temp_dir}/input/t1-mni.anat/
fsl_anat -o t1-mni -i ./t1vol_orig.nii.gz
echo fsl_anat done
echo  
# fsl_anat -o t1-mni -i ./t1vol_orig.nii.gz --nocrop

# create new subdirectory to pre-process input FLAIR image, change into it ${temp_dir}/input/flair-bet
mkdir flair-bet
cd flair-bet

# run FSL's tools on input FLAIR image to ensure mni orientation followed by brain extraction
echo preparing flair in ${temp_dir}/input/flair-bet/
fslreorient2std -m flair_orig2std.mat ../flairvol_orig.nii.gz flairvol
bet flairvol.nii.gz flairvol_brain -m -R -S -B -Z -v

# run FSL's flirt tool to register/align FLAIR brain with T1 brain
flirt -in flairvol_brain.nii.gz -omat flairbrain2t1brain.mat \
   -out flairbrain2t1brain \
   -bins 256 -cost normmi -searchrx 0 0 -searchry 0 0 -searchrz 0 0 -dof 6 \
   -interp trilinear -ref ../t1-mni.anat/T1_biascorr_brain.nii.gz

# run FSL's flirt tool to transform/align input FLAIR image (whole head) with T1 brain
flirt -in flairvol.nii.gz -applyxfm -init flairbrain2t1brain.mat \
   -out flairvol2t1brain \
   -paddingsize 0.0 -interp trilinear -ref ../t1-mni.anat/T1_biascorr_brain.nii.gz

# run FSL's convert_xfm to invert FLAIR to T1 transformation matrix
convert_xfm -omat flairbrain2t1brain_inv.mat -inverse flairbrain2t1brain.mat
echo flair prep done
echo  

# change one directory up to ${temp_dir}/input
cd ..

# run FSL's fslroi tool to crop correctly-oriented T1 and co-registered FLAIR, ready for UNets-pgs
cp ./t1-mni.anat/T1.nii.gz                     T1.nii.gz
cp ./flair-bet/flairvol2t1brain.nii.gz         FLAIR.nii.gz
###################################################################################
# if `fslsize ./t1-mni.anat/T1.nii.gz` shows any of dim1, dim2 or dim3 >= 500, then
# fslroi ./t1-mni.anat/T1.nii.gz                     T1    20 472 8 496 0 -1
# fslroi ./flair-bet/flairvol_trans2_t1brain.nii.gz  FLAIR 20 472 8 496 0 -1
###################################################################################

# run FSL's flirt tool to register/align cropped T1 with full-fov T1
flirt -in T1.nii.gz -omat T1_croppedmore2roi.mat \
   -out T1_croppedmore2roi \
   -bins 256 -cost normmi -searchrx 0 0 -searchry 0 0 -searchrz 0 0 -dof 6 \
   -interp trilinear -ref ./t1-mni.anat/T1.nii.gz

# change one directory up to ${temp_dir}
cd ..

# run UNets-pgs in Singularity
echo running UNets-pgs Singularity in ${temp_dir}
singularity exec --cleanenv ${code_dir}/pgs_cvriend.sif sh /WMHs_segmentation_PGS.sh T1.nii.gz FLAIR.nii.gz results.nii.gz ./input ./output
echo UNets-pgs done!
echo  

# change into output directory ${temp_dir}/output
cd ./output

echo processing outputs in ${temp_dir}/output/

# copy required images and transformation/warp coefficients from ${temp_dir}/input here, renaming T1 and FLAIR
cp ../input/T1_croppedmore2roi.mat                     .
cp ../input/t1-mni.anat/T1.nii.gz                      T1_roi.nii.gz
cp ../input/t1-mni.anat/T1_fullfov.nii.gz              .
cp ../input/t1-mni.anat/T1_to_MNI_lin.mat              .
cp ../input/t1-mni.anat/T1_to_MNI_nonlin_coeff.nii.gz  .
cp ../input/t1-mni.anat/T1_roi2nonroi.mat              .
cp ../input/flair-bet/flairbrain2t1brain_inv.mat       .
cp ../input/flair-bet/flairvol.nii.gz                  FLAIR_orig.nii.gz

# copy MNI T1 template images here
cp ${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz        .
cp ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz  .

# run FSL's flirt tool to transform/align WML segmentations from UNets-pgs with roi-cropped T1
flirt -in results.nii.gz -applyxfm -init T1_croppedmore2roi.mat \
   -out results2t1roi \
   -paddingsize 0.0 -interp nearestneighbour -ref T1_roi.nii.gz

# run FSL's flirt tool to transform/align WML segmentations from UNets-pgs with full-fov T1
flirt -in results2t1roi.nii.gz -applyxfm -init T1_roi2nonroi.mat \
   -out results2t1fullfov \
   -paddingsize 0.0 -interp nearestneighbour -ref T1_fullfov.nii.gz


# run FSL's flirt tool to transform/align WML segmentations with full-fov FLAIR
flirt -in results2t1roi.nii.gz -applyxfm -init flairbrain2t1brain_inv.mat \
   -out results2flairfullfov \
   -paddingsize 0.0 -interp nearestneighbour -ref FLAIR_orig.nii.gz

# run FSL's flirt tool to linearly transform/align WML segmentations with MNI T1
flirt -in results2t1roi.nii.gz -applyxfm -init T1_to_MNI_lin.mat \
   -out results2mni_lin \
   -paddingsize 0.0 -interp nearestneighbour -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz

# run FSL's applywarp tool to nonlinearly warp WML segmentations with MNI T1
applywarp --in=results2t1roi.nii.gz --warp=T1_to_MNI_nonlin_coeff.nii.gz \
   --out=results2mni_nonlin \
   --interp=nn --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz

# copy all contents of temporary data directory to output data directory, and delete temporary data directory
echo copying all contents 
echo  from ${temp_dir} 
echo  to ${data_outpath}
cp -r ${temp_dir}/* ${data_outpath}
# echo deleting ${temp_dir}
# rm -r ${temp_dir}

echo all done!
echo  

# change to ${data_outpath}
cd ${data_outpath}

## ==> zip up results2mni_lin.nii.gz and results2mni_nonlin.nii.gz,
##     using site_study_${subjid} as zip filename,
##     and upload to ENIGMA-PD-Vasc group
##
