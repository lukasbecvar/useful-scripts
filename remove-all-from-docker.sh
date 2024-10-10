#!/bin/bash

# clear console
clear

# stop all docker containers
sudo docker stop $(sudo docker ps -aq)

# remove all docker containers
sudo docker rm $(sudo docker ps -aq)

# remove all docker images
sudo docker rmi $(sudo docker images -q)

# remove networks
sudo docker network rm $(docker network ls -q)

# remove all docker volumes
sudo docker volume rm $(docker volume ls -q)
sudo docker system prune -a --volumes
