-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


-----------------
---- COLORS -----
-----------------

local colors = require("colors")


---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "foot"
-- yazi is a TUI file manager: it inherits foot's window class, so give it a
-- dedicated app-id ("yazi") — that's the class the ws-2 routing rule matches.
local fileManager = "foot --app-id=yazi yazi"
local menu = "rofi -show drun"


-------------------
----AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
-- hl.on("hyprland.start", function () 
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
-- end)

hl.on("hyprland.start", function()
    -- No autostart terminal: ws 1 is a plain empty desktop (wallpaper +
    -- waybar only) on login. Open a terminal on demand with Super+Q.
    hl.exec_cmd("waybar")
    -- swaybg, not hyprpaper: hyprpaper needs a real GL/EGL context this
    -- VM's software-rendered GPU can't provide (same reason kitty crashes).
    -- swaybg renders fine under software rendering. Swap the image path
    -- when the custom red/black wallpaper replaces the interim solid.
    hl.exec_cmd("swaybg -i ~/.config/hypr/wallpapers/gargantua.jpg -m fill")
    -- Control Center (phase 6): spawn the ws-0 placeholder widgets on login.
    -- The cc-* rules float them onto ws 10 silently, so we stay on ws 1.
    -- Phase 8 replaces the placeholders inside this script (same app-ids).
    hl.exec_cmd("~/.config/hypr/scripts/control-center.sh")
    hl.exec_cmd("VBoxClient --clipboard")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            -- Every window gets the same red outline, focused or not —
            -- no dimming/graying out based on which one you last touched.
            active_border   = { colors = {colors.rgba(colors.red), colors.rgba(colors.red_bright)}, angle = 45 },
            inactive_border = { colors = {colors.rgba(colors.red), colors.rgba(colors.red_bright)}, angle = 45 },
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
-- Workspace switching slides horizontally in the direction of travel (higher
-- ws slides one way, lower the other) — a macOS-Spaces feel, not a cross-fade.
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Workspace routing (phase 4). Each rule is inert until a window of the
-- matching class launches, so it's safe to define them before the apps are
-- installed — the rule just waits. No `silent`, so the view FOLLOWS the app
-- to its workspace. Verify each class against `hyprctl clients` when the real
-- app first runs: a native-Wayland app_id and an XWayland class can differ.
--   ws 1 stays empty (no rule — plain desktop on login)
--   ws 2 = file manager (yazi)
--   ws 3 = browser (Firefox)
--   ws 4 = general apps (Claude Desktop, VS Code, Spotify)
--   ws 0 (internal 10) = Control Center — reserved, built in phase 6

hl.window_rule({
    name  = "ws-files",
    match = { class = "^yazi$" },       -- we set this via `foot --app-id=yazi`
    workspace = "2",
})

hl.window_rule({
    name  = "ws-vscode",
    match = { class = "^(code|Code)$" },   -- verify on first launch (likely XWayland `Code`)
    workspace = "4",
})

hl.window_rule({
    name  = "ws-spotify",
    match = { class = "^(spotify|Spotify)$" },   -- verify on first launch (likely XWayland `Spotify`)
    workspace = "4",
})

hl.window_rule({
    name  = "ws-claude",
    match = { class = "(?i)^claude$" },   -- Electron; class unknown until it runs — verify
    workspace = "4",
})

hl.window_rule({
    name  = "ws-browser",
    match = { class = "^firefox$" },   -- native Wayland app_id, verified via hyprctl (xwayland: 0)
    workspace = "3",
})

-- ─── Control Center (phase 6) ────────────────────────────────────────────────
-- Workspace 0 (internal 10; waybar relabels it "0") is a FLOATING dashboard —
-- the deliberate opposite of the dwindle tiling every other workspace uses.
-- Each widget is its own window with a unique `cc-*` app-id (set via
-- `foot --app-id=`); the rule floats it at a fixed fractional size/position (see
-- POSITIONING below) and drops it on ws 10 *silently* — so the login view stays
-- on ws 1, not ws 0.
--
-- Borders + rounding are INHERITED from the global general/decoration config
-- (red border, rounding 10), matching the "borders first" decision. To make a
-- panel borderless later, add `no_border = true` (and `rounding = 0`) to it.
--
-- PHASE-6 = frame only: every window here is a PLACEHOLDER foot terminal (see
-- scripts/control-center.sh). PHASE-8 swaps each launch command for the real
-- widget (cava; calendar/todo apps; Spotify now-playing) but keeps the same
-- `cc-*` app-id so these rules keep matching. The "other jarvis (TBD)" zone is
-- intentionally left EMPTY — raw wallpaper — until it's designed.
--
-- Sizes/positions are read off docs/Control Center vision.png; eyeball-tune
-- them live (structure is checkable in the VM; final sizing is a hardware call).
--
-- POSITIONING: written as `monitor_w*<frac> monitor_h*<frac>` rather than the
-- literal `30% 15%` the phase-6 spec drafted. On this Hyprland 0.55.4 build the
-- Lua size/move rules silently ignore `%` strings (the window kept foot's
-- default size), but the `monitor_w`/`monitor_h` arithmetic form — same idiom as
-- the move-hyprland-run rule above — applies correctly. It's equally
-- resolution-independent (fractions of the live monitor), so it survives the
-- move to real hardware without a rewrite, which is what decision 1 wanted.

hl.window_rule({
    name      = "cc-cava",                  -- bottom-left: audio visualizer
    match     = { class = "^cc-cava$" },
    float     = true,
    size      = "monitor_w*0.30 monitor_h*0.15",
    move      = "monitor_w*0.03 monitor_h*0.82",
    workspace = "10 silent",
})

hl.window_rule({
    name      = "cc-calendar",              -- upper middle-right: calendar (jarvis)
    match     = { class = "^cc-calendar$" },
    float     = true,
    size      = "monitor_w*0.20 monitor_h*0.34",
    move      = "monitor_w*0.56 monitor_h*0.06",
    workspace = "10 silent",
})

hl.window_rule({
    name      = "cc-todo",                  -- upper-right: todo list (jarvis)
    match     = { class = "^cc-todo$" },
    float     = true,
    size      = "monitor_w*0.22 monitor_h*0.34",
    move      = "monitor_w*0.77 monitor_h*0.06",
    workspace = "10 silent",
})

hl.window_rule({
    name      = "cc-music",                 -- bottom-right: Spotify now-playing
    match     = { class = "^cc-music$" },
    float     = true,
    size      = "monitor_w*0.31 monitor_h*0.33",
    move      = "monitor_w*0.66 monitor_h*0.60",
    workspace = "10 silent",
})
