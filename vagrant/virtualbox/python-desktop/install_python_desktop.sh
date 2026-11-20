#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update

# Installation de Python, venv et IDLE
sudo apt-get install -y python3 python3-pip python3-venv idle3

# Installation de PyCharm
sudo apt-get install -y snapd
sudo snap install pycharm-community --classic
sudo snap install code --classic
# Optionnel : préinstaller l'extension Python pour l'utilisateur vagrant
sudo -u vagrant code --install-extension ms-python.python

# Configuration du clavier français et du fuseau horaire
sudo apt-get install -y x11-xkb-utils
sudo setxkbmap fr
echo "setxkbmap fr" >> /home/vagrant/.bashrc
sudo chown vagrant:vagrant /home/vagrant/.bashrc
sudo timedatectl set-timezone Europe/Paris
sudo sed -i "s/'de/'fr/g" /etc/xdg/autostart/input-source.desktop 2>/dev/null || true
sudo sed -i "s/'us/'fr/g" /etc/xdg/autostart/input-source.desktop 2>/dev/null || true

IP=$(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1)
echo "##############"
echo "## VM ready ##"
echo "##############"
echo "For this Stack, you will use $IP IP Address"
echo "The VM will restart, please wait until 2 minutes before connection the VM"
sudo reboot
