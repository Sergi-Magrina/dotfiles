# Desktop Integration Brief — JARVIS ↔ Hyprland Control Center

**Date:** 2026-07-11 · **Written for:** the Claude Code session in the Hyprland dotfiles repo
**Scope:** information only — describes JARVIS exactly as it exists at commit `9ebe7e9`.
Everything in §5 and §8 was **verified against a live run** today (isolated temp DB, real
server, real HTTP responses — pasted verbatim). Anything not built is marked **NOT BUILT**.

---

## 1. JARVIS today

- **Language/runtime:** Python 3.13 (repo venv is 3.13.7). Backend is **FastAPI + uvicorn**.
- **Major components:**
  - `server.py` (~4,000 lines) — the whole HTTP/WebSocket surface: REST endpoints, the
    `/ws/voice` WebSocket voice pipeline, TTS (Fish Audio), action-tag system, legacy brain.
  - `brain.py` — the default "brain": a Claude tool-use loop (Haiku 4.5) over the memory/tasks
    layer. Only relevant to the desktop insofar as voice commands mutate the same tasks table
    your widgets will read.
  - `memory.py` — all SQLite access: tasks, typed long-term memory, FTS5 search.
  - `frontend/` — Vite + TypeScript + Three.js audio-reactive orb (the voice UI). Served at `/`
    from `frontend/dist` when built; dev server on port 5173.
  - `todo.html` — a single-file mobile to-do webapp served at `/todo` (see §7).
  - Eval/dev loop: `backtest.py`, `eval.py`, `eval_cases.py` — not relevant to the desktop.
- **Repo layout (top two levels):**
  ```
  jarvis-main/
  ├── server.py, brain.py, memory.py, read_layer.py, memory_tools.py,
  │   reflection.py, trace.py, flags.py          # runtime path
  ├── actions.py, browser.py, screen.py, planner.py, work_mode.py,
  │   dispatch_registry.py                        # system actions / Claude Code spawning
  ├── backtest.py, eval.py, eval_cases.py, eval_judge.py, eval_runner.py,
  │   dev_report.py                               # test/eval harness
  ├── todo.html                                   # phone to-do webapp (served at /todo)
  ├── conversation.py, evolution.py, learning.py, monitor.py, qa.py,
  │   ab_testing.py, templates.py, tracking.py, suggestions.py   # inherited/legacy, mostly dormant
  ├── frontend/        # Vite+TS+Three.js orb UI (index.html, src/, dist/)
  ├── data/            # jarvis.db (SQLite, WAL), memory_trace.jsonl, flags.jsonl, eval_runs/
  ├── docs/            # plans/, specs/, specs/flags/
  ├── helpers/         # get_events.py — DEAD macOS AppleScript calendar fetcher (see §3)
  ├── desktop-overlay/ # DEAD legacy Swift macOS overlay
  └── tests/           # inherited tests
  ```
- **Runs today:** voice pipeline, REST API (health/todo/calendar/settings/outbox), `/todo`
  webapp, eval harness. **Planned (not built):** consolidator job, agentic tool-use phase,
  Ubuntu daemon deployment — see §10.
- **How it starts:** manually — `python server.py`. Defaults: host `0.0.0.0`, **port 8340**
  (`server.py:3971-3972`). HTTPS auto-enables if `cert.pem`/`key.pem` exist in the repo root
  (they do — a self-signed localhost cert), so a bare `python server.py` serves **https** with
  a self-signed cert; `--no-ssl` forces plain HTTP. There is no daemon/service wrapper today.

## 2. Where JARVIS runs relative to the desktop

- **Today:** the developer's Windows 11 machine, started by hand, not always running.
  **Eventually:** a 24/7 Ubuntu server (roadmap Phase 4, `docs/plans/2026-07-07-fable5-roadmap.md`).
  Either way it is **not on the desktop VM** — widgets reach it over the network.
- **Host/port assumptions:** `http(s)://<jarvis-host>:8340`. The server binds `0.0.0.0`, so it
  is LAN-reachable. From a VirtualBox VM: `10.0.2.2` reaches the host under NAT; under a
  bridged adapter use the host's LAN IP. **Make the base URL a widget config value** (e.g. a
  `JARVIS_URL` env var read at spawn) — the host will change when JARVIS moves to Ubuntu.
- **TLS:** assume plain HTTP for v1 (run the server with `--no-ssl`); the default self-signed
  cert would otherwise force cert-pinning/insecure flags into every widget.
