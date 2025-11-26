Param(
    [string]$Domain = "angleterre.lan",
    [string]$GroupName = "GG_DIRECTION",
    [string]$PSOName = "PSO_Direction"
)

Import-Module ActiveDirectory

$CurrentDomain = (Get-ADDomain).DNSRoot

Write-Host "=== Vérification du domaine ===" -ForegroundColor Cyan

if ($CurrentDomain -ne $Domain) {
    Write-Host "ERREUR : Ce script doit être exécuté dans le domaine '$Domain'." -ForegroundColor Red
    Write-Host "         Domaine actuel détecté : $CurrentDomain" -ForegroundColor Yellow
    exit
} else {
    Write-Host "OK : Domaine correct ($CurrentDomain)" -ForegroundColor Green
}

Write-Host "`n=== Vérification du groupe Direction ===" -ForegroundColor Cyan
$group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue

if (-not $group) {
    Write-Host "Le groupe $GroupName n'existe pas." -ForegroundColor Red
    exit
} else {
    Write-Host "Groupe trouvé : $($group.DistinguishedName)" -ForegroundColor Green
}

Write-Host "`n=== Création du Password Settings Object ===" -ForegroundColor Cyan

$minLength = 15
$complexityEnabled = $true
$lockoutDuration = New-TimeSpan -Minutes 30
$lockoutThreshold = 5

$existingPSO = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq '$PSOName'" -ErrorAction SilentlyContinue

if ($existingPSO) {
    Write-Host "Un PSO nommé $PSOName existe déjà." -ForegroundColor Yellow
} else {
    Write-Host "Création du PSO..." -ForegroundColor Yellow
    New-ADFineGrainedPasswordPolicy `
        -Name $PSOName `
        -Precedence 10 `
        -LockoutDuration $lockoutDuration `
        -LockoutObservationWindow $lockoutDuration `
        -LockoutThreshold $lockoutThreshold `
        -MinPasswordLength $minLength `
        -ComplexityEnabled $complexityEnabled `
        -PasswordHistoryCount 10 `
        -MinPasswordAge (New-TimeSpan -Hours 1) `
        -MaxPasswordAge (New-TimeSpan -Days 30) `
        -ReversibleEncryptionEnabled $false

    Write-Host "PSO créé." -ForegroundColor Green
}

Write-Host "`n=== Application du PSO au groupe ===" -ForegroundColor Cyan

Add-ADFineGrainedPasswordPolicySubject `
    -Identity $PSOName `
    -Subjects $group.DistinguishedName

Write-Host "PSO appliqué au groupe $GroupName." -ForegroundColor Green

Write-Host "`n=== Script terminé avec succès ===" -ForegroundColor Cyan
