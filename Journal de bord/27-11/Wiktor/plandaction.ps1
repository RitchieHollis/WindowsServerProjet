<#
.SYNOPSIS
    Chaîne de scripts d’industrialisation PKI/sécurité pour un environnement critique
    basé sur SRVSEC et le domaine angleterre.lan.

.DESCRIPTION
    Cette série de scripts a pour objectif de modéliser une infrastructure PKI et
    PowerShell en allant au-delà d’une simple installation ADCS.
    Les rôles sont clairement séparés et chaque script est responsable d’un volet
    précis de la sécurité, ce qui facilite l’audit et la maintenance.

    securityServPrep.ps1
        Prépare le serveur SRVSEC comme hôte de sécurité dédié :
        - Adresse IP statique, passerelle et DNS pointant vers le contrôleur de domaine.
        - Intégration au domaine angleterre.lan.
        - Durcissement réseau de base (pare-feu activé, désactivation RDP, partage de fichiers, etc.).
        - Activation optionnelle de BitLocker afin de chiffrer le volume contenant les
          fichiers sensibles (base ADCS, journaux), simulant la protection matérielle
          des clés dans un contexte de laboratoire.

    ADCS_CA.ps1
        Installe et sécurise l’autorité de certification sur SRVSEC :
        - Installation d’une Enterprise Root CA avec clé privée non exportable et durée
          de vie de 10 ans (rôle assimilé à une CA d’émission dans ce labo).
        - Configuration des points de distribution CRL/AIA en HTTP sur SRVSEC dans un
          répertoire dédié sous C:\www\angleterre\CertEnroll.
        - Définition d’une durée de vie des CRL de 1 semaine avec chevauchement d’1 jour.
        - Activation ciblée des règles de pare-feu liées à l’ADCS.

    ADCS_Templates.ps1
        Applique le principe du moindre privilège sur les modèles de certificats :
        - Création et configuration des groupes de sécurité PKI (PKI-Admins, WebServerCerts,
          ScriptSigners, etc.).
        - Restriction des modèles sensibles :
            - Modèle “Code Signing” limité au groupe ScriptSigners.
            - Modèle “Web Server” limité au groupe WebServerCerts et aux serveurs IIS autorisés.
        - Ajustement des EKU et des droits d’enrôlement afin que les utilisateurs ou
          machines standards ne puissent pas obtenir des certificats critiques.

    CodeSigning_Policy.ps1
        Renforce la sécurité des scripts d’administration via la PKI :
        - Création d’une GPO imposant ExecutionPolicy = AllSigned sur les serveurs
          et postes d’administration.
        - Mise en place d’un compte dédié à la signature de code (ScriptSigner) qui
          obtient un certificat de code signing depuis la CA.
        - Signature des scripts officiels (ex. scripts d’auto-configuration) et
          stockage sur un partage en lecture seule, garantissant que seuls les scripts
          signés et approuvés peuvent être exécutés.

    PKI_Auditing.ps1
        Active la journalisation avancée et la surveillance de l’autorité de certification :
        - Activation des sous-catégories d’audit Windows pertinentes (Certification Services,
          changements de configuration, gestion de comptes).
        - Configuration du filtre d’audit ADCS (CA\AuditFilter) pour tracer les opérations
          sensibles (émission, révocation, échec d’enrôlement, modifications de modèles).
        - Exemple de collecte et de consultation des événements depuis un serveur de
          supervision (DCROOT Londres), simulant l’intégration avec une solution de type SIEM.

    IIS_Intranet.ps1
        Déploie un site intranet sécurisé pour illustrer l’usage de la PKI :
        - Installation du rôle IIS et création d’un site “Intranet” dédié.
        - Demande automatique d’un certificat serveur via le modèle “Web Server” et
          association au site en HTTPS (binding 443).
        - Redirection HTTP vers HTTPS et activation des règles de pare-feu IIS nécessaires.
        - Ce script démontre comment la PKI est utilisée concrètement pour sécuriser
          les communications internes.

    Cette structuration en scripts indépendants permet de :
        - Documenter chaque couche de sécurité (réseau, PKI, modèles, scripts, audit).
        - Rejouer facilement le déploiement sur une nouvelle instance (infrastructure
          reproductible).
        - Discuter clairement de la différence entre un contexte de laboratoire et
          les exigences d’une PKI comme root hors ligne, HSM, SIEM, etc.,
          tout en montrant que l’architecture et les contrôles mis en place respectent
          l’esprit de ces bonnes pratiques.
#>
