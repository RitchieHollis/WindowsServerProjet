
# Structure Active Directory – OU / GG / GL

## OU Principale

| OU           | Groupe Global (GG) | Groupes Locaux (GL) |
|--------------|--------------------|----------------------|
| Direction    | GG_DIRECTION       | GL_DIRECTION_R<br>GL_DIRECTION_W<br>GL_DIRECTION_RW |

---

## Départements et Sous-OU

### Marketting
| Département | Sous-OU | Groupe Global (GG) | Groupes Locaux (GL) |
|------------|---------|--------------------|----------------------|
| Marketting | Site1 | GG_MARKETTING_SITE1 | GL_MARKETTING_SITE1_R<br>GL_MARKETTING_SITE1_W<br>GL_MARKETTING_SITE1_RW |
| Marketting | Site2 | GG_MARKETTING_SITE2 | GL_MARKETTING_SITE2_R<br>GL_MARKETTING_SITE2_W<br>GL_MARKETTING_SITE2_RW |
| Marketting | Site3 | GG_MARKETTING_SITE3 | GL_MARKETTING_SITE3_R<br>GL_MARKETTING_SITE3_W<br>GL_MARKETTING_SITE3_RW |
| Marketting | Site4 | GG_MARKETTING_SITE4 | GL_MARKETTING_SITE4_R<br>GL_MARKETTING_SITE4_W<br>GL_MARKETTING_SITE4_RW |

---

### Technique
| Département | Sous-OU | Groupe Global (GG) | Groupes Locaux (GL) |
|------------|---------|--------------------|----------------------|
| Technique | Techniciens | GG_TECHNIQUE_TECHNICIENS | GL_TECHNIQUE_TECHNICIENS_R<br>GL_TECHNIQUE_TECHNICIENS_W<br>GL_TECHNIQUE_TECHNICIENS_RW |
| Technique | Achat | GG_TECHNIQUE_ACHAT | GL_TECHNIQUE_ACHAT_R<br>GL_TECHNIQUE_ACHAT_W<br>GL_TECHNIQUE_ACHAT_RW |

---

### Informatique
| Département | Sous-OU | Groupe Global (GG) | Groupes Locaux (GL) |
|------------|---------|--------------------|----------------------|
| Informatique | Developpement | GG_INFORMATIQUE_DEVELOPPEMENT | GL_INFORMATIQUE_DEVELOPPEMENT_R<br>GL_INFORMATIQUE_DEVELOPPEMENT_W<br>GL_INFORMATIQUE_DEVELOPPEMENT_RW |
| Informatique | Hotline | GG_INFORMATIQUE_HOTLINE | GL_INFORMATIQUE_HOTLINE_R<br>GL_INFORMATIQUE_HOTLINE_W<br>GL_INFORMATIQUE_HOTLINE_RW |
| Informatique | Systemes | GG_INFORMATIQUE_SYSTEMES | GL_INFORMATIQUE_SYSTEMES_R<br>GL_INFORMATIQUE_SYSTEMES_W<br>GL_INFORMATIQUE_SYSTEMES_RW |

---

### R&D
| Département | Sous-OU | Groupe Global (GG) | Groupes Locaux (GL) |
|------------|---------|--------------------|----------------------|
| R&D | Testing | GG_R&D_TESTING | GL_R&D_TESTING_R<br>GL_R&D_TESTING_W<br>GL_R&D_TESTING_RW |
| R&D | Recherche | GG_R&D_RECHERCHE | GL_R&D_RECHERCHE_R<br>GL_R&D_RECHERCHE_W<br>GL_R&D_RECHERCHE_RW |

---

### Commerciaux
| Département | Sous-OU | Groupe Global (GG) | Groupes Locaux (GL) |
|------------|---------|--------------------|----------------------|
| Commerciaux | Sedentaires | GG_COMMERCIAUX_SEDENTAIRES | GL_COMMERCIAUX_SEDENTAIRES_R<br>GL_COMMERCIAUX_SEDENTAIRES_W<br>GL_COMMERCIAUX_SEDENTAIRES_RW |
| Commerciaux | Technico | GG_COMMERCIAUX_TECHNICO | GL_COMMERCIAUX_TECHNICO_R<br>GL_COMMERCIAUX_TECHNICO_W<br>GL_COMMERCIAUX_TECHNICO_RW |

---

### Ressources humaines
| Département | Sous-OU | Groupe Global (GG) | Groupes Locaux (GL) |
|------------|---------|--------------------|----------------------|
| Ressources humaines | Recrutement | GG_RESSOURCESHUMAINES_RECRUTEMENT | GL_RESSOURCESHUMAINES_RECRUTEMENT_R<br>GL_RESSOURCESHUMAINES_RECRUTEMENT_W<br>GL_RESSOURCESHUMAINES_RECRUTEMENT_RW |
| Ressources humaines | Gestion du personnel | GG_RESSOURCESHUMAINES_GESTIONDUPERSONNEL | GL_RESSOURCESHUMAINES_GESTIONDUPERSONNEL_R<br>GL_RESSOURCESHUMAINES_GESTIONDUPERSONNEL_W<br>GL_RESSOURCESHUMAINES_GESTIONDUPERSONNEL_RW |

---

### Finances
| Département | Sous-OU | Groupe Global (GG) | Groupes Locaux (GL) |
|------------|---------|--------------------|----------------------|
| Finances | Investissements | GG_FINANCES_INVESTISSEMENTS | GL_FINANCES_INVESTISSEMENTS_R<br>GL_FINANCES_INVESTISSEMENTS_W<br>GL_FINANCES_INVESTISSEMENTS_RW |
| Finances | Comptabilite | GG_FINANCES_COMPTABILITE | GL_FINANCES_COMPTABILITE_R<br>GL_FINANCES_COMPTABILITE_W<br>GL_FINANCES_COMPTABILITE_RW |