- **When unreachable (this will be the common case — the server is manually started):**
  treat "connection refused/timeout" as a normal state, not an error. Recommended behavior:
  render the panel shell immediately at spawn, show last-known data from a small local cache
  file if you keep one (optional), display an unobtrusive "JARVIS offline" state, and keep
  polling `GET /api/health` (cheap, no side effects) with backoff (e.g. 15 s → 60 s). Never
  block widget spawn on JARVIS, never prompt for anything — there is no auth to prompt for.

## 3. Calendar data

- **There is no dedicated calendar/appointments store.** "Calendar" in JARVIS = **tasks that
  have a due date**. One SQLite table serves both panels.
- **Storage:** SQLite, `data/jarvis.db` (WAL mode), table `tasks` (`memory.py:105-118`).
  Redirectable via the `JARVIS_DB_PATH` env var (`memory.py:26`) — that's how tests isolate
  temp DBs, and how you can run a sandbox instance (§8).
- **Do not confuse it with the `events` table** (`memory.py:210`): that is typed *life-event
  memory* (free-text "content" with fuzzy date ranges, embeddings, supersession chains) used
  by the brain's memory system — it is **not** an appointments calendar and has no API.
- **How it's read/written today:** voice commands via the brain's tools (`add_task`,
  `list_tasks`, … in `brain.py`), the REST API (§5), the `/todo` webapp, and an "outbox"
  poll-relay for iPhone Shortcuts (`/api/outbox*`). The brain also gets a dated 10-day
  calendar rendered into its prompt (`brain.py:93`) — same table.
- **External sync:** **NOT BUILT.** No Google Calendar, no CalDAV, no iCal import/export —
  present nowhere in the code and absent from the roadmap. The only calendar-ish artifact is
  `helpers/get_events.py`, a macOS AppleScript Apple-Calendar fetcher inherited from the
  original open-source project — it is **not imported by `server.py`** and is dead code
  (likely to be deleted in the cleanup phase). Plan on JARVIS tasks being the only event
  source for widget v1.

## 4. Todo data

- **Same table.** Full schema of a task row (`memory.py:105-118`):

  | field | type | notes |
  |---|---|---|
  | `id` | INTEGER | autoincrement PK |
  | `title` | TEXT | |
  | `description` | TEXT | usually `""` |
  | `priority` | TEXT | `high` / `medium` / `low` |
  | `status` | TEXT | `open` / `in_progress` / `done` / `cancelled` |
  | `due_date` | TEXT | ISO `YYYY-MM-DD`, `""`/NULL = undated (backlog) |
  | `due_time` | TEXT | `HH:MM` 24h, `""` = no time; only meaningful with a date |
  | `project` | TEXT | **= the list name**; `""` is folded into `General` on all read paths |
  | `tags` | TEXT | JSON array **as a string**, e.g. `"[]"` |
  | `notes` | TEXT | |
  | `created_at` | REAL | Unix epoch seconds (float) |
  | `completed_at` | REAL/NULL | epoch; set when status becomes `done` (also on cancel) |

- **Lists** are just distinct `project` values (`GET /api/todo/lists` aggregates them).
- **Deletes are soft:** `DELETE /api/todo/tasks/{id}` sets `status='cancelled'`.
- **Ordering** you'll receive: open-task reads sort by priority (high→low) then `due_date`;
  the calendar read sorts by date, then time (timeless last), then priority.
- The voice webapp/brain read paths were unified on 2026-07-08
  (`docs/specs/flags/2026-07-08-voice-webapp-task-list-parity.md`) — the widgets get the same
  view the voice brain reports, which the user cares about.

## 5. API surface (all EXISTING and verified live today)

FastAPI on port 8340. **Auth: none.** CORS: `*` (`server.py:2237-2243`). OpenAPI is
auto-served at `GET /openapi.json` and `GET /docs` while running — note the endpoints return
plain dicts, so the OpenAPI response schemas are empty (`{}`); the request bodies *are* typed
(`_TodoTaskCreate`, `_TodoTaskUpdate` at `server.py:3801-3813`). The shapes below are from a
real run against a seeded temp DB (2026-07-11).

**Read endpoints (what the widgets need):**

- `GET /api/health` → probe for reachability.
  ```json
  {"status":"online","name":"JARVIS","version":"0.1.0"}
  ```
- `GET /api/todo/lists` → all lists + open counts.
  ```json
  {"lists":[{"name":"General","count":2},{"name":"Home","count":1}]}
  ```
