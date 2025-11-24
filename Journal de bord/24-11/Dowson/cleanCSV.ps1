param(
    [Parameter(Mandatory=$true)]
    [string]$InputCsv,

    [Parameter(Mandatory=$true)]
    [string]$OutputCsv
)

# --- Fonctions de nettoyage ---
function Remove-Accents {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne "NonSpacingMark") {
            [void]$sb.Append($c)
        }
    }
    return $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function Clean-String {
    param([string]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Value)) { return "" }
    $clean = Remove-Accents $Value
    $clean = $clean -replace "\s+", ""                # supprime espaces
    $clean = $clean -replace "[^A-Za-z0-9\-_]", ""    # garde lettres/nombres/-/_
    return $clean
}

# Nettoie aussi les noms de colonnes
function Clean-Column {
    param([string]$col)
    return Clean-String $col
}

# --- Import du CSV ---
if (-not (Test-Path $InputCsv)) {
    Write-Error "Fichier d'entrée introuvable : $InputCsv"
    exit 1
}
$rows = Import-Csv -Path $InputCsv

if ($rows.Count -eq 0) {
    Write-Host "Aucune ligne dans le CSV d'entrée. Rien à faire."
    exit 0
}

# Nettoyer les noms de colonnes
$originalColumns = $rows[0].PSObject.Properties.Name
$cleanColumns = $originalColumns | ForEach-Object { Clean-Column $_ }

# --- Nettoyage ligne par ligne ---
$cleanedObjects = foreach ($row in $rows) {
    $props = @{}
    for ($i = 0; $i -lt $originalColumns.Count; $i++) {
        $origCol = $originalColumns[$i]
        $cleanCol = $cleanColumns[$i]
        if ($i -lt 2) {
            # Nettoie seulement les deux premières colonnes
            $props[$cleanCol] = Clean-String $row.$origCol
        } else {
            $props[$cleanCol] = $row.$origCol
        }
    }
    New-Object PSObject -Property $props
}

# --- Export manuel sans guillemets ---
$lines = New-Object System.Collections.Generic.List[string]

# Entête nettoyée
$lines.Add( ($cleanColumns -join ',') )

# Corps
foreach ($obj in $cleanedObjects) {
    $values = foreach ($col in $cleanColumns) { $obj.$col }
    $lines.Add( ($values -join ',') )
}

# Écriture
[System.IO.File]::WriteAllLines($OutputCsv, $lines, [System.Text.Encoding]::UTF8)

Write-Host "Nettoyage terminé. Fichier généré sans guillemets : $OutputCsv"
