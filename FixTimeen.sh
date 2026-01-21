#!/bin/bash

set -e

echo "=== Full system time repair (Arch Linux) ==="

# 1. Root check
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# 2. Interactive timezone selection
echo "[1/7] Timezone selection"
echo "Loading timezone list…"

mapfile -t TIMEZONES < <(timedatectl list-timezones)

PS3="Choose the timezone number (or Ctrl+C to cancel): "

select TZ in "${TIMEZONES[@]}"; do
  if [[ -n "$TZ" ]]; then
    echo "Selected timezone: $TZ"
    timedatectl set-timezone "$TZ"
    break
  else
    echo "Invalid choice."
  fi
done

# 3. Force RTC to UTC (recommended for Linux)
echo "[2/7] Configuring RTC to UTC"
timedatectl set-local-rtc 0 --adjust-system-clock || true

# 4. Enable NTP (systemd-timesyncd)
echo "[3/7] Enabling NTP"
timedatectl set-ntp true || true

# 5. Restart time services
echo "[4/7] Restarting time services"
systemctl restart systemd-timesyncd || true

# 6. Manual fallback synchronization
echo "[5/7] Manual fallback synchronization"
timedatectl set-time "$(date -u '+%Y-%m-%d %H:%M:%S')" || true

# 7. Fallback to chrony if not synchronized
SYNC_STATUS=$(timedatectl show -p NTPSynchronized --value || echo "no")

if [[ "$SYNC_STATUS" != "yes" ]]; then
  echo "[6/7] systemd-timesyncd not synchronized → installing chrony"
  pacman -Sy --noconfirm chrony
  systemctl disable --now systemd-timesyncd || true
  systemctl enable --now chronyd
fi

# 8. Final status
echo "[7/7] Final status:"
timedatectl
date

echo "=== Done ==="