- `GET /api/todo/lists/{list_name}` → open/in-progress tasks of one list.
  ```json
  {"list":"General","tasks":[
    {"id":2,"title":"Renew passport","description":"","priority":"high","status":"open",
     "due_date":"2026-07-15","due_time":"","project":"General","tags":"[]","notes":"",
     "created_at":1783789840.65,"completed_at":null},
    {"id":3,"title":"Dentist appointment","description":"","priority":"medium","status":"open",
     "due_date":"2026-07-14","due_time":"16:30","project":"General","tags":"[]","notes":"",
     "created_at":1783789840.654,"completed_at":null}],"count":2}
  ```
- `GET /api/todo/calendar?start=YYYY-MM-DD&end=YYYY-MM-DD&include_done=false` → dated tasks
  grouped by day. Defaults: `start`=today, `end`=today+29 (`server.py:3880-3892`).
  ```json
  {"days":[
    {"date":"2026-07-14","tasks":[{"id":3,"title":"Dentist appointment", "...":"same task shape as above"}]},
    {"date":"2026-07-15","tasks":[{"id":2,"title":"Renew passport", "...":""}]}],
   "start":"2026-07-11","end":"2026-07-20"}
  ```
  Days with no tasks are omitted (render empty days yourself).
- `GET /api/todo/completed` → last 200 `done` tasks, newest first (subset of fields:
  `id,title,project,priority,completed_at,due_date`).

**Write endpoints (exist today; see §9 before using):**

- `POST /api/todo/lists/{list_name}` body `{"title":"...","priority":"medium","due_date":"","due_time":""}`
  → `{"id":5,"title":"...","list":"General","status":"created"}`
- `PATCH /api/todo/tasks/{task_id}` body: any of `title, priority, status, due_date, due_time, list`.
  Check-off = `{"status":"done"}` (server sets `completed_at`). Un-check = `{"status":"open"}`.
  → `{"id":3,"updated":["status"]}`
- `DELETE /api/todo/tasks/{task_id}` → soft-cancels.

**Gotchas:**

- `/api/tasks` (no `/todo/`) is a **different thing entirely** — it lists/spawns Claude Code
  build subprocesses (`server.py:2278-2309`). Never touch it from the desktop.
- The calendar query excludes rows with `project=''` (`memory.py:1003`). Since the 2026-07-08
  fix, new tasks default to a real list name, so in practice this is moot — but a task minted
  with an empty project by some legacy path won't appear on `/api/todo/calendar`.
- `tags` arrives as a JSON string, and `created_at`/`completed_at` are epoch floats.
- Unauthenticated **dangerous** endpoints exist on the same port: `POST /api/restart`
  (re-execs the server), `POST /api/tasks` (spawns a Claude Code process from a prompt),
  `POST /api/settings/keys` (writes API keys to `.env`). Consequence: the JARVIS port must
  stay LAN/tailnet-only; the desktop must simply never call anything outside `/api/health` +
  `/api/todo/*`.

## 6. Change notification

- **What works TODAY: polling.** That is the only mechanism. JARVIS's own `/todo` webapp
  polls every **30 s** (`todo.html:625-631`); the iPhone integration also polls. The reads are
  single-table SQLite queries on a local DB — polling both widget endpoints every **15–30 s**
  is entirely safe, and you can drop to 5 s without harm if you want snappier check-off echo.
- **WebSocket:** `/ws/voice` exists and does broadcast `{"type":"chat_log",...}` frames to
  connected clients (`server.py:893-903`), but **no task/calendar mutation events are ever
  broadcast**, and the socket is the voice-session protocol — it is not designed for passive
  widget subscribers. Don't build on it.
- **SSE:** **NOT BUILT.**
- **File watching:** not applicable — `data/jarvis.db` lives on the JARVIS host, not the
  desktop machine; and WAL mode makes mtime-watching unreliable anyway.
- **Planned:** nothing on the roadmap adds a push channel. If glance-latency ever matters, a
  tiny `GET /api/todo/version` (change counter) or SSE stream would be a feature request to
  JARVIS — happy to add one post-cleanup-phase, but **v1 should assume polling**.

## 7. Frontend: who builds the widget UI

What JARVIS serves today:

- `/` — the Three.js voice orb (WebGL): irrelevant and **unusable in a software-rendered VM**.
- `/todo` — `todo.html`, a 635-line single-file phone webapp. It works in Firefox and uses CSS
  custom properties internally (`--bg`, `--accent`, … at `todo.html:12-16`), but the values are
  **hardcoded** (dark purple theme), the layout is phone-portrait, and it's a full interactive
  app — not a 310×370 glanceable tile. There is **no external theming hook** today.
