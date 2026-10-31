```bash
# Lancer la stack en stockant les logs dans un fichier
vagrant up 2>&1 | tee gitlab-ce-logs.txt
```

# GitLab CE Docker : forge Git complète avec CI/CD intégré
https://brandonvisca.com/gitlab-ce-docker-forge-cicd-complete/

Installe GitLab CE Docker chez toi, une forge Git complète avec CI/CD, Container Registry et Runners self-hosted, sans dépendre du cloud.

* **Date de publication :** 20 sept. 2026
* **Temps de lecture :** 7 min
* **Tags :** `#docker` `#auto-hebergement` `#guide` `#intermediaire`

> **💡 TL;DR**
> * **GitLab CE Docker**, c’est une forge Git complète (dépôts, issues, wiki, CI/CD, Container Registry) qui tourne dans un seul conteneur Omnibus.
> * **Installation** en un `docker-compose.yml`, mot de passe root à récupérer dans les 24h, puis GitLab Runner pour le CI/CD.
> * **Gratuit, open-source**, et tu gardes ton code chez toi au lieu de le confier à GitHub ou GitLab.com.

---

## GitLab CE Docker : la forge Git complète à la maison

Tu en as marre de dépenser de l’énergie à dépendre de GitHub pour héberger ton code perso, ou de payer un abonnement GitLab.com juste pour avoir du CI/CD illimité ? La solution tient dans un seul conteneur. GitLab CE Docker te donne une forge Git complète : dépôts privés, gestion des issues, wiki, container registry, et surtout un système de CI/CD intégré, sans limite artificielle de minutes de build.

Chez moi, GitLab CE Docker tourne depuis un moment sur une VM dédiée du homelab. C’est devenu le cœur de mon infra de dev : chaque projet a son dépôt, ses pipelines, ses images Docker buildées automatiquement. Zéro dépendance externe, zéro facture surprise en fin de mois. Ce guide t’emmène de l’installation jusqu’à un premier pipeline CI/CD fonctionnel.

---

## GitLab CE, c’est quoi exactement ?

GitLab Community Edition (CE) est la version gratuite et open-source de GitLab, éditée par GitLab Inc. Elle tourne sous licence MIT et regroupe dans un seul paquet Omnibus tout ce qu’il faut pour une forge logicielle complète :

* **Gestion de dépôts Git :** illimités, privés ou publics, avec mirroring possible depuis GitHub ou Bitbucket.
* **Issues et tableaux Kanban :** suivi de bugs, épics, jalons, comme sur GitHub mais sans les restrictions du plan gratuit.
* **CI/CD natif :** pipelines définis dans un `.gitlab-ci.yml`, sans limite de minutes en self-hosted.
* **Container Registry :** ton propre registre d’images Docker, privé, lié directement à chaque projet.
* **Wiki intégré :** pour documenter un projet à côté de son code, léger mais suffisant pour un dépôt.
* **Merge requests avec revue de code :** commentaires en ligne, approbations obligatoires, pipelines bloquants.

La différence avec GitLab Enterprise Edition (EE) : pas de SAML avancé, pas d’audit logs poussés, pas de fonctions IA propriétaires. Pour un homelab ou une petite équipe, la CE couvre largement le besoin. L’éditeur documente les deux éditions sur gitlab.com, et la distinction se joue surtout sur des fonctions de gouvernance qu’un usage perso ne réclame jamais.

---

## Prérequis pour installer GitLab CE avec Docker

GitLab CE Docker n’est pas un petit conteneur léger comme Nginx ou Redis. C’est un Omnibus qui embarque PostgreSQL, Redis, Puma, Sidekiq, Nginx et Gitaly, tout ça dans une seule image. Avant de te lancer, prévois :

* **4 Go de RAM minimum**, 8 Go recommandés si tu comptes activer le Container Registry et plusieurs runners.
* **Docker Engine** récent avec Docker Compose V2 (`docker compose version` pour vérifier).
* **Au moins 10 Go de disque** pour l’image et les données, plus selon le volume de tes dépôts.
* **Un nom d’hôte accessible**, pas `localhost` : GitLab génère ses URLs internes à partir du hostname configuré.
* **Un agent SMTP** ou un compte relais mail si tu veux les notifications par email, sinon tu peux t’en passer.

