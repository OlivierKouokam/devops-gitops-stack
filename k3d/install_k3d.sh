#!/usr/bin/env bash

set -euo pipefail

# Récupération des variables passées par Vagrant
CLUSTERS_COUNT="${NUM_CLUSTERS:-3}"
SERVERS_COUNT="${NUM_SERVERS:-1}"
WORKERS_COUNT="${NUM_WORKERS:-2}"

# Version fixe de Docker
VERSION_STRING="5:29.6.2-1~ubuntu.22.04~jammy"
export DEBIAN_FRONTEND=noninteractive

echo "=========================================="
echo " 0. Optimisation des limites Système (CRITIQUE MULTI-CLUSTER)"
echo "=========================================="
# Kubernetes consomme énormément de watchers inotify. Par défaut, Ubuntu sature à 3 clusters.
sudo sysctl fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
sudo sysctl fs.inotify.max_user_instances=512 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "=========================================="
echo " 1. Installation de Docker CE (${VERSION_STRING})"
echo "=========================================="
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg ufw lsb-release

# Clé GPG officielle Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Dépôt officiel Docker Ubuntu
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

# Installation avec version explicitement verrouillée
sudo apt-get install -y \
  docker-ce="${VERSION_STRING}" \
  docker-ce-cli="${VERSION_STRING}" \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Activation et droits Docker pour l'utilisateur vagrant
sudo systemctl enable --now docker
sudo usermod -aG docker vagrant

echo "=========================================="
echo " 2. Installation de kubectl et k3d"
echo "=========================================="
# Téléchargement sécurisé du binaire officiel de kubectl
echo "Téléchargement de la dernière version stable de kubectl..."
KUBECTL_VERSION=$(curl -sSL https://dl.k8s.io/release/stable.txt | tr -d '[:space:]')
curl -sSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /tmp/kubectl
sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

# Installation officielle de k3d
echo "Installation de k3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.7.4 bash

echo "=========================================="
echo " 3. Configuration Réseau & IP Privée"
echo "=========================================="
if command -v ufw >/dev/null 2>&1; then
    sudo ufw disable || true
fi

MAIN_IP=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1 || echo "127.0.0.1")
echo "[INFO] Adresse IP de l'hôte détectée : ${MAIN_IP}"

echo "=========================================="
echo " 4. Déploiement Multi-Cluster K3d"
echo "=========================================="
sudo -u vagrant mkdir -p /home/vagrant/.kube

BASE_API_PORT=6443

for i in $(seq 1 "${CLUSTERS_COUNT}"); do
    CLUSTER_NAME="cluster-${i}"
    API_PORT=$((BASE_API_PORT + i))

    echo "--- Création du ${CLUSTER_NAME} (Masters: ${SERVERS_COUNT}, Workers: ${WORKERS_COUNT}, API Port: ${API_PORT}) ---"

    # AJOUT DE K3D_FIX_DNS=0 pour éviter le blocage CoreDNS
    sudo -u vagrant K3D_FIX_DNS=0 k3d cluster create "${CLUSTER_NAME}" \
        --servers "${SERVERS_COUNT}" \
        --agents "${WORKERS_COUNT}" \
        --api-port "${API_PORT}" \
        --timeout 5m \
        --wait

    echo "Pause de 20 secondes pour stabiliser le réseau Docker..."
    sleep 20        
done

# Configuration KUBECONFIG pour vagrant
echo "export KUBECONFIG=/home/vagrant/.kube/config" | sudo tee /etc/profile.d/k3s.sh
sudo chmod +x /etc/profile.d/k3s.sh

echo "=========================================================="
echo " Tous les clusters K3d sont opérationnels !"
echo " Nombre de clusters créés : ${CLUSTERS_COUNT}"
echo " Adresse IP du Nœud : ${MAIN_IP}"
echo "=========================================================="
