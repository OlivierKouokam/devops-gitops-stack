# Configurer et Démarrage des Agents Jenkins Conteneurisés

## Lancer la VM jenkins-multinode 
```bash
vagrant up
```

## Créer les agents 1 et 2 dans le navigateur 
```bash
http://<IP_VM>:8080
# Remote root directory : /home/jenkins/agent
```
## Copier les secrets de chaque agent


## Coller les secrets dans le fichier .env

## Lancer l'agent-1
```bash
docker compose up -d jenkins-agent-1
```

## Lancer l'agent-2
```bash
docker compose up -d jenkins-agent-2
```

## Utiliser Les agents dans des jobs !!!