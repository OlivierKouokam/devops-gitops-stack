# Script de provisionnement PowerShell (install_iis.ps1)

Write-Host "=========================================="
Write-Host " 1. Installation du rôle IIS (Web Server)"
Write-Host "=========================================="
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

Write-Host "=========================================="
Write-Host " 2. Configuration de la page par défaut"
Write-Host "=========================================="
$HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Windows Server Vagrant</title>
</head>
<body>
    <h1>Serveur Windows provisionné avec succès via Vagrant !</h1>
</body>
</html>
"@

Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value $HtmlContent

Write-Host "Configuration terminée avec succès !"