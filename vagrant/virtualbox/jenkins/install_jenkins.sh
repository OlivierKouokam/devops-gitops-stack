#!/bin/bash
VERSION_STRING="5:29.8.1-1~ubuntu.24.04~noble"
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

# --- CONFIGURE JENKINS MULTI-NODES WITH DOCKER COMPOSE ---
echo "Setting up Jenkins with Docker Compose..."
mkdir -p /home/vagrant/jenkins
cd /home/vagrant/jenkins

# Create a docker-compose.yml file for Jenkins
cat << 'EOF' > docker-compose.yml
services:
  jenkins:
    image: jenkins/jenkins:2.568.3-lts-jdk21
    container_name: jenkins
    restart: always
    privileged: true
    user: root
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock

volumes:
  jenkins_data:
EOF

# Change ownership of the Jenkins directory to the vagrant user
sudo chown -R vagrant:vagrant /home/vagrant/jenkins

# Running Docker Compose to start Jenkins
sudo docker compose up -d
# ------------------------------------------------------------------

if [[ !(-z "$ENABLE_ZSH")  &&  ($ENABLE_ZSH == "true") ]]
then
    echo "We are going to install zsh"
    sudo apt -y install zsh git
    echo "vagrant" | chsh -s /bin/zsh vagrant
    su - vagrant  -c  'echo "Y" | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    su - vagrant  -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'

    sed -i 's/^plugins=/#&/' /home/vagrant/.zshrc
    echo "plugins=(git  docker docker-compose colored-man-pages aliases copyfile  copypath dotenv zsh-syntax-highlighting jsontools)" >> /home/vagrant/.zshrc
    sed -i "s/^ZSH_THEME=.*/ZSH_THEME='agnoster'/g"  /home/vagrant/.zshrc
  else
    echo "The zsh is not installed on this server"
fi

echo "----------------------------------------------------------------"
echo "For this Stack, you will use $(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1) IP Address"
echo "----------------------------------------------------------------"
echo "Jenkins is running on http://$(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1):8080"
echo "----------------------------------------------------------------"
echo "To get the initial admin password, run the following command:"
echo "sudo docker exec jenkins-lts cat /var/jenkins_home/secrets/initialAdminPassword"
echo "----------------------------------------------------------------"
