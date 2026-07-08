#!/usr/bin/env python3
"""Themed volume-slider popup for waybar (red / black palette).

A small gtk-layer-shell window that drops down just under the top bar and lets
you drag a slider to set the default sink's volume via `wpctl`. It's launched
(and re-clicked to close) by volume-slider-toggle.sh, which passes the click's
x-coordinate as argv[1] so the popup opens centred under the volume icon.

Dismiss: press Esc, click the icon again, or — once you've clicked into the
popup — click anywhere else (focus-out).

Palette mirrors hypr/colors.lua; keep in sync by hand until the roadmap step 7
palette-templating lands. GTK renders via cairo (software), so unlike the
GL-only tools this works inside the VM.
"""
import sys
import subprocess

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GtkLayerShell  # noqa: E402

SINK = "@DEFAULT_AUDIO_SINK@"
WIDTH = 240          # popup width in px; used to centre it under the click
MAX_VOL = 1.0        # cap the slider at 100 %

# Palette (hypr/colors.lua)
BG = "#0d0d0d"
RED = "#c8102e"
RED_BRIGHT = "#e8384f"
GRAY = "#5a5a5a"

CSS = f"""
window {{ background-color: {BG}; border: 1px solid {RED}; }}
label {{ color: {RED}; }}
scale {{ padding: 0 2px; }}
scale trough {{
    background-color: {GRAY};
    min-height: 5px;
    border: none;
    border-radius: 3px;
}}
scale highlight {{ background-color: {RED}; border-radius: 3px; }}
scale slider {{
    background-color: {RED_BRIGHT};
    border: none;
    border-radius: 50%;
    min-width: 14px;
    min-height: 14px;
    margin: -6px;   /* let the knob overhang the thin trough */
}}
""".encode()


def get_volume():
    """Current sink volume as 0.0–1.0 (0 on any error)."""
    try:
        out = subprocess.check_output(
            ["wpctl", "get-volume", SINK], stderr=subprocess.DEVNULL
        ).decode()
        return float(out.split()[1])
    except Exception:
        return 0.0


def set_volume(frac):
    subprocess.run(
        ["wpctl", "set-volume", SINK, f"{frac:.2f}"],
        stderr=subprocess.DEVNULL,
    )


class VolumeSlider(Gtk.Window):
    def __init__(self, click_x):
        super().__init__()
        self._armed = False  # only close on focus-out after we've been focused

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 24)  # just below the 22px bar
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.LEFT, self._left_for(click_x))

        self.set_size_request(WIDTH, -1)

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        box.set_margin_start(10)
        box.set_margin_end(10)
        self.add(box)

        icon = Gtk.Label()
        icon.set_markup(
            f"<span font_family='JetBrainsMono Nerd Font' size='large'>{chr(0xF028)}</span>"
        )
        box.pack_start(icon, False, False, 0)

        adj = Gtk.Adjustment(
            value=get_volume() * 100,
            lower=0,
            upper=MAX_VOL * 100,
            step_increment=5,
            page_increment=10,
        )
        self.scale = Gtk.Scale(
            orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj
        )
        self.scale.set_draw_value(False)
        self.scale.set_hexpand(True)
        self.scale.connect("value-changed", self._on_change)
        box.pack_start(self.scale, True, True, 0)

        self.connect("key-press-event", self._on_key)
        self.connect("focus-in-event", self._on_focus_in)
        self.connect("focus-out-event", self._on_focus_out)

        self._apply_css()

    def _left_for(self, click_x):
        """Left margin that centres the popup under click_x, clamped on-screen."""
        try:
            display = Gdk.Display.get_default()
            monitor = display.get_monitor_at_point(click_x, 0) or display.get_monitor(0)
            screen_w = monitor.get_geometry().width
        except Exception:
            screen_w = 1920
        return max(0, min(click_x - WIDTH // 2, screen_w - WIDTH))

    def _apply_css(self):
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def _on_change(self, scale):
        set_volume(scale.get_value() / 100.0)

    def _on_key(self, _widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.close()
        return False

    def _on_focus_in(self, *_):
        self._armed = True
        return False

    def _on_focus_out(self, *_):
        if self._armed:
            self.close()
        return False


def main():
    click_x = 0
    if len(sys.argv) > 1:
        try:
            click_x = int(sys.argv[1])
        except ValueError:
            click_x = 0

    win = VolumeSlider(click_x)
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
