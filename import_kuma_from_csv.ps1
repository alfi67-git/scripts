# OBJECTIF : Importer des routeurs DHCP dans Uptime Kuma v2
# FONCTIONNEMENT : Lecture CSV puis création des sondes Ping
# IMPACT : Ajout de sondes uniquement, sans suppression
# SIMULATION : Activée par défaut

import csv
import ipaddress
import logging
from getpass import getpass
from pathlib import Path

from uptime_kuma_api import UptimeKumaApi, MonitorType

# CONFIGURATION
KUMA_URL = "http://127.0.0.1:3001"
DOSSIER = Path(__file__).resolve().parent
FICHIER_CSV = DOSSIER / "routeurs.csv"
SIMULATION = True
INTERVALLE = 60

# JOURNALISATION
logging.basicConfig(
    filename=DOSSIER / "import_kuma.log",
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    encoding="utf-8",
)

def journal(message):
    print(message)
    logging.info(message)


def main():
    utilisateur = input("Utilisateur Uptime Kuma : ")
    mot_de_passe = getpass("Mot de passe : ")

    # Lecture du CSV Windows
    with open(FICHIER_CSV, newline="", encoding="utf-8-sig") as f:
        routeurs = list(csv.DictReader(f, delimiter=";"))

    if not routeurs:
        raise ValueError("Le fichier CSV est vide.")

    if not {"Nom", "IP"}.issubset(routeurs[0]):
        raise ValueError("Colonnes Nom et IP introuvables.")

    with UptimeKumaApi(KUMA_URL) as api:
        api.login(utilisateur, mot_de_passe)

        # Récupérer les sondes Ping déjà présentes
        existants = set()

        for sonde in api.get_monitors():
            if sonde.get("type") == MonitorType.PING:
                adresse = sonde.get("hostname")

                try:
                    ip = str(ipaddress.IPv4Address(adresse))
                    existants.add(ip)
                except (ValueError, TypeError):
                    pass

        # Traitement des routeurs DHCP
        for routeur in routeurs:
            nom = routeur["Nom"].strip()
            adresse = routeur["IP"].strip()

            try:
                ip = str(ipaddress.IPv4Address(adresse))
            except ValueError:
                journal(f"[IGNORE - IP INVALIDE] {adresse}")
                continue

            if not nom:
                journal(f"[IGNORE - NOM VIDE] {ip}")
                continue

            if ip in existants:
                journal(f"[EXISTANT] {nom} ({ip})")
                continue

            if SIMULATION:
                journal(f"[SIMULATION] {nom} ({ip})")
            else:
                resultat = api.add_monitor(
                    type=MonitorType.PING,
                    name=nom,
                    hostname=ip,
                    interval=INTERVALLE,
                )
                journal(f"[CREE] {nom} ({ip}) : {resultat}")

            # Évite les doublons au sein du CSV
            existants.add(ip)

    journal("Import termine.")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        logging.exception("Echec de l'import")
        raise
