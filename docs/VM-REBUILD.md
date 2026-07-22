# Rebuild Phase 1 test VM (Lubuntu 26.04)

Use this when recreating the KVM appliance test guest from scratch.  
Proven path: **Lubuntu 26.04 x86_64** + `install-appliance.sh` + optional Kinect USB passthrough.

> **Role of this VM:** **app + packaging smoke only.**  
> Guest sound (SPICE/PipeWire/virtio) is **not** RCA RT5651/SST. Do **not** sign off field speakers, PMIC/Goodix, or tablet touch from the VM.  
> Installer ship bar = **bare-metal wipe** (RCA / fleet) — [ARCHITECTURE.md](ARCHITECTURE.md) § Validation tracks.  
> Landscape rotate/CTM and field audio helpers **auto-skip** on hypervisor.

### App-only smoke (what worked well)

Before (or without) treating the guest as a full field appliance, the app already smoked well on the VM:

```bash
# from host app tree, or guest checkout / /opt/sls-camera after a light install
cd ~/sls-camera/software/linux/viewer   # or /opt/sls-camera/software/linux/viewer
./run.sh --demo
# or:  sls-camera --demo
# or:  Desktop / Applications → SLS Camera
```

That path is enough for **UI, Settings, TTS latency, quit codes** under tablet-class resources.  
Full `install-appliance` / SLS-MEDIA is for **field contracts** (autologin, GRUB, speakers, PMIC, poweroff) — prove those on **RCA**, not by SPICE audio.

## Lab credentials (standard for rebuilds)

| Role | Username | Password | Notes |
|------|----------|----------|--------|
| **Appliance user (use this)** | **`sls`** | **`20260717`** | Autologin target; app autostart; SSH as this user |
| Lubuntu installer user | *any temporary name* | *any* | Only needed for first ISO install; **remove after appliance setup** |

**Policy for rebuilds:** always finish with a single interactive user **`sls` / `20260717`**. Do not keep a long-lived “ghosthunter” (or other install) account — it leaves desktop scrap and breaks the “blow and go” story.

