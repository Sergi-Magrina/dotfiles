# Migration: VM "workshop" → HP Pavilion "showroom"

Moving this rice off the VirtualBox VM onto real hardware, **alongside a
preserved Windows** so family can still use the laptop.

The config migration is easy (everything's one symlinked repo). The real work
is the OS install and the GPU driver. Rough time: an afternoon if the GPU is
Intel/AMD, a weekend if it's older Nvidia.

**The one open variable:** which GPU the Pavilion has. Find out *before* the
driver step — it decides which package block to uncomment in
[`install/pkglist.txt`](../install/pkglist.txt):

- **From Windows:** Device Manager → *Display adapters* (Windows has no
  `lspci`). Seeing **two** adapters (Intel HD/UHD + an Nvidia GeForce) means
  Optimus — the happy path below.
- **From a live USB:** `lspci | grep -EA3 'VGA|3D'`.

**The Nvidia decision tree** (an old GeForce + Wayland is the one combo that
can eat a weekend — but there are two easy exits):

1. **Optimus laptop (most likely).** The Intel iGPU drives the screen; the
   Nvidia card is an optional helper. Uncomment the **Intel** block, ignore
   the Nvidia card entirely, and the whole "old Nvidia" problem disappears.
   For a rice (no gaming) you lose nothing. Revisit only if you later want
   the dGPU for something specific.
2. **Display wired to the Nvidia card only:** use **nouveau**, the open
   driver already inside `mesa` — zero extra packages, runs Hyprland
   acceptably for desktop use.
3. **Proprietary driver (last resort):** only worth it if the card is Turing
   (GTX 16xx/RTX) or newer — that's mainline `nvidia`. Older cards need AUR
   legacy `-dkms` builds (Maxwell/Pascal → `nvidia-580xx-dkms`, Kepler →
   `nvidia-470xx-dkms`) that are rough under Wayland; prefer option 2.

---

## Step 0 — On the VM, before you touch the laptop

The repo currently lives in **exactly one place with no git remote.** Get it
somewhere the laptop can reach, or the migration has nothing to clone.

- [ ] Commit the in-flight work (dirty tree across waybar/cava/spicetify) so
      you migrate a clean, known state. Don't move mid-edit.
- [ ] Push to a remote you own (GitHub — `Sergi-Magrina`), **or** copy the whole
      `~/dotfiles` folder to a USB stick as a fallback.
- [ ] The package list + scripts are already committed in `install/` — make
      sure they went up with everything else.

---

## Step 1 — Preserve Windows for the family (do this IN Windows, first)

The Pavilion almost certainly still has its original Windows. Keep it; just
make room next to it.

- [ ] **Back up anything the family cares about** — resizing partitions is
      low-risk but not zero-risk.
- [ ] **Disable Fast Startup** (Control Panel → Power Options → "Choose what
      the power buttons do" → uncheck Fast Startup). It leaves the Windows
      filesystem half-locked and can corrupt a shared disk.
- [ ] **Check for BitLocker** — if the drive is encrypted, suspend/disable it
      before resizing, or Windows may demand a recovery key at next boot.
- [ ] **Shrink the Windows partition** from *inside* Windows (Disk Management →
      right-click C: → Shrink Volume). Free up as much as you want for Arch
      (e.g. 60–120 GB). Leave the freed space **unallocated** — the Arch
      installer will use it.

Golden rule: **Windows first, Arch second.** Windows overwrites bootloaders;
installing Arch last means its GRUB detects Windows and adds it to the menu.
Since Windows is already there, you're naturally in the right order.

---

## Step 2 — Install Arch (into the free space, next to Windows)

- [ ] In BIOS/UEFI: disable **Secure Boot** (simplest path for an Arch
      install — it can be kept later with extra work). Note whether the machine
      boots **UEFI** (almost certainly) vs legacy BIOS.
- [ ] Boot the Arch ISO from USB.
- [ ] Run **`archinstall`** — the guided installer. Key choices:
      - **Disk:** use *manual partitioning* and install into the **unallocated
        space only**. Do **not** wipe the disk (that erases Windows).
      - Create an Arch root (and swap if you like; you also have
        `zram-generator` for compressed swap).
      - **Reuse the existing EFI partition** (the small ~100–500 MB FAT32 one
        Windows already made) as your `/boot` EFI mount — don't make a second.
      - **Bootloader: GRUB** (matches this repo's `grub` package).
      - Set hostname, root password, your user (`sergi`), timezone.
      - Profile: **minimal** — you'll install the desktop from `pkglist.txt`,
        not from archinstall's presets.
- [ ] Reboot into the new Arch.

---

## Step 3 — First boot: network, then make Windows show in the menu

- [ ] Bring up networking:
      `sudo systemctl enable --now NetworkManager` then `nmtui` for Wi-Fi.
- [ ] **Enable os-prober** so GRUB lists Windows. Edit `/etc/default/grub`,
      set `GRUB_DISABLE_OS_PROBER=false`, then regenerate:
      ```
      sudo grub-mkconfig -o /boot/grub/grub.cfg
      ```
      Reboot once and confirm **both Arch and Windows appear** in the GRUB
      menu. (If Windows is missing, it's almost always this flag or a still-on
      Fast Startup from Step 1.)

---

## Step 4 — Restore the rice

- [ ] Clone the repo to the same path the configs expect:
      ```
      git clone <your-remote> ~/dotfiles      # or copy from the USB to ~/dotfiles
      ```
- [ ] Install packages (the grep strips comments before pacman):
      ```
      grep -vE '^\s*#|^\s*$' ~/dotfiles/install/pkglist.txt | sudo pacman -S --needed -
      ```
      ...after uncommenting your **GPU block** in `pkglist.txt` (Step-0 lspci
      result).
- [ ] Symlink every config into place:
      ```
      ~/dotfiles/install/bootstrap-symlinks.sh
      ```
- [ ] Restore the `/etc` pieces the symlinks can't cover — full recipe in
      [`install/etc/README.md`](../install/etc/README.md):
      ```
      sudo cp ~/dotfiles/install/etc/zram-generator.conf /etc/systemd/   # or no swap
      sudo systemctl enable --now paccache.timer                          # cache trim
      ```
      ...plus `Color` + `ParallelDownloads = 5` in `/etc/pacman.conf`.
- [ ] Enable audio + SSH:
      ```
      systemctl --user enable --now pipewire pipewire-pulse wireplumber
      sudo systemctl enable --now sshd
      ```
- [ ] Make Hyprland start on login (no display manager in this setup — you
      log into the TTY and Hyprland launches from your shell profile). Append
      to `~/.bash_profile`:
      ```
      [[ -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]] && exec Hyprland
      ```
      (`exec` replaces the shell with Hyprland, so logging out of Hyprland
      logs out the TTY too. Other TTYs — Ctrl+Alt+F3 — stay plain shells for
      rescue work.)

---

## Step 5 — Reverse the VM substitutions

Walk [`vm-substitutions.md`](../vm-substitutions.md) row by row now that you
have a real GPU:

- [ ] **Terminal:** launch `kitty` — it should work now. If happy, rebind to
      it; keep `foot` installed as the fallback.
- [ ] **Wallpaper:** decide `swaybg` vs `hyprpaper`. Per the repo's own notes,
      for a single static wallpaper they're equivalent — only switch to
      hyprpaper if you want its runtime switching / per-monitor features (which
      phase 7's theme-swap might make attractive).
- [ ] `virtualbox-guest-utils` is already absent (not in `pkglist.txt`) —
      nothing to remove.
- [ ] The `VBoxClient --clipboard` autostart line in `hyprland.lua` is
      guarded (`command -v VBoxClient`), so it's inert on real hardware —
      delete it whenever the VM is retired, no rush.

---

## Step 6 — Verify (the payoff)

- [ ] Log into Hyprland. This is the first time you can actually **judge the
      aesthetics** — animations, gradients, transparency, the palette on a real
      panel. Screenshot with `grim` and compare against intent.
- [ ] Confirm the **clipboard works natively** (no more VirtualBox/SSH-only
      workaround).
- [ ] Sanity-check each workspace assignment (file manager, browser, apps,
      Control Center) and the waybar Nerd Font glyphs render.

---

## Step 7 — Keep developing from this laptop (optional)

Claude Code and VS Code don't have to move. The HP is now a *better*
Remote-SSH target than the VM ever was:

- [ ] From this laptop: VS Code → Remote-SSH → `sergi@<pavilion-ip>`. Same
      workflow you already use, pointed at real hardware.
- [ ] Claude Code can run over that SSH session, or directly on the HP.

---

## Later, not part of the core restore

- **spicetify** — not installed yet (config-only in the repo). When you set up
  Spotify on real HW, install `spicetify-cli` (AUR — you'll want an AUR helper
  like `yay` first) and wire its config then. Roadmap step 8.
- **Laptop niceties** the VM never needed: `bluez` + `bluez-utils`
  (Bluetooth), maybe `tlp` (battery). Add as wanted. (`brightnessctl` moved
  into `pkglist.txt` — the keybinds already reference it.)
- **hyprlock + hypridle configs** — the packages install with the list, but
  neither has a config in the repo yet (hyprlock can't render in the VM, so
  they're untestable until real hardware). Write them on the Pavilion:
  hypridle to lock/screen-off on idle + lid close, hyprlock themed from the
  palette. Until then `hyprlock` still works run by hand, just unstyled.
- **AUR helper (`yay`)** — needed for spicetify, and for the legacy Nvidia
  path if it ever comes up. Install once Arch is settled.
