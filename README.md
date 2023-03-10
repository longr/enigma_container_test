# Testing for building Docker container

Quick notes for building simple container: https://www.baeldung.com/linux/docker-output-redirect

## Running
 Docker may fail to run, have to enable firewall
 
 ```bash
systemctl enable docker
firewall-cmd --zone=docker --change-interface=docker0
systemctl start docker
```
