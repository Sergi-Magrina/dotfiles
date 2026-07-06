-- Shared color palette: red / black / gold theme.
-- Hex values are stored without a leading "#" so they can be
-- interpolated directly into Hyprland's rgba(RRGGBBAA) strings.

local M = {}

M.background = "0d0d0d" -- near-black background
M.red        = "c8102e" -- primary red, for text / interactive elements
M.red_bright = "e8384f" -- brighter red, for hover / active states
M.gold       = "d4af37" -- gold accent, used sparingly (borders, highlights)
M.gray       = "5a5a5a" -- muted gray, for inactive / disabled elements

-- Builds a Hyprland rgba(RRGGBBAA) string from one of the hex values
-- above plus an optional alpha byte (0-255, defaults to fully opaque).
function M.rgba(hex, alpha)
    alpha = alpha or 255
    return string.format("rgba(%s%02x)", hex, alpha)
end

return M
