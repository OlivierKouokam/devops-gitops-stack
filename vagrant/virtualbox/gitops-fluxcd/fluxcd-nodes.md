1- kubectl config use-context k3d-cluster-1
2- curl -s https://fluxcd.io/install.sh | FLUX_VERSION=2.10.0 bash
3- flux install

# Création du secret pour cluster1
kubectl create secret generic cluster1-kubeconfig \
  --namespace=flux-system \
  --from-file=value=/vagrant/kubeconfig-fluxcd-cluster1.yaml

# Création du secret pour cluster2
kubectl create secret generic cluster2-kubeconfig \
  --namespace=flux-system \
  --from-file=value=/vagrant/kubeconfig-fluxcd-cluster2.yaml


flux create source git mon-depot-gitops \
  --url=https://github.com \
  --branch=main \
  --interval=1m \
  --export > git-source.yaml

kubectl apply -f git-source.yaml

### deploy-clusters.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps-cluster1
  namespace: flux-system
spec:
  interval: 2m
  path: "./clusters/cluster1"
  prune: true
  sourceRef:
    kind: GitRepository
    name: mon-depot-gitops
  # C'est cette section qui cible le cluster distant :
  kubeConfig:
    secretRef:
      name: cluster1-kubeconfig
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps-cluster2
  namespace: flux-system
spec:
  interval: 2m
  path: "./clusters/cluster2"
  prune: true
  sourceRef:
    kind: GitRepository
    name: mon-depot-gitops
  # C'est cette section qui cible le cluster2 :
  kubeConfig:
    secretRef:
      name: cluster2-kubeconfig


kubectl apply -f deploy-clusters.yaml


flux get kustomizations

kubectl --kubeconfig=/vagrant/kubeconfig-fluxcd-cluster1.yaml get pods -A
