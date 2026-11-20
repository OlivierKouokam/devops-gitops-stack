#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-master}"
CLUSTER_IP="${2:-192.168.60.80}"

echo "=========================================="
echo " 0. Configuration Réseau Statique (Hyper-V)"
echo "=========================================="
# Détection de l'interface réseau principale (souvent eth0 sous Hyper-V)
IFACE=$(ip -o link show | awk -F': ' '$2 !~ "lo|veth|docker|flannel|cni" {print $2; exit}')

cat <<EOF | sudo tee /etc/netplan/99-vagrant-static.yaml
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: no
      addresses:
        - ${CLUSTER_IP}/24
      routes:
        - to: default
          via: 192.168.60.1
      nameservers:
        addresses:
EOF

sudo chmod 600 /etc/netplan/99-vagrant-static.yaml
sudo netplan apply
sleep 3

echo "=========================================="
echo " 1. Configuration système (Swap & Firewall) [$CLUSTER_NAME]"
echo "=========================================="
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y curl wget iptables ufw

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

if command -v ufw >/dev/null 2>&1; then
    sudo ufw disable || true
fi

FLANNEL_INTERFACE=$(ip -o -4 addr show | awk -v ip="$CLUSTER_IP" '$4 ~ "^"ip"/" {print $2; exit}')

echo "=========================================="
echo " 2. Installation du serveur K3s (Master)"
echo "=========================================="
INSTALL_ARGS="server --node-ip=${CLUSTER_IP} --advertise-address=${CLUSTER_IP} --flannel-iface=${FLANNEL_INTERFACE} --tls-san=${CLUSTER_IP} --write-kubeconfig-mode 644"
curl -sfL https://k3s.io | sh -s - ${INSTALL_ARGS}

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
sed -i "s/127.0.0.1/${CLUSTER_IP}/g" /home/vagrant/.kube/config
sed -i "s/default/${CLUSTER_NAME}/g" /home/vagrant/.kube/config
echo "export KUBECONFIG=/home/vagrant/.kube/config" | sudo tee /etc/profile.d/k3s.sh
sudo chmod +x /etc/profile.d/k3s.sh
export KUBECONFIG=/home/vagrant/.kube/config

# Sauvegarde dans /home/vagrant pour récupération facile sans SMB
cp /home/vagrant/.kube/config "/home/vagrant/kubeconfig-${CLUSTER_NAME}.yaml"
chown vagrant:vagrant "/home/vagrant/kubeconfig-${CLUSTER_NAME}.yaml"

if [ "$CLUSTER_NAME" == "argocd-hub" ]; then
    echo "=========================================="
    echo " 4. Installation et configuration de Argo CD"
    echo "=========================================="
    export ARGOCD_VERSION=v3.6.1
    kubectl create namespace argocd
    kubectl apply -n argocd --server-side --force-conflicts -f https://githubusercontent.com{ARGOCD_VERSION}/manifests/install.yaml

    # Exposition NodePort 30443 et mode insecure intégrés
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"name": "https", "port": 443, "targetPort": 8080, "nodePort": 30443}]}}'
    kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
    kubectl rollout restart deployment argocd-server -n argocd

    curl -sSL -o argocd https://github.com{ARGOCD_VERSION}/argocd-linux-amd64
    chmod +x argocd && sudo mv argocd /usr/local/bin/
fi

echo "=========================================================="
echo " Nœud ${CLUSTER_NAME} prêt sur IP : ${CLUSTER_IP}"
echo "=========================================================="
