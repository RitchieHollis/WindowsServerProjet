# Note sur sauvegarde

## Créer un nouveau disque virtuel

### Sur Hyper-V : ajouter un disque pour la sauvegarde

1) Éteindre la VM (recommandé)

2) Aller dans Paramètres

3) Choisir Contrôleur SCSI 

4) Cliquer Ajouter → Disque dur

5) Crée un nouveau .vhdx

- Exemple : BackupDisk.vhdx

6) Redémarrer la VM

7) Dans Windows → Disk Management (diskmgmt.msc)

- Initialiser le disque, sélectionner GPT

- Créer une partition (clique gauche dans la partie allocation)

- Formater (NTFS)

- Donner une lettre (ex : B:)

- Créer un dossier 'Sauvegardes' (ça sera ici qu'on mettera les backups)

---

## Consulter les tâches planifiées

1) Se rendre dans `taskschd.msc`
2) Aller dans Task Scheduler Library

En commande, pour consulter une tâche spécifique : 
```powershell
Get-ScheduledTask -TaskName "FullServerBackupWeekly" | Format-List *
```

---

## Consulter les backups

1) Ouvrir Windows Server Backup `wbadmin.msc`
Plusieurs option possible :
   - Sauvegardes locales : liste les sauvegardes déjà réalisées et où elles sont stockées.

    - Sauvegarde planifiée : montre la planification configurée (horaire, type de sauvegarde, volumes cibles).

    - Restauration : permet de vérifier que les sauvegardes sont valides et récupérables.

En commande, pour voir les politiques WSB : 
```powershell
Get-WBPolicy | Format-List *
```
---

## Tester une sauvegarde System State manuellement (Windows Server Backup)

### 1. Lancer la commande manuellement

```powershell
wbadmin start systemstatebackup -backuptarget:B:
```

### 2. Vérifier que la sauvegarde a fonctionné

#### Option A : via l'interface graphique
- Une fois la sauvegarde terminée, dans `Windows Server Backup`, aller dans `Action` → `View Details` pour consulter le journal de la sauvegarde.
- On peut voir si la sauvegarde s’est terminée avec succès, la taille, l’heure et le volume utilisé.

#### Option B : via PowerShell
1. Lancer la commande :  
   ```powershell
   Get-WBJob | Sort-Object EndTime -Descending | Select-Object StartTime, EndTime, Status, BackupType
   ```
Remarque: Cette commande liste seulement les sauvegardes en cours et terminées correctement. 
On peut voir la dernière backup avec cette commande : 
```powershell
Get-WBJob -Previous 1 | Select-Object StartTime, EndTime, Status, BackupType, Error
```
Mais si elle fail on aura pas vraiment beaucoup d'informations. 