> **Security:** `20260717` is a **lab / VM-only** password. Change it on real tablets and never reuse it as a production secret. Deps/version issues → [sls-camera#2](https://github.com/tmdrake/sls-camera/issues/2) / [#3](https://github.com/tmdrake/sls-camera/issues/3).

### After `install-appliance.sh`

The script creates **`sls`** if missing. Set/reset the lab password explicitly:

```bash
sudo passwd sls
# enter: 20260717  (twice)
# or non-interactive on a throwaway VM:
echo 'sls:20260717' | sudo chpasswd
```

SSH from the build host (libvirt NAT example):

```bash
ssh sls@192.168.122.100
# password: 20260717
```

Console:

```bash
# Layout / Settings QA: pin guest resolution — do NOT auto-resize with the window
virt-viewer -c qemu:///system -a sls-appliance-phase1 --auto-resize never
```

### SPICE auto-resize (why the guest “forces” a new resolution)

**Not an SLS app bug.** With **virtio** video + **spice-vdagent** (stock Lubuntu), resizing the **virt-viewer** window asks the guest to match that size. Modes like **5120×2160** or odd preferred sizes appear; fixed **1280×800** / **1920×1200** layout tests break.

| Earlier smoke tests | What changed |
|---------------------|--------------|
| Window often left alone / scaled by viewer | Dragging the window edge triggers agent resize |
| Preferred mode stuck at 1280×800 | Mode list reshuffles; preferred can become something else |

**For tablet layout QA (keep resolution fixed):**

```bash
virt-viewer … --auto-resize never
# guest (optional pin):
export DISPLAY=:0
xrandr --output Virtual-1 --mode 1280x800    # or 1920x1200
```

Scale the viewer window if you want a larger host window without changing guest pixels (viewer zoom / window size with auto-resize off).

Real tablets have no SPICE — this only affects the lab VM.

### Landscape lock is for field tablets, not this VM

`sls-lock-landscape` is **fleet glass only** (RCA / TMAX portrait panels → landscape + Goodix CTM). On KVM/QEMU it **auto-skips** so Spice mouse is not CTM-warped.

| Host | Landscape rotate + touch CTM |
|------|------------------------------|
| RCA / TMAX bare metal | **Yes** (default) |
| `sls-appliance-phase1` VM | **No** (detect hypervisor → exit) |

Override only for weird lab experiments: `SLS_FORCE_LANDSCAPE=1`. See [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md) § Landscape lock.

### Kinect USB passthrough (live depth in guest)

```bash
# on host
cd ~/sls-camera-firmware
./scripts/vm-kinect-usb.sh status
./scripts/vm-kinect-usb.sh reattach   # preferred after host reboot / glitch
# guest: lsusb | grep 045e ; sls-camera   (not --demo)
```

---

## 1. Build host prep

On the **host** (not the guest), from this repo:

```bash
cd ~/sls-camera-firmware
./scripts/00-check-host.sh
./scripts/10-fetch-offline.sh    # recursive debs + wheels + model
./scripts/20-sync-app.sh         # pin from packages/app-ref.txt
```

ISO for the guest (download once; keep under `/var/lib/libvirt/images/` so QEMU can read it):

```text
https://cdimage.ubuntu.com/lubuntu/releases/26.04/release/lubuntu-26.04-desktop-amd64.iso
```

---

## 2. Create the VM (virt-install)

One-time storage pool if needed:

```bash
sudo virsh pool-define-as default dir --target /var/lib/libvirt/images
sudo virsh pool-build default
sudo virsh pool-start default
sudo virsh pool-autostart default
```

```bash
ISO=/var/lib/libvirt/images/lubuntu-26.04-desktop-amd64.iso
virt-install \
  --name sls-appliance-phase1 \
  --memory 2048 \
  --vcpus 2 \
  --cpu host \
  --disk size=30,format=qcow2,bus=virtio \
  --cdrom "$ISO" \
  --os-variant ubuntu24.04 \
  --network network=default,model=virtio \
  --graphics spice,listen=none \
  --video virtio \
  --channel spicevmc \
  --boot uefi \
  --noautoconsole

virt-viewer -c qemu:///system -a sls-appliance-phase1
```

Suggested guest resources: **2 vCPU / 2 GiB RAM / 25–30 GiB disk**.

### Tablet-class resources (required for performance / DrakeVox TTS smoke)

Field tablets are **~2 GiB RAM** + slow Atom (Z8350/Z8300). A fat host VM (8 GiB / 8 vCPU) **will not** catch TTS stalls or RAM thrash from [#13](https://github.com/tmdrake/sls-camera/issues/13).

| Profile | vCPU | RAM | Use |
|---------|------|-----|-----|
| **tablet-class (default Phase 1)** | **2** | **2 GiB** | Layout + TTS + app smoke (match virt-install above) |
| Stress (optional worse case) | **1** | **2 GiB** | Extra-jank TTS / pose only — not daily |

**Check current guest:**

```bash
virsh -c qemu:///system dominfo sls-appliance-phase1 | grep -E 'CPU\(s\)|Max memory|Used memory'
# Expect: CPU(s)=2  Max/Used memory ≈ 2097152 KiB (2 GiB)
```

**Enforce tablet-class (guest should be shut down):**

```bash
# from firmware tree
./scripts/vm-tablet-class-resources.sh sls-appliance-phase1
# or manually:
virsh -c qemu:///system shutdown sls-appliance-phase1
# wait until shut off
virsh -c qemu:///system setmaxmem sls-appliance-phase1 2097152 --config
virsh -c qemu:///system setmem    sls-appliance-phase1 2097152 --config
virsh -c qemu:///system setvcpus  sls-appliance-phase1 2 --config --maximum
virsh -c qemu:///system setvcpus  sls-appliance-phase1 2 --config
virsh -c qemu:///system start sls-appliance-phase1
```

**Inside the guest (confirm pressure):**

```bash
free -h          # ~1.8–2.0 Gi total
nproc            # 2
```

**DrakeVox / TTS smoke under this profile** (app pin with #13 fixes):

1. `DISPLAY=:0` run field app (`sls-camera` or `./run.sh` — not `--demo` if testing mic/speakers).  
2. Spectrum ON if available; wait until UI is live (pose model loaded).  
3. **DrakeVox now** (or key **O**) several times under load — UI must not multi-second freeze; panel speakers or AVI inject OK.  
4. **Record** → speak a word mid-REC → stop → AVI has mic + TTS.  
5. Note wall-clock feel vs desktop host; still not as slow as real Atom, but RAM-bound paths show up.

Do **not** raise Phase 1 to 4–8 GiB for “comfort” and call that field QA.

---

## 3. Lubuntu installer (inside the guest only)

1. **Install Lubuntu** (not “Try only”).  
2. Create a **temporary** admin user if the installer requires one (any name).  
3. Finish install → reboot.  
4. **Eject the ISO** so you boot the installed disk:

```bash
virsh -c qemu:///system change-media sls-appliance-phase1 sda --eject --config --live 2>/dev/null || true
virt-xml sls-appliance-phase1 --edit --boot hd
virsh -c qemu:///system reboot sls-appliance-phase1
```

5. Optional snapshot before appliance install:

```bash
virsh -c qemu:///system snapshot-create-as sls-appliance-phase1 pre-appliance \
  "Clean Lubuntu before install-appliance"
```

---

## 4. Copy firmware tree into the guest

Guest must be on the network (default libvirt NAT). Find IP:

```bash
virsh -c qemu:///system domifaddr sls-appliance-phase1
```

From the **host** (example):

```bash
# as temporary install user, or after sls exists:
scp -r ~/sls-camera-firmware USER@GUEST_IP:~/
```

Prefer placing the tree under **`/home/sls/sls-camera-firmware`** once `sls` exists.

Enable SSH on the guest if needed:

```bash
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

---

## 5. Run appliance install (on the guest)

```bash
cd ~/sls-camera-firmware   # or /home/sls/sls-camera-firmware
sudo ./scripts/install-appliance.sh
```

This should:

- Create/configure user **`sls`**
- Install offline debs (apt cache + `--no-download` when vendor is complete)
- Install app to `/opt/sls-camera`, launcher `/usr/local/bin/sls-camera`
- Captures dir `/data/sls-captures`
- SDDM autologin → **`sls`** (Lubuntu 26.04)
- Autostart SLS Camera
- Quiet session: no update notifiers, no LXQt power popups, logind no-suspend  
  (see [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md))

Then set the lab password and reboot:

```bash
echo 'sls:20260717' | sudo chpasswd
sudo hostnamectl set-hostname sls-appliance
# remove temporary install user when ready (frees greeter / home scrap)
# sudo userdel -r TEMP_INSTALL_USER
sudo reboot
```

### Expected after reboot

| Check | Expected |
|--------|----------|
| Login | Autologin as **`sls`** (not the ISO install user) |
| Hostname | `sls-appliance` (optional but recommended) |
| App | SLS Camera autostarts (or run `/usr/local/bin/sls-camera`) |
| Password | `sls` / `20260717` for console unlock / SSH |

Smoke without Kinect:

```bash
/usr/local/bin/sls-camera --demo
```

---

## 6. Kinect USB passthrough (optional)

**Preferred:** use the helper script (handles stale hostdevs, re-enum wait, status):

```bash
# on the build host, from sls-camera-firmware
./scripts/vm-kinect-usb.sh status
./scripts/vm-kinect-usb.sh reattach    # fix most “failed to attach” cases
./scripts/vm-kinect-usb.sh detach      # return Kinect to host

# optional: reattach + freenect-camtest over SSH (lab password)
SSHPASS=20260717 GUEST_SSH=sls@192.168.122.100 ./scripts/vm-kinect-usb.sh test
```

| Product | ID |
|---------|-----|
| Motor | `045e:02b0` |
| Camera | `045e:02ae` |
| Audio | `045e:02bb` |

Host must see all three before attach (`lsusb | grep 045e`). Power brick required.

Manual one-liner (if you prefer not to use the script):

```bash
for id in 02b0 02ae 02bb; do
  cat >/tmp/k-$id.xml <<EOF
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='0x045e'/>
    <product id='0x$id'/>
  </source>
</hostdev>
EOF
  virsh -c qemu:///system attach-device sls-appliance-phase1 /tmp/k-$id.xml --live --config
done
```

In guest: `lsusb | grep 045e`, then `/usr/local/bin/sls-camera` (no `--demo`).

After a **guest reboot**, run `./scripts/vm-kinect-usb.sh reattach` if freenect cannot open the camera.

---

## 7. Checklist — “rebuild looks right”

- [ ] Guest is Lubuntu **26.04**  
- [ ] Only appliance user **`sls`** is used day-to-day (`20260717`)  
- [ ] Temporary ISO install user removed (or marked system account)  
- [ ] SDDM autologin → `sls`  
- [ ] `/usr/local/bin/sls-camera` works (`--demo` or live Kinect)  
- [ ] No update / power-management popups after login  
- [ ] Captures under `/data/sls-captures` when snapping  
- [ ] Screenshots / notes: [FIRST-BOOT.md](FIRST-BOOT.md), [images/](images/README.md)  

---

## 8. Destroy and recreate (clean slate)

```bash
virsh -c qemu:///system destroy sls-appliance-phase1
virsh -c qemu:///system undefine sls-appliance-phase1 --nvram --remove-all-storage
# then repeat from section 2
```

---

## Related docs

| Doc | Topic |
|-----|--------|
| [BUILD.md](BUILD.md) | Host fetch/sync/install overview |
| [FIRST-BOOT.md](FIRST-BOOT.md) | After appliance install |
| [POWER-AND-DISPLAY.md](POWER-AND-DISPLAY.md) | No rotate, no suspend, no update popups, brightness |
| [OFFLINE-MIRROR.md](OFFLINE-MIRROR.md) | vendor/ debs + wheels |
| [HARDWARE.md](HARDWARE.md) | Kinect BOM |
