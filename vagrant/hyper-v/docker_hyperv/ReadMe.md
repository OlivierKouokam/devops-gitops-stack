# Utilisation un Commutateur Interne dédié (Recommandé pour un lab fixe)

## Créer un Internal Switch dans Hyper-V vous permet d'assigner une IP statique fixe à la VM (par exemple 192.168.50.10).

## 1. Créer le Commutateur Interne sous Windows (PowerShell Administrateur) {Se fait dans le Vagrantfile}

<!-- ```PowerShell
# Création de la Carte Réseau Virtuelle
New-VMSwitch -Name "Vagrant-Internal-50" -SwitchType Internal

# Attribution d'une IP à la passerelle par defaut
New-NetIPAddress -IPAddress 192.168.50.1 -PrefixLength 24 -InterfaceAlias "vEthernet (Vagrant-Internal-50)"
```

- Permettre à la Carte Réseau d'accéder à Internet (Ne pas faire pour rester en Host-Only)

```
# Réactiver l'obtention automatique de l'adresse IP (DHCP)
Set-NetIPInterface -InterfaceAlias "vEthernet (Vagrant-Internal-50)" -Dhcp Enabled

# Réactiver l'obtention automatique du serveur DNS
Set-DnsClientServerAddress -InterfaceAlias "vEthernet (Vagrant-Internal-50)" -ResetServerAddresses
``` -->

## 2. Lancer la VM
```PowerShell
vagrant up --no-provision
```
## 3. Arrêter la VM
```PowerShell
vagrant halt
```

## 4. Créez le switch et injectez la carte réseau à froid depuis Windows 
```PowerShell
powershell -ExecutionPolicy Bypass -Command "if (-not (Get-VMSwitch -Name 'Vagrant-Internal-50' -ErrorAction SilentlyContinue)) { New-VMSwitch -Name 'Vagrant-Internal-50' -SwitchType Internal; New-NetIPAddress -IPAddress 192.168.50.1 -PrefixLength 24 -InterfaceAlias 'vEthernet (Vagrant-Internal-50)' }; Add-VMNetworkAdapter -VMName 'docker' -SwitchName 'Vagrant-Internal-50' -Name 'Vagrant-Internal-50'"
```
## 5. Relancez la machine en forçant le provisioning réseau
```PowerShell
#vagrant up --provision-with network_setup
vagrant up --provision
```

## 6. Commandes pour SUPPRIMER le Switch Interne (si nécessaire)

Si un jour vous souhaitez nettoyer cette configuration ou supprimer le switch créé :

- Assurez-vous d'abord d'arrêter ou détruire la VM Vagrant :

```PowerShell
vagrant destroy -f
```

- Supprimez l'adresse IP associée puis le switch virtuel dans PowerShell (en mode Administrateur) :

```PowerShell
# 1. Supprimer l'adresse IP configurée sur la carte hôte
Remove-NetIPAddress -InterfaceAlias "vEthernet (Vagrant-Internal-50)" -Confirm:$false

# 2. Supprimer le commutateur virtuel Hyper-V
Remove-VMSwitch -Name "Vagrant-Internal-50" -Force
```