Une machine avec 2 vCPU et 4 Go suffit pour un usage solo. Dès que tu ajoutes une équipe ou des pipelines CI/CD gourmands, passe à 4 vCPU et 8 Go. Pour ceux qui débutent avec les conteneurs, j’ai un guide sur *Code Server Docker* qui explique les bases de Docker Compose avant d’attaquer un service plus lourd comme celui-ci.

---

## Installation de GitLab CE en Docker Compose

Crée un dossier dédié avec les trois sous-répertoires que GitLab Omnibus attend :

```bash
mkdir -p ~/gitlab/{config,logs,data}
cd ~/gitlab
```

Voici le fichier `docker-compose.yml` pour lancer ton GitLab CE Docker :

```yaml
services:
  gitlab:
    image: gitlab/gitlab-ce:19.4.0-ce.0
    container_name: gitlab
    hostname: gitlab.mondomaine.fr
    restart: unless-stopped
    shm_size: "256m"
    ports:
      - "80:80"
      - "443:443"
      - "2222:22"
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.mondomaine.fr'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        nginx['listen_port'] = 80
        nginx['listen_https'] = false
    volumes:
      - ./config:/etc/gitlab
      - ./logs:/var/log/gitlab
      - ./data:/var/opt/gitlab
```

Deux points à retenir sur ce fichier. D’abord le port SSH : on le remappe sur `2222` côté hôte parce que le `22` est probablement déjà pris par le SSH de ta machine. Ensuite le `nginx['listen_https'] = false` : ici, GitLab sert du HTTP en interne, et c’est ton reverse proxy externe qui gère le certificat TLS. C’est la configuration la plus simple à maintenir sur la durée.

Lance le tout :

```bash
docker compose up -d
```

Le premier démarrage prend entre 3 et 5 minutes le temps que PostgreSQL s’initialise et que Puma compile ses assets. Suis les logs pour vérifier que tout se passe bien :

```bash
docker compose logs -f gitlab
```

Quand tu vois `gitlab Reconfigured!` dans les logs, ton GitLab CE Docker est prêt.

---

## Premiers pas : mot de passe root et configuration

GitLab génère un mot de passe root aléatoire au premier démarrage, stocké dans un fichier qui s’autodétruit après 24 heures. Récupère-le tout de suite :

```bash
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

Connecte-toi sur `https://gitlab.mondomaine.fr` avec l’utilisateur `root` et ce mot de passe, puis change-le immédiatement dans les paramètres du compte. C’est aussi le bon moment pour désactiver les inscriptions publiques si ton instance est exposée sur internet : **Admin Area > Settings > General > Sign-up restrictions**.

Crée ensuite ton premier groupe et ton premier projet. Un groupe GitLab regroupe plusieurs dépôts sous une même organisation, avec des permissions héritées, pratique dès que tu gères plus de deux ou trois projets.

---

## CI/CD et Container Registry avec les GitLab Runners

Le CI/CD est la vraie raison de choisir GitLab CE Docker plutôt qu’une simple forge Git. Chaque projet peut définir un fichier `.gitlab-ci.yml` à la racine, et GitLab exécute les pipelines à chaque push. Mais pour que ça tourne, il faut au moins un runner enregistré.

Déploie un GitLab Runner dans un conteneur séparé :

```bash
docker run -d --name gitlab-runner --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

Puis enregistre-le auprès de ton instance, avec le token récupéré dans **Admin Area > CI/CD > Runners** :

```bash
docker run --rm -it -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner register
```

Le script interactif te demande l’URL de ton GitLab CE Docker, le token, un tag pour le runner, et l’executor. Choisis `docker` comme executor : chaque job de pipeline tournera alors dans son propre conteneur jetable, isolé du reste.

Un `.gitlab-ci.yml` minimal pour tester :

```yaml
build:
  image: alpine:latest
  script:
    - echo "Pipeline GitLab CE Docker fonctionnel"
