Param(
    [string]$DomainDN = (Get-ADDomain).DistinguishedName
)

Import-Module ActiveDirectory

$RootOU = "Direction"
$RootOUPath = "OU=$RootOU,$DomainDN"

$Structure = @{
    "Informatique"        = @("Developpement", "Hotline", "Systemes")
    "Ressources humaines" = @("Recrutement", "Gestion du personnel")
    "Finances"            = @("Investissements", "Comptabilite")
    "R&D"                 = @("Testing", "Recherche")
    "Technique"           = @("Techniciens", "Achat")
    "Commerciaux"         = @("Sedentaires", "Technico")
    "Marketting"           = @("Site1", "Site2", "Site3", "Site4")
}

$RootGroup = "GG_DIRECTION"
$GLTypes = @("R", "W", "RW")

Write-Host "=== VERIFICATION DE L'OU DIRECTION ET GG_DIRECTION ===" -ForegroundColor Cyan
Write-Host ""

if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$RootOU)" -ErrorAction SilentlyContinue) {
    Write-Host "[OK] OU Direction trouvée"
} else {
    Write-Host "[ERREUR] OU Direction manquante"
}

if (Get-ADGroup -Filter "SamAccountName -eq '$RootGroup'" -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Groupe : $RootGroup"
} else {
    Write-Host "[ERREUR] Groupe manquant : $RootGroup"
}

foreach ($type in $GLTypes) {
    $GLName = "GL_DIRECTION_$type"
    if (Get-ADGroup -Filter "SamAccountName -eq '$GLName'" -ErrorAction SilentlyContinue) {
        Write-Host "   [OK] GL : $GLName"
    } else {
        Write-Host "   [ERREUR] GL manquant : $GLName"
    }
}

Write-Host ""
Write-Host "=== VERIFICATION DES UO, GG ET GL PAR DEPARTEMENT ===" -ForegroundColor Cyan
Write-Host ""

foreach ($OUParent in $Structure.Keys) {

    $ParentOUPath = "OU=$OUParent,$RootOUPath"

    if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUParent)" -SearchBase $RootOUPath -ErrorAction SilentlyContinue) {
        Write-Host "[OK] OU parent : $OUParent"
    } else {
        Write-Host "[ERREUR] OU parent manquante : $OUParent"
    }

    foreach ($OUSub in $Structure[$OUParent]) {

        $SubOUPath = "OU=$OUSub,$ParentOUPath"

        if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUSub)" -SearchBase $ParentOUPath -ErrorAction SilentlyContinue) {
            Write-Host "   [OK] Sous-OU : $OUSub"
        } else {
            Write-Host "   [ERREUR] Sous-OU manquante : $OUSub"
        }

        $Prefix = $OUParent.ToUpper().Replace(" ", "")
        $GroupName = "GG_${Prefix}_$($OUSub.ToUpper().Replace(' ', ''))"

        if (Get-ADGroup -Filter "SamAccountName -eq '$GroupName'" -ErrorAction SilentlyContinue) {
            Write-Host "      [OK] Groupe : $GroupName"
        } else {
            Write-Host "      [ERREUR] Groupe manquant : $GroupName"
        }

        foreach ($type in $GLTypes) {
            $GLName = "GL_"+$GroupName.Substring(3)+"_"+$type
            if (Get-ADGroup -Filter "SamAccountName -eq '$GLName'" -ErrorAction SilentlyContinue) {
                Write-Host "         [OK] GL : $GLName"
            } else {
                Write-Host "         [ERREUR] GL manquant : $GLName"
            }
        }
    }

    Write-Host ""
}

Write-Host "=== VERIFICATION TERMINEE ===" -ForegroundColor Green
