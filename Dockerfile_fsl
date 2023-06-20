# apt install wget
# # https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation/Linux
# wget https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/releases/fslinstaller.py

#FROM alpine:latest
FROM cvriend/pgs

# Need fslinstaller.py
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y wget && rm -rf /var/lib/apt/lists/*

RUN wget https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/releases/fslinstaller.py && python fslinstaller.py -d /usr/local/fsl/ -V 6.0.6

RUN echo '\n # FSL Setup \nFSLDIR=/usr/local/fsl \nPATH=${FSLDIR}/share/fsl/bin:${PATH} \nexport FSLDIR PATH \n. ${FSLDIR}/etc/fslconf/fsl.sh' >> /root/.bashrc

COPY analysis_script.sh .

RUN mkdir /data
RUN mkdir /code

RUN chmod +x analysis_script.sh

CMD ["/analysis_script.sh"]
## only allowed one CMD per file

ENTRYPOINT []
