#!/bin/bash
VERSION_STRING="5:29.8.1-1~ubuntu.24.04~noble"
ENABLE_ZSH="${ENABLE_ZSH:-true}"
# SERVER_IP=$(ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
# SERVER_IP=$(ip -4 addr show | grep '192.168.56.' | awk '{print $2}' | cut -d/ -f1)
SERVER_IP=$(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1)

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce=${VERSION_STRING} docker-ce-cli=${VERSION_STRING} containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker vagrant
echo '1' | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables > /dev/null

echo "========================================="
echo "Creation of persistence directories"
echo "========================================="
sudo mkdir -p /srv/gitlab/config /srv/gitlab/logs /srv/gitlab/data
sudo mkdir -p /srv/gitlab-runner/config
sudo chown -R 1000:1000 /srv/gitlab
sudo chown -R 1000:1000 /srv/gitlab-runner

echo "========================================="
echo "GitLab CE & Runner Deployment with Docker"
echo "========================================="

# Utilisation d'un fichier docker-compose éphémère sur la VM
sudo mkdir -p /home/vagrant/gitlab-ce
sudo chown -R vagrant:vagrant /home/vagrant/gitlab-ce

cat <<EOF > /home/vagrant/gitlab-ce/docker-compose.yml
version: '3.8'

services:
  gitlab:
    container_name: gitlab
    image: 'gitlab/gitlab-ce:19.5.3-ce.0'
    restart: always
    hostname: 'gitlab.local'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://${SERVER_IP}'
        # Configuration optionnelle du port SSH interne si besoin
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        gitlab_rails['monitoring_whitelist'] = ['127.0.0.0/8', '192.168.56.0/24', '172.16.0.0/12']
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
    volumes:
      - '/srv/gitlab/config:/etc/gitlab'
      - '/srv/gitlab/logs:/var/log/gitlab'
      - '/srv/gitlab/data:/var/opt/gitlab'
    shm_size: '256m'

  gitlab-runner:
    image: 'gitlab/gitlab-runner:v19.5.2'
    container_name: 'gitlab-runner'
    restart: always
    depends_on:
      - gitlab
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock'
      - '/srv/gitlab-runner/config:/etc/gitlab-runner'  
EOF

cd /home/vagrant/gitlab-ce
sudo docker compose up -d

echo "========================================="
echo "GitLab is being deployed..."
echo "========================================="

echo "+++++++++++++++++++++++++++++++++++++++++"

echo "========================================="
echo "Waiting for GitLab to start..."
echo "========================================="
# GitLab met quelques minutes à initialiser ses services internes
# until docker exec -it gitlab curl -s http://127.0.0.1/-/liveness | grep -q "OK"; do
until curl -s http://${SERVER_IP}/-/liveness | grep -qi "OK"; do
  echo "GitLab is heating up... New attempt in 10 seconds."
  sleep 10
done
echo "========================================="
echo "GitLab is up & running !"
echo "========================================="

echo "+++++++++++++++++++++++++++++++++++++++++"

echo "==========================================="
echo "Token Generation and Runner Registration..."
echo "==========================================="

# 1. Création du Personal Access Token (PAT) temporaire pour l'administrateur root
GITLAB_PAT=$(sudo docker exec -i gitlab gitlab-rails runner "user = User.find_by_username('root'); token = user.personal_access_tokens.create(scopes: ['api', 'create_runner'], name: 'Automation Token', expires_at: 1.day.from_now); token.set_token('TempAdminToken999XYZ'); token.save!; print 'TempAdminToken999XYZ'")

# 2. Appel à l'API REST GitLab pour créer le Runner d'instance
API_RESPONSE=$(curl --silent --request POST \
  --header "PRIVATE-TOKEN: ${GITLAB_PAT}" \
  --header "Content-Type: application/json" \
  --data '{"runner_type": "instance_type", "description": "Docker Auto Runner", "tag_list": "docker,ubuntu"}' \
  "http://${SERVER_IP}/api/v4/user/runners")

# 3. Extraction du token d'authentification (glrt-...)
RUNNER_TOKEN=$(echo "$API_RESPONSE" | grep -o '"token":"[^"]*' | grep -o '[^"]*$')

# 4. Enregistrement du GitLab Runner dans son conteneur
sudo docker exec -i gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "http://${SERVER_IP}" \
  --token "${RUNNER_TOKEN}" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "docker-executor-runner"

# 5. NETTOYAGE SÉCURITÉ : Révocation immédiate du token administrateur temporaire
echo "Revoking temporary admin token..."
sudo docker exec -i gitlab gitlab-rails runner "token = PersonalAccessToken.find_by(token_digest: Devise.token_generator.digest(PersonalAccessToken, :token, 'TempAdminToken999XYZ')); token.revoke! if token"


echo "========================================="
echo "Zsh Configuration (if needed)..."
echo "========================================="

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
echo "----------------------------------------------------------------"
echo "GitLab CE & Runner is now installed and running on your server."
echo "For this Stack, you will use ${SERVER_IP} IP Address"

echo "Enter the following command to retrieve the Root password for GitLab:"
echo "sudo docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password"
echo "----------------------------------------------------------------"

