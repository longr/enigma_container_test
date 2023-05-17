#!/bin/bash

pwd > /home/pwd_WMHs.txt
ls >> /home/pwd_WMHs.txt
./WMHs_segmentation_PGS.sh  > /home/output_WMHs.txt 2>/home/error_WMHs.txt
