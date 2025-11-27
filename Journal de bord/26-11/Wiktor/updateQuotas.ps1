<#
updateQuotas.ps1

    Met à jour les actions e-mail des quotas FSRM sous C:\
    en utilisant les responsables définis dans DeptResponsables.csv.

    Pré-requis :
      - Les quotas existent déjà (FSRMconf.ps1 exécuté)
      - Les responsables ont été tirés au sort et exportés
        dans C:\Scripts\DeptResponsables.csv (setPermissions.ps1)

    Logique :
      - Pour C:\<Dept>        -> e-mail à tous les responsables du département
      - Pour C:\<Dept>\<Sub>  -> e-mail au responsable du sous-département
      - Si aucun mail trouvé         -> fallback vers l’admin
#>

param(
    [string]$SharesRoot = 'C:',
    [string]$CsvPath = 'C:\Scripts\DeptResponsables.csv',
    [string]$AdminFallbackMail = 'admin@angleterre.lan'
)

Import-Module FileServerResourceManager -ErrorAction Stop

if (-not (Test-Path $CsvPath)) {
    Write-Error "There's no CSV, baka: $CsvPath"
    exit 1
}

$Responsables = Import-Csv $CsvPath

$quotas = Get-FsrmQuota | Where-Object { $_.Path -like "$SharesRoot*" }

foreach ($quota in $quotas) {

    $rel = $quota.Path.Substring($SharesRoot.Length).TrimStart('\')
    if (-not $rel) { continue }   

    $parts = $rel -split '\\'
    $dept = $parts[0]
    $sub = if ($parts.Count -gt 1) { $parts[1] } else { $null }

    if ($sub) {
        # Quota sur un sous-dossier : on prend le responsable du sous-département
        $emails = $Responsables |
        Where-Object { $_.Department -eq $dept -and $_.SubDept -eq $sub -and $_.ManagerMail } |
        Select-Object -Expand ManagerMail -Unique
    }
    else {
        # Quota sur le dossier de département : tous les responsables du département
        $emails = $Responsables |
        Where-Object { $_.Department -eq $dept -and $_.ManagerMail } |
        Select-Object -Expand ManagerMail -Unique
    }

    if (-not $emails) {
        $emails = @($AdminFallbackMail)
    }

    $mailTo = ($emails -join ';')

    Write-Host "[*] $($quota.Path)" -ForegroundColor Yellow
    Write-Host "    Dept='$dept' Sub='$sub' -> MailTo: $mailTo"

    # --- Recréation des seuils avec le bon MailTo ---
    $act80 = New-FsrmAction -Type Email -MailTo $mailTo
    $th80 = New-FsrmQuotaThreshold -Percentage 80 -Action $act80

    $act90 = @(
        New-FsrmAction -Type Email -MailTo $mailTo
        New-FsrmAction -Type Event
    )
    $th90 = New-FsrmQuotaThreshold -Percentage 90 -Action $act90

    $act100 = @(
        New-FsrmAction -Type Email -MailTo $mailTo
        New-FsrmAction -Type Event
    )
    $th100 = New-FsrmQuotaThreshold -Percentage 100 -Action $act100

    $thresholds = @($th80, $th90, $th100)

    Set-FsrmQuota -Path $quota.Path -Threshold $thresholds -ErrorAction Stop
}

Write-Host "Ok we're good" -ForegroundColor Cyan
