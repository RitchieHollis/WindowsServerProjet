
# Résumé de commande de test

Ce document présente une liste de commande afin de tester des users, UO, groupes. 

# **Lister tous les utilisateurs du domaine**

```
Get-ADUser -Filter * -Properties * | Select Name, SamAccountName, Enabled, DistinguishedName
```

---

# **Lister les utilisateurs par OU**


```
Get-ADUser -Filter * -SearchBase "OU=Developpement,OU=Informatique,OU=Direction,DC=london,DC=local" -Properties * | Select Name, SamAccountName, Enabled
```

Pour tout le département Marketting par exemple : 

```
Get-ADUser -Filter * -SearchBase "OU=Marketting,OU=Direction,DC=london,DC=local"
```

---

# **Lister TOUTES les OU**

```
Get-ADOrganizationalUnit -Filter * | Select Name, DistinguishedName
```

---

# **Tester la connexion d’un utilisateur (sans mot de passe en clair)**

Utiliser le script : ``test_connection.ps1``

---

# **Voir l’appartenance d’un utilisateur aux groupes**

```
Get-ADUser Mathieu.AGRILLO -Properties MemberOf | Select -ExpandProperty MemberOf
```

---

# **Lister tous les utilisateurs désactivés**

```
Get-ADUser -Filter "Enabled -eq 'False'"
```

---

# **Tester les GPO appliquées à un user**

(en ouvrant une session sur la machine)

```
gpresult /r
```

---

# **Vérifier un user précis**

Exemple : voir toutes les propriétés d’un user :

```
Get-ADUser Mathieu.AGRILLO -Properties *
```

---

# **Lister tous les groupes d’une OU**

```
Get-ADGroup -Filter * -SearchBase "OU=Hotline,OU=Informatique,OU=Direction,DC=london,DC=local"
```

Pour UO Direction : 
```
Get-ADGroup -Filter * -SearchBase "OU=Direction,DC=london,DC=local"
```