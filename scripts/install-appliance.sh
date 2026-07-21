#!/usr/bin/env bash
# Phase 1: install SLS Camera as a system appliance on THIS machine.
#
# Requires root. Prefer a dedicated tablet or VM.
#
#   sudo ./scripts/install-appliance.sh
#
# Optional:
#   SLS_USER=sls
#   APP_SRC from prior 20-sync-app (default: build/app or vendor/sls-camera)
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLS_USER="${SLS_USER:-sls}"
APP_ROOT="/opt/sls-camera"
DATA_CAPTURES="/data/sls-captures"
OVERLAY="$ROOT/overlay"

echo "=== SLS appliance install ==="
echo "  firmware tree: $ROOT"
echo "  user: $SLS_USER"
echo "  app:  $APP_ROOT"

# Resolve app source
if [[ -d "$ROOT/build/app/software/linux/viewer" ]]; then
  SRC="$ROOT/build/app"
elif [[ -d "$ROOT/vendor/sls-camera/software/linux/viewer" ]]; then
  SRC="$ROOT/vendor/sls-camera"
elif [[ -d /home/tmdrake/sls-camera/software/linux/viewer ]]; then
  SRC=/home/tmdrake/sls-camera
  echo "  NOTE: using live checkout $SRC"
else
  echo "ERROR: no app tree. Run scripts/20-sync-app.sh first." >&2
  exit 1
fi
echo "  src: $SRC"

# --- user ---
if ! id "$SLS_USER" &>/dev/null; then
  useradd -m -s /bin/bash -G video,plugdev,audio,sudo "$SLS_USER" || \
    useradd -m -s /bin/bash -G video,plugdev,audio "$SLS_USER"
  echo "Created user $SLS_USER"
else
  usermod -aG video,plugdev,audio "$SLS_USER" 2>/dev/null || true
fi

# --- debs ---
mapfile -t SEED_PKGS < <(grep -vE '^\s*(#|$)' "$ROOT/packages/apt-packages.txt" || true)
# Resolve t64 renames for seed list (best-effort)
resolve_seed() {
  local p="$1"
  if apt-cache show "$p" >/dev/null 2>&1; then
    echo "$p"
  elif [[ "$p" == "libfreenect0.5t64" ]] && apt-cache show libfreenect0.5 >/dev/null 2>&1; then
    echo "libfreenect0.5"
  elif [[ "$p" == "libfreenect0.5" ]] && apt-cache show libfreenect0.5t64 >/dev/null 2>&1; then
    echo "libfreenect0.5t64"
  else
    echo "$p"
  fi
}
PKGS=()
for p in "${SEED_PKGS[@]}"; do
  PKGS+=("$(resolve_seed "$p")")
done