- A compact calendar view: **NOT BUILT** in any form.

**JARVIS-side preference: (a) — the dotfiles repo builds native GTK widgets over the REST
API.** Reasons, in order:

1. Your palette/theming problem disappears: GTK widgets take the 5 palette slots however your
   theme-switcher already delivers them; nothing on the JARVIS side needs to know about themes.
2. Software rendering: GTK-in-Python is proven in your VM; embedding browser views is not.
3. The contract shrinks to three GET endpoints (§11) that are already stable and verified —
   the desktop depends on nothing else while JARVIS goes through its cleanup/refactor phases.
4. The existing web view is the wrong shape for the panels anyway.

If you strongly prefer (b) embedded web views: the honest answer is JARVIS would need **new
compact views built for it** (NOT BUILT), and the natural palette mechanism would be query
params (`/widget/calendar?bg=%23112233&accent=...&fg=...`) mapped onto CSS custom properties —
trivial to implement on a page built for it, but it's new JARVIS-side work during a phase
where the repo is deliberately being *shrunk*. Not offered for v1.

## 8. Dev-mode quickstart (verified 2026-07-11 on the JARVIS repo)

The todo/calendar slice has **no API-key dependency** — verified: the server starts and serves
all `/api/todo/*` endpoints with `ANTHROPIC_API_KEY` and `FISH_API_KEY` empty (voice/TTS are
simply inert). Heavy deps (playwright, sentence-transformers, mss) are lazy-imported, but the
supported install is still the full requirements file.

```bash
# 1. Setup (Python 3.13 is what the repo runs; 3.11+ almost certainly fine — UNVERIFIED)
git clone <jarvis repo> && cd jarvis-main
python -m venv .venv && source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt    # fastapi, uvicorn, anthropic, httpx, pydantic, websockets,
                                   # playwright, pyyaml, mss, Pillow, numpy, sentence-transformers

# 2. Seed an ISOLATED sandbox DB (never point the seams at data/jarvis.db — that's live data)
export JARVIS_DB_PATH=/tmp/jarvis-widget-dev.db
export JARVIS_TRACE_PATH=/tmp/jarvis-widget-trace.jsonl
export JARVIS_FLAGS_PATH=/tmp/jarvis-widget-flags.jsonl
python - <<'EOF'
import memory   # importing memory auto-creates the schema in JARVIS_DB_PATH
memory.create_task('Water the plants', priority='low',    project='Home')
memory.create_task('Renew passport',   priority='high',   due_date='2026-07-15', project='General')
memory.create_task('Dentist appointment', priority='medium', due_date='2026-07-14', due_time='16:30', project='General')
print('seeded:', [t['title'] for t in memory.get_open_tasks()])
EOF

# 3. Run (same env vars still exported); plain HTTP, any port
python server.py --no-ssl --port 8340

# 4. Smoke test
curl http://localhost:8340/api/health
curl http://localhost:8340/api/todo/lists
curl "http://localhost:8340/api/todo/calendar?start=2026-07-11&end=2026-07-20"
```

Notes: the server refuses to start if the port is taken (`server.py:3978-3986`). Running the
whole repo inside your VM should work (pure Python + SQLite; Linux is the eventual target) but
is **UNVERIFIED on Linux** — during v1 development it's simpler to run JARVIS on the host and
point widgets at `http://10.0.2.2:8340` (NAT) or the host LAN IP (bridged). A mock is also
trivial: the three read endpoints above are static-JSON-shaped.

## 9. Read-only vs interactive for widget v1

- **Recommendation: read-only display for v1**, plus at most **one** write in v1.1: check-off
  (`PATCH /api/todo/tasks/{id}` with `{"status":"done"}`). It exists today, it's a soft state
  change, and it's reversible (`{"status":"open"}`). The voice brain tolerates concurrent
  writes fine — it's the same table everyone shares.
- Adding tasks/events from the widget: hold off. The endpoint exists, but input validation is
  thin (dates/times are trusted strings) and the small panels aren't a good capture surface
  anyway — capture is JARVIS's voice job.
- **Never expose from the desktop:** `POST /api/restart`, `POST /api/fix-self`,
  `POST /api/tasks` (spawns Claude Code), `POST /api/settings/*` (writes API keys),
  `/api/memory/*`. No auth separates them from the todo routes — discipline in the widget code
  and network scoping are the guardrails until JARVIS's Phase-4 auth work.

