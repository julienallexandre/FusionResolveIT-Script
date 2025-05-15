#!/bin/bash
YELLOW='\e[0;33m'
RED='\e[0;31m'
GREEN='\e[0;32m'
RESET='\e[0m'

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Ce script doit être exécuté en tant que root. Utilisez 'sudo'.${RESET}"
    exit 1
fi

echo "${GREEN}FusionResolveIT - Installation${RESET}"

function installationDesOutils {
    echo -e "${YELLOW}Installation des outils nécessaires au bon fonctionnement du script.${RESET}"
    apt install jq curl -y
}
installationDesOutils

function installationDesPrerequis {
    echo -e "${YELLOW}Installation des prérequis.${RESET}"
    apt update
    apt install apt-transport-https
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg 
    sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
    apt update
    echo -e "${YELLOW}Installation de Nginx.${RESET}"
    apt install nginx -y
    echo -e "${YELLOW}Installation de PHP et ses dépendances.${RESET}"
    apt install php$FUSION_PHP_VERSION-{fpm,curl,gd,imap,intl,mbstring,mysql,xml,zip} -y
    echo -e "${YELLOW}Installation de MariaDB.${RESET}"
    apt install mariadb-server -y
    configurationBDD
}

function configurationBDD {
    echo -e "${YELLOW}Configuration de MariaDB.${RESET}"
    mysql -e "CREATE DATABASE IF NOT EXISTS $FUSION_DB_NAME;"
    mysql -e "CREATE USER IF NOT EXISTS $FUSION_DB_USER@$FUSION_DB_HOST IDENTIFIED BY '$FUSION_DB_PASSWORD';"
    mysql -e "GRANT ALL PRIVILEGES ON $FUSION_DB_NAME.* TO $FUSION_DB_USER@$FUSION_DB_HOST;"
    mysql -e "FLUSH PRIVILEGES;"
    telechargementFichiersFusion
}

function telechargementFichiersFusion {
    echo -e "${YELLOW}Téléchargement des fichiers FusionResolveIT.${RESET}"
    FUSION_TAR_NAME=$(echo "$FUSION_URL" | jq -r '.assets[0].name')
    if [ -f "/tmp/$FUSION_TAR_NAME" ]; then
        rm -r "/tmp/$FUSION_TAR_NAME"
    fi
    wget -P /tmp $FUSION_DOWNLOAD_URL
    if [ -d "/var/www/fusionresolveit" ]; then
        echo -e "${RED}Erreur : /var/www/fusionresolveit existe déjà.${RESET}"
    else
        tar -xzf "/tmp/$FUSION_TAR_NAME" -C /var/www
    fi
    configurationNginx
}

function configurationNginx {
    echo -e "${YELLOW}Configuration de Nginx.${RESET}"
    if [ ! -f /etc/nginx/sites-available/fusionresolveit ]; then
    cat > /etc/nginx/sites-available/fusionresolveit << EOF
server {
    listen 80;

    root /var/www/fusionresolveit/public;
    index index.php;

    location /assets/ {
        alias /var/www/fusionresolveit/public/assets/;
    }

    location / {
        try_files \$uri /index.php\$is_args\$args;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php${FUSION_PHP_VERSION}-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
        fastcgi_index index.php;
    }
}
EOF
    ln -s /etc/nginx/sites-available/fusionresolveit /etc/nginx/sites-enabled/
    rm /etc/nginx/sites-enabled/default
    systemctl restart nginx.service
    else
    echo -e "${RED}Le fichier /etc/nginx/sites-available/fusionresolveit existe déjà.${RESET}"
    fi
    configurationPhinx
}