if compgen -G "$ROOT/vendor/debs/*.deb" >/dev/null 2>&1; then
  n_debs=$(find "$ROOT/vendor/debs" -name '*.deb' | wc -l)
  echo "Installing seeds using offline deb cache ($n_debs files in vendor/debs)…"
  # Prefer apt's archive cache + --no-download so:
  #  - already-installed packages (python3, etc.) are left alone
  #  - only missing seeds/deps are installed
  #  - OR-alternatives are chosen by apt (no dpkg -i *.deb conflicts)
  ARCHIVES=/var/cache/apt/archives
  mkdir -p "$ARCHIVES"
  # Copy without clobbering identical files; ignore Permission errors on partial
  cp -n "$ROOT"/vendor/debs/*.deb "$ARCHIVES/" 2>/dev/null || \
    cp "$ROOT"/vendor/debs/*.deb "$ARCHIVES/" 2>/dev/null || true

  set +e
  if [[ ${#PKGS[@]} -gt 0 ]]; then
    if [[ "${SLS_OFFLINE:-0}" == "1" ]]; then
      apt-get install -y --no-install-recommends --no-download "${PKGS[@]}"
      apt_rc=$?
    else
      # Try fully offline first; if deps missing from cache, allow network fill
      apt-get install -y --no-install-recommends --no-download "${PKGS[@]}"
      apt_rc=$?
      if [[ "$apt_rc" -ne 0 ]]; then
        echo "WARN: --no-download incomplete; retrying with network allowed…"
        apt-get update || true
        apt-get install -y --no-install-recommends "${PKGS[@]}"
        apt_rc=$?
      fi
    fi
  else
    apt_rc=0
  fi
  set -e

  if [[ "${apt_rc:-1}" -ne 0 ]]; then
    if [[ "${SLS_OFFLINE:-0}" == "1" ]]; then
      echo "ERROR: offline apt install failed (SLS_OFFLINE=1)." >&2
      echo "  Re-run scripts/10-fetch-offline.sh (FETCH_DEPS=1) on matching Ubuntu." >&2
      exit 1
    fi
    echo "WARN: cache install failed — last resort dpkg -i selected seeds only…"
    # Install only seed .debs by name match, not every recursive deb
    for p in "${PKGS[@]}"; do
      match=$(ls "$ROOT"/vendor/debs/"${p}"_*.deb 2>/dev/null | head -1 || true)
      if [[ -n "$match" ]]; then
        dpkg -i "$match" || true
      fi
    done
    apt-get -f install -y || true
  fi
else
  echo "No vendor/debs — installing seeds from apt (online)…"
  if [[ ${#PKGS[@]} -gt 0 ]]; then
    apt-get update
    apt-get install -y --no-install-recommends "${PKGS[@]}" || true
  fi
fi

# --- gspca blacklist + udev ---
install -D -m 644 "$OVERLAY/etc/modprobe.d/blacklist-gspca-kinect.conf" \
  /etc/modprobe.d/blacklist-gspca-kinect.conf
install -D -m 644 "$OVERLAY/etc/udev/rules.d/60-sls-kinect.rules" \
  /etc/udev/rules.d/60-sls-kinect.rules
udevadm control --reload-rules 2>/dev/null || true
if lsmod 2>/dev/null | grep -q '^gspca_kinect'; then
  modprobe -r gspca_kinect 2>/dev/null || echo "WARN: could not unload gspca_kinect"
fi

# --- no suspend / lid sleep (appliance field use) ---
if [[ -f "$OVERLAY/etc/systemd/logind.conf.d/50-sls-no-suspend.conf" ]]; then
  install -D -m 644 "$OVERLAY/etc/systemd/logind.conf.d/50-sls-no-suspend.conf" \
    /etc/systemd/logind.conf.d/50-sls-no-suspend.conf
  systemctl restart systemd-logind 2>/dev/null || true
  echo "Installed logind no-suspend policy (see docs/POWER-AND-DISPLAY.md)"
fi

# --- quiet field session: no update popups, no LXQt power idle warnings ---
if [[ -f "$OVERLAY/etc/apt/apt.conf.d/99sls-disable-auto-upgrades" ]]; then
  install -D -m 644 "$OVERLAY/etc/apt/apt.conf.d/99sls-disable-auto-upgrades" \
    /etc/apt/apt.conf.d/99sls-disable-auto-upgrades
fi
if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
  cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
fi
systemctl disable --now unattended-upgrades.service 2>/dev/null || true
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
systemctl mask apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
systemctl disable --now packagekit.service 2>/dev/null || true
systemctl mask packagekit.service 2>/dev/null || true
for f in lubuntu-update-autostart.desktop lxqt-powermanagement.desktop lxqt-xscreensaver-autostart.desktop sls-disable-dpms.desktop sls-lock-landscape.desktop; do
  if [[ -f "$OVERLAY/etc/xdg/autostart/$f" ]]; then
    install -D -m 644 "$OVERLAY/etc/xdg/autostart/$f" "/etc/xdg/autostart/$f"
  fi
done
if [[ -f "$OVERLAY/usr/local/bin/sls-disable-dpms" ]]; then
  install -D -m 755 "$OVERLAY/usr/local/bin/sls-disable-dpms" /usr/local/bin/sls-disable-dpms
fi
if [[ -f "$OVERLAY/usr/local/bin/sls-lock-landscape" ]]; then
  install -D -m 755 "$OVERLAY/usr/local/bin/sls-lock-landscape" /usr/local/bin/sls-lock-landscape
fi
# Charge-idle poweroff: RCA dedicated charger / unattended charge (see CHARGE-IDLE-POWEROFF.md)
if [[ -f "$OVERLAY/usr/local/bin/sls-charge-idle-poweroff" ]]; then
  install -D -m 755 "$OVERLAY/usr/local/bin/sls-charge-idle-poweroff" \
    /usr/local/bin/sls-charge-idle-poweroff
fi
if [[ -f "$OVERLAY/etc/sls/charge-idle.conf" ]]; then
  install -D -m 644 "$OVERLAY/etc/sls/charge-idle.conf" /etc/sls/charge-idle.conf
fi
if [[ -f "$OVERLAY/etc/systemd/system/sls-charge-idle-poweroff.service" ]]; then
  install -D -m 644 "$OVERLAY/etc/systemd/system/sls-charge-idle-poweroff.service" \
    /etc/systemd/system/sls-charge-idle-poweroff.service
  systemctl daemon-reload 2>/dev/null || true
  systemctl enable --now sls-charge-idle-poweroff.service 2>/dev/null || true
  echo "Enabled sls-charge-idle-poweroff (15 min sustained charge → poweroff; disable for OTG-run tablets)"
fi
# Stop accelerometer-driven auto-rotate fighting landscape lock (tablet-01/02)
systemctl disable --now iio-sensor-proxy.service 2>/dev/null || true
systemctl mask iio-sensor-proxy.service 2>/dev/null || true
echo "Disabled auto-updates + power/screensaver; DPMS off + landscape lock installed"

# --- app tree ---
echo "Installing app → $APP_ROOT"
mkdir -p "$APP_ROOT"
rsync -a --delete \
  --exclude '.git' \
  --exclude 'software/linux/viewer/.venv' \
  --exclude 'software/linux/viewer/captures' \
  "$SRC/" "$APP_ROOT/"

# Field USB is FAT32 — +x is lost on the stick; force scripts executable on target
VIEWER="$APP_ROOT/software/linux/viewer"
find "$APP_ROOT" -type f -name '*.sh' -exec chmod 755 {} \; 2>/dev/null || true
chmod 755 "$VIEWER/run.sh" 2>/dev/null || true

# pose model offline
mkdir -p "$VIEWER/models"
if [[ -f "$ROOT/vendor/models/pose_landmarker_lite.task" ]]; then
  install -m 644 "$ROOT/vendor/models/pose_landmarker_lite.task" \
    "$VIEWER/models/pose_landmarker_lite.task"
fi

# venv
echo "Creating venv…"
python3 -m venv "$VIEWER/.venv"
# shellcheck disable=SC1091
source "$VIEWER/.venv/bin/activate"
if compgen -G "$ROOT/vendor/wheels/*" >/dev/null 2>&1; then
  # Fully offline: never hit PyPI when wheels are vendored
  pip install --no-index --find-links="$ROOT/vendor/wheels" --upgrade pip 2>/dev/null || true
  pip install --no-index --find-links="$ROOT/vendor/wheels" -r "$VIEWER/requirements.txt" \
    || pip install --no-index --find-links="$ROOT/vendor/wheels" -r "$ROOT/packages/python-requirements.txt"
  pip install --no-index --find-links="$ROOT/vendor/wheels" \
    'sounddevice>=0.5' 'imageio-ffmpeg>=0.5' 2>/dev/null || true
else
  if [[ "${SLS_OFFLINE:-0}" == "1" ]]; then
    echo "ERROR: no vendor/wheels and SLS_OFFLINE=1" >&2
    exit 1
  fi
  pip install --upgrade pip
  pip install -r "$VIEWER/requirements.txt"
  pip install 'sounddevice>=0.5' 'imageio-ffmpeg>=0.5' 2>/dev/null || true
fi
deactivate
chown -R "$SLS_USER:$SLS_USER" "$VIEWER/.venv" 2>/dev/null || true

# launcher (Quit → poweroff by default; see SLS_ON_QUIT in overlay launcher)
install -D -m 755 "$OVERLAY/usr/local/bin/sls-camera" /usr/local/bin/sls-camera

# passwordless poweroff for appliance user (launcher fallback)
if [[ -f "$OVERLAY/etc/sudoers.d/sls-poweroff" ]]; then
  install -D -m 440 "$OVERLAY/etc/sudoers.d/sls-poweroff" /etc/sudoers.d/sls-poweroff
  # rewrite user name if SLS_USER overridden
  if [[ "$SLS_USER" != "sls" ]]; then
    sed -i "s/^sls /${SLS_USER} /" /etc/sudoers.d/sls-poweroff
  fi
  if command -v visudo >/dev/null 2>&1; then
    visudo -cf /etc/sudoers.d/sls-poweroff >/dev/null 2>&1 \
      || echo "WARN: sudoers.d/sls-poweroff failed visudo check" >&2
  fi
fi

# UDisks2 polkit: Format removable media without root password (sls-camera FORMAT-MEDIA-PRIVS)
if [[ -f "$OVERLAY/etc/polkit-1/rules.d/60-sls-udisks-format.rules" ]]; then
  install -D -m 644 "$OVERLAY/etc/polkit-1/rules.d/60-sls-udisks-format.rules" \
    /etc/polkit-1/rules.d/60-sls-udisks-format.rules
  if [[ "$SLS_USER" != "sls" ]]; then
    sed -i "s/subject.user !== \"sls\"/subject.user !== \"${SLS_USER}\"/" \
      /etc/polkit-1/rules.d/60-sls-udisks-format.rules
  fi
  systemctl restart polkit 2>/dev/null || true
  echo "Installed polkit rule for UDisks2 format (user ${SLS_USER})"
fi

# captures
mkdir -p "$DATA_CAPTURES"
chown -R "$SLS_USER:$SLS_USER" /data 2>/dev/null || chown -R "$SLS_USER:$SLS_USER" "$DATA_CAPTURES"

# autostart for user
USER_HOME="$(getent passwd "$SLS_USER" | cut -d: -f6)"
install -D -m 644 "$OVERLAY/home/sls/.config/autostart/sls-camera.desktop" \
  "$USER_HOME/.config/autostart/sls-camera.desktop"
# LXQt power management: no idle/battery/lid popups (app owns brightness)
if [[ -f "$OVERLAY/home/sls/.config/lxqt/lxqt-powermanagement.conf" ]]; then
  install -D -m 644 "$OVERLAY/home/sls/.config/lxqt/lxqt-powermanagement.conf" \
    "$USER_HOME/.config/lxqt/lxqt-powermanagement.conf"
fi
# User-level Hidden=true overrides for update/power autostart (belt + suspenders)
for f in lubuntu-update-autostart.desktop lxqt-powermanagement.desktop lxqt-xscreensaver-autostart.desktop; do
  cat >"$USER_HOME/.config/autostart/$f" <<'EOF'
[Desktop Entry]
Hidden=true
X-GNOME-Autostart-enabled=false
EOF
done
chown -R "$SLS_USER:$SLS_USER" "$USER_HOME/.config"

# LightDM autologin if present
if [[ -d /etc/lightdm ]]; then
  conf=/etc/lightdm/lightdm.conf.d/50-sls-autologin.conf
  mkdir -p "$(dirname "$conf")"
  cat >"$conf" <<EOF
[Seat:*]
autologin-user=$SLS_USER
autologin-user-timeout=0
EOF
  echo "Configured LightDM autologin for $SLS_USER"
fi

# SDDM autologin (Lubuntu 26.04 default display manager)
if [[ -d /etc/sddm.conf.d ]] || command -v sddm >/dev/null 2>&1 || [[ -f /etc/sddm.conf ]]; then
  mkdir -p /etc/sddm.conf.d
  if [[ -f "$OVERLAY/etc/sddm.conf.d/50-sls-autologin.conf" ]]; then
    # Prefer overlay (Relogin=true so greeter is not sticky after session crash)
    sed "s/^User=.*/User=$SLS_USER/" \
      "$OVERLAY/etc/sddm.conf.d/50-sls-autologin.conf" \
      >/etc/sddm.conf.d/50-sls-autologin.conf
  else
    cat >/etc/sddm.conf.d/50-sls-autologin.conf <<EOF
