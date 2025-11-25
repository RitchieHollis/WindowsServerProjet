# --- VARIABLES ---
$DomainName   = "angleterre.lan"
$NetbiosName  = "ANGLETERRE"
$DSRMPassword = "Test123*" | ConvertTo-SecureString -AsPlainText -Force

# --- INSTALLATION AD DS ---
Write-Host "`n--- INSTALLATION DU RÔLE AD DS ---`n" -ForegroundColor Cyan
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# --- PROMOTION EN CONTRÔLEUR DE DOMAINE ---
Write-Host "`n--- PROMOTION EN CONTRÔLEUR DE DOMAINE ---`n" -ForegroundColor Cyan
Install-ADDSForest `
    -DomainName $DomainName `
    -SafeModeAdministratorPassword $DSRMPassword `
    -DomainNetbiosName $NetbiosName `
    -InstallDns `
    -Force

# Après la promotion, le serveur redémarre automatiquement
