#!/bin/bash

# Quitter immédiatement si une commande échoue
set -e

# Version de Calico à installer
CALICO_VERSION="v3.27.0"
# Votre plage d'IP pour les Pods (modifier si différent de 192.168.0.0/16)
POD_CIDR="192.168.0.0/16" 

echo "=== 1. Application du manifeste Tigera Operator ==="
kubectl create -f "https://githubusercontent.com{CALICO_VERSION}/manifests/tigera-operator.yaml"

echo "=== 2. Attente de la mise en route de l'opérateur ==="
# Attend que le déploiement de l'opérateur soit disponible
kubectl wait --namespace tigera-operator \
  --for=condition=available deployment/tigera-operator \
  --timeout=60s

echo "=== 3. Préparation des Custom Resources ==="
# Téléchargement du fichier localement pour modification à la volée
curl -sL "https://githubusercontent.com{CALICO_VERSION}/manifests/custom-resources.yaml" -o /tmp/custom-resources.yaml

# Modification dynamique du CIDR si nécessaire
if [ "$POD_CIDR" != "192.168.0.0/16" ]; then
    echo "Ajustement du Pod CIDR vers $POD_CIDR..."
    sed -i "s|cidr: 192.168.0.0/16|cidr: $POD_CIDR|g" /tmp/custom-resources.yaml
fi

echo "=== 4. Application de la configuration du réseau Calico ==="
kubectl create -f /tmp/custom-resources.yaml

echo "=== 5. Vérification du statut du réseau ==="
echo "Calico s'initialise. Vous pouvez suivre le statut avec : kubectl get pods -n calico-system -w"

# Nettoyage
rm -f /tmp/custom-resources.yaml
