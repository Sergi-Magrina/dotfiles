# Phase 4 — Workspace assignments

Spec for a fresh Claude Code session. Roadmap step 4 in
[../CLAUDE.md](../CLAUDE.md). Decisions in the "Decisions" section below are
**settled with Sergi** — don't re-ask them.

## Goal
Pin apps to fixed workspaces by window **class**, so each app always opens
where it belongs, and make workspace-switching a clean macOS-style slide:

| WS | Purpose | What lands here |
|----|---------|-----------------|
| **1** | Empty desktop | nothing pinned — wallpaper + waybar only |
| **2** | File manager | **yazi** (in a dedicated foot window) |
| **3** | Browser | *placeholder rule only* — browser not chosen yet |
| **4** | General apps | Claude Desktop, VS Code, Spotify |
| **0** | Control Center | *reserved, left empty* — built in its own session (phase 6) |

> Note on "ws 0": the current keybind loop maps **Super+0 → internal workspace
> 10** (`i % 10`, i=10→key 0). So "workspace 0" colloquially = workspace 10.
> Phase 6 will pin the Control Center there; not a phase-4 concern, just don't
> lose it.

## The key idea — rules don't need the apps installed
A window rule that says "class `Spotify` → workspace 4" is **inert config**.
It does nothing until a window with class `Spotify` actually appears, then
routes it. So we can write **all** the routing rules now even though almost
none of the apps are installed yet (`pacman -Q` on 2026-07-06: no `code`,
`spotify`, `claude-desktop`, or any browser — only `foot`, `rofi`, `wofi`,
`swaybg`, and `yazi` is available in `extra` to install).

This decouples two things that don't have to happen together:
- **Building the routing layer** (this phase) — pure config, done now.
- **Installing the real apps** — incremental, one at a time, later. Each app
  slots into the rule already waiting for it.

### Simulating apps to test the rules (verified working)
We don't need to install Spotify to prove "class `Spotify` → ws 4" works.
`foot` can spoof any window class via `--app-id`:

```bash
foot --app-id=Spotify -e sleep 30   # a foot window whose class is "Spotify"
```

**Verified on 2026-07-06:** `hyprctl clients` shows `class: Spotify` /
`initialClass: Spotify` for that window — so `--app-id` genuinely sets the
class Hyprland matches on. This is the phase-4 test harness: zero installs.

> **Why Sergi's earlier test "did nothing":** running the simulation *before
> any rule exists* just opens a terminal on your current workspace — exactly
> like Super+Q. Nothing routes because there's no rule yet; the simulation
> only demonstrates routing **after** the rule is in `hyprland.lua`. That was
> expected, not a bug.
>
> **The `xdg-toplevel-icon` warning is harmless.** `foot` tries to set a
> window icon via the `xdg-toplevel-icon` protocol, which Hyprland 0.55.4
> doesn't implement, so it warns and skips it. It has nothing to do with
> app-id, routing, or workspaces. Ignore it.

## Scope — what this phase does NOT do (deferred, on purpose)
- **Choosing a browser (ws 3).** Its own session — real per-browser trade-offs
  (Firefox vs Chromium-based vs Vivaldi/qutebrowser: privacy, Wayland support,
  resource use). This phase only leaves a *placeholder* for ws 3. Do **not**
  pick a browser here.
- **Building the Control Center (ws 0).** Phase 6, its own session. This phase
  only *reserves* ws 0.
- **Theming Spotify / other apps.** Real but separate — Spicetify, now on the
  CLAUDE.md roadmap (step 8). Not part of getting routing working.
