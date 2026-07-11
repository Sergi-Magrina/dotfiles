# Jarvis integration — living coordination doc

> **Status: slice 1 (calendar + todo) — waiting on the first jarvis brief.**
> Last updated 2026-07-11.
>
> This document **will churn** — Jarvis is a moving target and the interface
> will be renegotiated as both sides grow. The body of this doc is *current
> truth only*; history lives in the changelog at the bottom. When something
> here contradicts an older phase doc, this doc wins for integration matters.

## What this is

Two Claude Code sessions are building this together and **cannot see each
other's files**:

- **Desktop session** — this repo (`~/dotfiles`). Owns panel geometry,
  launch/lifecycle, theming, and any widget code that lives here.
- **Jarvis session** — the jarvis repo (a separate machine/checkout; it is
  *not* on this VM). Owns Jarvis's data, APIs, and app code.

**Sergi is the courier**: documents are relayed by pasting between sessions.
This doc is the desktop side's single source of truth for the integration —
the fixed desktop contract, the open questions, and decisions as they land.

**Slice 1** (called for directly on 2026-07-11): fill the `cc-calendar` and
`cc-todo` Control Center placeholders with real Jarvis-backed widgets. This
deliberately lifts the "gated on Jarvis" block that
[phase-8-control-center-widgets.md](phase-8-control-center-widgets.md) placed
on those two panels. Everything else Jarvis stays gated (see Scope).

## Scope

**In (slice 1):**
- Calendar widget in the `cc-calendar` panel.
- Todo-list widget in the `cc-todo` panel.

**Still out — do not build, unchanged from CLAUDE.md step 8:**
- The two Jarvis-fed terminal panes (live actions; memory/context retrieval).
- The Jarvis-linked notepad (Control Center layout item, tool TBD).
- The centre-left "other jarvis (TBD)" zone (undesigned — stays empty).
- Voice / anything inside Jarvis's own codebase (this repo only *wires*).

## The desktop-side contract (fixed — the jarvis side designs against this)

### Panels
Floating, always-on, glanceable panels on the Control Center workspace
(ws 0). Sizes are fractions of the monitor
([../hypr/hyprland.lua](../hypr/hyprland.lua) `cc-*` rules):

| Panel | app-id | Size (w × h) | ≈ px at 1080p | ≈ px in the VM today |
|---|---|---|---|---|
| calendar | `cc-calendar` | 26% × 34% | 499 × 367 | 285 × 201 |
| todo list | `cc-todo` | 16% × 34% | 307 × 367 | 175 × 201 |

These are **small dashboard tiles, not full apps** — a month-at-a-glance /
upcoming-events view and a short task list, readable at those sizes. (Split
re-set 2026-07-11: calendar wider than todo at ~1.6:1, same height.)

