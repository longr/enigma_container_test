# Testing for building Docker container

## Running

The container can be run and built using the two scripts.  To build the container locally run the following command.

The container will expect 2 direcories, `./code` and `./data` where data should contain the correct directory structure and the `ubjects.txt`.

```bash
bash docker_buildscript.sh
```

Once this completes successfully, run the container using the command:

```bash
bash docker_runscript.sh
```

This will run the analysis and generate some log files.

The main log files are `./code/logs.txt` and `./docker_logs.txt`


## Running without scripts

To build the container run: 

```bash
docker build . -f Dockerfile -t fsl_test
```

To run the container run:

```bash
docker run -v $(pwd):/home -v $(pwd)/code:/code -v $(pwd)/data:/data fsl_test  >> docker_log.txt 2>&1
```

### Troubleshooting

Docker may fail to run, have to enable firewall
 
 ```bash
systemctl enable docker
firewall-cmd --zone=docker --change-interface=docker0
systemctl start docker
```


# Development Notes

Quick notes for building simple container: https://www.baeldung.com/linux/docker-output-redirect

