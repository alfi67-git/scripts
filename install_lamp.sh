#!/bin/bash
# install_lamp.sh — script d’installation automatique LAMP (Apache + MariaDB/MySQL + PHP) pour Debian
# Utilisation : sudo bash install_lamp.sh

ROOT_PWD_DB=

set -e

echo "=== Mise à jour du système ==="
apt update && apt upgrade -y

echo "=== INSTALLATION DE MARIADB ==="
apt install mariadb-server mariadb-client -y

echo "=== Sécurisation de MariaDB (interactive) ==="
mysql_secure_installation <<EOF
$ROOT_PWD_DB
n
n
y
y
y
y
EOF

echo "=== INSTALLATION DE APACHE2 ==="
apt install apache2 apache2-doc

echo "=== ACTIVATION DU MODULE ==="
a2enmod userdir

echo "=== Installation de PHP et modules courants ==="
apt -y install php libapache2-mod-php php-mysql php-xml php-mbstring

echo "=== Redémarrage d’Apache pour prendre en compte PHP ==="
systemctl restart apache2

echo "=== Vérification des services ==="
systemctl status apache2 --no-pager
systemctl status mariadb --no-pager

echo "=== Création d’un fichier phpinfo pour tester ==="
cat <<EOF >/var/www/html/info.php
<?php
phpinfo();
?>
EOF
chown www-data:www-data /var/www/html/info.php
chmod 644 /var/www/html/info.php

echo "=== Installation LAMP terminée ==="
echo "Ouvrez http://<votre-ip>/info.php pour vérifier que PHP fonctionne."