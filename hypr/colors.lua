-- Hyprland colour shim (roadmap step 7).
--
-- No longer a static palette: this reads the ACTIVE palette from the theme/
-- source of truth and exposes it as the `M` table Hyprland's config expects
-- (so hyprland.lua's `require("colors")` keeps working unchanged). The active
-- palette name is theme/state/active-palette (defaulting to red-black when
-- absent); its colours live in theme/palettes/<name>.env. Hyprland hot-reloads
-- this file, so `set-theme` re-tinting the borders is automatic once the state
-- file changes.
--
-- Hex values are stored WITHOUT a leading "#" so they interpolate straight into
-- rgba(RRGGBBAA) strings — same convention as before the refactor.

local M = {}

local home = os.getenv("HOME") or ""
local theme = home .. "/.config/theme"
local DEFAULT = "red-black"

-- Active palette name (theme/state/active-palette); default red-black.
local function active_name()
    local f = io.open(theme .. "/state/active-palette", "r")
    if not f then return DEFAULT end
    local name = (f:read("l") or ""):gsub("%s+", "")
    f:close()
    if name == "" then return DEFAULT end
    return name
end

-- Parse theme/palettes/<name>.env into a {key = hex} table. Skips blank/comment
-- lines and strips inline "# ..." comments. Returns nil if the file is missing.
local function load_palette(name)
    local f = io.open(theme .. "/palettes/" .. name .. ".env", "r")
    if not f then return nil end
    local t = {}
    for line in f:lines() do
        local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if key then
            t[key] = value:gsub("%s*#.*$", "")   -- drop any inline comment
        end
    end
    f:close()
    return t
end

-- Active palette, falling back to red-black, then to hardcoded defaults — so a
-- broken state file or missing env can never leave Hyprland without a border.
local palette = load_palette(active_name()) or load_palette(DEFAULT) or {}

M.background    = palette.background    or "0d0d0d"
M.accent        = palette.accent        or "c8102e"
M.accent_bright = palette.accent_bright or "e8384f"
M.muted         = palette.muted         or "5a5a5a"
M.foreground    = palette.foreground    or "ffffff"

-- Builds a Hyprland rgba(RRGGBBAA) string from one of the hex values above
-- plus an optional alpha byte (0-255, defaults to fully opaque).
function M.rgba(hex, alpha)
    alpha = alpha or 255
    return string.format("rgba(%s%02x)", hex, alpha)
end

return M
