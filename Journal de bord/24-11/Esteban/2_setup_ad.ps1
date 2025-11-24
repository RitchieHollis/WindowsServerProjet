########################################
# VARIABLES AD
########################################

$DomainName   = "anglettere.lan"
$DSRMPassword = "Test123*" | ConvertTo-SecureString -AsPlainText -Force

########################################
# 1. Installer AD DS
########################################
Write-Host "Installation du rôle AD DS..." -ForegroundColor Cyan
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

########################################
# 2. Promotion du contrôleur de domaine
########################################
Write-Host "Promotion du serveur en contrôleur de domaine..." -ForegroundColor Cyan

Install-ADDSForest `
    -DomainName $DomainName `
    -SafeModeAdministratorPassword $DSRMPassword `
    -DomainNetbiosName ($DomainName.Split(".")[0].ToUpper()) `
    -InstallDns `
    -Force

########################################
# 3. Le serveur va redémarrer automatiquement
########################################
