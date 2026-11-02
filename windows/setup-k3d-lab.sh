#!/bin/bash
set -e

echo "=== 1. Mise à jour du système & dépendances ==="
sudo apt-get update && sudo apt-get install -y curl ca-certificates iptables

echo "=== 2. Installation de Docker (Nativement dans WSL2) ==="
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
fi

# Démarrer le service Docker dans WSL2 si non actif
sudo service docker start

echo "=== 3. Installation de kubectl ==="
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

echo "=== 4. Installation de k3d ==="
if ! command -v k3d &> /dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

echo "=== 5. Provisioning des Clusters K3s ==="
# Cluster 1 avec exposition du port 80 pour l'Ingress
k3d cluster create cluster-1 \
  --agents 2 \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer"

# Cluster 2 (pour vos labs multi-clusters)
k3d cluster create cluster-2 \
  --agents 2

# Cluster 3
k3d cluster create cluster-3 \
  --agents 2

echo "=== Bilan du déploiement ==="
k3d cluster list
kubectl get nodes --context k3d-cluster-1
