# Plan de Sauvegarde 

## 1. Objectif

L'objectif de ce plan est de garantir la **disponibilité et la restauration des données critiques** sur nos serveurs Windows. Il détaille la fréquence des sauvegardes, les types de sauvegardes, les volumes concernés et les procédures de test et de restauration.

---

## 2. Architecture des sauvegardes

Nous avons décidé de séparer les sauvegardes en **quotidiennes** et **hebdomadaires** afin de minimiser la perte de données et de faciliter la gestion des ressources de stockage.

| Type de sauvegarde | Fréquence        | Contenu                      | Destination      |
|------------------|-----------------|------------------------------|----------------|
| Daily (System State) | Quotidienne, 23h00 | Configuration du système, Active Directory, registry, etc. | Volume B:      |
| Weekly (Full Server) | Hebdomadaire, dimanche 02h00 | Tous les volumes système et données utilisateur | Volume B:      |

---

## 3. Sauvegarde quotidienne (Daily)

### 3.1 Type de sauvegarde

- **System State Backup**  
- Contient les éléments critiques du système :  
  - Active Directory  
  - Registry  
  - Configuration système  
  - Fichiers essentiels Windows  

### 3.2 Volume ciblé

- La sauvegarde est stockée directement sur le volume `B:`.

### 3.3 Planification

- La sauvegarde est planifiée **tous les jours à 23h00**.
- Utilisation de **Windows Server Backup** avec une planification via script PowerShell.

### 3.4 Processus de sauvegarde

1. Vérifier que le volume de sauvegarde existe : `Test-Path B:`  
2. Installer Windows Server Backup si nécessaire : `Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools`  
3. Créer une politique de sauvegarde System State : `New-WBPolicy` et `Add-WBSystemState -Policy $policy`  
4. Ajouter le volume de destination : `Add-WBBackupTarget -Policy $policy -Target (New-WBBackupTarget -VolumePath 'B:')`  
5. Définir la planification automatique : `Set-WBSchedule -Policy $policy -Schedule (Get-Date "23:00")`  
6. Appliquer la politique : `Set-WBPolicy -Policy $policy`  

### 3.5 Test et vérification

- Test manuel : `wbadmin start systemstatebackup -backuptarget:B:`  
- Vérifier le résultat : `Get-WBJob | Sort-Object EndTime -Descending | Select StartTime, EndTime, Status, BackupType`  
- Succès confirmé si `Status` = `Completed` et `BackupType` = `SystemState`.

---

## 4. Sauvegarde hebdomadaire (Weekly)

**Note : la sauvegarde hebdomadaire n’est pas encore implémentée, mais voici le plan prévu.**

### 4.1 Type de sauvegarde

- **Full Server Backup**  
- Contient **tous les volumes** (système + données utilisateurs)  
- Marqué avec **VSS Full Backup** pour que tous les fichiers soient considérés comme sauvegardés.

### 4.2 Volume ciblé

- Destination prévue : `B:`.

### 4.3 Planification

- Prévue tous les dimanches à 02h00 via **Task Scheduler**.
- Script séparé pour exécuter la sauvegarde et un autre pour créer la tâche planifiée.

### 4.4 Processus envisagé

1. Vérifier que le volume de destination existe : `Test-Path B:`  
2. Installer Windows Server Backup si nécessaire : `Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools`  
3. Créer une politique Full Server Backup : `New-WBPolicy`  
4. Ajouter tous les volumes : `Add-WBVolume -Policy $policy -Volume $vol`  
5. Ajouter le volume de backup : `Add-WBBackupTarget -Policy $policy -Target (New-WBBackupTarget -VolumePath 'B:')`  
6. Définir les options VSS Full : `Set-WBVssBackupOptions -Policy $policy -VssFullBackup`  
7. Créer la tâche planifiée via PowerShell : `Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "FullServerBackupWeekly"`

### 4.5 Test et vérification (prévu)

- Test manuel via script : `.\Run_WeeklyFullBackup.ps1 -BackupVolume B:`  
- Vérification du résultat : `Get-WBJob | Sort-Object EndTime -Descending | Select StartTime, EndTime, Status, BackupType`  

---

## 5. Conclusion

- La stratégie actuelle protège **la configuration système et l’Active Directory** via les backups quotidiens.  
- La sauvegarde hebdomadaire complète est planifiée mais pas encore mise en place.  
- La séparation des scripts permet de tester facilement les sauvegardes quotidiennes sans lancer les Full Backup.
