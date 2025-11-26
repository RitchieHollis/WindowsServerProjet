# Note sur les comptes ordinateurs

## **Récupérer la redirection actuelle des comptes ordinateurs**

```
Get-ADDomain | Select-Object -Property ComputersContainer
```

