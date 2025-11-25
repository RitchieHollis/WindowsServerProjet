# Note de commande pour les PSO

## **1. Voir tous les PSO existants**

```
Get-ADFineGrainedPasswordPolicy -Filter *
```

---

## **2. Voir un PSO en détail (ex: PSO_Direction)**

```
Get-ADFineGrainedPasswordPolicy -Identity "PSO_Direction" | Format-List *
```

---

## **3. Voir sur quels groupes/utilisateurs un PSO est appliqué**

```
(Get-ADFineGrainedPasswordPolicy -Identity "PSO_Direction").AppliesTo
```

## **4. Voir le PSO effectif d’un utilisateur**

exemple avec Christophe.Alsteen : 

```
Get-ADUserResultantPasswordPolicy -Identity "Christophe.Alsteen"
```