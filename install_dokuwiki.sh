#! /usr/bin/bash 
### VARIABLES 
DOKUWIKI_LINK_DL="https://download.dokuwiki.org/src/dokuwiki/dokuwiki-stable.tgz" 
PHP_VER=$(php -r 'echo PHP_VERSION;') 
INSTALL_PATH=/var/www/dokuwiki/public_html 
DOWNLOAD_PATH="/tmp/dokuwiki-*.tgz" 
DOMAIN="dokuwiki.intracloud.local" 
VH_FOLDER="/etc/apache2/sites-available/" 
VH_CONFIG_NAME="dokuwiki.conf" 
 
### MISE À JOUR DU SYSTEME 
apt update 
apt upgrade -y 
 
echo "===== [?] VERIFICATION DE LA VERSION PHP =====" 
if command -v php >/dev/null 2>&1; then 
    PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;") 
    PHP_MAJOR=$(php -r "echo PHP_MAJOR_VERSION;") 
    echo "PHP détecté : version $PHP_VER" 
     
    if [ "$PHP_MAJOR" -ge 8 ]; then 
        echo "✅ PHP $PHP_VER est déjà installé (version >= 8)" 
    else 
        echo "⚠️ PHP est trop ancien (version $PHP_VER). Installation de PHP 8.x..." 
        apt update 
        apt install -y apt-transport-https lsb-release ca-certificates wget 
        wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg 
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list 
        apt update 
        apt install php8.0 -y 
    fi 
fi 
 
echo "===== [+] INSTALLATION DES EXTENSIONS =====" 
apt update 
# Note : on suppose déjà Apache2 + PHP installés ; on installe les modules recommandés 
apt -y install \ 
  php-xml \ 
  php-gd \ 
  php-cli \ 
  php-curl \ 
  php-mbstring \ 
  php-zip \ 
  php-bcmath \ 
  php-json 
apt update 

# Note : on suppose déjà Apache2 + PHP installés ; on installe les modules recommandés 
apt -y install \ 
  php-xml \ 
  php-gd \ 
  php-cli \ 
  php-curl \ 
  php-mbstring \ 
  php-zip \ 
  php-bcmath \ 
  php-json 
 
echo "===== [+] TELECHARGEMENT DU DOKUWIKI =====" 
wget -P /tmp/ "$DOKUWIKI_LINK_DL" 
 
echo "===== [?] VERIFICATION DE L'EXISTANCE DE L'EMPLACEMENT =====" 
if [ -d "$INSTALL_PATH" ]; then 
    echo "[!] Folder ${INSTALL_PATH} already exists, skipping.." 
    rm $DOWNLOAD_PATH 
else 
    echo "[+] Extracting files to $INSTALL_PATH" 
    mkdir -p $INSTALL_PATH 
    tar zxf "${DOWNLOAD_PATH}" -C "${INSTALL_PATH}" --strip-components=1 
    chown -R www-data:www-data "${INSTALL_PATH}" 
    chmod -R 755 "${INSTALL_PATH}" 
    rm $DOWNLOAD_PATH 
fi 
 
echo "===== [?] VERIFICATION DU VIRTUAL HOST =====" 
if [ -f "$VH_FOLDER/$VH_CONFIG_NAME" ]; then 
    echo "[!] Virtual Host already exists, skipping.." 
else 
    echo "<VirtualHost *:80> 
    ServerName ${DOMAIN} 
    DocumentRoot ${INSTALL_PATH} 
 
    ErrorLog ${APACHE_LOG_DIR}/dokuwiki_error.log 
    CustomLog ${APACHE_LOG_DIR}/dokuwiki_access.log combined 
 
    <Directory ${INSTALL_PATH}> 
        AllowOverride All 
        Require all granted 
    </Directory> 
</VirtualHost>" > "$VH_FOLDER/$VH_CONFIG_NAME" 
    a2ensite $VH_CONFIG_NAME 
    systemctl reload apache2 
    echo "[/] Installation done - Finish installation on http://${DOMAIN}/install.php" 
fi