#!/bin/bash
sudo apt -y update
ENABLE_ZSH=true
# ENABLE TOOLS
DOCKER="5:29.8.1-1~ubuntu.24.04~noble"

# install docker
sudo apt install -y git
# Install docker
case $DOCKER in
  ON)
    echo "Only ON and OFF value supported"
    sudo curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
    sudo usermod -aG docker vagrant
    sudo systemctl enable docker
    sudo systemctl start docker
    ;;
  OFF)
    echo "skip docker installation"
    ;;
  *)
    echo "Only ON and OFF value supported"
    sudo curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh --version $DOCKER
    sudo usermod -aG docker vagrant
    sudo systemctl enable docker
    sudo systemctl start docker
    ;;
esac
sudo apt install -y sshpass

if [ $1 == "master" ]
then
        echo "###################################################"
        echo "Initialize docker swarm cluster"
        echo "###################################################"
        docker swarm init --advertise-addr $2
        echo "###################################################"
        echo "For this Stack, you will use $(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1) IP Address"
        echo "###################################################"
else
        echo "###################################################"
        echo "Add worker to cluster"
        echo "###################################################"
        TOKEN=$( sshpass -p vagrant ssh -o StrictHostKeyChecking=no vagrant@${2} "docker swarm join-token -q worker" | tail -1)
        docker swarm join --token $TOKEN ${2}:2377
        echo "----------------------------------------------------------------"
        echo "For this Stack, you will use $(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1) IP Address"
        echo "----------------------------------------------------------------"

fi
