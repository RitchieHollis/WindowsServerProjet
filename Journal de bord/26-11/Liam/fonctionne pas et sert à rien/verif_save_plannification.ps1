<#
.SYNOPSIS
    Vérification des planifications de sauvegarde Windows Server.

.DESCRIPTION
    Ce script affiche toutes les informations importantes concernant :
      - La tâche planifiée Full Server hebdomadaire.
      - La planification System State quotidienne.
    Il permet de vérifier que les sauvegardes sont correctement configurées sans lancer de backup.

.EXAMPLE
    .\VerificationBackup.ps1
#>

Write-Host "`n=== Vérification de la tâche planifiée Full Server hebdomadaire ===" -ForegroundColor Cyan

# Tâche planifiée Full Server
$taskName = "FullServerBackupWeekly"
try {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    Write-Host "Nom de la tâche       : $($task.TaskName)"
    Write-Host "Description          : $($task.Description)"
    Write-Host "Etat                 : $($task.State)"

    if ($task.Triggers) {
        foreach ($trigger in $task.Triggers) {
            if ($trigger) {
                Write-Host "Type du déclencheur  : $($trigger.TriggerType)"
                if ($trigger.DaysOfWeek) {
                    Write-Host "Jour(s)              : $($trigger.DaysOfWeek -join ', ')"
                }
                if ($trigger.StartBoundary) {
                    Write-Host "Heure                : $($trigger.StartBoundary.ToLocalTime().ToString('HH:mm'))"
                }
            }
        }
    } else {
        Write-Host "Aucun déclencheur configuré." -ForegroundColor Yellow
    }

    if ($task.Actions) {
        foreach ($action in $task.Actions) {
            Write-Host "Action               : $($action.Execute) $($action.Arguments)"
        }
    } else {
        Write-Host "Aucune action configurée." -ForegroundColor Yellow
    }

} catch {
    Write-Host "La tâche planifiée '$taskName' n'existe pas." -ForegroundColor Red
}

Write-Host "`n=== Vérification de la planification System State quotidienne ===" -ForegroundColor Cyan

# Planification System State
try {
    # Pour éviter les alias existants
    if (-not (Get-Module -Name WindowsServerBackup)) {
        Import-Module WindowsServerBackup -ErrorAction Stop
    }

    $wbPolicy = Get-WBPolicy -ErrorAction SilentlyContinue
    if ($wbPolicy) {
        Write-Host "Nom de la politique  : $($wbPolicy.PolicyId)"
        
        Write-Host "Volumes inclus       :"
        if ($wbPolicy.Volumes) {
            foreach ($vol in $wbPolicy.Volumes) {
                Write-Host "  - $($vol.Path) (System: $($vol.IsSystemVolume))"
            }
        } else {
            Write-Host "  Aucun volume inclus." -ForegroundColor Yellow
        }

        Write-Host "Volumes cible        :"
        if ($wbPolicy.Targets) {
            foreach ($target in $wbPolicy.Targets) {
                Write-Host "  - $($target.Path) ($($target.TargetType))"
            }
        } else {
            Write-Host "  Aucun volume cible." -ForegroundColor Yellow
        }

        Write-Host "VSS Full Backup      : $($wbPolicy.VssFullBackup)"
        if ($wbPolicy.Schedule) {
            Write-Host "Schedule             : $($wbPolicy.Schedule | ForEach-Object { $_.ToString() })"
        } else {
            Write-Host "Schedule             : Non configuré." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Aucune politique de sauvegarde trouvée." -ForegroundColor Yellow
    }

} catch {
    Write-Host "Impossible de récupérer les planifications System State. Vérifiez que Windows Server Backup est installé." -ForegroundColor Red
}

Write-Host "`n=== Vérification terminée ===" -ForegroundColor Cyan
