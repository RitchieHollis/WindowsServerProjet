Import-Module ActiveDirectory

$ADRecycleBinStatus = Get-ADOptionalFeature -Filter 'name -like "Recycle Bin Feature"' | Select-Object Name, EnabledScopes

if ($ADRecycleBinStatus.EnabledScopes) {
    Write-Host "La corbeille AD est déjà activée."
} else {
    Enable-ADOptionalFeature -Identity "Recycle Bin Feature" -Scope ForestOrConfigurationSet -Target (Get-ADForest).Name
    Write-Host "Corbeille AD activée avec succès."
}