### Launch & lifecycle
- Everything on ws 0 is spawned at login by
  [../hypr/scripts/control-center.sh](../hypr/scripts/control-center.sh). A
  real widget replaces the `place cc-…` placeholder line, **keeping the same
  app-id** so the phase-6 float rule keeps matching (a GUI toolkit that sets
  its own class either adopts the `cc-*` app-id — precedent:
  [../hypr/scripts/cc-music.py](../hypr/scripts/cc-music.py) via
  `GLib.set_prgname` — or the rule's `match` gets repointed; verify live).
- **Widgets get killed and respawned on every theme switch**
  (`theme/set-theme.sh`). They must start fast and hold no precious state.
- They run **unattended from login** — no interactive auth at spawn, and they
  must degrade gracefully (placeholder state, retry) when Jarvis is
  unreachable (login races, network down, Jarvis not running).

### Theming (non-negotiable)
Every colored surface consumes the phase-7 palette — 5 slots:
`background`, `accent`, `accent_bright`, `muted`, `foreground` (+
`foot_alpha`). Two established styles, no third:
- **Runtime-read**: source/read `theme/colors.env` (`KEY='#hex'`) at launch.
- **Templated**: a `theme/templates/*.in` rendered by `theme/gen.py`.

If Jarvis ever *serves* UI for these panels, it must accept those colors from
outside (query params / CSS variables / a config it reads) — a hardcoded
Jarvis color scheme would break the desktop-wide hot-swap.

### Environment reality
- **VM now, hardware imminent**: the desktop currently runs in a VirtualBox
  VM with **software rendering**. Electron/GL-heavy apps don't run here
  (kitty/hyprpaper precedents — [../vm-substitutions.md](../vm-substitutions.md));
  **GTK-in-Python, TUIs in foot, and Firefox are proven**. Mechanisms get
  built and tested in the VM; final looks judged on hardware.
- **The jarvis repo is not on this machine.** Until deployment is decided,
  assume the desktop reaches Jarvis over the network *or* runs a local dev
  instance for development — this is open question 2 below.
- **Claude can't `sudo`/`pacman`** in either session's shell here — installs
  are Sergi's actions.

## Open questions (waiting on the jarvis brief)

Numbered to match the kickoff prompt (appendix). Answers get distilled back
into this doc; the raw brief is saved verbatim as `docs/jarvis-brief.md`.

1. What Jarvis *is* today — stack, components, what runs vs planned.
2. **Where Jarvis runs at desktop runtime** (same box / server / both) and
   the offline story. Shapes everything else.
3. Calendar data: exists? storage, event schema, external sync?
4. Todo data: same.
5. API surface for events + tasks (endpoints, payloads, auth, port).
6. Change notification: poll vs push, what works today.
7. Who renders the UI — native widget here vs Jarvis-served views (and how a
   served view would take the palette).
8. Dev-mode quickstart + seed data, so widgets can be built against something
   real inside the VM.
9. Read-only v1 or interactive (check off todos, add events)?
10. What's unstable on the jarvis side; decisions the jarvis session needs.

## Architecture options (decide after the brief — Sergi's call, do not pre-build)

| Option | Shape | Precedent / risk |
|---|---|---|
| **(A) Native GTK widgets in this repo** over a Jarvis API | Python + GTK, `playerctl`-style data layer swapped for HTTP | Direct precedent: `cc-music.py`, `volume-slider.py` (palette-consuming GTK). VM-safe. Desktop owns look; Jarvis owns data. |
| **(B) Jarvis-served web views** embedded in browser windows | Jarvis ships compact pages; desktop opens dedicated browser windows on ws 0 | Phase-6 decision 3 leaned this way ("apps read a live DB behind the browser", FastAPI). But: per-window class/app-id control is poor in Firefox (would clash with the ws-3 rule), and Chromium/Electron is the VM-risky GPU class → leans real-hardware. Theming must cross the boundary. |
| **(C) TUIs in foot** | ncurses-style calendar/todo | Matches cava's pattern; weakest fit for a calendar grid + interaction. |

The brief's "recommended v1 contract" + question 7 answer feed this; then
Sergi picks. **(A)** is the desktop side's default lean for slice 1 because
it's VM-testable today and keeps theming trivially correct — but that's a
lean, not a decision.

## Coordination workflow (the loop)

1. Sergi pastes the **kickoff prompt** (appendix) into the jarvis session.
2. The jarvis session writes `docs/desktop-integration-brief.md` *in its
   repo* and prints it; Sergi relays it back here.
3. This session saves the relayed brief **verbatim** as
   `docs/jarvis-brief.md` (a replaceable snapshot), distills answers into
   this doc, and drafts the v1 interface contract as a new section here.
4. Contract changes go **through this doc first**, then get relayed — each
   repo treats the other's internals as opaque; only the contract is shared.
5. Every relay/decision gets a changelog line. When the brief goes stale,
   re-run the loop with an updated prompt asking only the deltas.

## Decisions log

- **2026-07-11** — Slice 1 scope = calendar + todo only; rest of Jarvis stays
  gated. Panel split re-set to ~1.6:1 (calendar 26%, todo 16%, both 34%
  tall) per Sergi + the vision sketch.
- *(v1 interface contract — pending the brief.)*

## Appendix — kickoff prompt for the jarvis session

Paste verbatim into a Claude Code session in the jarvis repo. Re-usable: for
later rounds, trim it to just the questions that changed.

```
I'm coordinating you with another Claude Code session that lives in my
Hyprland dotfiles repo (separate machine — you cannot see that repo and it
cannot see yours; I relay documents between you by pasting).

Desktop context you need: my Hyprland desktop has a "Control Center"
workspace of small floating always-on panels. Two reserved panels will be
Jarvis-powered: a CALENDAR (26% × 34% of the monitor, ≈500×370 px at 1080p)
and a TODO LIST (16% × 34%, ≈310×370 px) — small glanceable dashboard tiles,
not full apps. Constraints on anything that ends up on screen: (1) the
desktop has a runtime theme-switcher, so every visible surface must take its
colors from a 5-slot palette (background, accent, accent_bright, muted,
foreground) supplied from outside — no hardcoded color schemes; (2) widgets
are killed and respawned on theme switch and at login, run unattended (no
interactive auth at spawn), and must degrade gracefully if Jarvis is
unreachable; (3) the desktop currently runs in a VirtualBox VM with SOFTWARE
RENDERING — Electron/GL-heavy UIs don't work there; GTK-in-Python, terminal
UIs, and Firefox are proven. Real hardware comes soon, but v1 gets built and
tested in the VM.

Your job right now is INFORMATION ONLY — do not build or change anything.
Write a "desktop integration brief" at docs/desktop-integration-brief.md in
this repo AND print its full contents in chat so I can relay it. Answer from
the actual code — cite real files/paths — and mark anything that doesn't
exist yet explicitly as NOT BUILT or UNKNOWN instead of guessing. Cover:

1. Jarvis today: language/framework, major components, repo layout (top two
   levels), what actually runs today vs planned, how it's started.
2. Where Jarvis runs when my desktop is using it: same machine as the
   desktop, a server, or both? Host/port assumptions. What should the
   desktop do when Jarvis is unreachable?
3. Calendar data: does it exist yet? Storage (engine + file/DB location),
   schema/fields of an event, how it's read/written today, any external
   sync (Google Calendar / CalDAV) present or planned.
4. Todo data: same questions as 3.
5. API surface: existing or planned HTTP/WebSocket endpoints for events and
   tasks — method, path, example request/response JSON, auth story, port.
   If it's FastAPI, include the OpenAPI schema for those routes if it
   exists.
6. Change notification: how should a small always-on widget learn about
   updates — polling (what interval is safe), WebSocket/SSE, or watching a
   file? Distinguish what works TODAY from what's planned.
7. Frontend: does Jarvis serve (or plan to serve) its own web UI for
   calendar/todo? Given the panel sizes and constraints above, what does
   the jarvis side prefer: (a) the dotfiles repo builds native GTK widgets
   over your API, (b) Jarvis serves compact web views the desktop embeds,
   (c) something else? If (b), how would your UI accept the 5 palette
   colors from outside?
8. Dev-mode quickstart: exact commands to run Jarvis — or just its
   calendar/todo slice — locally with seed/sample data, so the widgets can
   be developed against something real inside the VM. Dependencies, ports,
   Python/runtime versions.
9. Read-only vs interactive: for widget v1, should the desktop be able to
   write (check off todos, add events) or display-only? What's safe to
   expose?
10. Stability: what's about to change on your side, what should the desktop
    NOT depend on yet, and any open decisions you need from me — list them
    explicitly.

End the brief with a "Recommended v1 contract" section: your suggested
minimal interface (concrete endpoints or file formats) for a read-only
calendar widget and todo widget, buildable against Jarvis exactly as it
exists today.
```

## Changelog

- **2026-07-11** — Doc created. Slice-1 scope set (calendar + todo);
  desktop-side contract written; kickoff prompt v1 drafted; calendar/todo
  panels re-split 26%/16% (same 34% height). Next: Sergi runs the prompt in
  the jarvis session and relays the brief back.
