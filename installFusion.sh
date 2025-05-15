#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root. Utilisez 'sudo'."
    exit 1
fi

echo "FusionResolveIT - Installation (Debian/Nginx/MariaDB)"

function installationDesPrerequis {
    sudo apt update
    sudo apt install apt-transport-https
    sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg 
    sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
    sudo apt update
    sudo apt install nginx -y
    sudo apt install php$FUSION_PHP_VERSION-curl php$FUSION_PHP_VERSION-gd php$FUSION_PHP_VERSION-imap php$FUSION_PHP_VERSION-intl php$FUSION_PHP_VERSION-mbstring php$FUSION_PHP_VERSION-mysql php$FUSION_PHP_VERSION-xml php$FUSION_PHP_VERSION-zip php$FUSION_PHP_VERSION-fpm -y
    sudo apt install mariadb-server -y
    configurationBDD
}

function configurationBDD {
    sudo mysql -e "CREATE DATABASE $FUSION_DB_NAME;"
    sudo mysql -e "CREATE USER $FUSION_DB_USER@$FUSION_DB_HOST IDENTIFIED BY '$FUSION_DB_PASSWORD';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON $FUSION_DB_NAME.* TO $FUSION_DB_USER@$FUSION_DB_HOST;"
    sudo mysql -e "FLUSH PRIVILEGES;"
    telechargementFichiersFusion
}

function telechargementFichiersFusion {
    sudo wget $FUSION_DOWNLOAD_URL
    sudo tar -xzvf fusionresolveit-$FUSION_VERSION.tar.gz -C /var/www
    configurationNginx
}

function configurationNginx {
    sudo tee /etc/nginx/sites-available/fusionresolveit > /dev/null << EOF
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
    sudo ln -s /etc/nginx/sites-available/fusionresolveit /etc/nginx/sites-enabled/
    sudo rm /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx.service
    configurationPhinx
}

function configurationPhinx {
    sudo bash -c 'cat > /var/www/fusionresolveit/phinx.php << EOF
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
            "host" => "'"$FUSION_DB_HOST"'",
            "name" => "'"$FUSION_DB_NAME"'",
            "user" => "'"$FUSION_DB_USER"'",
            "pass" => "'"$FUSION_DB_PASSWORD"'",
            "port" => "3306",
            "charset" => "utf8mb4",
            "collation" => "utf8mb4_general_ci",
        ],
    ],
    "version_order" => "creation"
];
EOF'
    sudo ln -s /etc/nginx/sites-available/fusionresolveit /etc/nginx/sites-enabled/
    sudo rm /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx.service
    permissionsFichiers
}

function permissionsFichiers {
    sudo chown -R www-data:www-data /var/www/fusionresolveit
    sudo chmod -R 755 /var/www/fusionresolveit
    startMigration
}

function startMigration {
    cd /var/www/fusionresolveit
    sudo ./bin/cli migrate
}

PS3="Quelle version de PHP souhaitez-vous utiliser ?"
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
            echo "Version invalide"
            ;;
    esac
done

read -p "Quelle version de FusionResolveIT souhaitez-vous utiliser ? (ex. 1.0.0-beta.1)" FUSION_VERSION
FUSION_DOWNLOAD_URL="https://github.com/fusionresolveit/FusionResolveIT/releases/download/$FUSION_VERSION/fusionresolveit-$FUSION_VERSION.tar.gz"

read -p "Quel nom utilisateur souhaitez-vous utilisé pour la base de données ?" FUSION_DB_USER

echo "Quel mot de passe souhaitez-vous utilisé pour la base de données ?"
read -s FUSION_DB_PASSWORD

read -p "Quel est le nom d'hote/IP de votre base de données ? (ex. localhost ou 127.0.0.1)" FUSION_DB_HOST

read -p "Quel est le nom que vous souhaitez utiliser pour votre base de données ?" FUSION_DB_NAME

echo "Voici un récapitulatif :"
echo " "
echo "PHP Version: $FUSION_PHP_VERSION"
echo "FusionResolveIT Version: $FUSION_VERSION ($FUSION_DOWNLOAD_URL)"
echo "Utilisateur BDD : $FUSION_DB_USER"
echo "Hôte BDD : $FUSION_DB_HOST"
echo "Nom de base de données : $FUSION_DB_NAME"
echo " "
PS3="Est-ce bon ? (Si NON, le script sera relancé à zéro)"
options=("Oui" "Non")
select choix in "${options[@]}"; do 
    case $REPLY in 
        1)
            installationDesPrerequis
            break
            ;;
        2)
            exec ./installFusion.sh
            break
            ;;
        *)
            echo "Version invalide"
            ;;
    esac
done