```

Pousse ce fichier sur ton dépôt, et regarde l’onglet **CI/CD > Pipelines**. Si tout est vert, ton runner fonctionne. À partir de là, tu peux builder des images Docker et les pousser directement vers le Container Registry intégré, activé par défaut sur chaque projet, sans configuration supplémentaire à part une entrée DNS pour le sous-domaine `registry`.

---

## Sécuriser et exposer ton GitLab CE Docker

Un GitLab CE Docker exposé sur internet sans précaution est une cible. Quelques réflexes avant d’ouvrir les ports vers l’extérieur.

* ⚠️ **Pare-feu d’abord.** N’expose que les ports 80/443 (via ton reverse proxy) et le port SSH remappé si tu veux le `git push` en SSH. Mon guide sur *UFW et Docker* explique pourquoi Docker contourne parfois les règles UFW classiques en manipulant `iptables` directement, un piège classique qui laisse des ports grands ouverts sans que tu le voies.
* ✅ **Authentification renforcée.** Si ton instance sert plusieurs personnes, mets une couche de 2FA devant l’interface web en plus du 2FA natif de GitLab. J’utilise Authelia devant mes services Docker pour centraliser le SSO, pratique quand tu hai GitLab, un wiki et un dashboard de monitoring à protéger avec les mêmes identifiants.
* 💡 **Résolution DNS propre.** Si ton GitLab CE Docker vit sur un sous-domaine interne (`gitlab.lan` par exemple), un résolveur DNS local évite de dépendre du DNS public pour un service qui ne sort jamais de ton réseau. J’ai détaillé la configuration dans mon guide sur *Unbound en DNS récursif*.

Pense aussi à limiter les tentatives de connexion : GitLab intègre un rate limiting configurable dans `gitlab_rails['rack_attack_git_basic_auth']`, activable directement dans le bloc `GITLAB_OMNIBUS_CONFIG` du compose.

---

## GitLab CE vs GitHub vs Gitea

La vraie question c’est : pourquoi préférer GitLab CE Docker à une alternative plus légère ou à un service cloud gratuit ?

* **GitHub :** gratuit en dépôts publics et privés, mais tu ne possèdes rien. Les Actions ont des quotas de minutes, et ton code vit sur l’infra de Microsoft. Zéro contrôle en cas de suspension de compte.
* **Gitea (ou son fork Forgejo) :** beaucoup plus léger, 200 Mo de RAM suffisent, idéal pour un simple hébergement Git. Mais le CI/CD intégré (Actions Gitea) est récent et moins mature que celui de GitLab, qui a plus de dix ans de rodage.
* **GitLab CE Docker :** le compromis le plus complet. Plus lourd à faire tourner que Gitea, mais tu récupères CI/CD, Container Registry, merge requests avancées et wiki dans un seul outil, sans jongler entre trois services séparés.

Si ta machine a moins de 2 Go de RAM disponibles, Gitea reste le choix raisonnable. Si tu as la RAM et que tu veux du CI/CD sérieux sans repasser par GitHub Actions, GitLab CE Docker est largement au niveau d’une offre cloud payante, gratuitement, chez toi.

> 💡 **À lire aussi :** *PairDrop Docker : AirDrop multiplateforme via le navigateur*, dans la même veine que cet article.
> 💡 **À lire aussi :** *Whoogle Docker : pourquoi le projet est mort et par quoi le remplacer*, dans la même veine que cet article.
> 💡 **À lire aussi :** *SearXNG Docker : méta-moteur de recherche auto-hébergé et personnalisable*, dans la même veine que cet article.

---

## Sauvegardes, mises à jour et conclusion

GitLab embarque son propre outil de sauvegarde, à lancer directement dans le conteneur :

```bash
docker exec -t gitlab gitlab-backup create
```

L’archive atterrit dans `/var/opt/gitlab/backups`, donc dans ton volume `./data` si tu as suivi le compose plus haut. Programme-la en cron hebdomadaire, et sauvegarde aussi le dossier `./config` séparément : il contient les clés de chiffrement, sans lesquelles une restauration de backup est inutilisable.

Pour les mises à jour, ne saute jamais plus d’une version mineure d’un coup, GitLab impose des chemins de migration précis entre versions majeures. Un simple `docker compose pull && docker compose up -d` suffit pour une mise à jour mineure, mais consulte toujours la documentation de mise à jour officielle sur docs.gitlab.com avant un saut de version majeure.

Voilà, ton GitLab CE Docker est en ligne, sécurisé, avec un runner qui exécute tes pipelines. Tu as maintenant une forge complète qui ne dépend d’aucun service tiers, avec un vrai CI/CD et un registre d’images privé. La seule contrepartie, c’est la maintenance : c’est toi l’admin système, maintenant. Mais franchement, reprendre la main sur son code, ça n’a pas de prix.
