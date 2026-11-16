#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-master}"
CLUSTER_IP="${2:-192.168.60.80}" 

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

MAIN_IP=$(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1)
# FLANNEL_INTERFACE=$(ip -4 route get "$CLUSTER_IP" | awk '{print $3; exit}')
FLANNEL_INTERFACE=$(ip -o -4 addr show | awk -v ip="$CLUSTER_IP" '$4 ~ "^"ip"/" {print $2; exit}')

echo "=========================================="
echo " 2. Installation du serveur K3s (Master)"
echo "=========================================="

INSTALL_ARGS="server --node-ip=${CLUSTER_IP} --advertise-address=${CLUSTER_IP} --flannel-iface=${FLANNEL_INTERFACE} --tls-san=${CLUSTER_IP} --write-kubeconfig-mode 644"
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
sed -i "s/127.0.0.1/${CLUSTER_IP}/g" /home/vagrant/.kube/config
sed -i "s/default/${CLUSTER_NAME}/g" /home/vagrant/.kube/config
echo "export KUBECONFIG=/home/vagrant/.kube/config" | sudo tee /etc/profile.d/k3s.sh
sudo chmod +x /etc/profile.d/k3s.sh
export KUBECONFIG=/home/vagrant/.kube/config

# Copie le kubeconfig dans /vagrant pour faciliter l'ajout de clusters dans Argo CD
cp /home/vagrant/.kube/config "/vagrant/kubeconfig-${CLUSTER_NAME}.yaml"


if [ "$CLUSTER_NAME" == "argocd-hub" ]; then
    echo "=========================================="
    echo " 4. Installation de Argo CD"
    echo "=========================================="
    export ARGOCD_VERSION=v3.6.1
    kubectl create namespace argocd
    kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    echo "[INFO] Argo CD installé dans le namespace 'argocd'"
    echo "[INFO] Pour récupérer le mot de passe initial de l'utilisateur 'admin', exécutez la commande suivante :"
    echo 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo'
    
    cat << 'EOF'
[INFO] Pour exposer l'interface Web d'Argo CD sur le port 30443, exécutez :
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"name": "https", "port": 443, "targetPort": 8080, "nodePort": 30443}]}}'
EOF
    curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
    chmod +x argocd && sudo mv argocd /usr/local/bin/
    argocd version --client
    echo "[INFO] Argo CD CLI installé et accessible via la commande 'argocd'"
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
    echo 'export KUBECONFIG=/home/vagrant/.kube/config' >> /home/vagrant/.zshrc
    echo 'source <(kubectl completion zsh)' >> /home/vagrant/.zshrc
    echo 'command -v argocd >/dev/null && source <(argocd completion zsh)' >> /home/vagrant/.zshrc
else
    echo "=========================================="
    echo " 4. Statut ZSH"
    echo "=========================================="
    echo "The zsh is not installed on this server"    
fi

echo "=========================================================="
echo " Nœud ${CLUSTER_NAME} du Cluster k3s est prêt !"
echo " Adresse IP du Nœud : ${MAIN_IP:-'127.0.0.1'}"
echo "=========================================================="