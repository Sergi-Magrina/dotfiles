# VM substitutions — programs swapped for the workshop

Programs we *want* on the real Arch box (the "showroom") but have had to
swap for a different program to work inside the VirtualBox VM (the
"workshop"). The root cause is almost always the VM's **software-rendered
GPU** (no real GL/EGL), the same thing that dictates several of the VM
constraints in [CLAUDE.md](CLAUDE.md).

When this repo lands on real hardware, walk this table and decide — per row —
whether to switch back to the "wanted" program. Nothing here is automatic.

Versions are the packages **installed in the VM as of 2026-07-06** (Arch,
`pacman -Q`). They're a snapshot reference, not a pin — real hardware will
pull whatever is current at install time.

| Purpose | Wanted on real HW | VM version | Using in VM | VM version | Why swapped | Switch back when… |
|---|---|---|---|---|---|---|
| Terminal | `kitty` | 0.47.4-1 | `foot` | 1.27.0-1 | kitty needs GPU acceleration the software-rendered VM GPU can't serve — it crashes on launch here. | On real hardware kitty should just work. Switch back and retest; keep `foot` installed as a fallback. |
| Wallpaper | `hyprpaper` | 0.8.4-3 | `swaybg` | 1.2.2-1 | hyprpaper needs a real GL/EGL context (renders via OpenGL); the VM can't provide one, so nothing shows. swaybg draws via CPU/shared-memory and renders fine. | Only if you actually want hyprpaper's extras — runtime wallpaper switching (its IPC), preloading, or per-monitor wallpapers. For a single static wallpaper the two are equivalent, so otherwise keep swaybg. |

## Notes

- **kitty is still installed in the VM** (0.47.4-1) even though it crashes —
  it just isn't used. Don't uninstall it; it's the real-hardware target.
- **Not in this table on purpose:** `rofi-wayland` vs plain `rofi`. That's a
  Wayland/Hyprland requirement that holds on real hardware too, not a VM
  downgrade — so it doesn't belong here.
- **Not a program swap, but related:** VirtualBox's shared clipboard doesn't
  work under Hyprland, so clipboard goes through SSH + VS Code Remote-SSH.
  That's a workflow workaround, not a program substitution, so it's recorded
  in CLAUDE.md's VM constraints rather than here.
