#!/bin/bash
set -e

# --- 1. SPÉCIFICATION DE LA VERSION DE DOCKER ---
# Définissez ici la version exacte souhaitée.
# Remarque : si cette version exacte n'est pas disponible dans les dépôts d'Ubuntu 24.04 (Noble),
# laissez les variables vides ("") pour installer la dernière version stable automatiquement.
DOCKER_VERSION="5:29.8.1-1~ubuntu.24.04~noble"

# --- 2. INSTALLATION DE DOCKER ---
echo "Mise à jour du système et installation des dépendances Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Ajout du dépôt officiel Docker Ubuntu (URL corrigée)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

# Verification et installation de la version demandée
if [ -n "$DOCKER_VERSION" ] && apt-cache policy docker-ce | grep -q "$DOCKER_VERSION"; then
    echo "Installation de la version spécifique de Docker : $DOCKER_VERSION"
    sudo apt-get install -y \
      docker-ce=$DOCKER_VERSION \
      docker-ce-cli=$DOCKER_VERSION \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin
else
    echo "La version spécifique '$DOCKER_VERSION' n'a pas été trouvée dans le dépôt."
    echo "Installation de la dernière version stable disponible..."
    sudo apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin
fi

sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker vagrant

# --- 3. CONFIGURATION DE LA STACK JENKINS MULTI-NODES ---
echo "Configuration de la stack Jenkins (Master + Agents)..."
mkdir -p /home/vagrant/jenkins/init.groovy.d
cd /home/vagrant/jenkins

# Création du fichier docker-compose.yml
cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  jenkins-master:
    image: jenkins/jenkins:2.568.3-lts-jdk21
    container_name: jenkins-master
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false # Désactive l'assistant de configuration si vous voulez aller vite
    volumes:
      - jenkins_home:/var/jenkins_home
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/login || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  jenkins-agent-1:
    image: jenkins/inbound-agent:latest
    container_name: jenkins-agent-1
    restart: unless-stopped
    depends_on:
      jenkins-master:
        condition: service_healthy # L'agent ne démarre QUE si le Master répond sur le port 8080
    environment:
      - JENKINS_URL=http://jenkins-master:8080
      - JENKINS_AGENT_NAME=agent-1
      - JENKINS_SECRET=${JENKINS_AGENT_1_SECRET} # Variable récupérée dans un fichier .env ou exportée
      - JENKINS_WEB_SOCKET=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # Optionnel: si l'agent doit exécuter des commandes Docker

  jenkins-agent-2:
    image: jenkins/inbound-agent:latest
    container_name: jenkins-agent-2
    restart: unless-stopped
    depends_on:
      jenkins-master:
        condition: service_healthy # L'agent ne démarre QUE si le Master répond sur le port 8080
    environment:
      - JENKINS_URL=http://jenkins-master:8080
      - JENKINS_AGENT_NAME=agent-2
      - JENKINS_SECRET=${JENKINS_AGENT_2_SECRET} # Variable récupérée dans un fichier .env ou exportée
      - JENKINS_WEB_SOCKET=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # Optionnel: si l'agent doit exécuter des commandes Docker

volumes:
  jenkins_home:
EOF

cat << 'EOF' > .env
JENKINS_AGENT_1_SECRET=votre_secret_hexadecimal_ici
JENKINS_AGENT_2_SECRET=votre_second_secret_ici
EOF

sudo chown -R vagrant:vagrant /home/vagrant/jenkins

# Démarrage des conteneurs
docker compose up -d jenkins-master

# --- 4. AFFICHAGE DES INFORMATIONS DE CONNEXION ---
VM_IP=$(ip -4 addr show eth1 | awk '/inet / {print $2}' | cut -d/ -f1)

echo "----------------------------------------------------------------"
echo "Adresse IP de la VM : $VM_IP"
echo "URL de Jenkins : http://$VM_IP:8080"
echo "----------------------------------------------------------------"

#echo "En attente de la génération du mot de passe administrateur Jenkins..."



# until sudo docker exec jenkins-master test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; do
#     sleep 2
# done

# echo "----------------------------------------------------------------"
# echo "MOT DE PASSE INITIAL DE L'ADMINISTRATEUR JENKINS :"
# sudo docker exec jenkins-master cat /var/jenkins_home/secrets/initialAdminPassword
# echo "----------------------------------------------------------------"