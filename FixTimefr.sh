#!/bin/bash
# FitTime.sh
# Script Arch Linux permettant de remédier à des problèmes
#   de mauvaise synchronisation

set -e

echo "=== Correction complète de l'heure système (Arch Linux) ==="

# 1. Vérification root
if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être exécuté en root."
  exit 1
fi
# 2. Sélection interactive du fuseau horaire
echo "[1/7] Sélection du fuseau horaire"
echo "Chargement de la liste des fuseaux horaires…"

mapfile -t TIMEZONES < <(timedatectl list-timezones)

PS3="Choisis le numéro du fuseau horaire (ou Ctrl+C pour annuler) : "

select TZ in "${TIMEZONES[@]}"; do
  if [[ -n "$TZ" ]]; then
    echo "Fuseau horaire sélectionné : $TZ"
    timedatectl set-timezone "$TZ"
    break
  else
    echo "Choix invalide."
  fi
done

# 3. Forcer RTC en UTC (bonne pratique Linux)
echo "[2/7] Configuration du RTC en UTC"
timedatectl set-local-rtc 0 --adjust-system-clock || true

# 4. Activer NTP (systemd-timesyncd)
echo "[3/7] Activation NTP"
timedatectl set-ntp true || true

# 5. Redémarrer les services temps
echo "[4/7] Redémarrage des services temps"
systemctl restart systemd-timesyncd || true

# 6. Forcer une synchro manuelle si NTP échoue
echo "[5/7] Synchronisation manuelle de secours"
date -u +"%Y-%m-%d %H:%M:%S" >/tmp/utc_now
timedatectl set-time "$(cat /tmp/utc_now)" || true
rm -f /tmp/utc_now

# 7. Installer chrony si systemd-timesyncd ne synchronise pas
SYNC_STATUS=$(timedatectl show -p NTPSynchronized --value || echo "no")

if [[ "$SYNC_STATUS" != "yes" ]]; then
  echo "[6/7] systemd-timesyncd non synchronisé → installation de chrony"
  pacman -Sy --noconfirm chrony
  systemctl disable --now systemd-timesyncd || true
  systemctl enable --now chronyd
fi

# 8. Résultat final
echo "[7/7] État final :"
timedatectl
date

echo "=== Fin ==="
