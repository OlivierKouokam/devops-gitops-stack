#!/bin/bash
VERSION_STRING="5:29.8.2-1~ubuntu.22.04~jammy"
ENABLE_ZSH=true

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker vagrant
echo '1' | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables > /dev/null

if [[ -n "$ENABLE_ZSH" && "$ENABLE_ZSH" == "true" ]]
then
    echo "We are going to install zsh"
    
    # 1. Installation des paquets requis
    sudo apt update && sudo apt -y install zsh git curl
    
    # 2. Changement du shell par défaut pour l'utilisateur vagrant
    echo "vagrant" | chsh -s /bin/zsh vagrant
    
    # 3. Installation de Oh My Zsh (mode non-interactif via RUNZSH=no et KEEP_ZSHRC=yes)
    su - vagrant -c 'RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    
    # 4. Clonage du plugin (utilisation de guillemets simples pour laisser vagrant évaluer son propre home)
    su - vagrant -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'
    
    # 5. Configuration du fichier .zshrc
    # Commente l'ancienne ligne de plugins s'il elle existe
    sed -i 's/^plugins=/#&/' /home/vagrant/.zshrc
    
    # Ajoute les nouveaux plugins et change le thème
    echo "plugins=(git docker docker-compose colored-man-pages aliases copyfile copypath dotenv zsh-syntax-highlighting jsontools)" >> /home/vagrant/.zshrc
    sed -i "s/^ZSH_THEME=.*/ZSH_THEME='agnoster'/g" /home/vagrant/.zshrc
    
    echo "Zsh successfully installed and configured!"
else
    echo "The zsh is not installed on this server"    
fi

echo
echo "For this Stack, you will use $(hostname -I | awk '{print $1}') IP Address"
echo
