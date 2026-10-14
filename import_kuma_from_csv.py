# OBJECTIF :
# Importer les routeurs DHCP dans Uptime Kuma v2.
# Organiser les sondes par departement / Barracuda.
#
# FONCTIONNEMENT :
# Lecture CSV, detection des doublons, creation des groupes,
# creation ou mise a jour des sondes Ping.
#
# IMPACT :
# En mode reel, cree les sondes/groupes manquants et modifie
# les parametres et le groupe des sondes Ping existantes.
# Aucune suppression.
#
# MODE SIMULATION :
# True = aucune modification
# False = appliquer les changements

import csv
import ipaddress
import logging
from pathlib import Path
from getpass import getpass
from uptime_kuma_api import UptimeKumaApi, MonitorType

# =========================
# CONFIGURATION
# =========================

KUMA_URL = "http://10.68.2.34:3001"

DOSSIER = Path(__file__).resolve().parent
CSV = DOSSIER / "switchs2.csv"

SIMULATION = False

INTERVALLE = 20
TENTATIVES = 3
DELAI_TENTATIVES = 20

# =========================
# Premier nombre est cherché dans l'adresse IP
# Ensuite est défini le nom du département
# =========================

DEPARTEMENTS = {
    "25": "25 - DOUBS",
    "42": "42 - LOIRE",
    "15": "43 - HAUTE-LOIRE",
    "51": "51 - MARNE",
    "55": "55 - MEUSE",
    "68": "68 - HAUT-RHIN",
    "71": "71 - SAÔNE-ET-LOIRE",
    "90": "90 - TERRITOIRE DE BELFORT"
}

# =========================
# JOURNALISATION
# =========================

logging.basicConfig(
    filename=DOSSIER / "import_kuma.log",
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    encoding="utf-8"
)

def log(message):
    print(message)
    logging.info(message)


# =========================
# FONCTIONS
# =========================

def creer_groupe(api, nom, parent, groupes):
    """Retourne un groupe existant ou cree le groupe."""

    cle = (nom, parent)

    if cle in groupes:
        return groupes[cle]

    if SIMULATION:
        log(f"[SIMULATION GROUPE] {nom} (parent={parent})")
        groupes[cle] = f"simulation:{nom}:{parent}"
        return groupes[cle]

    resultat = api.add_monitor(
        type=MonitorType.GROUP,
        name=nom,
        parent=parent
    )

    groupe_id = resultat["monitorID"]

    groupes[cle] = groupe_id

    log(f"[GROUPE CREE] {nom} (ID={groupe_id})")

    return groupe_id


# =========================
# PROGRAMME PRINCIPAL
# =========================

def main():

    with open(CSV, encoding="utf-8-sig", newline="") as f:
        routeurs = list(csv.DictReader(f, delimiter=";"))

    if not routeurs:
        raise ValueError("Le fichier CSV est vide.")

    for colonne in ("Nom", "Reseau", "IP"):
        if colonne not in routeurs[0]:
            raise ValueError(f"Colonne absente : {colonne}")

    utilisateur = input("Utilisateur Uptime Kuma : ")
    password = getpass("Mot de passe : ")

    with UptimeKumaApi(KUMA_URL) as api:

        api.login(utilisateur, password)

        monitors = api.get_monitors()

        # Index des groupes existants
        groupes = {}

        for monitor in monitors:
            if monitor["type"] == MonitorType.GROUP:
                cle = (
                    monitor["name"],
                    monitor.get("parent")
                )
                groupes[cle] = monitor["id"]

        # Index des sondes Ping existantes
        sondes = {}

        for monitor in monitors:
            if monitor["type"] != MonitorType.PING:
                continue

            try:
                ip = str(
                    ipaddress.IPv4Address(
                        monitor["hostname"]
                    )
                )
                sondes.setdefault(ip, []).append(monitor)

            except (ValueError, TypeError, KeyError):
                continue

        ips_traitees = set()

        # =========================
        # TRAITEMENT CSV
        # =========================

        for routeur in routeurs:

            nom = routeur["Nom"].strip()
            reseau = routeur["Reseau"].strip()

            try:
                ip = str(
                    ipaddress.IPv4Address(
                        routeur["IP"].strip()
                    )
                )
                parties = str(
                    ipaddress.IPv4Address(reseau)
                ).split(".")
            except ValueError:
                log(f"[IP INVALIDE] {routeur}")
                continue

            if not nom:
                log(f"[NOM VIDE] {ip}")
                continue

            if ip in ips_traitees:
                log(f"[DOUBLON CSV] {ip}")
                continue

            ips_traitees.add(ip)

            if parties[0] != "10":
                log(f"[RESEAU IGNORE] {reseau}")
                continue

            departement = DEPARTEMENTS.get(parties[1])

            if not departement:
                log(f"[DEPARTEMENT INCONNU] {reseau}")
                continue

            # =========================
            # GROUPE DEPARTEMENT
            # =========================

            groupe_departement = creer_groupe(
                api,
                departement,
                None,
                groupes
            )

            # =========================
            # SOUS-GROUPE SWITCH
            # =========================

            nom_sous_groupe = f"{departement} - Switchs"

            groupe_barracuda = creer_groupe(
                api,
                nom_sous_groupe,
                groupe_departement,
                groupes
            )

            # =========================
            # VERIFICATION DES SONDES
            # =========================

            existantes = sondes.get(ip, [])

            if len(existantes) > 1:
                log(f"[DOUBLON KUMA] {ip} - ignore")
                continue

            if existantes:

                sonde = existantes[0]

                # Comparaison des parametres actuels
                conforme = (
                    sonde.get("parent") == groupe_barracuda
                    and int(sonde.get("interval", -1)) == INTERVALLE
                    and int(sonde.get("maxretries", -1)) == TENTATIVES
                    and int(sonde.get("retryInterval", -1)) == DELAI_TENTATIVES
                )

                if conforme:
                    log(f"[DEJA CONFORME] {nom}")
                    continue

                if SIMULATION:
                    log(
                        f"[SIMULATION MODIFICATION] "
                        f"{nom} -> {nom_sous_groupe}"
                    )
                else:
                    api.edit_monitor(
                        sonde["id"],
                        parent=groupe_barracuda,
                        interval=INTERVALLE,
                        maxretries=TENTATIVES,
                        retryInterval=DELAI_TENTATIVES
                    )

                    log(
                        f"[SONDE MODIFIEE] "
                        f"{nom} -> {nom_sous_groupe}"
                    )

            else:

                if SIMULATION:
                    log(
                        f"[SIMULATION CREATION] "
                        f"{nom} ({ip}) -> {nom_sous_groupe}"
                    )

                else:
                    api.add_monitor(
                        type=MonitorType.PING,
                        name=nom,
                        hostname=ip,
                        parent=groupe_barracuda,
                        interval=INTERVALLE,
                        maxretries=TENTATIVES,
                        retryInterval=DELAI_TENTATIVES
                    )

                    log(
                        f"[SONDE CREEE] "
                        f"{nom} ({ip}) -> {nom_sous_groupe}"
                    )

        log("Traitement termine.")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        logging.exception("Erreur lors de l'import")
        raise
