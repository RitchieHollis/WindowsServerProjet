# Note de commande pour la corbeille AD

## **Lister les objets supprimés :**

```
Get-ADObject -Filter 'isDeleted -eq $true' -IncludeDeletedObjects
```

## **Restaurer un objet supprimé**

```
Restore-ADObject -Identity 'DistinguishedNameDeletedObject'
```
