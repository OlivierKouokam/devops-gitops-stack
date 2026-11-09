#!/usr/bin/env bash

set -euo pipefail

NODE_NAME="${1:-$(hostname)}"
NODE_IP="${2:-}"

echo "=========================================================="
echo " 1. Mise à jour du système & dépendances (Ubuntu 24.04)"
echo "=========================================================="
export DEBIAN_FRONTEND=noninteractive

# Attente de la libération éventuelle du verrou APT sur Ubuntu 24.04
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "En attente du verrou DPKG/APT..."
    sleep 2
done

sudo apt-get update -y
sudo apt-get install -y curl wget iptables ufw net-tools

echo "=========================================================="
echo " 2. Configuration du système (Swap & Firewall)"
echo "=========================================================="
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

if command -v ufw >/dev/null 2>&1; then
    sudo ufw disable || true
fi

echo "=========================================================="
echo " 3. Détection de l'IP réseau"
echo "=========================================================="
if [ -z "$NODE_IP" ]; then
    # Détection dynamique sur enp0s8 ou eth1 (Interfaces VirtualBox sous Ubuntu 24.04)
    NODE_IP=$(ip -4 addr show enp0s8 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1 || true)
    if [ -z "$NODE_IP" ]; then
        NODE_IP=$(ip -4 addr show eth1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1 || true)
    fi
fi

if [ -n "$NODE_IP" ]; then
    echo "[INFO] IP configurée pour k3s : ${NODE_IP}"
    INSTALL_ARGS="--node-ip ${NODE_IP} --node-external-ip ${NODE_IP} --tls-san ${NODE_IP} --write-kubeconfig-mode 644"
else
    echo "[AVERTISSEMENT] Aucune IP statique réseau trouvée sur enp0s8/eth1. Installation par défaut."
    INSTALL_ARGS="--write-kubeconfig-mode 644"
fi

echo "=========================================================="
echo " 4. Installation directe de K3s sur l'OS"
echo "=========================================================="
curl -sfL https://get.k3s.io | sh -s - server ${INSTALL_ARGS}

echo "=========================================================="
echo " 5. Configuration des accès pour l'utilisateur 'vagrant'"
echo "=========================================================="
until [ -f /etc/rancher/k3s/k3s.yaml ]; do
    echo "En attente de la création de /etc/rancher/k3s/k3s.yaml..."
    sleep 2
done

# Copie du kubeconfig avec remplacement automatique de 127.0.0.1 par l'IP de la VM
mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config

if [ -n "$NODE_IP" ]; then
    sudo sed -i "s/127.0.0.1/${NODE_IP}/g" /home/vagrant/.kube/config
fi

sudo chown -R vagrant:vagrant /home/vagrant/.kube
chmod 600 /home/vagrant/.kube/config

# Variable KUBECONFIG dans l'environnement de l'utilisateur
echo "export KUBECONFIG=/home/vagrant/.kube/config" | sudo tee /etc/profile.d/k3s.sh
sudo chmod +x /etc/profile.d/k3s.sh

echo "=========================================================="
echo " 6. Validation du statut du Cluster"
echo "=========================================================="
echo "En attente de l'initialisation du nœud ${NODE_NAME}..."
until sudo k3s kubectl get nodes 2>/dev/null | grep -q "Ready"; do
    sleep 2
done

sudo k3s kubectl wait --for=condition=Ready node --all --timeout=60s

echo "=========================================================="
echo " 7. Installation de FluxCD (CLI + controllers)"
echo "=========================================================="
# Version sans le "v" (ex: 2.x.y). Vide = dernière release GitHub
FLUX_VERSION="${FLUX_VERSION:-$(curl -s https://api.github.com/repos/fluxcd/flux2/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')}"

if [ "$NODE_NAME" == "fluxcd" ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml   # k3s ; sur k8s: ~/.kube/config

    # CLI figé
    curl -sSL https://fluxcd.io/install.sh | sudo FLUX_VERSION="${FLUX_VERSION}" bash

    # Pré-vérification cluster
    flux check --pre

    # Controllers (version = celle du CLI)
    flux install --namespace=flux-system

    kubectl -n flux-system rollout status deploy --timeout=180s
    flux check
else
    echo "[INFO] FluxCD non installé sur ${NODE_NAME}"
fi

echo "=========================================================="
echo " 8. Installation de ZSH"
echo "=========================================================="
ENABLE_ZSH="${ENABLE_ZSH:-true}"
if [[ !(-z "$ENABLE_ZSH")  &&  ($ENABLE_ZSH == "true") ]]
then
    echo "We are going to install zsh"
    sudo apt -y install zsh git
    echo "vagrant" | chsh -s /bin/zsh vagrant
    su - vagrant  -c  'echo "Y" | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    # su - vagrant  -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    su - vagrant  -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'

    sed -i 's/^plugins=/#&/' /home/vagrant/.zshrc
    echo "plugins=(git  docker docker-compose colored-man-pages aliases copyfile  copypath dotenv zsh-syntax-highlighting jsontools)" >> /home/vagrant/.zshrc
    sed -i "s/^ZSH_THEME=.*/ZSH_THEME='agnoster'/g"  /home/vagrant/.zshrc
else
    echo "The zsh is not installed on this server"    
fi

echo ""
echo "=========================================================="
echo " Cluster k3s (${NODE_NAME}) est prêt !"
echo " Adresse IP du Nœud : ${NODE_IP:-'127.0.0.1'}"
echo "=========================================================="
# echo 'sudo k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'
# echo "argocd login 192.168.60.80:30080 --insecure --username admin --password <password>"