- **Installing the heavy apps** (Claude Desktop, VS Code, Spotify). They come
  in incrementally; the rules wait for them. (yazi is the exception — install
  it now, it's the ws-2 file manager.)

## Read first
- `CLAUDE.md` — project brief, working conventions, VM constraints.
- `hypr/hyprland.lua` — where the rules go. Existing window rules are near the
  bottom under `WINDOWS AND WORKSPACES` (~line 331); the `workspaces`
  animation leaves are ~line 177; the autostart block is ~line 58; the
  `fileManager` var is ~line 39 and the `Super+E` bind ~line 280.
- `/usr/share/hypr/stubs/hl.meta.lua` — ground-truth Lua API for this exact
  Hyprland (0.55.4). Confirms `hl.window_rule` takes `match` + rule keys.

## Hard constraints (from CLAUDE.md — do not relitigate)
- **Lua config, hot-reload.** Edit `hypr/hyprland.lua`; Hyprland reloads on
  save. Makes rule-testing a tight loop.
- **Symlink discipline.** Edit files in `~/dotfiles/`, never `~/.config/`.
- **One logical change per commit.** Suggested commits: (a) routing rules +
  yazi as file manager, (b) remove the autostart terminal, (c) slide
  animation. Keep them separate.
- **Claude can't `sudo`/`pacman`.** Sergi installs `yazi`
  (`sudo pacman -S yazi`). Everything else is config or simulation.
- **VM software rendering.** Judge *structure/correctness* here (does the
  window land on the right workspace? does the slide go the right direction?).
  Slide *smoothness* is a real-hardware judgment.
- **Never assume aesthetics** — but the phase-4 decisions below are already
  settled, so there's little left to ask.

## Decisions (settled with Sergi — do NOT re-ask)
1. **File manager = `yazi`.** A blazing-fast Rust **TUI** file manager (in
   `extra`, so a normal `pacman -S yazi`, no AUR). It runs inside a terminal,
   so it's fully VM-supported (no GPU needs, unlike a GUI FM), lighter than
   dolphin (no KDE/Qt deps), and themeable to red/black. **Routing wrinkle:** a
   TUI inherits `foot`'s class, so launch it with a dedicated app-id to give it
   its own routable class:
   ```
   foot --app-id=yazi yazi
   ```
   Set `local fileManager = "foot --app-id=yazi yazi"` and the ws-2 rule
   matches class `yazi`. `Super+E` already runs `fileManager`.
2. **Auto-routed apps FOLLOW the view.** When an app opens on its assigned
   workspace, the view switches there too — so **no `silent`** on the rules
   (plain `workspace = "N"`, not `"N silent"`).
3. **Unruled apps open on the current workspace.** This is Hyprland's default:
   any app without a rule appears on whatever workspace you're focused on. We
   keep that — it's the flexible, expected behavior for one-off/scratch windows.
   No catch-all workspace.
4. **No autostart terminal.** Remove `hl.exec_cmd(terminal)` from the
   `hyprland.start` block so ws 1 stays a truly empty desktop on login.
5. **Slide = macOS-style, horizontal, directional.** Content slides left/right
   depending on whether the target workspace is higher or lower than the
   current one — Hyprland's `slide` style does exactly this by workspace order.

## App class reference (best-guess — VERIFY each on first real launch)
`class` matching is a case-sensitive regex on the window's Wayland `app_id`
(native Wayland) or its X11 class (XWayland). **These differ**, so when each
real app first runs, read its actual class with
`hyprctl clients | grep -iE 'class|initialClass'` and lock the rule to it.

| App | Likely native `app_id` | Likely XWayland class | Notes |
|-----|------------------------|-----------------------|-------|
| yazi | `yazi` (we set it) | — | class is whatever we pass to `foot --app-id=` |
| VS Code | `code` | `Code` | usually XWayland → `Code` |
| Spotify | `spotify` | `Spotify` | usually XWayland → `Spotify` |
| Claude Desktop | `Claude` / `claude` | `claude` | Electron; class unknown until it runs — must verify |
| Browser | TBD | TBD | deferred to its own session |

## Window-rule shape (grounded in the existing file + the Lua stub)
The existing config already uses top-level rule keys like `move`, `float`,
`no_focus` (see `move-hyprland-run` at the bottom of `hyprland.lua`), and the
stub confirms `hl.window_rule` takes `match` + rule keys. Workspace assignment
follows the same pattern — no `silent` (apps follow):

```lua
-- Workspace routing. Inert until an app of the matching class launches, so
-- it's safe to define these before the apps are installed. Verify each class
-- against `hyprctl clients` when the real app first runs (app_id vs XWayland
-- class differ). No `silent` -> the view follows the app to its workspace.
-- ws 1 stays empty (no rule); ws 0 reserved for phase 6.

hl.window_rule({
    name  = "ws-files",
    match = { class = "^yazi$" },       -- we set this via foot --app-id=yazi
    workspace = "2",
})

hl.window_rule({
    name  = "ws-vscode",
    match = { class = "^(code|Code)$" },
    workspace = "4",
})

hl.window_rule({
    name  = "ws-spotify",
    match = { class = "^(spotify|Spotify)$" },
    workspace = "4",
})

hl.window_rule({
    name  = "ws-claude",
    match = { class = "(?i)^claude$" },
    workspace = "4",
})

-- ws 3 = browser: placeholder only, no browser chosen yet.
-- hl.window_rule({ name = "ws-browser", match = { class = "TODO-browser" }, workspace = "3" })
```

**Confirm on first hot-reload:** that placement is `workspace = "2"` (not a
nested form). Since we want *follow*, there's no `silent` to add. Hot-reload
makes this a 5-second check.

## Companion change — clean macOS-style slide
Right now (`hyprland.lua` ~line 177) the workspace animation leaves use
`style = "fade"`:
```lua
hl.animation({ leaf = "workspaces",    ... style = "fade" })
hl.animation({ leaf = "workspacesIn",  ... style = "fade" })
hl.animation({ leaf = "workspacesOut", ... style = "fade" })
```
Change `"fade"` → `"slide"` on those three leaves. Hyprland's `slide` slides
horizontally in the **direction of travel** (going to a higher workspace slides
one way, lower the other) — the macOS Spaces feel Sergi wants. Tune `speed` if
it's too fast/slow.

**VM caveat:** animations *run* under software rendering, so the slide will
function and its *direction/correctness* is verifiable here. **Smoothness**
(software rendering may be choppy) is a real-hardware call — set it now, confirm
direction here, defer the "does it feel silky" verdict to the showroom.

## Related but separate — customizing Spotify (do later, own task)
Now recorded on the CLAUDE.md roadmap (step 8): theme the Spotify **client**
via **Spicetify** (`spicetify-cli`) — injects custom CSS for a red/black look.
Needs Spotify installed and its ws-4 rule verified first; modifies the client's
own files (not a dotfile symlink). Its own focused session, after phase 4.

## Implementation steps
1. Sergi installs yazi: `sudo pacman -S yazi`.
2. Set `local fileManager = "foot --app-id=yazi yazi"` (~line 39). `Super+E`
   already runs it.
3. Add the workspace-routing `hl.window_rule` block (above) under
   `WINDOWS AND WORKSPACES`. Placeholder-comment ws 3; nothing for ws 0/1.
4. Verify by simulation from a *different* workspace:
   `foot --app-id=yazi -e sleep 20`, `--app-id=Code`, `--app-id=Spotify`,
   `--app-id=claude` — each should jump the view to its workspace. Check with
   `hyprctl clients`. Then launch real `yazi` via `Super+E` and confirm ws 2.
5. Commit: *"Route apps to workspaces by class; yazi as file manager"*.
6. Remove `hl.exec_cmd(terminal)` from the `hyprland.start` block (~line 59) so
   ws 1 is empty on login. Commit: *"Drop autostart terminal so ws 1 stays empty"*.
7. Change the three `workspaces*` animation leaves `"fade"` → `"slide"`, save,
   switch workspaces (`Super+1..4`) and confirm a clean directional slide.
   Commit: *"Slide workspace-switch animation instead of fade"*.

## Verify (don't skip)
- Each rule: `foot --app-id=<class>` from another workspace pulls the view to
  the assigned one. Screenshot a routed result — desktop-screenshot workflow is
  in this project's memory (`grim` via a borrowed `WAYLAND_DISPLAY`, no sudo).
- Real `yazi` (`Super+E`) opens on ws 2 and is usable in foot.
- ws 1 stays empty on login (no autostart terminal); ws 0 stays empty.
- Switching workspaces slides horizontally in the right direction (smoothness =
  real-hardware call).

## Done when
- Routing rules for ws 2 (yazi) and ws 4 apps are in `hyprland.lua`, verified
  by simulation; yazi installed and opening on ws 2 via `Super+E`.
- ws 3 has a reserved placeholder; ws 1 and ws 0 stay empty (no autostart term).
- Workspace switching slides (macOS-style) instead of fading, verified live.
- Committed in logical chunks (rules, autostart removal, animation).
- Browser choice, Control Center build, and Spotify theming remain untouched —
  each has its own future session.

---

## Kickoff prompt (paste into the new session)
```
Start phase 4 of the Hyprland rice — workspace assignments. Read CLAUDE.md and
docs/phase-4-workspace-assignments.md first, then work through that spec. The
decisions in the spec's "Decisions" section are already settled — don't re-ask.

Goal: window rules pinning apps to workspaces by class — yazi to ws 2 (launched
as `foot --app-id=yazi yazi`); Claude Desktop / VS Code / Spotify to ws 4; a
placeholder for the browser on ws 3; ws 1 and ws 0 empty. Apps FOLLOW the view
to their workspace (no `silent`). Also: remove the autostart terminal so ws 1
stays empty, and change the workspace-switch animation from fade to a clean
macOS-style horizontal slide.

Most apps aren't installed yet — fine, the rules are inert until a matching
class appears. Verify each rule WITHOUT installing by spoofing the class with
`foot --app-id=<class>` and checking `hyprctl clients`. I'll install yazi
myself (you can't sudo). Do NOT choose a browser, build the Control Center, or
start Spotify theming — each is its own session. One logical change per commit;
verify live with a screenshot.
```
