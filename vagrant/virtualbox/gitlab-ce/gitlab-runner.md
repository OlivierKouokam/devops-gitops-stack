# Guide d'enregistrement de nouveaux GitLab Runners (Docker)

Ce document récapitule les deux méthodes pour enregistrer et ajouter de nouveaux runners conteneurisés selon vos cas d'usage.

---

## Cas 1 : Création via l'UI GitLab + Enregistrement `docker exec`
*Recommandé pour initialiser un runner classique de manière sécurisée en générant un jeton unique par l'interface.*

### Étape 1 : Générer le Token sur l'UI GitLab
1. Connectez-vous avec votre compte Administrateur (`root`) sur votre instance (`http://192.168.56.60`).
2. Ouvrez la **Admin Area** (Zone d'administration) en haut à gauche.
3. Dans le menu latéral gauche, cliquez sur **Runners**.
4. Cliquez sur le bouton bleu **New instance runner**.
5. *(Optionnel)* Cochez la case **Run untagged jobs** pour qu'il accepte n'importe quel projet sans tag imposé.
6. Cliquez sur **Create runner**.
7. Copiez le jeton d'authentification généré (il commence par `glrt-`).

### Étape 2 : Lancer l'enregistrement dans le conteneur
Exécutez la commande suivante dans votre terminal Vagrant (en remplaçant `VOTRE_TOKEN_A_COPIER` par votre clé `glrt-`) :

```bash
docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "http://192.168.56.60" \
  --token "VOTRE_TOKEN_A_COPIER" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
  --clone-url "http://192.168.56.60"
```

---

## Cas 2 : Enregistrement via `docker exec` uniquement (Mode Interactif)
*Pratique si vous ne souhaitez pas passer par le processus complet de création de boutons sur l'UI, mais préférez répondre aux questions directement dans votre terminal.*

### Étape 1 : Récupérer le Token global d'enregistrement (Legacy)
1. Allez dans **Admin Area** > **Runners**.
2. Récupérez le **Registration Token** global d'instance (généralement accessible via les options de l'ancienne méthode ou disponible dans les configurations d'intégration).

### Étape 2 : Lancer l'assistant interactif dans le terminal
Exécutez la commande suivante :

```bash
docker exec -it gitlab-runner gitlab-runner register
```

### Étape 3 : Saisir les informations demandées au prompt
Répondez aux questions de l'assistant de la manière suivante :

1. **Enter the GitLab instance URL:**  
   `http://192.168.56.60`
2. **Enter the registration token:**  
   `VOTRE_REGISTRATION_TOKEN_GLOBAL`
3. **Enter a description for the runner:**  
   `runner-interactif-custom` (ou laissez vide pour utiliser l'ID du conteneur)
4. **Enter tags for the runner (comma-separated):**  
   *(Laissez vide ou spécifiez des tags comme `docker,linux`)*
5. **Enter optional maintenance note for the runner:**  
   *(Laissez vide)*
6. **Enter an executor:**  
   `docker`
7. **Enter the default Docker image:**  
   `alpine:latest`

> ⚠️ **Important :** Après un enregistrement interactif, vous devez éditer manuellement le fichier de configuration avec `sudo vi /srv/gitlab-runner/config/config.toml` afin d'ajouter les lignes cruciales `clone_url = "http://192.168.56.60"` et le volume `"/var/run/docker.sock:/var/run/docker.sock"` sous la section `[runners.docker]`.

---

## Vérification de la configuration

Peu importe la méthode choisie, validez le succès de l'opération avec les commandes suivantes :

```bash
# 1. Vérifier que la communication est active (Doit renvoyer "is valid")
docker exec -it gitlab-runner gitlab-runner verify

# 2. Consulter la structure générée dans le fichier de l'hôte
sudo cat /srv/gitlab-runner/config/config.toml
```


# General Checking - HealthCheck

```bash
docker exec -it gitlab curl -i http://192.168.56.60/-/liveness
docker exec -it gitlab curl -s http://192.168.56.60/-/liveness
docker exec -it gitlab curl -i http://127.0.0.1/-/liveness
docker exec -it gitlab curl -s http://127.0.0.1/-/liveness
```