Param(
    [string]$DomainDN = (Get-ADDomain).DistinguishedName
)

Import-Module ActiveDirectory

$RootOU = "Direction"
$RootOUPath = "OU=$RootOU,$DomainDN"

if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$RootOU)" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name $RootOU -Path $DomainDN
    Write-Host "OU créée : $RootOU"
} else {
    Write-Host "OU déjà existante : $RootOU"
}

$Structure = @{
    "Informatique"        = @("Developpement", "Hotline", "Systemes")
    "Ressources humaines" = @("Recrutement", "Gestion du personnel")
    "Finances"            = @("Investissements", "Comptabilite")
    "R&D"                 = @("Testing", "Recherche")
    "Technique"           = @("Techniciens", "Achat")
    "Commerciaux"         = @("Sedentaires", "Technico")
    "Marketing"           = @("Site1", "Site2", "Site3", "Site4")
}

Write-Host "=== DÉBUT DE CRÉATION DES OU ET GROUPES ===" -ForegroundColor Cyan

foreach ($OUParent in $Structure.Keys) {

    $ParentOUPath = "OU=$OUParent,$RootOUPath"

    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUParent)" -SearchBase $RootOUPath -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $OUParent -Path $RootOUPath
        Write-Host "OU créée : $OUParent"
    } else {
        Write-Host "OU déjà existante : $OUParent"
    }

    foreach ($OUSub in $Structure[$OUParent]) {

        $SubOUPath = "OU=$OUSub,$ParentOUPath"

        if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUSub)" -SearchBase $ParentOUPath -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $OUSub -Path $ParentOUPath
            Write-Host "  Sous-OU créée : $OUSub"
        } else {
            Write-Host "  Sous-OU déjà existante : $OUSub"
        }

        $Prefix = $OUParent.ToUpper().Replace(" ", "")
        $GroupName = "GG_${Prefix}_$($OUSub.ToUpper().Replace(' ', ''))"

        if (-not (Get-ADGroup -Filter "SamAccountName -eq '$GroupName'" -ErrorAction SilentlyContinue)) {

            New-ADGroup -Name $GroupName `
                        -SamAccountName $GroupName `
                        -GroupScope Global `
                        -GroupCategory Security `
                        -Path $SubOUPath

            Write-Host "    Groupe créé : $GroupName"
        } else {
            Write-Host "    Groupe déjà existant : $GroupName"
        }
    }
}

Write-Host "=== SCRIPT TERMINÉ ===" -ForegroundColor Green
