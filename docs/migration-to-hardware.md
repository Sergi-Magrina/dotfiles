# Migration: VM "workshop" → HP Pavilion "showroom"

Moving this rice off the VirtualBox VM onto real hardware. **Decided
2026-07-11: the family is done with this laptop — Windows gets wiped and Arch
takes the whole disk.** No dual-boot, which deletes the partition-shrinking,
os-prober, and clock-skew work that used to live in this plan.

The config migration is easy (everything's one symlinked repo). The real work
is the OS install and the GPU driver.

**The one open variable — RESOLVED (2026-07-11).** Confirmed specs:
i5-8250U, 12 GB RAM, and **two** display adapters — Intel UHD Graphics 620 +
NVIDIA GeForce MX130. That's Optimus, option 1 below (the happy path): the
**Intel** block in [`install/pkglist.txt`](../install/pkglist.txt) is now
uncommented, and the MX130 is ignored — it's Maxwell, so a vendor driver
would mean the rough AUR `nvidia-580xx-dkms` path, pointless for a rice;
nouveau (already inside mesa) binds the idle card and powers it down. Time
estimate: the "afternoon", not the "weekend".

**The Nvidia decision tree** (kept for reference — option 1 is the one that
applies):

1. **Optimus laptop (most likely).** The Intel iGPU drives the screen; the
   Nvidia card is an optional helper. Uncomment the **Intel** block, ignore
   the Nvidia card entirely, and the whole "old Nvidia" problem disappears.
   For a rice (no gaming) you lose nothing. Revisit only if you later want
   the dGPU for something specific.
2. **Display wired to the Nvidia card only:** use **nouveau**, the open
   driver already inside `mesa` — zero extra packages, runs Hyprland
   acceptably for desktop use.
3. **Vendor driver (last resort):** only worth it if the card is Turing
   (GTX 16xx/RTX) or newer — that's `nvidia-open` + `nvidia-utils` (the
   closed `nvidia` package no longer exists in the repos). Older cards need
   AUR legacy `-dkms` builds (Maxwell/Pascal → `nvidia-580xx-dkms`, Kepler →
   `nvidia-470xx-dkms`) that are rough under Wayland; prefer option 2.

---

## Step 0 — On the VM, before you touch the laptop

~~The repo currently lives in exactly one place with no git remote.~~ Done:
it's pushed to **`github.com/Sergi-Magrina/dotfiles`** (private; the VM's
SSH key is registered on the account).

- [x] Commit the in-flight work (dirty tree across waybar/cava/spicetify) so
      you migrate a clean, known state. Don't move mid-edit. *(Done
      2026-07-11. Note: `git status` still shows the palette-generated files
      (waybar/cava/foot/mako/rofi/spicetify/`theme/colors.env`) as modified —
      that's the **live purple-blue theme switch**, which stays uncommitted
      by design, like the wallpaper: committed defaults remain red-black, and
      `theme/set-theme.sh purple-blue` reproduces the look on the laptop.)*
      **Superseded 2026-07-20:** the generated files aren't committed at all
      any more — they're gitignored build artifacts regenerated at bootstrap
      and login, so `git status` no longer shows them. See
      `docs/phase-7-selectable-palettes.md`.
- [x] Push to a remote you own (GitHub — `Sergi-Magrina`), **or** copy the whole
      `~/dotfiles` folder to a USB stick as a fallback. *(Pushed 2026-07-12,
      `origin/master` = `db37c3e`.)*
- [x] The package list + scripts are already committed in `install/` — make
      sure they went up with everything else. *(Verified: all four `install/`
      files are on `origin/master`.)*
- [x] **Flip the repo public** (clone-auth decision, made 2026-07-12: public
      beats a read-only PAT / phone-added SSH key / USB copy — the laptop
      then clones with no credentials at all). On GitHub: repo →
      **Settings → General → Danger Zone → Change visibility → Make
      public.** Verify from any shell:
      ```
      GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/Sergi-Magrina/dotfiles.git
      ```
      — refs listed = public; a username prompt/error = still private.
