# Live session helpers (Lubuntu installer, not yet installed)

Use this while booted from the **OS installer USB** to probe hardware, get
**internet**, and open **SSH**. Changes do **not** persist after reboot.

Field product (**blow-and-go**) does not require Wi‑Fi. Lab needs network for
SSH, `apt`, cloning, and running install scripts.

---

## Landscape + touch (fleet note)

Live validation on tablet glass: lock **landscape** with RandR **`right`**, then
map touch so axes follow.

One-shot on the live tablet (X11 session):

```bash
# preferred fleet default
export DISPLAY="${DISPLAY:-:0}"
export SLS_LANDSCAPE_ROTATE=right

# If firmware tree is available (USB / clone):
#   bash /path/to/sls-lock-landscape
# Else manual:
OUT=$(xrandr | awk '/ connected/{print $1; exit}')
xrandr --output "$OUT" --rotate right
# map every slave pointer (touch) to the panel
for id in $(xinput list | sed -n 's/.*id=\([0-9]*\).*slave *pointer.*/\1/p'); do
  xinput map-to-output "$id" "$OUT" 2>/dev/null || true
  xinput set-prop "$id" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1 2>/dev/null || true
done
xrandr | awk '/ connected/{print}'
```

Appliance default after install: same policy in `/usr/local/bin/sls-lock-landscape`
(`SLS_LANDSCAPE_ROTATE` default **`right`** + touch CTM / `map-to-output`).

If drag axes are still wrong, try `left` once and report on [sls-camera#7](https://github.com/tmdrake/sls-camera/issues/7).

---

## Wi‑Fi acting weird (lab only)

Cherry Trail tablets often need a nudge under live images.

### 1. See state

```bash
rfkill list
nmcli general status
nmcli device status
nmcli device wifi list
ip -br a
```

### 2. Unblock + power save off

```bash
sudo rfkill unblock all
# replace wlan0 with your iface from `ip -br a` / nmcli
IFACE=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')
echo "wifi iface: ${IFACE:-none}"
[[ -n "${IFACE:-}" ]] && sudo iw dev "$IFACE" set power_save off 2>/dev/null || true
sudo systemctl restart NetworkManager
sleep 2
nmcli device wifi list
```

### 3. Connect (SSID + password)

```bash
# interactive
nmcli device wifi connect 'YOUR_SSID' password 'YOUR_PASSWORD'

# or reconnect known profile
nmcli connection show
nmcli connection up 'YOUR_SSID'
```

### 4. Still flaky

| Try | Why |
|-----|-----|
| Move closer / 2.4 GHz SSID | Weak dual-band radios on Z83x0 |
| Forget + re-add | `nmcli connection delete 'SSID'` then connect again |
| USB Ethernet dongle | Most reliable lab path |
| Phone USB tethering | Instant NAT without tablet Wi‑Fi |
| Disable MAC randomization | Some captive / AP setups: NetworkManager wifi.scan-rand-mac-address=no |

```bash
# temporary: disable Wi‑Fi MAC randomization (session)
echo -e '[device]\nwifi.scan-rand-mac-address=no' | sudo tee /etc/NetworkManager/conf.d/00-sls-wifi.conf
sudo systemctl restart NetworkManager
```

### 5. Prove internet

```bash
ping -c 2 1.1.1.1
ping -c 2 github.com
curl -I https://github.com | head -3
```

---

## SSH into the live tablet

### Enable server

Lubuntu live may not ship `openssh-server`. With network:

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

Set a password for the live user (often the user you created in the greeter, or `lubuntu`):

```bash
whoami
sudo passwd "$(whoami)"
ip -br a   # note the Wi‑Fi / eth address
```

From the build host:

```bash
ssh YOUR_USER@TABLET_IP
```

### Without good Wi‑Fi

1. USB Ethernet dongle → same `apt install openssh-server` path.  
2. Phone USB tether → share connection, then SSH to the tether IP.  
3. Local only: keyboard + on-screen terminal (no SSH).

**Security:** live SSH with a weak password is lab-only; wipe when done.

---

## Run scripts over the network

Once `ping github.com` works:

```bash
# shallow clone firmware on live (RAM + maybe free disk on USB)
cd /tmp
git clone --depth 1 https://github.com/tmdrake/sls-camera-firmware.git
cd sls-camera-firmware

# display + touch only (safe on live)
export DISPLAY=:0
export SLS_LANDSCAPE_ROTATE=right
bash overlay/usr/local/bin/sls-lock-landscape

# Full install-appliance on LIVE will not stick on eMMC — use after
# real install, or target the internal disk carefully.
```

Preferred offline path remains **SLS-MEDIA** after a real eMMC install:
`bash install-from-usb.sh` (no network required).

---

## Related

- [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md) — landscape + DPMS policy  
- [ISO-AND-FIELD-USB.md](ISO-AND-FIELD-USB.md) — two sticks, install order  
- [FIRST-BOOT.md](FIRST-BOOT.md) — after appliance install  
