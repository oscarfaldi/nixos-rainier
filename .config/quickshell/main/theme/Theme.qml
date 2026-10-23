import QtQuick

// The shell's colour + metric surface.
//
// COLOURS ARE NOT DEFINED HERE any more. They come from ThemeState, a singleton that reads the
// palette `theme-apply` writes into the state dir, so switching a theme changes every binding below
// at once with no rebuild. Components keep using `Theme { }` and `theme.accent` exactly as before.
//
// Metrics, fonts and motion stay here on purpose: they are layout, not theme. A theme switch must
// not move the bar or resize a dialog.
QtObject {
    id: root

    // ---------------------------------------------------------------- colours (live)

    readonly property color bg: ThemeState.bg
    readonly property color bgAlpha: ThemeState.bgAlpha
    // Popup/panel surface. Separate from `bg` so a palette whose background is near-black can
    // lift the menus without lightening every window (ThemeState falls back to `background`).
    readonly property color panel: ThemeState.panel
    readonly property color panelAlpha: ThemeState.panelAlpha
    readonly property color fg: ThemeState.fg
    readonly property color muted: ThemeState.muted
    readonly property color accent: ThemeState.accent
    readonly property color warning: ThemeState.warning
    readonly property color success: ThemeState.success

    readonly property string themeName: ThemeState.name

    // ---------------------------------------------------------------- text + layout (static)

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14
    readonly property int margins: 13
    readonly property int barHeight: 35

    // calibrated empirically, never derived: niri measures the exclusive zone
    // from the bar's own top edge and the visible gap also includes the window
    // shadow. Measured with grim: EZ 30 put the first window row at y=56, i.e.
    // only 8px below the bar bottom (y=48) while the top gap is 13px. 35 lifts
    // the window to a 13px gap, matching the top margin.
    readonly property int exclusiveZone: 35

    // popup panels: bar bottom (13 margin + 35 height = 48) + 12 (gap) from
    // the screen top, flush right via their own right margin. Do not add a
    // exclusive-zone offset here again: layers are screen-absolute, so the
    // old 108 value pushed the panels 48px further down than intended.
    readonly property int popupTop: 60

    // Motion. Omarchy does not animate its menu either - these are fade-only and short enough that
    // they never delay the first frame of input. Set animationsEnabled to false and every duration
    // collapses to 0, which is the reduce-motion switch Omarchy ships as `Style.duration()`.
    readonly property bool animationsEnabled: true
    readonly property int motion: 110

    function duration(ms) {
        return animationsEnabled ? ms : 0;
    }
}
