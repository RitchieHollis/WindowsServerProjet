# Plan de Sauvegarde des Serveurs

## 1. Objectif
Le présent plan de sauvegarde a pour objectif d'assurer la protection des données critiques du réseau, notamment :  
- Active Directory (comptes utilisateurs, GPO, DNS, DHCP)  
- Données des serveurs de fichiers  
- Serveurs complets pour restauration en cas de panne

## 2. Périmètre
| Serveur / Ressource | Contenu sauvegardé | Type de sauvegarde |
|--------------------|-----------------|-----------------|
| Serveur AD         | System State (AD, GPO, DNS, DHCP) | Quotidienne |
| Serveur de fichiers| Dossiers partagés critiques | Quotidienne |
| Serveur complet    | OS + applications + données | Hebdomadaire |

## 3. Fréquence et type de sauvegarde
| Type de sauvegarde | Fréquence | Support de stockage | Rétention |
|-------------------|-----------|-------------------|-----------|
| System State AD    | Quotidienne | Disque réseau dédié | 7 jours  |
| Fichiers partagés  | Quotidienne | Disque réseau dédié | 30 jours |
| Full server        | Hebdomadaire | Disque externe ou NAS | 4 semaines |

## 4. Support et stockage
- **Local / réseau :** Les sauvegardes sont stockées sur un disque réseau dédié pour un accès rapide.  
- **Redondance :** Une copie des sauvegardes critiques est conservée sur un autre site ou support externe pour assurer la résilience.

## 5. Procédure de restauration
- **Test de restauration :** Une VM de test sera utilisée pour vérifier la validité des sauvegardes.  
- **Restauration AD :** Restauration possible via le System State pour récupérer un objet ou un domaine complet.  
- **Restauration complète serveur :** En cas de panne, restauration depuis la sauvegarde Full Server avec réinstallation minimale si nécessaire.

## 6. Planification
- Les sauvegardes sont programmées **hors heures de production** (ex. entre 22h et 6h) pour minimiser l'impact sur les utilisateurs.  
- **Alertes et notifications :** Tout échec de sauvegarde déclenche un email d’alerte à l’administrateur système.

## 7. Outils utilisés
- **Windows Server Backup (WSB)** pour la gestion automatique des sauvegardes.  
- **Scripts PowerShell** (optionnel) pour l'automatisation et le contrôle des sauvegardes.  

---

> **Remarque :** Ce plan est conçu pour un environnement Windows Server 2019 avec Active Directory et serveurs de fichiers critiques.

IAAAAA