# FusionResolveIT Script

![Screenshot_2025-04-21_at_13-25-32_Fusion_Resolve_IT_-_Home](https://github.com/user-attachments/assets/e270ba7b-29e1-42e4-a6a1-afa3811f24ca)

## À propos de ce dépôt

Ce dépôt est une galerie de scripts destinée au projet FusionResolveIT [Code](https://github.com/fusionresolveit/FusionResolveIT) [Site](https://www.fusionresolveit.org/).

Vous y retrouverez des scripts pour installer, mettre à jour et sauvegarder FusionResolveIT.

Si vous rencontrez un problème avec un script, vous pouvez me faire un [ticket](https://github.com/julienallexandre/FusionResolveIT-Script/issues), je vous aiderai. Mais si le problème provient de FusionResolveIT, je vous recommande de les [contacter](https://www.fusionresolveit.org/#team) ou de regarder leur documentation : [Administrateurs](https://documentation.fusionresolveit.org/administrators/) ou [Utilisateurs](https://documentation.fusionresolveit.org/End-user%20guide/introduction/).

## Comment utiliser les scripts

### ℹ️ Compatibilité :

Les scripts fonctionnent sur les distributions basées sur Debian. Ils ont été testés sur :
| OS | VERSION | COMPATIBILITE |
| --- | --- |--- |
| Debian | 12 | ✅ |

### Pour le script d'installation :
```
wget https://raw.githubusercontent.com/julienallexandre/FusionResolveIT-Script/refs/heads/main/Fusion.sh && bash fusion.sh
```
Le script installera tous les prérequis (Nginx, MariaDB, PHP et les dépendances), puis il vous permettra de configurer votre base de données.

⚠️ Installation en HTTP et non en HTTPS, vous devrez le configurer vous-même. Pour des raisons de sécurité, il est préférable d'exécuter ce script sur une machine dédiée à l'application FusionResolveIT.
ℹ️ Une fois l'installation terminée, rendez-vous sur l'URL de votre instance FusionResolveIT. Les identifiants de base sont : `admin` / `adminIT`