[Autologin]
User=$SLS_USER
Session=Lubuntu
Relogin=true
EOF
  fi
  # Lubuntu ships lubuntu_settings / sddm.conf with User=install-user — override
  if [[ -f /etc/sddm.conf ]]; then
    if grep -q '^\[Autologin\]' /etc/sddm.conf; then
      sed -i "/^\[Autologin\]/,/^\[/{s/^User=.*/User=$SLS_USER/; s/^Session=.*/Session=Lubuntu/}" /etc/sddm.conf \
        || true
    else
      printf '\n[Autologin]\nUser=%s\nSession=Lubuntu\n' "$SLS_USER" >>/etc/sddm.conf
    fi
  fi
  if [[ -f /etc/sddm.conf.d/lubuntu_settings.conf ]]; then
    sed -i "s/^User=.*/User=$SLS_USER/" /etc/sddm.conf.d/lubuntu_settings.conf 2>/dev/null || true
  fi
  echo "Configured SDDM autologin for $SLS_USER"
fi

# GDM autologin if present
if [[ -f /etc/gdm3/custom.conf ]]; then
  if ! grep -q "AutomaticLoginEnable" /etc/gdm3/custom.conf 2>/dev/null; then
    echo "NOTE: enable GDM AutomaticLogin for $SLS_USER in /etc/gdm3/custom.conf if needed"
  fi
