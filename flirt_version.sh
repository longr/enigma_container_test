#!/bin/bash

# FSL Setup
FSLDIR=/usr/local/fsl
PATH=${FSLDIR}/share/fsl/bin:${PATH}
export FSLDIR PATH
. ${FSLDIR}/etc/fslconf/fsl.sh

echo $PATH > /home/path.txt
flirt -version > /home/output.txt 2>/home/error.txt
