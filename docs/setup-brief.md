# Setup brief — what this project is, the stack, and where Jarvis fits

> Written 2026-07-18. A self-contained snapshot for anyone (or any session)
> that needs the full picture without reading the whole repo. For integration
> matters, [jarvis-integration.md](jarvis-integration.md) remains the living
> source of truth; this brief summarizes, it doesn't decide.

## 1. What we're building

A fully themed **Arch Linux + Hyprland desktop** ("rice"), managed entirely
from this repo (`~/dotfiles`) — the single source of truth. It's being built
and tested inside a **VirtualBox VM** (the "workshop") and will be cloned
onto real hardware (the "showroom"): an HP Pavilion first (migration under
way — full Windows wipe decided, repo already public on GitHub for
cloning), a new PC around August 2026.

The signature piece is a **Control Center**: a special workspace (0) of
small, floating, always-on dashboard panels — music, audio visualizer,
calendar, todo — over raw wallpaper, deliberately *not* tiled. The calendar
and todo panels are where **Jarvis** (Sergi's separate voice-assistant
project) plugs into the desktop.

## 2. The stack

| Role | Program | Notes |
|---|---|---|
| Compositor | **Hyprland 0.55+** | Config in **Lua** (`hypr/hyprland.lua`), hot-reloads on save |
| Terminal | **kitty** | Real hardware since 2026-07-20 (was **foot** in the VM, which stays installed + generated as the fallback) |
| Bar | **Waybar** | No hot-reload: `killall waybar && waybar &` after changes |
| Launcher | **rofi-wayland** | Not plain rofi (X11-only); bound to `Super+R` |
| Notifications | **mako** | |
| Wallpaper | **hyprpaper** | Real hardware since 2026-07-20 (was **swaybg** in the VM). Chosen for its IPC: `set-wallpaper.sh` swaps inside the running daemon — see `vm-substitutions.md` |
| Visualizer | **cava** | Control Center bottom strip |
| Spotify skin | **Spicetify** | Palette-generated `color.ini` |
| Widgets | **Python + GTK** (PyGObject) | Proven in the VM; precedent: `hypr/scripts/cc-music.py` (MPRIS/playerctl now-playing panel) |

Everything is **symlinked** from `~/dotfiles/*` into the live config
locations (`~/.config/hypr/`, `~/.config/waybar/`, …) by
`install/bootstrap-symlinks.sh`. Config is only ever edited inside the repo.

## 3. The theme system (the technical heart)

One palette definition drives every colored surface, and themes are
**runtime hot-swappable** — no logout:

- **5 palette slots** (+1 knob): `background`, `accent`, `accent_bright`,
  `muted`, `foreground`, plus `foot_alpha` (terminal transparency).
- Palettes live in `theme/palettes/`; the default is the original
  **black/red** theme.
- Two consumption styles, and only two:
  1. **Templated** — `theme/templates/*.in` rendered by `theme/gen.py` into
     the hardcoded-format configs (waybar config + CSS, rofi rasi, kitty,
     foot, mako, cava, spicetify), since CSS/rasi/ini can't `require()` Lua.
  2. **Runtime-read** — programs/scripts source `theme/colors.env`
     (`KEY='#hex'`) at launch; Hyprland reads `hypr/colors.lua`.
- **`theme/set-theme.sh`** does the switch: regenerate from templates,
  reload waybar/mako, let Hyprland hot-reload its Lua, and **kill + respawn
  the Control Center widgets**. `theme/set-wallpaper.sh` swaps the wallpaper
  over hyprpaper's IPC — wallpaper is an **independent axis**, not a per-theme field,
  and live wallpaper choices are never committed.
- Current picker is a rofi menu (`theme/pick.sh`); a proper settings GUI is
  a later phase built *on top of* these CLIs.

## 4. Desktop structure

- **Workspaces:** 1 = empty (wallpaper + waybar only), 2 = file manager,
  3 = Firefox, 4 = general apps (VS Code, Claude Desktop, Spotify),
  **0 = Control Center** (internally ws 10).
- **Control Center mechanics:** `hypr/scripts/control-center.sh` runs at
  login and spawns each panel with a unique `cc-*` app-id; window rules in
  `hyprland.lua` float each at a fixed size/position (fractions of the
  monitor). Placeholders get swapped for real widgets **keeping the same
  app-id**, so the rules never change. Live today: cava and the GTK music
  widget (each with graceful fallbacks if not installed). Still
  placeholders: `cc-calendar` and `cc-todo` — reserved for Jarvis.
- **VM constraints** (only if you boot the workshop again — the rice now
  runs on real hardware): software-rendered GPU — no kitty, no hyprpaper, no
  Electron/WebGL; GTK-in-Python, TUIs in foot, and Firefox are proven.
  Aesthetics are judged on real hardware, structure/correctness in the VM. Claude sessions can't `sudo`/`pacman` —
  installs are Sergi's.

## 5. Jarvis integration — status and expectations

**Full detail: [jarvis-integration.md](jarvis-integration.md) (living doc)
and [jarvis-brief.md](jarvis-brief.md) (the jarvis side's verbatim brief).**

- **Workflow:** two Claude Code sessions that cannot see each other's repos
  — this one (desktop) and one in the jarvis repo (not on this machine).
  Sergi relays documents between them by pasting.
- **Scope (slice 1, started 2026-07-11):** fill the `cc-calendar`
  (26% × 34% of monitor, ≈500×370 @1080p) and `cc-todo` (16% × 34%,
  ≈310×370) panels with real Jarvis-backed widgets. Everything else Jarvis
  (terminal panes, notepad, voice) stays out of scope.
- **What Jarvis is** (from its brief, 2026-07-11): Python 3.13 **FastAPI**
  server on **port 8340**, SQLite storage. There is no separate calendar —
  "calendar" = tasks with due dates in one `tasks` table. REST API exists
  and is verified: `GET /api/health`, `GET /api/todo/lists`,
  `GET /api/todo/lists/{name}`, `GET /api/todo/calendar?start&end`, plus
  write endpoints (PATCH check-off etc.). **No auth, no push — polling only**
  (30 s is its own webapp's cadence). Jarvis runs on another machine
  (Windows now, a 24/7 Ubuntu server later) — widgets reach it over the
  network via a configurable `JARVIS_URL`.
- **What's expected of the widgets (the contract shape):**
  - **Read-only v1** over the three GET endpoints + the health probe,
    polling ~30 s; at most one write later (check-off) in v1.1.
  - **Theming from outside:** consume the 5 palette slots via `colors.env`
    or a template — never hardcode colors. (The jarvis side explicitly
    prefers option **(a): native GTK widgets in this repo over its REST
    API** — theming stays desktop-side, VM-safe, smallest contract.)
  - **Lifecycle-hardened:** killed/respawned on every theme switch, spawned
    unattended at login, must render instantly and degrade gracefully to a
    "JARVIS offline" state when the server is unreachable (which is the
    common case today — it's started by hand).
  - **Never call** anything outside `/api/health` + `/api/todo/*` — the
    same port exposes unauthenticated dangerous endpoints (server restart,
    Claude Code spawning, API-key writes) until Jarvis's later auth phase.
    Build the HTTP layer so a bearer token can be added in one place later.
- **Where it stands / what's next:** the jarvis brief is received and
  committed; distilling it into the living doc and drafting the v1
  interface contract is the next step. The architecture pick (GTK lean vs
  alternatives) and the brief's six open decisions — network topology for
  dev (NAT `10.0.2.2` vs bridged), write scope, poll interval, todo-list
  scope, calendar window size, future push channel — are **Sergi's calls,
  still open**. Nothing widget-side is built yet.