function configurationPhinx {
    echo -e "${YELLOW}Edition du fichier Phinx.${RESET}"
    if [ ! -f /var/www/fusionresolveit/phinx.php ]; then
    cat > /var/www/fusionresolveit/phinx.php << EOF
<?php
return [
    "paths" => [
        "migrations" => "%%PHINX_CONFIG_DIR%%/db/migrations",
        "seeds" => "%%PHINX_CONFIG_DIR%%/db/seeds"
    ],
    "environments" => [
        "default_migration_table" => "phinxlog",
        "default_environment" => "production",
        "production" => [
            "adapter" => "mysql",
            "host" => "$FUSION_DB_HOST",
            "name" => "$FUSION_DB_NAME",
            "user" => "$FUSION_DB_USER",
            "pass" => "$FUSION_DB_PASSWORD",
            "port" => "3306",
            "charset" => "utf8mb4",
            "collation" => "utf8mb4_general_ci",
        ],
    ],
    "version_order" => "creation"
];
EOF
    else
    echo -e "${RED}Le fichier /var/www/fusionresolveit/phinx.php existe déjà.${RESET}"
    fi
    permissionsFichiers
}

function permissionsFichiers {
    echo -e "${YELLOW}Définition des permissions.${RESET}"
    chown -R www-data:www-data /var/www/fusionresolveit
    chmod -R 755 /var/www/fusionresolveit
    startMigration
}

function startMigration {
    echo -e "${YELLOW}Migration de la BDD${RESET}."
    cd /var/www/fusionresolveit
    ./bin/cli migrate
    finish
}

function finish {
    echo -e "${GREEN}Tout est prêt, rendez-vous sur http://IPDELAMACHINE !${RESET}"
    echo -e "${GREEN}Les identifiants par défaut sont admin / adminIT.${RESET}"
}

PS3="Quelle version de PHP souhaitez-vous utiliser ? "
options=("8.2" "8.3")
select choix in "${options[@]}"; do 
    case $REPLY in 
        1)
            FUSION_PHP_VERSION=8.2
            break
            ;;
        2)
            FUSION_PHP_VERSION=8.3
            break
            ;;
        *)
            echo -e "${RED}Version invalide${RESET}"
            ;;
    esac
done

read -p "Quelle version de FusionResolveIT souhaitez-vous utiliser ? (ex. 1.0.0-beta.1) " FUSION_VERSION
FUSION_URL=$(curl -s https://api.github.com/repos/fusionresolveit/FusionResolveIT/releases/tags/$FUSION_VERSION)
FUSION_DOWNLOAD_URL=$(echo "$FUSION_URL" | jq -r '.assets[0].browser_download_url')

read -p "Quel est le nom d'hote/IP de votre base de données ? (ex. localhost ou 127.0.0.1) " FUSION_DB_HOST

read -p "Quel est le nom que vous souhaitez utiliser pour votre base de données ? " FUSION_DB_NAME

read -p "Quel nom utilisateur souhaitez-vous utilisé pour la base de données ? " FUSION_DB_USER

echo "Quel mot de passe souhaitez-vous utilisé pour la base de données ? "
read -s FUSION_DB_PASSWORD

echo " "
echo -e "${GREEN}Voici un récapitulatif ${RESET}:"
echo " "
echo -e "${GREEN}PHP Version: $FUSION_PHP_VERSION${RESET}"
echo -e "${GREEN}FusionResolveIT Version: $FUSION_VERSION ($FUSION_DOWNLOAD_URL)${RESET}"
echo -e "${GREEN}Hôte BDD : $FUSION_DB_HOST${RESET}"
echo -e "${GREEN}Nom de base de données : $FUSION_DB_NAME${RESET}"
echo -e "${GREEN}Utilisateur BDD : $FUSION_DB_USER${RESET}"
echo " "
PS3="Est-ce bon ? (Si NON, le script sera relancé à zéro) "
options=("Oui" "Non")
select choix in "${options[@]}"; do 
    case $REPLY in 
        1)
            installationDesPrerequis
            break
            ;;
        2)
            exec bash installFusion.sh
            break
            ;;
        *)
            echo -e "${RED}Version invalide${RESET}"
            ;;
    esac
done
