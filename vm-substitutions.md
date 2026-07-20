# VM substitutions — programs swapped for the workshop

Programs we *want* on the real Arch box (the "showroom") but have had to
swap for a different program to work inside the VirtualBox VM (the
"workshop"). The root cause is almost always the VM's **software-rendered
GPU** (no real GL/EGL), the same thing that dictates several of the VM
constraints in [CLAUDE.md](CLAUDE.md).

When this repo lands on real hardware, walk this table and decide — per row —
whether to switch back to the "wanted" program. Nothing here is automatic.

> **STATUS: both rows reversed on 2026-07-20**, on the Pavilion (UHD 620). The
> repo now ships `kitty` + `hyprpaper`; `foot` and `swaybg` stay installed as
> fallbacks. Details under [Reversals](#reversals) below. The table is kept as
> the record of *why* each swap existed — it's history now, not current state.

Versions are the packages **installed in the VM as of 2026-07-06** (Arch,
`pacman -Q`). They're a snapshot reference, not a pin — real hardware will
pull whatever is current at install time.

| Purpose | Wanted on real HW | VM version | Using in VM | VM version | Why swapped | Switch back when… | Reversed? |
|---|---|---|---|---|---|---|---|
| Terminal | `kitty` | 0.47.4-1 | `foot` | 1.27.0-1 | kitty needs GPU acceleration the software-rendered VM GPU can't serve — it crashes on launch here. | On real hardware kitty should just work. Switch back and retest; keep `foot` installed as a fallback. | ✅ 2026-07-20 |
| Wallpaper | `hyprpaper` | 0.8.4-3 | `swaybg` | 1.2.2-1 | hyprpaper needs a real GL/EGL context (renders via OpenGL); the VM can't provide one, so nothing shows. swaybg draws via CPU/shared-memory and renders fine. | Only if you actually want hyprpaper's extras — runtime wallpaper switching (its IPC), preloading, or per-monitor wallpapers. For a single static wallpaper the two are equivalent, so otherwise keep swaybg. | ✅ 2026-07-20 |

## Reversals

Both done on the Pavilion, 2026-07-20 (migration step 5).

### Terminal: foot → kitty (0.48.0-1)

kitty launches fine on real hardware, as predicted. What changed in the repo:

- `hypr/hyprland.lua` — `terminal` and `fileManager` (yazi).
- `hypr/scripts/control-center.sh` — the ws-0 placeholder panels.
- `theme/templates/kitty.conf.in` + `theme/gen.py` — kitty is now palette-
  generated like every other surface.

**The one porting gotcha:** kitty spells the window app-id `--class` where foot
spelled it `--app-id`. On Wayland kitty maps `--class` onto the app_id, so every
`cc-*` / `yazi` window rule matches the same string as before and none of them
needed editing — but anything *grepping* for the old flag had to change (it bit
`set-theme.sh`'s fallback panel-kill, which silently matched nothing).

Terminal transparency (roadmap step 5) moved from foot's `[main] alpha` to
kitty's `background_opacity`, still reading the palette's `foot_alpha` key so
both terminals stay visually identical. The key name predates kitty — it's
shared, not stale.

**foot stays installed and palette-generated** as the fallback, per the row's
own instruction. Don't remove `foot/foot.ini` or its template.

### Wallpaper: swaybg → hyprpaper (0.8.4-3)

The row said to switch back *only* for hyprpaper's extras — and phase 7 turned
out to be exactly that case. `theme/set-wallpaper.sh` now swaps the image over
hyprpaper's **IPC** (`hyprctl hyprpaper wallpaper`), inside the running daemon,
instead of killing and respawning swaybg. Verified: same PID before and after,
so no flicker — and phase 9's settings app gets a clean surface to drive.

New file `hypr/hyprpaper.conf` (symlinked to `~/.config/hypr/`) holds the
**login** wallpaper only; runtime swaps are local gitignored state
(`theme/state/active-wallpaper`), honouring CLAUDE.md's "don't commit wallpaper
changes" rule.

**Two hyprpaper 0.8.x gotchas** — it rewrote both the config and the IPC on top
of hyprtoolkit/hyprwire, and most guides online still show the old syntax:

- Config uses `wallpaper { }` blocks, **not** `preload = ` / `wallpaper = mon,path`.
  Those keys no longer exist; hyprpaper starts with "no target: no wp will be
  created" if you use them.
- `preload` / `unload` IPC requests were **removed** (0.8 manages image memory
  itself) and now fail with "invalid hyprpaper request". `wallpaper` and
  `listactive` are the whole API.

Also verified: hyprpaper does **not** re-read its config while running, and
SIGUSR1 kills it rather than reloading. Fine, since nothing edits it at runtime.

**swaybg stays installed** as the fallback.

## Notes

- **kitty was kept installed in the VM** (0.47.4-1) even though it crashed
  there, because it was always the real-hardware target. That's now moot: the
  hardware runs kitty for real (0.48.0-1). If you ever boot the VM again, note
  that the committed config now points at kitty and hyprpaper — neither works
  under software rendering, so the VM would need both swaps re-applied locally.
- **Not in this table on purpose:** `rofi-wayland` vs plain `rofi`. That's a
  Wayland/Hyprland requirement that holds on real hardware too, not a VM
  downgrade — so it doesn't belong here.
- **Not a program swap, but related:** VirtualBox's shared clipboard doesn't
  work under Hyprland, so clipboard goes through SSH + VS Code Remote-SSH.
  That's a workflow workaround, not a program substitution, so it's recorded
  in CLAUDE.md's VM constraints rather than here.
