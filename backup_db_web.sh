#!/bin/bash
# ------------------------------------------------------------
# 🧩 Script de backup MySQL + fichiers applicatifs
# Auteur : er0x
# ------------------------------------------------------------

# === Configuration ===
BACKUP_DIR="/home/er0x/backups"
WEB_DIR="/var/www/"
TMP_DIR="/tmp/backup"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
YEAR_MONTH=$(date +"%Y-%m")  # ex : 2025-10
DAY=$(date +"%d")            # ex : 24
MYSQL_USER="root"
MYSQL_PASS="ton_mot_de_passe"
MYSQL_HOST="localhost"

# === Préparation ===
BACKUP_DIR="$BASE_BACKUP_DIR/$YEAR_MONTH/$DAY"
mkdir -p "$TMP_DIR"
mkdir -p "$BACKUP_DIR"

echo "🚀 Lancement du backup complet à $DATE..."
echo "📁 Dossier de sauvegarde : $BACKUP_DIR"

# === Export MySQL ===
echo "💾 Export des bases MySQL..."
mysqldump --all-databases -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" > "$TMP_DIR/mysql_backup.sql"
if [ $? -ne 0 ]; then
    echo "❌ Erreur : échec de l’export MySQL"
    exit 1
fi

# === Copie des fichiers applicatifs ===
echo "📂 Copie des fichiers applicatifs..."
rsync -a --delete "$WEB_DIR" "$TMP_DIR/app_files/"
if [ $? -ne 0 ]; then
    echo "❌ Erreur : copie des fichiers échouée"
    exit 1
fi

# === Compression ===
BACKUP_FILE="$BACKUP_DIR/backup_${DATE}.tar.gz"
echo "🗜️ Compression du backup..."
tar -czf "$BACKUP_FILE" -C "$TMP_DIR" .
if [ $? -ne 0 ]; then
    echo "❌ Erreur : échec de la compression"
    exit 1
fi

# === Nettoyage ===
rm -rf "$TMP_DIR"

# === Terminé ===
echo "✅ Sauvegarde terminée avec succès !"
echo "📦 Fichier créé : $BACKUP_FILE"
