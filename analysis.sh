#!/bin/bash

# assumes input data is in directory called: data_input
# assumes output data is to be placed in directory called: data_output

# Directroy to UNets code - need to replace whole structure
export code_dir=/<code_dir_for_UNETS>
export data_path=/data_input

# Hamied's setup involves SGE and a cluster. SGE Job has tasks, each task ID grabs a
# line of a file to run on a single subject ID.  Will need to swap to a for loop.
# However, for now write scrip as if it will get SGE_TASK_ID.

# Get subject ID list
#export subjids_list=${data_path}/subjects.txt
# Unneeded step

# Get a single subject id from the file. To ensure each is processed once,
# get a line from file based on SGE job task list

export subjid=`awk "NR==$SGE_TASK_ID" ${data_path}/subjects.txt`

# search full paths and filenames for input T1 and FLAIR images in compressed NIfTI format
#export t1_fn=`find ${data_path}/${subjid}/niftis/*[Tt]1*.nii.gz`
#export flair_fn=`find ${data_path}/${subjid}/niftis/*[Ff][Ll][Aa][Ii][Rr]*.nii.gz`
#  This is the method used in Hamied's script.  This relies on file system globbing
#  and expansion.  Could lead to errors?  Let find do the work instead.

export t1_fn=`find ${data_path}/${subjid}/niftis/ -iname "*T1*.nii.gz"`
export flair_fn=`find ${data_path}/${subjid}/niftis/ -iname "*FLAIR*.nii.gz`

# REL # Why under code dir?
#
# Create a temp directory to run the code in?
# assign path for a temporary data directory under the code directory and create it

export temp_dir=${code_dir}/Controls+PD/${subjid}
mkdir -p ${temp_dir}
mkdir -p ${temp_dir}/input
mkdir -p ${temp_dir}/output


# change into temp/input directory ${temp_dir}/input

cd ${temp_dir}/input

# files need to be renamed otherwise they are overwritten when fslroi is called.
# copy input T1 and FLAIR images here, renaming them
# REL # why do we want the originals?
cp ${t1_fn}    t1vol_orig.nii.gz
cp ${flair_fn} flairvol_orig.nii.gz

# run FSL's fsl_anat tool on the input T1 image, with outputs
# saved to a new subdirectory ${temp_dir}/input/t1-mni.anat
fsl_anat -o t1-mni -i ./t1vol_orig.nii.gz

# create new subdirectory to pre-process input FLAIR image, change into it ${temp_dir}/input/flair-bet
mkdir flair-bet
cd flair-bet


# run FSL's tools on input FLAIR image to ensure mni orientation followed by brain extraction
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

# change one directory up to ${temp_dir}/input
##cd ..
## Make it more explicit?
cd ${temp_dir}/input

# run FSL's fslroi tool to crop correctly-oriented T1 and co-registered FLAIR, ready for UNets-pgs

# Is this export $t1_fn $flair_fn if so, call explicitly?

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
#cd ..
## Make it more explicit?
cd ${temp_dir}


##################
Big re-write as will want to merge containers
######

# run UNets-pgs in Singularity
singularity exec --cleanenv ${code_dir}/pgs_cvriend.sif sh /WMHs_segmentation_PGS.sh T1.nii.gz FLAIR.nii.gz results.nii.gz ./input ./output


# change into output directory ${temp_dir}/output
#cd ./output
## Make it more explicit?
cd ${temp_dir}/output

# copy required images and transformation/warp coefficients from ${temp_dir}/input here, renaming T1 and FLAIR
cp ../input/T1_croppedmore2roi.mat                     .
cp ../input/t1-mni.anat/T1.nii.gz                      T1_roi.nii.gz
cp ../input/t1-mni.anat/T1_fullfov.nii.gz              .
cp ../input/t1-mni.anat/T1_to_MNI_lin.mat              .
cp ../input/t1-mni.anat/T1_to_MNI_nonlin_coeff.nii.gz  .
cp ../input/t1-mni.anat/T1_roi2nonroi.mat              .
cp ../input/flair-bet/flairbrain2t1brain_inv.mat       .
cp ../input/flair-bet/flairvol.nii.gz                  FLAIR_orig.nii.gz

## Make it more explicit?
cp ${temp_dir}/input/T1_croppedmore2roi.mat                     .
cp ${temp_dir}/input/t1-mni.anat/T1.nii.gz                      T1_roi.nii.gz
cp ${temp_dir}/input/t1-mni.anat/T1_fullfov.nii.gz              .
cp ${temp_dir}/input/t1-mni.anat/T1_to_MNI_lin.mat              .
cp ${temp_dir}/input/t1-mni.anat/T1_to_MNI_nonlin_coeff.nii.gz  .
cp ${temp_dir}/input/t1-mni.anat/T1_roi2nonroi.mat              .
cp ${temp_dir}/input/flair-bet/flairbrain2t1brain_inv.mat       .
cp ${temp_dir}/input/flair-bet/flairvol.nii.gz                  FLAIR_orig.nii.gz


# REL # Where is this set?
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
cp -r ${temp_dir}/* ${data_outpath}


# change to ${data_outpath}
cd ${data_outpath}

## ==> zip up results2mni_lin.nii.gz and results2mni_nonlin.nii.gz,
##     using site_study_${subjid} as zip filename,
##     and upload to ENIGMA-PD-Vasc group
##


####  Next step is to run  a container  looks like line 71 (117 in new file) in file.   How doi we add this to our docker container?  Looks at how you include a container and use its end points?  Need to understand format of the container and what ths script needs as input.