- [ ] **Make the Arch install USB.** Download the ISO from
      <https://archlinux.org/download/> (grab a mirror near you), verify the
      checksum against the one on that page, and write it to a spare USB
      stick — from Windows use Rufus (or Ventoy), from Linux
      `sudo dd if=archlinux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync`
      (double-check `/dev/sdX` with `lsblk` — dd to the wrong disk is
      unrecoverable). This is a *different* stick than the dotfiles-backup
      one, or at least a Ventoy stick that can hold both.
- [ ] Have the **Wi-Fi password** written down somewhere — the fresh install
      has no saved networks and no browser to look it up with.

---

## Step 1 — Last call on Windows (one-time salvage)

Windows is getting wiped, so this boot is the only chance to pull anything
off it.

- [ ] **Copy off anything anyone still wants** — family photos, documents,
      browser bookmarks/passwords, game saves — onto a USB stick or cloud
      storage. Once Step 2 runs, the disk is gone for good. If in doubt,
      copy it; a stick of "maybe" files is cheap insurance.
- [ ] While you're still in Windows, it's also the convenient place to
      **write the Arch USB with Rufus** and note the Wi-Fi password (both
      from Step 0), if you haven't already.

Everything else this step used to contain — Fast Startup, BitLocker,
partition shrinking, the UTC clock registry fix — was a dual-boot concern
and is irrelevant on a full wipe.

---

## Step 2 — Install Arch (whole disk)

- [ ] In BIOS/UEFI: disable **Secure Boot** (simplest path for an Arch
      install — it can be kept later with extra work). Note whether the machine
      boots **UEFI** (almost certainly) vs legacy BIOS.
- [ ] Boot the Arch ISO from USB.
- [ ] Run **`archinstall`** — the guided installer. Key choices:
      - **Disk:** select the laptop's internal drive and choose the **wipe /
        "erase disk and use a best-effort default layout"** option. This is
        the moment Windows ceases to exist — Step 1's salvage must be done.
        Skip a swap partition if offered; `zram-generator` (already in the
        repo's `/etc` recipe) covers swap.
      - **Bootloader: GRUB** (matches this repo's `grub` package).
      - Set hostname, root password, your user (`sergi`), timezone.
      - Profile: **minimal** — you'll install the desktop from `pkglist.txt`,
        not from archinstall's presets.
- [ ] Reboot into the new Arch.

---

## Step 3 — First boot: network

- [ ] Bring up networking:
      `sudo systemctl enable --now NetworkManager` then `nmtui` for Wi-Fi.
      (Arch is the only OS on the disk now — GRUB boots straight into it, no
      os-prober needed.)

---

## Step 4 — Restore the rice

- [ ] Clone the repo to the same path the configs expect:
      ```
      git clone https://github.com/Sergi-Magrina/dotfiles.git ~/dotfiles
      # (repo is public — anonymous HTTPS clone, no credentials needed;
      #  or copy from the USB stick to ~/dotfiles)
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

- [x] **Terminal:** kitty works on the Pavilion (0.48.0-1) and is now the
      repo's terminal — Hyprland's `terminal`/`fileManager`, the Control
      Center panels, and a palette-generated `kitty/kitty.conf`. `foot` stays
      installed and generated as the fallback. **Done 2026-07-20.**
- [x] **Wallpaper:** switched to `hyprpaper` (0.8.4-3). Phase 7 made the
      "only if you want its extras" case real — `set-wallpaper.sh` now swaps
      over hyprpaper's IPC inside the running daemon (no flicker), instead of
      killing and respawning swaybg. `swaybg` stays installed as the
      fallback. **Done 2026-07-20.** Watch out for the 0.8.x syntax rewrite —
      see `vm-substitutions.md`.
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
