#!/usr/bin/env bash
set -euo pipefail

NODE_TYPE="${1:-master}"
NODE_IP="${2:-192.168.60.90}"
MASTER_IP="${3:-192.168.60.90}" 

echo "=========================================="
echo " 1. Configuration système (Swap & Firewall) [$NODE_TYPE]"
echo "=========================================="
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y curl wget iptables ufw

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

if command -v ufw >/dev/null 2>&1; then
    sudo ufw disable || true
fi

MAIN_IP=$(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1)
# FLANNEL_INTERFACE=$(ip -4 route get "$NODE_IP" | awk '{print $3; exit}')
FLANNEL_INTERFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')


if [ "$NODE_TYPE" == "master" ]; then
    echo "=========================================="
    echo " 2. Installation du serveur K3s (Master)"
    echo "=========================================="

    INSTALL_ARGS="server --node-ip=${NODE_IP} --advertise-address=${NODE_IP} --flannel-iface=${FLANNEL_INTERFACE} --tls-san=${NODE_IP} --write-kubeconfig-mode 644"
    curl -sfL https://get.k3s.io | sh -s - ${INSTALL_ARGS}

    echo "=========================================="
    echo " 3. Configuration des accès pour 'vagrant'"
    echo "=========================================="
    until [ -f /etc/rancher/k3s/k3s.yaml ]; do
        sleep 2
    done

    mkdir -p /home/vagrant/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
    sudo chown -R vagrant:vagrant /home/vagrant/.kube
    chmod 600 /home/vagrant/.kube/config
    sed -i "s/127.0.0.1/${NODE_IP}/g" /home/vagrant/.kube/config
    echo "export KUBECONFIG=/home/vagrant/.kube/config" | sudo tee /etc/profile.d/k3s.sh
    sudo chmod +x /etc/profile.d/k3s.sh

    sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token
    echo "[INFO] Node token sauvegardé dans /vagrant/node-token"

    echo "=========================================="
    echo " 4. Installation de FluxCD"
    echo "=========================================="
    curl -s https://fluxcd.io/install.sh | FLUX_VERSION=2.10.0 bash
    flux install
else
    echo "=========================================="
    echo " 2. Attente et récupération du Token (Worker)"
    echo "=========================================="
    while [ ! -f /vagrant/node-token ]; do
        echo "En attente du token du master..."
        sleep 3
    done
    K3S_TOKEN=$(cat /vagrant/node-token)

    echo "=========================================="
    echo " 3. Installation de l'agent K3s (Worker)"
    echo "=========================================="
    curl -sfL https://get.k3s.io | K3S_URL="https://${MASTER_IP}:6443" K3S_TOKEN="${K3S_TOKEN}" sh -s - agent --node-ip=${NODE_IP} --flannel-iface=${FLANNEL_INTERFACE}
    echo " Worker K3s installé et connecté avec succès !"
fi

ENABLE_ZSH="${ENABLE_ZSH:-true}"
if [[ !(-z "$ENABLE_ZSH")  &&  ($ENABLE_ZSH == "true") ]]
then
    echo "=========================================="
    echo " 4. Installation de l'agent K3s (Worker)"
    echo "=========================================="
    echo "We are going to install zsh"
    sudo apt -y install zsh git
    echo "vagrant" | chsh -s /bin/zsh vagrant
    su - vagrant  -c  'echo "Y" | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    su - vagrant  -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'

    sed -i 's/^plugins=/#&/' /home/vagrant/.zshrc
    echo "plugins=(git  docker docker-compose colored-man-pages aliases copyfile  copypath dotenv zsh-syntax-highlighting jsontools)" >> /home/vagrant/.zshrc
    sed -i "s/^ZSH_THEME=.*/ZSH_THEME='agnoster'/g"  /home/vagrant/.zshrc
else
    echo "=========================================="
    echo " 4. Statut ZSH"
    echo "=========================================="
    echo "The zsh is not installed on this server"    
fi

echo "=========================================================="
echo " Nœud ${NODE_TYPE} du Cluster k3s est prêt !"
echo " Adresse IP du Nœud : ${MAIN_IP:-'127.0.0.1'}"
echo "=========================================================="