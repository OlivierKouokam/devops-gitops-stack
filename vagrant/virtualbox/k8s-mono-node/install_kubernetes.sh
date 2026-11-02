
#!/bin/bash
# 1. Mettre à jour la liste des paquets et appliquer les mises à jour disponibles
sudo apt update

# 2. (Optionnel) Activer le dépôt Universe – l’équivalent le plus proche de « extras »
#    – ainsi que le PPA officiel si vous souhaitez la dernière version stable d’Ansible
sudo add-apt-repository universe
sudo add-apt-repository --yes ppa:ansible/ansible
sudo apt update            # Re-lecture des index après ajout de dépôts

# 3. Installer Ansible
sudo apt -y install ansible

cd /vagrant

ansible-galaxy install -r roles/requirements.yml

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

KUBERNETES_VERSION=1.31
IP=$(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1)

if [ "$1" == "k8s-mono" ]
then
    ansible-playbook install_kubernetes.yml --extra-vars "kubernetes_role=control_plane kubernetes_apiserver_advertise_address=$2 installation_method=vagrant kubernetes_version='$KUBERNETES_VERSION'"
    # Installer bash-completion puis enregistrer l’auto-complétion de kubectl
    sudo apt update && sudo apt -y install bash-completion \
    && kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    echo 'source <(kubectl completion bash)' >> ~/.bashrc

    # # Version de Calico à installer
    # CALICO_VERSION="v3.33.0"
    # # Votre plage d'IP pour les Pods (modifier si différent de 192.168.0.0/16)
    # # POD_CIDR="10.244.0.0/16" 
    # POD_CIDR="192.168.0.0/16" 

    # echo "=== 1. Application du manifeste Tigera Operator ==="
    # # kubectl create -f "https://githubusercontent.com{CALICO_VERSION}/manifests/tigera-operator.yaml"
    # kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml

    # echo "=== 2. Attente de la mise en route de l'opérateur ==="
    # # Attend que le déploiement de l'opérateur soit disponible
    # kubectl wait --namespace tigera-operator --for=condition=available deployment/tigera-operator --timeout=60s

    # echo "=== 3. Préparation des Custom Resources ==="
    # # Téléchargement du fichier localement pour modification à la volée
    # curl -sL "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml" -o /tmp/custom-resources.yaml

    # # Modification dynamique du CIDR si nécessaire
    # if [ "$POD_CIDR" != "192.168.0.0/16" ]; then
    #     echo "Ajustement du Pod CIDR vers $POD_CIDR..."
    #     sed -i "s|cidr: 192.168.0.0/16|cidr: $POD_CIDR|g" /tmp/custom-resources.yaml
    # fi

    # echo "=== 4. Application de la configuration du réseau Calico ==="
    # kubectl create -f /tmp/custom-resources.yaml

    # echo "=== 5. Vérification du statut du réseau ==="
    # echo "Calico s'initialise. Vous pouvez suivre le statut avec : kubectl get pods -n calico-system -w"

    # # Nettoyage
    # rm -f /tmp/custom-resources.yaml
    
    echo "###################################################"
    echo "For this Stack, you will use $IP IP Address"
    echo "You need to be root to use kubectl in $IP VM (run 'sudo su -' to become root and then use kubectl as you want)"
    echo "###################################################"
    
else
    ansible-playbook install_kubernetes.yml --extra-vars "kubernetes_role=$1 kubernetes_apiserver_advertise_address=$2 kubernetes_version='$KUBERNETES_VERSION' kubernetes_join_command='kubeadm join {{ kubernetes_apiserver_advertise_address }}:6443 --ignore-preflight-errors=all --token={{ token }}  --discovery-token-unsafe-skip-ca-verification'"
    echo "For this Stack, you will use $IP IP Address"
fi