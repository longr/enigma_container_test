clean:
	rm -rf data/UNet-pgs/ code/Controls+PD/ docker_log.txt code/logs.txt
run:
	date > docker_log.txt
	docker run -v $(pwd):/home -v $(pwd)/code:/code -v $(pwd)/data:/data fsl_test  >> docker_log.txt 2>&1
	date >> docker_log.txt

build:
	docker build -f Dockerfile -t fsl_test .
