# PRÉ-REQUIS HÔTE : Créer le vSwitch interne et son IP si absents

# 1. Créer le VMSwitch interne si inexistant
if (!(Get-VMSwitch -Name 'Vagrant-Internal-50' -ErrorAction SilentlyContinue)) {
    Write-Host "Creation du vSwitch Vagrant-Internal-50..."
    New-VMSwitch -Name 'Vagrant-Internal-50' -SwitchType Internal | Out-Null
}

# 2. Configurer la passerelle hôte 192.168.50.1
$ifAlias = 'vEthernet (Vagrant-Internal-50)'
if (Get-NetAdapter -Name $ifAlias -ErrorAction SilentlyContinue) {
    $hasIP = Get-NetIPAddress -InterfaceAlias $ifAlias -IPAddress '192.168.50.1' -ErrorAction SilentlyContinue
    if (!$hasIP) {
        Write-Host "Configuration de L`IP 192.168.50.1 sur l hote..."
        New-NetIPAddress -IPAddress '192.168.50.1' -PrefixLength 24 -InterfaceAlias $ifAlias | Out-Null
    }
}