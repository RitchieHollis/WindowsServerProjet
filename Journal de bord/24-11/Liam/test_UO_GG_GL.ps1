# Ce script vérifie l'existence des OU, sous-OU et des groupes GG et GL
# Il tient compte de la nouvelle structure AD :
# - Pour les départements sans sous-OU, vérifie les sous-OU GG, GL et Users et leurs groupes
# - Pour les départements avec sous-OU, vérifie chaque sous-OU et les groupes correspondants
# - Les noms des groupes sont basés sur la nomenclature du script de création

Param(
    [string]$DomainDN = (Get-ADDomain).DistinguishedName
)

Import-Module ActiveDirectory

$Structure = @{
    "Direction"           = @()
    "Informatique"        = @("Developpement", "Hotline", "Systemes")
    "Ressources humaines" = @("Recrutement", "Gestion du personnel")
    "Finances"            = @("Investissements", "Comptabilite")
    "R&D"                 = @("Testing", "Recherche")
    "Technique"           = @("Techniciens", "Achat")
    "Commerciaux"         = @("Sedentaires", "Technico")
    "Marketting"          = @("Site1", "Site2", "Site3", "Site4")
}

$SubFolders = @("GG","GL","Users")
$GLTypes = @("R","W","RW")

Write-Host "=== VERIFICATION DE LA STRUCTURE AD ===" -ForegroundColor Cyan
Write-Host ""

foreach ($OUParent in $Structure.Keys) {

    $ParentOUPath = "OU=$OUParent,$DomainDN"

    if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUParent)" -SearchBase $DomainDN -ErrorAction SilentlyContinue) {
        Write-Host "[OK] OU parent : $OUParent"
    } else {
        Write-Host "[ERREUR] OU parent manquante : $OUParent"
    }

    if ($Structure[$OUParent].Count -eq 0) {
        # Vérification des sous-dossiers GG, GL, Users
        foreach ($folder in $SubFolders) {
            $FolderPath = "OU=$folder,$ParentOUPath"
            if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$folder)" -SearchBase $ParentOUPath -ErrorAction SilentlyContinue) {
                Write-Host "   [OK] Sous-OU : $folder"
            } else {
                Write-Host "   [ERREUR] Sous-OU manquante : $folder"
            }
        }

        $Prefix = $OUParent.ToUpper().Replace(" ","")
        $GroupGG = "GG_${Prefix}"

        if (Get-ADGroup -Filter "SamAccountName -eq '$GroupGG'" -ErrorAction SilentlyContinue) {
            Write-Host "   [OK] GG : $GroupGG"
        } else {
            Write-Host "   [ERREUR] Groupe manquant : $GroupGG"
        }

        foreach ($type in $GLTypes) {
            $GLName = "GL_${Prefix}_$type"
            if (Get-ADGroup -Filter "SamAccountName -eq '$GLName'" -ErrorAction SilentlyContinue) {
                Write-Host "      [OK] GL : $GLName"
            } else {
                Write-Host "      [ERREUR] GL manquant : $GLName"
            }
        }

    } else {
        # Départements avec sous-OU
        foreach ($OUSub in $Structure[$OUParent]) {
            $SubOUPath = "OU=$OUSub,$ParentOUPath"

            if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$OUSub)" -SearchBase $ParentOUPath -ErrorAction SilentlyContinue) {
                Write-Host "   [OK] Sous-OU : $OUSub"
            } else {
                Write-Host "   [ERREUR] Sous-OU manquante : $OUSub"
            }

            # Vérification sous-dossiers GG, GL, Users
            foreach ($folder in $SubFolders) {
                $SubFolderPath = "OU=$folder,OU=$OUSub,OU=$OUParent,$DomainDN"
                if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$folder)" -SearchBase $SubOUPath -ErrorAction SilentlyContinue) {
                    Write-Host "      [OK] Sous-OU : $folder"
                } else {
                    Write-Host "      [ERREUR] Sous-OU manquante : $folder"
                }
            }

            $PrefixParent = $OUParent.ToUpper().Replace(" ","")
            $PrefixSub = $OUSub.ToUpper().Replace(" ","")
            $GroupGG = "GG_${PrefixParent}_${PrefixSub}"

            if (Get-ADGroup -Filter "SamAccountName -eq '$GroupGG'" -ErrorAction SilentlyContinue) {
                Write-Host "      [OK] GG : $GroupGG"
            } else {
                Write-Host "      [ERREUR] Groupe manquant : $GroupGG"
            }

            foreach ($type in $GLTypes) {
                $GLName = "GL_${PrefixParent}_${PrefixSub}_$type"
                if (Get-ADGroup -Filter "SamAccountName -eq '$GLName'" -ErrorAction SilentlyContinue) {
                    Write-Host "         [OK] GL : $GLName"
                } else {
                    Write-Host "         [ERREUR] GL manquant : $GLName"
                }
            }
        }
    }

    Write-Host ""
}

Write-Host "=== VERIFICATION TERMINEE ===" -ForegroundColor Green
