#!/usr/bin/env bash

set -euo pipefail

echo "=========================================="
echo " 1. Mise à jour du système & dépendances"
echo "=========================================="
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y curl wget iptables ufw

echo "=========================================="
echo " 2. Configuration du système (Swap & Firewall)"
echo "=========================================="
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

if command -v ufw >/dev/null 2>&1; then
    sudo ufw disable || true
fi

echo "=========================================="
echo " 3. Détection de l'IP du réseau privé"
echo "=========================================="
MAIN_IP=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

if [ -z "$MAIN_IP" ]; then
    echo "[AVERTISSEMENT] IP non trouvée sur enp0s8. Configuration par défaut."
    INSTALL_ARGS=""
else
    echo "[INFO] Adresse IP détectée : ${MAIN_IP}"
    INSTALL_ARGS="--node-external-ip ${MAIN_IP} --tls-san ${MAIN_IP}"
fi

echo "=========================================="
echo " 4. Installation directe de K3s sur l'OS"
echo "=========================================="
curl -sfL https://get.k3s.io | sh -s - server ${INSTALL_ARGS}

echo "=========================================="
echo " 5. Configuration des accès pour 'vagrant'"
echo "=========================================="
# Attente de la création du fichier kubeconfig
until [ -f /etc/rancher/k3s/k3s.yaml ]; do
    echo "En attente de /etc/rancher/k3s/k3s.yaml..."
    sleep 2
done

# Copie et attribution des droits sur le kubeconfig pour l'utilisateur vagrant
mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube
chmod 600 /home/vagrant/.kube/config

# Configuration permanente de KUBECONFIG vers le fichier de l'utilisateur vagrant
echo "export KUBECONFIG=/home/vagrant/.kube/config" | sudo tee /etc/profile.d/k3s.sh
sudo chmod +x /etc/profile.d/k3s.sh

echo "=========================================="
echo " 6. Attente et vérification du cluster"
echo "=========================================="
# Boucle d'attente active pour s'assurer que le nœud est enregistré avant de lancer 'kubectl wait'
echo "En attente de l'enregistrement du nœud dans l'API..."
until sudo k3s kubectl get nodes 2>/dev/null | grep -q "Ready\|NotReady"; do
    sleep 2
done

# Attente du statut Ready
sudo k3s kubectl wait --for=condition=Ready node --all --timeout=60s

echo ""
echo "=========================================================="
echo " K3s est opérationnel !"
echo " Adresse IP du Nœud : ${MAIN_IP:-'N/A'}"
echo "=========================================================="
