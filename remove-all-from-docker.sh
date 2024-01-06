#!/bin/bash

# clear console
clear

# stop all docker containers
sudo docker stop $(sudo docker ps -aq)

# remove all docker containers
sudo docker rm $(sudo docker ps -aq)

# remove all docker images
sudo docker rmi $(sudo docker images -q)

# remove all docker volumes
sudo docker system prune