## 10. Stability — what's about to change, what not to depend on, open decisions

**About to change on the JARVIS side** (roadmap `docs/plans/2026-07-07-fable5-roadmap.md`):

1. **Phase 1 cleanup (imminent):** dead modules get deleted (`helpers/`, `desktop-overlay/`,
   inherited legacy modules). The `/api/todo/*` routes and the `tasks` schema are *not*
   cleanup targets — they were actively fixed as recently as 2026-07-08.
2. **Phase 3 agentic:** the legacy `[ACTION:*]` tag system is slated for retirement; brain
   internals will churn. Doesn't touch the REST contract.
3. **Phase 4 Ubuntu:** host changes, a daemon wrapper appears, and **auth/permissions work is
   explicitly deferred to this phase** — i.e., no auth will appear before then (simple for v1),
   and an auth header will likely be required *after* it. Build the widget's HTTP layer so a
   bearer token can be added in one place later.

**Do NOT depend on:** the `/ws/voice` protocol; `todo.html` markup or its URL; `/api/tasks`
(the Claude Code one); the legacy `memories` table or the memory `events` table; HTTPS being
off (make the scheme part of the configured base URL); the server being up at widget spawn.

**Open decisions I need from you (the desktop side):**

1. **Network topology for v1 dev:** NAT (`10.0.2.2`) or bridged (host LAN IP)? Pick one so the
   default `JARVIS_URL` in the widget config is real.
2. **v1 write scope:** pure read-only, or read-only + check-off? (My vote: read-only first.)
3. **Poll interval:** is 20–30 s fresh enough for glanceable tiles? (Anything ≥5 s is safe.)
4. **Todo panel scope:** all lists interleaved, one pinned list (e.g. General), or a per-list
   cycle? The API supports any of these; it changes which endpoint you call.
5. **Calendar panel window:** how many days fits 500×370 — 7? 10? (`/api/todo/calendar` takes
   arbitrary ranges; the voice brain uses 10 days.)
6. **Push channel:** do you want me to plan a `/api/todo/version` counter or SSE stream after
   the cleanup phase, or is polling permanently fine for these panels?

## 11. Recommended v1 contract

**Read-only widgets over three GET endpoints + one probe, polling, no auth, palette entirely
desktop-side.** Buildable against JARVIS exactly as committed today.

```
Base URL:   JARVIS_URL (widget config, e.g. http://10.0.2.2:8340)  — scheme+host+port, no default hardcoded
Auth:       none (v1). Isolate to LAN/tailnet. Structure HTTP client so a token header can be added later.
Probe:      GET /api/health                     → 200 {"status":"online",...}  → widget is "live"
                                                  anything else / no answer    → widget is "offline", keep last data

CALENDAR panel (≈500×370):
  GET /api/todo/calendar?start=<today>&end=<today+9>
  → {"days":[{"date":"YYYY-MM-DD","tasks":[Task,...]},...]}   (days without tasks omitted)
  Render: date header + "HH:MM title" lines; due_time=="" → all-day/timeless, render last.
  Poll: every 30 s, plus once immediately at spawn.

TODO panel (≈310×370):
  GET /api/todo/lists                            → list names + counts (optional header row)
  GET /api/todo/lists/General                    → open tasks, already sorted priority→due date
  Render: title + small priority marker (map high/medium/low → accent/fg/muted from your palette).
  Poll: every 30 s, plus once immediately at spawn.

Task object (both panels):
  {id:int, title:str, description:str, priority:"high"|"medium"|"low",
   status:"open"|"in_progress"|"done"|"cancelled", due_date:"YYYY-MM-DD"|"",
   due_time:"HH:MM"|"", project:str, tags:json-string, notes:str,
   created_at:epoch-float, completed_at:epoch-float|null}

Offline behavior: render shell instantly, show "JARVIS offline" muted state, retry /api/health
with backoff (15s→60s), resume polling on first 200.

v1.1 (single opt-in write, after v1 is stable):
  PATCH /api/todo/tasks/{id}   body {"status":"done"}     → check off
  PATCH /api/todo/tasks/{id}   body {"status":"open"}     → undo
```

JARVIS-side commitments implied by this contract: the three GET routes and the task fields
listed above don't change shape without a version bump being communicated; any future auth
lands as an additive header requirement, not a route change.
