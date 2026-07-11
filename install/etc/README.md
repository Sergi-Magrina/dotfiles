# /etc config the repo can't symlink

Everything else in this repo symlinks into `~/.config`, but a few pieces of
the setup live in `/etc` — root-owned, outside the home directory, so the
symlink bootstrap can't place them. They have to be copied/edited by hand
once per machine. This directory keeps the files + the recipe.

## 1. zram (compressed swap)

The `zram-generator` package is inert without its config file:

```
sudo cp ~/dotfiles/install/etc/zram-generator.conf /etc/systemd/zram-generator.conf
```

Takes effect on next boot; verify with `swapon --show` (expect `/dev/zram0`).

## 2. pacman quality-of-life (`/etc/pacman.conf`)

Not a file copy — `pacman.conf` differs per machine (repos, mirrors), so just
edit it. In the `[options]` section, uncomment/add:

```
Color
ParallelDownloads = 5
```

The VM already runs with both; a fresh install has them commented out.

## 3. GRUB dual-boot (Pavilion only)

Covered in the migration doc (step 3): set `GRUB_DISABLE_OS_PROBER=false` in
`/etc/default/grub`, then `sudo grub-mkconfig -o /boot/grub/grub.cfg` so the
menu lists Windows.

## 4. Package-cache trimming (optional but cheap)

With `pacman-contrib` installed:

```
sudo systemctl enable --now paccache.timer
```

Weekly-trims old package versions from `/var/cache/pacman/pkg` — matters on
the Pavilion's smallish shared-with-Windows disk.