fi

# GRUB: unclean power-off sets recordfail → default 30s menu (feels like "EFI hang")
# Cherry Trail tablets often use ia32 UEFI + grubia32; still apply on all arches.
if [[ -f /etc/default/grub ]]; then
  if grep -q '^GRUB_RECORDFAIL_TIMEOUT=' /etc/default/grub; then
    sed -i 's/^GRUB_RECORDFAIL_TIMEOUT=.*/GRUB_RECORDFAIL_TIMEOUT=0/' /etc/default/grub
  else
    printf '\n# SLS appliance: no 30s GRUB menu after hard power-off (recordfail)\nGRUB_RECORDFAIL_TIMEOUT=0\n' \
      >>/etc/default/grub
  fi
  sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub 2>/dev/null || true
  if command -v grub-editenv >/dev/null 2>&1; then
    grub-editenv /boot/grub/grubenv unset recordfail 2>/dev/null || true
  fi
  if command -v update-grub >/dev/null 2>&1; then
    update-grub 2>/dev/null || echo "WARN: update-grub failed (ok if no grub on this image)" >&2
  fi
  echo "Configured GRUB_RECORDFAIL_TIMEOUT=0 (skip 30s failed-boot menu)"
fi

echo
echo "=== Appliance install complete ==="
echo "  App:      $APP_ROOT"
echo "  Launcher: /usr/local/bin/sls-camera"
echo "  Captures: $DATA_CAPTURES"
echo "  User:     $SLS_USER (autostart enabled)"
echo
echo "Reboot, plug Kinect + power brick, and the SLS app should start."
echo "Optional mic: sudo apt install kinect-audio-setup  (MS firmware — not bundled)"
