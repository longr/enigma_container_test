#!/bin/bash

# FSL Setup
FSLDIR=/usr/local/fsl
PATH=${FSLDIR}/share/fsl/bin:${PATH}
export FSLDIR PATH
. ${FSLDIR}/etc/fslconf/fsl.sh

echo $PATH > /home/path.txt

echo "########### Flirt" >> /home/output.txt
flirt -version >> /home/output.txt 2>&1 #/home/error.txt

echo "############ fsl_anat" >> /home/output.txt
fsl_anat -version >> /home/output.txt 2>&1 #/home/error.txt

echo "################# fslreorient2std" >> /home/output.txt
fslreorient2std -version >> /home/output.txt 2>&1 #/home/error.txt

echo "############ convert_xfm" >> /home/output.txt
convert_xfm -version >> /home/output.txt 2>&1 #/home/error.txt

echo "############ applywarp" >> /home/output.txt
applywarp -version >> /home/output.txt 2>&1 #/home/error.txt

