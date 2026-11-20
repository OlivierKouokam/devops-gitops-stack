# Créer le commutateur virtuel interne
```Powershell
New-VMSwitch -SwitchName "Vagrant-GitOps" -SwitchType Internal
```

# Attribuer l'IP passerelle à votre PC Windows sur ce commutateur
```Powershell
New-NetIPAddress -IPAddress 192.168.60.1 -PrefixLength 24 -InterfaceAlias "vEthernet (Vagrant-GitOps)"
```

# Activer le partage de connexion (NAT) pour que les VM aient accès à Internet
```Powershell
New-NetNat -Name "VagrantGitOpsNAT" -InternalIPInterfaceAddressPrefix 192.168.60.0/24
```


# Depuis votre machine hôte
vagrant up --provider=hyperv
vagrant ssh argocd-hub

# Enregistrer les clusters sur le Hub (sans avoir besoin du dossier partagé /vagrant, via scp entre les VM) 
```bash
vagrant ssh argocd-hub

# Sur argocd-hub : récupérer les kubeconfigs des deux clusters
scp -o StrictHostKeyChecking=no vagrant@192.168.60.81:~/kubeconfig-argocd-cluster1.yaml ~/
scp -o StrictHostKeyChecking=no vagrant@192.168.60.82:~/kubeconfig-argocd-cluster2.yaml ~/

# Connexion à Argo CD (en HTTP car server.insecure=true est déjà appliqué)
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login 192.168.60.80:30443 --username admin --password "$ARGOCD_PWD" --plaintext

# Ajout des clusters cibles
argocd cluster add argocd-cluster1 --kubeconfig ~/kubeconfig-argocd-cluster1.yaml --name staging-cluster --yes
argocd cluster add argocd-cluster2 --kubeconfig ~/kubeconfig-argocd-cluster2.yaml --name prod-cluster --yes
argocd cluster list
```

###############################

# Une fois sur argocd-hub : exposez le service sur le port 30443
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"name": "https", "port": 443, "targetPort": 8080, "nodePort": 30443}]}}'

# Récupération du mot de passe dans une variable
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Connexion au serveur Argo CD
argocd login 192.168.60.80:30443 --username admin --password "$ARGOCD_PWD" --insecure

# autoriser le http - https insecure
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'

# Relancer argocd server
kubectl rollout restart deployment argocd-server -n argocd

# Vider le cache dns du PC Hôte
ipconfig /flushdns

# Ajout du cluster 1
argocd cluster add argocd-cluster1 --kubeconfig /vagrant/kubeconfig-argocd-cluster1.yaml --name staging-cluster --yes

# Ajout du cluster 2
argocd cluster add argocd-cluster2 --kubeconfig /vagrant/kubeconfig-argocd-cluster2.yaml --name prod-cluster --yes

# Lister les clusters gérés par Argo CD
argocd cluster list


