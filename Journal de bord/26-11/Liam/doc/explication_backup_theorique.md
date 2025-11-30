# 📘 Documentation Technique – Plan de Sauvegarde Windows Server

## 📌 Introduction
La sauvegarde constitue un pilier essentiel de la résilience informatique. Elle permet de protéger les données, restaurer un système en cas de panne, et garantir la continuité d’activité.  
Dans un environnement Windows Server, l’outil **Windows Server Backup (WSB)** offre une solution native pour planifier et automatiser plusieurs types de sauvegardes : *System State*, *Full Server*, volumes, dossiers spécifiques, etc.

Ce document présente :
- Les différents types de sauvegardes
- Les stratégies courantes (daily, weekly, retention…)
- Le fonctionnement interne (VSS)
- Les bonnes pratiques
- Les procédures pour tester et restaurer

---

# 🧩 1. Types de sauvegardes Windows Server

## 🔹 1.1 System State Backup
Contient les composants critiques du système :
- Active Directory (NTDS)
- Registre Windows
- SYSVOL
- Base de données COM+
- Boot files
- Certificats  
- Drivers essentiels

👉 **Indispensable pour restaurer un contrôleur de domaine (DC).**

## 🔹 1.2 Full Server Backup
Sauvegarde complète :
- Système
- Applications
- Volumes
- Fichiers utilisateurs

👉 Permet une **restauration bare-metal** (machine entière) ou la récupération de fichiers individuels.

## 🔹 1.3 Backup de volumes
Sauvegarde ciblée d’un ou plusieurs volumes spécifiques.

## 🔹 1.4 Backup de fichiers/dossiers
Moins utilisée dans les environnements serveurs, sauf pour des groupes de fichiers spécifiques.

---

# ⚙️ 2. Comprendre VSS (Volume Shadow Copy Service)

## 🔹 2.1 Qu’est-ce que VSS ?
VSS est un service Windows permettant de créer des **instantanés cohérents** des volumes au moment de la sauvegarde.

## 🔹 2.2 Les deux modes
### ✔ *VssFullBackup*  
- Marque les fichiers comme sauvegardés  
- Indique aux applications (AD, SQL, etc.) de nettoyer leurs journaux

### ✔ *VssCopyBackup*  
- Ne modifie rien  
- N’affecte pas les journaux  

👉 Recommandé pour les backups quotidien *System State* afin de ne pas perturber les autres stratégies.

---

# 🗂 3. Les questions fondamentales d’un plan de sauvegarde

Tout plan de sauvegarde doit répondre à **5 questions critiques** :

## ❓ 1. Quoi sauvegarder ?  
- System State (pour les DC)  
- Fichiers métiers  
- Bases de données  
- Applications  
- Configuration système  

## ❓ 2. Quand sauvegarder ?  
Exemples :
- Daily System State → chaque soir 23h00  
- Weekly Full Backup → dimanche 2h00  

## ❓ 3. Où sauvegarder ?  
- Disque dédié (ex : Volume B:)  
- NAS  
- Baie SAN  
- Cloud  
- Disque externe  

Règle : **séparer la sauvegarde du système**.

## ❓ 4. Combien de temps conserver ?  
Selon besoins :
- 7 jours
- 30 jours
- 3 mois
- 1 an  
- Archivage (immutable)  

## ❓ 5. Comment restaurer ?  
Plans de restauration documentés :
- Restauration de fichier
- Restauration System State (authoritative / non-authoritative)
- Restauration bare-metal

---

# 🕒 4. Logiciels et automatisation

## 🔹 4.1 Windows Server Backup
Outil natif sous Windows Server.

## 🔹 4.2 Automatisation via PowerShell
Exemples :
- `New-WBPolicy`
- `Add-WBBackupTarget`
- `Set-WBSchedule`
- `Set-WBPolicy`

Scripts possibles :
- Daily System State
- Weekly Full Server
- Logs automatiques
- Tâches planifiées via Scheduled Tasks

---

# 📆 5. Exemple de stratégie de sauvegarde complète

| Type de sauvegarde | Fréquence | Heure | Destination |
|--------------------|-----------|--------|--------------|
| **System State** | Daily | 23h00 | Volume B: |
| **Full Server** | Weekly | Dimanche 02h00 | Volume B: |
| Données métiers | Selon besoin | Variable | NAS |

---

# 🧪 6. Tester une sauvegarde

## 🔹 6.1 Test manual System State
1. Ouvrir **Windows Server Backup**
2. Cliquer sur **Local Backup**
3. Dans le volet à droite → **Backup Once**
4. Choisir **System State**
5. Définir la destination
6. Lancer  

### Vérification :
- Event Viewer → *Applications and Services Logs → Microsoft → Windows → Backup*  
- Code de succès : **0x00**

---

# ♻️ 7. Restaurations

## 🔹 7.1 Restaurer un fichier ou volume
Depuis WSB :
- **Recover**
- Choisir type
- Sélectionner date
- Restaurer

## 🔹 7.2 Restaurer System State
Permet de réparer un DC.

Deux modes possibles :

### ✔ Non-authoritative restore
- La réplication AD **corrige automatiquement** l’état restauré

### ✔ Authoritative restore
- Permet de restaurer des objets AD supprimés  
- Commande `ntdsutil` pour marquer des objets comme *authoritative*

## 🔹 7.3 Bare-metal restore
Utilisé quand :
- Le serveur est totalement perdu  
- Besoin de restaurer OS + configuration + données

---

# 📚 8. Bonnes pratiques

### ✔ Toujours isoler le disque de sauvegarde  
Ne jamais sauvegarder sur C:.

### ✔ Toujours tester les restaurations  
Une sauvegarde non testée = sauvegarde inexistante.

### ✔ Monitorer les logs (Event Viewer)

### ✔ Séparer Daily / Weekly  
Daily = System State  
Weekly = Full Backup  

### ✔ Avoir au moins 2 copies  
Local + externe (NAS / cloud)

### ✔ Utiliser VssCopy pour le quotidien  
Évite l’impact sur journaux applicatifs.

---

# 📜 Conclusion

Un plan de sauvegarde professionnel se construit autour de :
- La granularité (System State, Full, fichiers)
- La fréquence (daily, weekly)
- L’isolation des supports
- La redondance
- La vérification régulière
- La capacité à restaurer rapidement

Ce document peut servir :
- De support de projet
- De base pour une documentation d’entreprise
- De justification technique pour un audit

