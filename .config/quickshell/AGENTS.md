# AGENTS.md — Quickshell shell config

Quickshell desktop shell config for the Niri compositor, vendored inside the NixOS flake at
`~/System/.config/quickshell/`. It provides the bar, its popups, the notification daemon, the
application launcher, the lock screen and the audio/network/power panels.
Current focus: the bar and its popups. All of it runs live and is calibrated module by module.

## Aesthetic direction (owner's choice, treat as a hard constraint)

- Inspired by Omarchy: oldschool, flat, functional. **Square corners everywhere (radius 0)**,
  no rounded edges, no gratuitous animations, no candy/"pretty" look (explicitly NOT dankshell /
  noctalia / GNOME-modern).
- Colors follow the owner's gruvbox palette via `theme/Theme.qml` — do not import outside palettes.
- Simple text-driven modules that "just work". Deviations from this direction are a mistake even
  if they look better by modern standards.

## Hard rules

- Do NOT commit or push to any remote. These files live inside `~/System` (which has a GitHub
  origin); the owner personally controls commits/pushes until he declares the shell finished.
- In-code comments AND any commit messages must be 100% English.
- Announce intent and expected result before touching anything under `~/System`.
- Never claim a change works without actually running the shell and reading its error output
  (see Run and iterate). QML fails at runtime, not at "it looks right".
- `theme/Theme.qml` is the single source of visual truth. Never hardcode colors, fonts, or sizes
 elsewhere — use the `Theme` singleton. If a new token is needed, add it to Theme.

## Current status (update this section as things land)

- `quickshell` 0.3.2 installed via `modules/packages.nix`; shell is live on the desktop.
- Network module shows live state (wired = "eth" + icon, wifi = SSID, offline = red "offline"),
  opens the existing NetworkPopup on click. The popup hosts a self-contained WARP
  section (header + Status line + REGISTER/DISCONNECT/ENABLE button, warp-cli based;
  first use requires interactive 'warp-cli registration new' by the owner). The DNS
  section/options were fully removed by owner decision.
- Bar surface: background at 60% alpha, never fully opaque. QML colour hex is #AARRGGBB (alpha
  FIRST): "#99" + the palette background. A '#RRGGBBAA' string silently becomes the wrong colour
  (blue tint) at the wrong opacity. Left modules are separated by a single space after the glyph.
- NetworkPopup layout: sections top-to-bottom are NETWORK title, CONNECTIONS
  (device cards), WARP, DETAILS. When inserting sections into this ColumnLayout,
  search the DETAILS header FRESH at insertion time — never reuse a byte offset
  computed before earlier removals (that once injected a section inside DETAILS).
- DATE & TIME PANEL: one popup shared by two bar segments - the clock opens it on the
  calendar tab, the weather segment next to it opens the same panel on the weather tab,
  and the tabs inside switch between them (owner's design call: one dropdown, not two).
  One instance per screen, owned by `bar/Center.qml`. 805x370, CENTERED under the bar
  (`margins.left: (screen.width - width) / 2`, because both triggers sit in the middle of
  the bar), top at `theme.popupTop`. DATE tab: month grid (week numbers, prev/next month
  and year, TODAY in a footer under the grid - it used to dangle beside the year arrows and
  left a hole) + live clock + date + week/day-of-year + year progress. WEATHER tab: current
  temperature and condition, FEELS/WIND/HUMIDITY, 3-day forecast, and the city name is
  clickable to type a new one (Enter saves, Escape cancels).
  PLANNED: an alarm section in the right column, under the progress line, where space is
  already reserved.
- TABS ARE NOT A StackLayout. `StackLayout { currentIndex: ... }` crashed the whole shell
  with a segmentation fault inside `QQuickStackLayout::setCurrentIndex ->
  collectItemSizeHints` (Qt 6.11.2) the first time the owner switched to the weather tab -
  the layout re-measures children that the weather Repeaters keep rebuilding. The tabs are
  now two sibling Items toggled by `visible`, inside a plain Item. Long backtrace evidence
  lives in `~/.cache/quickshell/crashes/<id>/report.txt` ("Signal: Segmentation fault").
- WEATHER DATA: `services/Weather.qml` reads wttr.in's `j1` JSON - no API key, no account -
  every 15 minutes and on demand. The location is one line in
  `~/.local/state/quickshell/weather.txt`; an empty file means wttr.in picks the city from
  the public IP (measured: "Bawagempol" area, i.e. Jakarta, for this connection).
  `services/WeatherIcons.js` maps the 48 WWO codes to Nerd Font glyphs and is GENERATED
  from `~/omarchy-quattro/bin/omarchy-weather-icon` (day variant of each pair) - never
  hand-type those glyphs. A failed fetch keeps the last reading and raises `failed`.
- CALENDAR MATH: `services/CalendarMath.js` is pure JS - months 0-based, everything walked
  in UTC, fixed six-row grid so the panel never changes height, ISO week numbers. Year
  progress is 0% on January 1 and 100% on December 31 (measured 79% on 18 October 2026),
  so it resets itself when the year rolls over.
- BAR CENTER LAYOUT: the clock is anchored to the window's exact horizontalCenter and the
  weather segment is anchored to the clock's RIGHT EDGE. Never put both in one centered
  row - centering the row shifts the clock by half the weather width whenever the weather
  text changes length. Bar reads `Sunday, 18 October 2026 | 21:38 | <glyph> 29°`.
- POPUP SLOT: each popup claims its own size on show (`PopupManager.claimSlot(width,
  height)` at the instantiation site) and the click shield's pass-through region follows
  that claim, so there is no dead strip beside the smaller panels.
- BAR AND NOTIFICATIONS are both the shell. `~/System/.config/niri/config.kdl` spawns
  `qs -p /home/oscarfaldi/System/.config/quickshell/main`, and `services/Notifications.qml` claims
  `org.freedesktop.Notifications`. Nothing else draws a bar or owns the notification bus. The niri
  config is a Home Manager symlink, so changes reach the session only after a rebuild + niri start;
  a "the bar is missing" report starts there.
- Right group spacing is OPTICAL, not one RowLayout value: `spacing: 0` and each module carries
  its own `Layout.leftMargin`, because the glyphs have very different ink widths and side
  bearings (the speaker glyph is 16px of ink, the power circle has a negative left bearing), so
  an identical layout spacing reads as uneven gaps. Measured ink-to-ink gaps with grim:
  cpu->ram 21, ram->network 23, network->audio 22, audio->power 22, right clearance 24.
  RE-MEASURE after any change; do not trust the margins to produce equal visible gaps.
- SystemStats internal spacing stays 20 (cpu <-> memory, measured 21, owner-approved).
- Tray (`bar/modules/Tray.qml`): visibility comes from the FILTERED item list (`visibleItems`),
  not from the raw list, because the NetworkManager applet is filtered out by owner request.
  Counting the raw list kept the module `visible` with zero width while RowLayout still paid its
  left and right margins — that read as a 38px gap between audio and power instead of ~20px.
- power glyph rightPadding: 22 (24px measured clearance; owner is strongly OCD about bar
  alignment).
- HOVER AFFORDANCE: every clickable module signals itself before the click —
  `HoverHandler { cursorShape: Qt.PointingHandCursor }` plus
  `color: hover.hovered ? theme.accent : theme.fg`. Present on Network, Audio and SystemActions;
  tray items take the pointing cursor. The owner asked for this explicitly ("give me a sign that
  I am about to click this"), so a new clickable module without it is incomplete.
- POPUP SWITCHING: services/PopupManager.qml holds ONE active popup globally
  (activeName + activeScreen; 'network' | 'audio' | 'system'). One popup open on
  one screen closes the popup on the other screen (owner considers two live
  popups bad design). Modules bind `popupOpen: PopupManager.isOpen(root.screenName,
  '<name>')` with `screenName` derived from the QsWindow attached object, and
  taps call `PopupManager.toggle(root.screenName, '<name>')`. Bar.qml has a
  MouseArea under the modules closing THIS screen's popup on empty-bar clicks.
  Popup windows must NOT use grabFocus and must NOT be grabbing PopupWindows:
  grabs swallow the first bar click, which killed module switching.
- CLICK SHIELD (shell.qml): one full-screen transparent PanelWindow per screen,
  mapped ONLY while some popup is open (visible: PopupManager.activeName !== "").
  Its `mask: Region { intersection: Subtract; regions: [barStrip, panelSlot] }`
  makes the input region = full screen minus the bar strip minus the panel slot:
  clicks on the bar and on the popup panel pass through to them, ANY other click
  (desktop void, app windows, wallpaper) hits the shield's MouseArea and closes
  the popup via PopupManager.closeAll(). Mapping on demand keeps idle pointer
  behavior 100% stock niri (an always-mapped fullscreen top-layer surface eats
  every pointer event and breaks hover-focus). The shield is declared BEFORE the
  Bar in the delegate so it maps first (below the bar and the popup panel).
  PopupManager is GLOBAL-SINGLE: one popup across all screens (opening on one
  screen closes the other screen's popup) - closeAll() is the shield's action.
  Shield geometry must follow the bar geometry: `barStrip` height 50 (= margin 13 + bar height 35
  + 2px tolerance) so everything below the bar closes the popup, and `panelSlot.topMargin` must
  equal `theme.popupTop`.
- POPUP POSITION: `Theme.popupTop` = 60 = bar bottom (margins 13 + barHeight 35 = 48) + a 12px
  gap. Layer margins are SCREEN-absolute, so an exclusive-zone offset must never be added on top.
  Verified with grim: the panel's top border row is y=60 on both screens, 12px below the bar.
- POPUP SCREEN (fixed + verified): a popup window does NOT inherit the screen of the bar that
  creates it. With no `screen` binding Quickshell puts every popup on one default screen, so the
  DP-2 bar's popup painted on DP-1 (measured: accent border at columns 1007..1426 on DP-1).
  Fix: `screen: root.QsWindow.window ? root.QsWindow.window.screen : null` on the popup in
  `Audio.qml`, `Network.qml` and `SystemActions.qml`. The ternary is required — `QsWindow.window` is
  NULL while the file is being created, and an unguarded `root.QsWindow.window.screen` logs
  `TypeError: Cannot read property 'screen' of null` at creation (6 warnings per launch) before it
  settles. Same reason `screenName` reads "" at creation and is only correct once the bar window
  attaches: never key creation-time logic on it.
  `NetworkEditPopup` MUST NOT get a `screen` binding: an anchored PopupWindow takes its screen from
  the window it is anchored to, and Qt logs "Cannot set screen of popup window, as that is
  controlled by the parent window" and ignores the assignment.
  Verified by mapping the popups 5s after launch (popup created invisible, `visible` flipped by a
  Timer — the real click flow): the log shows "mapping popup on bar DP-1 popupScreen=DP-1" and
  "...bar DP-2 popupScreen=DP-2", and grim finds each panel flush right on its own screen
  (DP-1 cols 1007..1426, DP-2 cols 2127..2546, top border row 60 on both).
- Known cosmetic warnings (legacy popup files, unfixed): `Setting 'width'/'height' is deprecated.
  Set 'implicitWidth'/'implicitHeight' instead` — 16 per launch, from the legacy popups and the
  new DateTimePopup setting `width:`/`height:` on their PanelWindow root.
- POPUP SCREEN — TWO RULES, both learned the hard way:
  1. a popup needs `screen:` bound at its instantiation site (`screen: root.screen` from the
     module that owns it), or Quickshell maps it to whatever screen it picks by default;
  2. the popup QML file itself must NOT declare a `screen` property. PanelWindow already
     carries the layer-shell property that picks the output, and a QML declaration shadows
     it - the binding then looks perfect on the property (console.log printed DP-1 and DP-2
     per instance) while BOTH surfaces still mapped onto one monitor, and which monitor
     changed between runs. Symptom to recognise: identical panels stacked on one screen.
- `Quickshell.statePath`, `dataPath`, `cachePath` and `shellPath` are METHODS taking a
  relative path (`Quickshell.statePath("weather.txt")`), not properties. Used as a property
  they stringify into "function() { [native code] }" and the shell cheerfully writes to a
  file with that literal name in its working directory. This shell uses
  `Quickshell.env("HOME") + "/.local/state/quickshell/..."` instead, because statePath()
  additionally namespaces every path per shell root as
  `state/quickshell/by-shell/<hash>/`, which makes the file impossible to find by hand.
- Singletons are created on FIRST ACCESS. A test that only references the service at t+15s
  starts nothing before that moment (no fetch, no file read), so the measurement shows an
  empty service and looks like a bug. Touch it at startup - the bar's weather segment does -
  or the test is measuring the test.
- A vision model reading a dense screenshot is NOT reliable evidence: it reported the
  calendar month as NOVEMBER and the highlighted day as December 6 while the model state
  (logged) was viewMonth=9 and todayKey=2026-10-18 and the real grid was correct. Crop
  TIGHTLY around the element (a 420x240 crop at 220% read correctly) and trust the logged
  or pixel-measured values for anything numeric.
- NetworkPopup `noLink` scope error (fixed): `noLink` was declared on the card `Rectangle` but used
  unqualified inside its children (Text ~line 858, MouseArea ~line 878). QML resolves unqualified
  names only against the object itself and the component root — never an intermediate ancestor — so
  both bindings threw `ReferenceError: noLink is not defined` at load and the
  CONNECT/DISCONNECT/NO LINK button drew empty. The Rectangle now has `id: actionButton` and the
  children use `actionButton.noLink`. Watch for the same shape in legacy popup code.
- WARP status classification: 'Disconnected' CONTAINS the substring 'connected' —
  classify Disconnected BEFORE Connected or 'Off' reads as 'On'.
- WARP known issue (owner chose to skip for now): one-click ENABLE can require a
  second click when the daemon needs >4-5s to settle — the 4-round poll budget
  (~4.4s) expires while still Connecting, leaving status displayed as Connecting;
  fix later by extending polls (e.g. 12 rounds, unlock-as-soon-as-classified).
- POPUP VERIFICATION over ssh (works without a click): popups are plain non-grabbing PanelWindows,
  so copy the shell root to /tmp and drive them from there. Two recipes:
  (a) force a popup visible from one bar only: patch `visible: root.popupOpen` into a screen-name
  condition (e.g. `visible: root.QsWindow.window.screen.name === "DP-2"`);
  (b) the REAL click flow — leave the popup hidden at creation and flip its visibility from a Timer
  a few seconds later, then `console.log` the bar's `screenName` and the popup's `screen.name` at
  that moment. (b) is the one to trust for anything screen-related, because popups created at
  startup resolve their screen BEFORE the bar window attaches.
  Launch the copy with the session env, grim BOTH screens, then kill it and relaunch the real root.
  Detect a panel through its 2px accent border (#458588): a border column holds >=250 accent pixels
  in the top 420 rows, and the topmost border row is the panel's y position. Patch QML with python
  in BYTE mode — the files carry Nerd Font PUA glyphs that must never be decoded/re-encoded.
- Never put a command containing the literal `/quickshell -p` in the same ssh invocation as a
  reload script that runs `pkill -f "/quickshell -p"`: the remote shell's own cmdline matches the
  pattern and the pkill kills the ssh chain mid-run (exit 255, later steps silently never happen).
  Run the reload in its own ssh call.

## Directory map (shell root: `~/System/.config/quickshell/main/`)

- `shell.qml` — entry point. `Variants` over `Quickshell.screens`; each screen gets its own `Bar`
  plus the click shield.
- `bar/` — the bar. `Bar.qml` (PanelWindow; Left / Center / Right are anchored straight to the
  window and the clock to the window's exact horizontalCenter, so no layout spacer can shift it),
  `Left.qml` (user label + Workspaces), `Center.qml` (Clock), `Right.qml` (optical spacing),
  `modules/` (Audio, Clock, Network, SystemActions, SystemStats, Tray, Workspaces).
- `popups/` — top-right `PanelWindow` panels (Audio, DateTime, Network, NetworkEdit, System),
  NOT `PopupWindow`s: they are pinned to the screen edge with no input grab (see the popup rules
  above). Large legacy files adapted from the outfoxxed example config; keep edits minimal and
  localized. `DateTimePopup.qml` is hand-written (calendar + weather, two tabs) and is the one
  panel that needs keyboard focus, which it takes on demand only.
- `services/` — singletons (`pragma Singleton` + `Singleton {}`): NiriWorkspaces, SystemStats,
  PopupManager (single active popup, keyed by screen name, plus the payload and slot claim),
  Weather (wttr.in fetch + location state). Plain JS helpers live next to them:
  `CalendarMath.js` (calendar/year-progress math) and `WeatherIcons.js` (generated WWO code to
  glyph map). JS libraries are imported by relative path (`../services/CalendarMath.js`).
- `theme/` — `Theme.qml`: colors (gruvbox), font family/size, margins, barHeight, exclusiveZone,
  popupTop.

## Code conventions

- Import order: Quickshell modules (`Quickshell.*`), Qt modules (`QtQuick.*`), `qs.services`,
  relative imports (`"../theme"`, `"modules"`).
- `qs.services` resolves from the shell root (`quickshell/`). Relative imports are also used —
  match the file you are editing.
- Theme access pattern (required everywhere):
  `readonly property Theme theme: Theme {}` — reached via `import "../theme"` (or the correct
  relative path).
- Services are singletons declared with `pragma Singleton`; access as `qs.services.NiriWorkspaces`
  etc.
- Bar modules: plain `Item` roots that expose `implicitWidth`/`implicitHeight`, set
  `implicitHeight: theme.barHeight`, and take a `required property var screen` when
  screen-dependent (e.g. Workspaces filters by `output`).
- Use `Quickshell.execDetached([...])` for launching compositor/system actions.

## Networking API (verified against Quickshell 0.3.2)

- `Networking.devices.values` — array of devices. `device.type` compares to `DeviceType.Wifi` /
  `DeviceType.Wired` (import `Quickshell.Networking`).
- `device.connected`, `device.name` (interface), `device.hasLink`, `device.linkSpeed` (Mbps),
  `device.network` (wired connection name).
- Wifi: `device.networks.values` — each entry has `.connected`, `.ssid` (verify any other field
  against the running version before relying on it).
- `nmcli` is used by the legacy popup for detail fields (IP/gateway/DNS).

## Niri specifics

- Workspace data: the service polls `niri msg -j workspaces` every 500 ms into a JSON array. Each
  workspace object has (at least) `idx` and `output`.
- Compositor actions: `niri msg action focus-workspace <idx>` etc.
- Never assume a single screen. All bar code must be per-screen (plumb `screen` through).
- Exclusive zone: niri measures it from the bar's own top edge and the visible gap also includes
  the window shadow. Calibrated 2026-10-18 by screenshot: `exclusiveZone: 30` left only 8px below
  the bar (owner: "too tight"), `35` gives 13px, matching the 13px top margin. Never derive it on
  paper; adjust by the measured delta.

## Run and iterate

Shell root: `~/System/.config/quickshell/main` (no space in path).

```
qs -p ~/System/.config/quickshell/main
```

- Launching over ssh (test loop): qs needs the session env or it dies with
  "Failed to create wl_display" / workspaces parse errors:
  `XDG_RUNTIME_DIR=/run/user/1000`, `WAYLAND_DISPLAY=wayland-1`, `QT_QPA_PLATFORM=wayland`,
  `NIRI_SOCKET=$(ls /run/user/1000/niri.*.sock | head -1)`.
- Exactly ONE instance must run: kill with `pkill -f "/quickshell -p"` — note plain `pkill -x
  quickshell` does NOT match (process comm differs). Multiple stacked instances cause duplicated
  bars.
- Iteration loop: edit one file, relaunch, then READ the error/log output. Fix, relaunch, repeat.
- One concern at a time; do not bundle unrelated edits before a verify pass.
- Screenshot verify: `grim -o DP-1 /tmp/shot.png` with the same session env.
- If a module misbehaves visually, prefer relaunching and checking the log over reasoning from
  code alone.
- MEASURE, do not eyeball. Crop the top of a screenshot to a P6 PPM
  (`magick /tmp/shot.png -crop 2560x420+0+0 +repage /tmp/bar.ppm`), copy it back and parse it with
  plain Python (no PIL needed). The bar occupies rows 13..47. Scan ink (luminance > 170) ONLY
  inside x [13, width-13] and inside the bar rows: outside/behind the translucent bar the bright
  wallpaper passes the same threshold and produces phantom "modules" that read as clipped content.

## NixOS integration (~/System)

- The shell is vendored at `~/System/.config/quickshell/`; the flake at `~/System` is the source of
  truth. `quickshell` is installed via `modules/packages.nix` (Desktop Environment section).
- `rebuild` (bare command on the PC) performs a full rebuild + switch. It runs under sudo and
  requires the sudo password — never store the password in any file; obtain it interactively /
  ask the owner at run time. Over ssh, non-interactive sudo needs `SUDO_ASKPASS` (ask the owner).
- niri's `spawn-at-startup` carries the shell only; the shell is also the notification daemon.
  `libnotify` stays installed because `notify-send` is how `services/Notifier.qml` delivers the
  shell's own notifications.
- The power menu and the audio panel are reachable from the keyboard through
  `Mod+Shift+Q` / `Mod+Shift+V`, which spawn `.config/quickshell/scripts/qs-popup <power|audio|powermanagement|
  close>`; that script resolves the running instance by pid and calls the shell's
  `IpcHandler { target: "shell" }`, which opens the popup on the output niri reports as focused
  (`services/ScreenFocus.qml`). `qs ipc` cannot resolve a config outside the XDG dirs, which is
  why the pid lookup exists.

## Weather data & city search

- City type-ahead uses Photon: `https://photon.komoot.io/api/?q=<query>&limit=6&lang=en`
  Open-Meteo's geocoder is NOT usable for type-ahead: it answers `Jak` with Jakmel and
  `New` with Nnewi. Photon returns Jakarta / New York / New Jersey first.
- A picked suggestion is stored WITH its coordinates in the state file (one JSON line in
  `~/.local/state/quickshell/weather.txt`), so a name that exists in several countries
  cannot resolve to the wrong place. Free text typed without picking a suggestion stores
  the name only and lets wttr.in resolve it. A bare name (the older format) still reads.
- Debounce the search ~320 ms in the popup. One request per keystroke against a free
  community geocoder is not acceptable.
- wttr.in with coordinates (`https://wttr.in/40.71,-74.01?format=j1`) returns the same
  payload shape as with a name, so the parser is unchanged.
- Reading age, UV index and sunrise/sunset come from the same j1 payload
  (`current_condition[0].uvIndex`, `weather[0].astronomy[0]`); per-day rain chance is the
  day's max `chanceofrain`.

## Popup layout rules (learned the hard way)

- The panel is a FIXED 805x370. After any content change, verify nothing is clipped:
  screenshot, then scan for text bands and check the last band's bottom stays above the
  panel's bottom edge (y 430 on DP-2). Bands come from ImageMagick `ppm:-` + a luminance
  scan per row; a band below 430 is content the user will never see.
- Never push a column's content to the bottom with `Item { Layout.fillHeight: true }`.
  Short content leaves a hole in the middle and long content (a place detail line) pushes
  the last rows off the panel. Give the repeated rows `Layout.fillHeight` instead so they
  share the slack evenly.
- Date tab geometry (measured on DP-2, panel x 878..1682): content x 898..1662; the
  calendar half is a fixed 360-wide Item with the 320 grid centred inside it (20 px of air
  each side); the divider lands at x 1280 = the panel's midline; the clock column fills the
  rest. Day cells 42 px, week-number column 26 px, grid = 26 + 7*42 = 320.
- A column's own nav row/title must share the grid's width, otherwise the title centres
  over empty space and the grid reads as "condong ke kiri".

## Testing the panel over SSH

- Property defaults CANNOT force state for a test: `setTab()` runs when the panel opens and
  resets `editingCity`. To test the city editor, flip the property from a Timer that fires
  roughly 5 s after the panel is up, not in the property declaration.
- Turn a test copy at /tmp into the *only* thing on screen by copying the shell, forcing
  `bar/Center.qml` `visible: true` and `PopupManager.payload` to the tab you want, then
  `qs -p /tmp/<copy>/main`. Restore the real instance afterwards and confirm with
  `ps -eo cmd | grep -c "[q]uickshell -p"` that exactly 1 is alive.
- QML brace errors are fatal: the shell logs `Syntax error` plus a chain of
  `Type ... unavailable` and STAYS DOWN (it does not keep running with a broken panel).
  Count braces after every edit before pushing, and check the reload log for ERROR before
  reporting anything as done.

## Popup geometry (measured on DP-2: panel x 878..1682, y 60..430)

- Content box x 898..1662 (the shell Rectangle's 20 px margins), y 80..410. After the
  header (~26 px), the 1 px rule and two 12 px gaps, the tab host is 279 px tall. The
  bottom border's INNER edge is y 428, so text must end by y 410 to keep the 18 px
  clearance the owner asked for in the layout revision.
- Both tabs place the divider at x 1309: the left half is a fixed 389 px (54% of the
  720 px the two columns share) and the right column takes the remaining 331 px.
  Change one tab's half and change the other, or the divider jumps on tab switch.
- Calendar grid: 320 px wide (26 px week column + 7 x 42 px day cells) centred in its
  389 px half. The week rows take `Layout.fillHeight`, so the 34 px pitch and the 27 px
  clearance under the last row fall out of the tab height. Anchored to the top only,
  the grid was 296 px tall inside a 279 px host and the last week row hung past the
  content box.
- Year progress: the track is a fixed 224 px (`Layout.preferredWidth`), not fillWidth,
  with 8 px gaps to the "2026" label and the percentage.
- Weather left column: header block (icon + temperature + city on ONE line, then the
  condition and the place detail aligned to the temperature's left edge), a 1 px rule,
  then six metric rows capped by `Layout.maximumWidth: 260`. The cap is measured: the
  header block ends at x 1139, the values end at x 1153, the divider sits at 1309.
  Six metric rows share the leftover height (28 px pitch) and end 47 px above the
  content box.
- Forecast: three equal columns, day name at the top, then `Layout.topMargin`
  28 / 10 / 5 / 12 for icon, high, low, rain - the owner's 24-32 / 8-12 / 4-6 / 10-14 px
  targets expressed as layout gaps. No fillHeight spacers: the leftover height stays at
  the bottom of the column, reserved for the alarm.
- While the city editor is open the rule and the six metric rows are hidden: a search
  row plus a suggestion list plus six metric rows overflows the fixed 370 px panel.

## QtQuick Layouts traps

- A fillWidth ColumnLayout/RowLayout does NOT grow past its implicit maximum width,
  which comes from its widest child. The clock column capped itself at 292 px (its
  longest caption) and pushed the divider 22 px off; the fix is an explicit
  `Layout.maximumWidth: 100000`. Log `Layout.maximumWidth` before blaming the maths.
- Repeater delegates inside a layout accept `Layout.fillHeight` and split the leftover
  height evenly (calendar weeks, weather metrics) - the clean way to fill a column
  without a spacer item.
- Raising a `Layout.bottomMargin` inside a fillHeight column moves that item UP and
  re-balances every row: the weekday header went from 25/29 px gaps to 31/23.
- Verify geometry by ASKING QML, not by scanning pixels. The panel is translucent over
  the wallpaper, so a pixel scan reports phantom vertical lines and bogus "empty"
  regions. Add temporary `id`s, log `x + "/" + width` from a Timer, then remove the
  logging (see the pkill/restore pattern below).

## Revision 2 numbers (all measured on DP-2)

- The 320 px month grid is centred in the 389 px left half, so its left edge is x 933,
  NOT x 898: the air is 35 px on each side. Week-number column 26 px (933..959), day
  cells 42 px (959..1253). The nav row spans the same 320 px, so "the calendar area's
  centre" is x 1093 - do not assume the content box's left padding is the grid's edge.
- NavKey is a fixed 28 x 26 (implicitWidth/Height), so a pair is 28 + 6 + 28 = 62 px and
  the title's cell is symmetric about the grid: measured title centre 1092.5 vs grid
  centre 1093 (0.5 px off). Symmetry holds only while BOTH pairs are the same width.
- The title's visual (ink) centre sits 3 px above the digital clock's ink centre, which
  is a font-metric difference, not a layout bug. Reaching it needs `Layout.topMargin: 8`
  on the nav row, which leaves the header-rule -> buttons gap at 21 px. At topMargin 6
  the gap is exactly 18 px but the ink centres differ by 5 px - 8 px is the better trade.
- Weather left column: one 260 px container centred in the 389 px column (64/65 px of air
  per side, x 962..1222). The header group (icon + temperature + city + condition) is
  centred inside it with `Layout.alignment: Qt.AlignHCenter` on the header row, no spacer
  item. The metric rows use the container's full 260 px: labels left, values right
  (measured label at 964, value ends 1220).
- Forecast: the heading's cell and the three day columns ALL need `Layout.maximumWidth`
  raised. Without it a fillWidth Text shrinks to the text width and a fillWidth
  ColumnLayout stops at its widest child; the three days then bunched at the left at
  ~68 px each. With spacing 0 over 331 px the day centres land on 1/6, 1/2, 5/6 of the
  area (measured 1386/1495/1606 vs ideal 1387/1496/1606).
- The 1 px rule under "3-DAY FORECAST" is gone (owner's call): the panel already has the
  header rule and the column divider. The heading is fontSize-1 (13 px), Font.DemiBold,
  colour theme.fg.

## Visual gap vs layout gap

- The owner's spacing numbers are sometimes VISUAL (ink to ink) and sometimes layout
  gaps. The forecast rhythm is layout: `Layout.topMargin: 7` on the icon renders as a
  26 px visual gap (his 24-28 target) because the day Text's leading plus the icon
  glyph's internal padding add about 19 px. Always measure the rendered ink before
  deciding, and state which kind of gap the number is when reporting.
- Clock column layout gaps: clock -> date 16 px, date -> week 8 px, week -> year group
  20 px, year -> caption 8 px.
- After every popup change: brace count, then reload and check the log for ERROR, then
  measure the rendered ink. A QML syntax error takes the whole shell down
  (`Type Bar unavailable`), it does not degrade gracefully.

## TIMER module (rest countdown + one-shot alarm)

- State and clock live in `services/TimerService.qml` at SHELL level, not in the popup:
  the countdown keeps running with the panel closed and while the owner switches tabs,
  and every readout is derived from an absolute deadline (`cdEndAt`, `alarmTargetAt`),
  so a late UI tick cannot lose time. The popup block is only the interface.
- The finish / ring event fires exactly once because the state flips BEFORE the
  notification and the sound are sent (see `checkDeadlines`).
- Notifications go through `services/Notifier.qml` (`notify-send`, delivered by the shell's own
  daemon); sound goes through `services/SoundFx.qml` (`pw-play` with
  `~/System/assets/sounds/{positive,negative}.ogg`). Keep the two paths
  independent so either backend can be swapped for the native Quickshell notification
  service later without touching the timer logic.
- Persistence: `~/.local/state/quickshell/timer.json`, the same pattern as weather. A
  running countdown survives a reload with the right remaining time; an alarm that came
  due while the shell was down is shown as RINGING and notified once when the shell
  starts again. LIMIT: while the Quickshell process is stopped nothing can fire.
- An HH:MM that already passed today is scheduled for TOMORROW and the UI says
  `TOMORROW 07:30` - never a silent shift to the next day.
- RESET clears: `resetCountdown()` sets `cdInput` back to `00:00:00` and zeroes duration and
  remainder. It used to return to the last typed duration, which read as "reset does nothing"
  because the field kept the old value.
- Defaults are zero (`cdInput "00:00:00"`, `durationMs 0`, `cdFrozenMs 0`). A leftover duration in
  the field made the timer look stuck at a few seconds.
- The duration field is a LIVE BINDING (`text: TimerService.cdInput`). Two things used to break it,
  and both had to go: the one-shot `Component.onCompleted: text = ...`, and a `Connections` block
  that assigned `durationInput.text = TimerService.cdInput` on every change. **Any imperative
  assignment to `.text` destroys the binding permanently**, so after the first external change the
  field froze - a preset or RESET updated the service while the old number stayed on screen, which
  the owner reported as "reset goes back to 5 seconds". Verified end to end afterwards: preset ->
  field shows 00:03:00 with the 3:00 chip lit, RESET -> 00:00:00 with no chip lit.
- The alarm field edits a DRAFT; ENABLE ALARM commits it first (`root.commitAlarmDraft()` then
  `toggleAlarm()`) and refuses to arm while the field is invalid instead of arming the old time.
  DISABLE never commits. `commitAlarmDraft()` also re-reads `alarmInput.text` in case a paste or an
  IME skipped `onTextEdited`. Previously the button used the last committed time, so typing 07:45
  and pressing ENABLE armed the old 07:30 unless Enter was pressed first.

## Liveness and diagnosis

- The shell is a **systemd user service** (`home/quickshell.nix`), started by niri through
  `systemctl --user import-environment ... && systemctl --user start quickshell.service`. Niri is the
  only process holding `WAYLAND_DISPLAY`/`NIRI_SOCKET`, so the import is what makes the unit work;
  the spawn line falls back to running the shell directly if systemd refuses.
- `qs-check` is the first stop for anything that "stopped working": it walks the chain (process,
  env, pipe, reader, a real ping round trip, lock, PAM, swayidle, theme, recent errors) and exits
  non-zero when a check fails. `qs-check --fix` restarts the shell.
- Never `pkill -f "quickshell -p ..."` from a shell whose own command line contains that text: the
  pattern matches the command running it and kills the caller first. Use a bracket pattern
  (`quickshell/mai[n]`) or target the pid from `$XDG_RUNTIME_DIR/quickshell-shell.pid`.

## Command pipe (`qs-popup` -> shell)

- The FIFO reader (`pipeReader` in `main/shell.qml`) is the ONLY path from a keybind to the shell. It
  must restart itself (`onExited` -> Timer), because when it dies every shortcut goes silent while
  the bar still looks fine: `qs-popup` opens the FIFO read-write, writes, and exits 0.
- Never clean up pipes with a global `pkill -f` pattern. A second instance starting anywhere (even
  with its own `XDG_RUNTIME_DIR`, as a diagnostic run does) would kill the live shell's reader. Scope
  the cleanup to this runtime dir and to pipes whose owner pid is gone.
- The shell must be started with `NIRI_SOCKET` set (niri only sets it for its own children). Without
  it the bar still draws but workspaces log `Failed to parse niri workspaces` and every popup that
  resolves the focused output does nothing. Restarting the shell by hand from SSH means copying that
  variable: `NIRI_SOCKET=$XDG_RUNTIME_DIR/niri.<display>.<pid>.sock`.

## Notifications

- `services/Notifications.qml` is the daemon: a Quickshell `NotificationServer` that claims
  `org.freedesktop.Notifications`. Never run a second notification daemon beside it - whichever
  claims the name first wins, the loser logs "Could not register notification server" and then
  receives nothing.
- **THE critical line**: `notification.tracked = true` in `receive()`. The `notification` signal
  hands over an UNTRACKED notification, and an untracked one is discarded (its C++ object destroyed)
  as soon as the handler returns. Without that line every kept reference dangles: the card renders
  empty (all texts read as "") and the next D-Bus call SIGSEGVs the whole shell inside
  `DBusNotificationServer::qt_metacall`. So `recent` stores plain data via `snapshot()`, never
  Notification objects, and every close path detaches from `visible` BEFORE calling `dismiss()`.
- Advertised capabilities: body yes, actions yes, image yes; markup, hyperlinks, body images,
  inline reply and persistence NO. That is what makes clients send plain text, and the card also
  sets `textFormat: Text.PlainText` so a client's HTML cannot leak into the toast.
- Policy: normal 6 s / low 4 s (a sender may ask longer, capped at 30 s), hover pauses the timer,
  CRITICAL is sticky until clicked, at most 5 cards (a 6th retires the oldest - the owner raised
  this from 3 after living with it, and will drop it back if it gets annoying). No DND and no
  history on purpose; the newest 20 are kept in memory as plain data if recall is ever wanted.
- Sound: `SoundFx.play("positive")` for normal/low, `SoundFx.play("error")` (negative.ogg) for
  critical; skipped when `appName == "Quickshell"` because TimerService plays its own sample and
  two `pw-play` processes would cut each other off.
- `popups/NotificationToast.qml` is one window per screen, top-centre (`theme.popupTop`), 380 wide.
  Only the screen named by `Notifications.targetScreen` maps it (resolved from the focused output
  while the stack is empty), so a notification never shows twice on a two-monitor desk.
- The surface has a FIXED height (`stackHeight` 700, enough for five tall cards) plus `mask: Region { item: column }`. A
  surface that grows with its cards maps with a stale buffer and the tallest card (title + body +
  buttons) ends up invisible; the mask keeps the unused part click-through.
- `visible` must NOT depend on the layer surface's own `screen`: that property is only resolved
  while the surface is mapped, so gating `visible` on it is a binding loop ("Binding loop detected
  for property mine") and the card silently never appears. `shell.qml` passes `screenName` +
  `targetScreen` explicitly - same spirit as the "no `screen` property in a popup" rule.
- Icons: `notify-send -i firefox` arrives as `image://icon/firefox`, and that URL renders Qt's
  missing-texture placeholder when the icon theme has no such icon. Validate the name with
  `Quickshell.iconPath(name, true)` and fall back to the bell glyph; `Image.onStatusChanged` sets
  `iconFailed` as a second guard. Remote http(s) images are ignored on purpose (no surprise fetch).
- Card anatomy: app label (hidden for `notify-send` / `Quickshell` / empty - that is what removes
  the ugly source line), bold `theme.fontSize` summary, body ALSO at `theme.fontSize` in
  `secondaryText` (max 3 lines, elided). Same size as the title on purpose: hierarchy comes from
  weight and colour, and `fontSize - 2` read as too small on a real WhatsApp toast. Up to two action
  chips (the `default` action belongs to the whole card) at 32 px tall, 30 px of horizontal padding
  and a `theme.fontSize` label - the first draft at 24 px / 18 px was not readable at a glance.
  `x` on hover. Click = default action, otherwise dismiss.
- Chromium/Edge web notifications (WhatsApp Web, PWAs) arrive with a bogus `Settings` action that
  opens the site's notification permissions. `buttonActions` drops it by label OR identifier
  (`settings|setelan|pengaturan|preferences|options|more`), so a WhatsApp toast shows only the real
  action (`Reply`). The body of those notifications also carries the origin line
  (`web.whatsapp.com`); that comes from the sender and is left alone.
- `notify-send -A ...` (action notification) MUST be tested with `--wait`: without it the sender
  disconnects immediately, the server withdraws the notification and nothing is drawn - which looks
  exactly like a rendering bug.
- IPC: `qs-popup notifications` dismisses every card (`.config/quickshell/scripts/qs-popup` ->
  `IpcHandler.notifications()`), handy for a binding and used by the test scripts.
- Reload hygiene: `pkill -f "/quickshell -p"` does NOT match a nix-wrapped instance
  (`.quickshell-wrapped`), so a reload that uses only that pattern leaves the old shell alive: two
  bars, two notification servers, and the OLD one keeps the D-Bus name while IPC reaches it by pid.
  Always confirm `pgrep -c` is 1 after a reload; kill by `quickshell-wrapped` + `-x quickshell` +
  `-p <root>`.
- Testing over ssh needs `XDG_RUNTIME_DIR=/run/user/1000` and
  `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`, or the message never reaches the shell.
  Proof of ownership: `busctl --user status org.freedesktop.Notifications` reports the shell's pid,
  and the log shows `NOTIFY in: app=... urgency=... summary=...`.
- Verification that caught the real bugs: screenshot BOTH outputs and detect cards by their 1px
  theme border runs (#bdae93 normal, #cc241d critical) and #3c3836 fill, then pair the edges. A
  browser with a similar dark theme fools fill-colour scans and a single-screen screenshot misses a
  toast that legitimately went to the other output.

## Bar: countdown / alarm readout (modules/TimerIndicator.qml)

- Shows `| hourglass MM:SS` while a countdown runs (or is paused) and `| bell HH:MM` while an alarm
  is armed/ringing. Order of the centre line: `date | time | countdown | alarm | weather` - the
  readout sits DIRECTLY right of the clock and the weather stays the rightmost segment (so the
  weather shifts right while the readout is visible; the clock never moves). Both active = two
  pipes. Nothing at all when both are idle.
- Pipe spacing must match the existing separators: measured ink gaps around every pipe in that line
  are 12-13 px before and 11 px after. That comes from the cell padding (`text + 16`, so 8 px per
  side) plus the pipe glyph's own side bearing - do not "fix" it with an extra margin.
- Placement: `x: clock.x + clock.width`, and the weather anchors to `readout.right` (which equals
  `clock.right` while the readout has zero width, i.e. while nothing is active).
  `Center.implicitWidth` intentionally does NOT include the readout. Center's width is what
  keeps the clock dead centre, so a readout that appears must never widen the group - it overflows
  to the right and the clock does not move by a single pixel (verified: 0 differing pixels in the
  date/time area between an idle bar and one with both segments showing).
- Do NOT anchor it to `Center.right`: these bar items are zero-width with their rows centred on
  their anchor point, so `Center.right` lands in the middle of the weather label.
- Colour stays `theme.fg`; accent only on hover. A PAUSED countdown drops to `#bdae93`, so "paused"
  reads differently from "running" without a new colour. Both segments are click targets that open
  the CLOCK tab.
- Glyphs via `String.fromCodePoint`: hourglass `0xF254`, bell `0xF0F3`, calendar `0xF073`, clock
  `0xF017`. All verified present in the Nerd Font build this desktop uses; never write five-digit
  codepoints as `\uXXXX`.

## Bar: icons in the centre group (Clock.qml)

- Every text segment of the centre line carries an icon, for one visual language: calendar + date,
  clock + time, weather glyph + temperature, hourglass/bell + timer/alarm.
- Each cell is laid out with explicit anchors, not a Row: `8px padding, icon, 7px gap, text, 8px
  padding`, and the cell width is `8 + icon.implicitWidth + 7 + text.implicitWidth + 8`. Anchoring
  inside a positioner (`Row`) is not reliable, and the explicit width keeps the pipe between the
  date and the time on the bar's exact centre.

## Network panel (Network.qml, NetworkPopup.qml, NetworkEditPopup.qml)

- The bar label must answer "is there internet", not "is a cable plugged in". `healthy` is link
  state (`Networking.devices` has a connected device); `online` is `healthy && !netDown`. **The
  bug the owner reported** - cable plugged into a dead switch/ISP, bar still showing "Up" - was
  `netDown` being computed every 4 s and never read by `label`. Both texts and the icon colour now
  follow `online`.
- Reachability: `ping -c 1 -W 2 1.1.1.1` every 4 s, three consecutive failures = down (so ~12 s to
  flip). The timer only runs while a device is connected. `ping` is in the system profile; if that
  ever changes the probe fails closed and the bar says "Down", which is the safe direction.
- Icon keeps the DEVICE glyph while the link is up and only switches to the crossed-out glyph when
  the link itself is gone, so "cable fine, internet dead" is distinguishable from "no cable".
- The connection editor is NOT a window any more. `NetworkEditPopup.qml` was a `PopupWindow`
  anchored to the pencil glyph (a second floating window beside the panel); it is now a plain
  `Item` that `NetworkPopup` stretches with `anchors.fill: parent`. Its own first child draws
  `theme.bg` + 2 px accent, i.e. the same surface as the panel, so the swap reads as one page.
  Internals untouched on purpose - only the window properties (`width/height/color/grabFocus`,
  `anchor.*`, `anchorItem`) were removed, and `NetworkPopup` no longer passes `anchorItem`.
- Because the editor lives in the panel's layer surface, text fields need a focused surface:
  `WlrLayershell.keyboardFocus: editorOpen ? OnDemand : None`. The list view stays grab-free, so
  bar clicks keep working.

## Layer-shell surfaces are not windows (focus / close keys)

- The bar and every panel are `wlr-layer-shell` surfaces. niri does not list them as windows, so
  `close-window` never targets them: pressing the close-window key while a panel is open closes
  whatever real window is focused underneath (the owner closed a browser this way).
  There is no way to make a layer surface a window; the options are (a) a dedicated binding that
  runs `.config/quickshell/scripts/qs-popup close` (it calls `PopupManager.closeAll()`), or (b) Escape inside a
  panel that asked for keyboard focus (the editor does). Do not pretend `close-window` works here.

## Network panel: speed test (scripts/speedtest.sh)

- `speedtest.sh down|up [seconds]` prints ONE Mbps sample per second; `NetworkPopup` parses the
  lines with a `SplitParser` for the live value and keeps the average of the samples after the
  first second as the result. 8 s per direction, download first then upload, driven by one press.
- UI: ONE tachometer button (FA `0xF0E4`) in the section header, like a dashboard control - not a
  TEST DOWN / TEST UP pair. The press runs both legs (`speedBoth` carries the run from the download
  leg to the upload leg in `finishSpeedTest`).
- `popups/SpeedGauge.qml` draws each dial with `QtQuick.Shapes` + `PathAngleArc` (270 degrees, 0 deg
  at 3 o'clock, clockwise), a needle as a `PathLine`, and the number in the middle. `QtQuick.Shapes`
  is available in this Quickshell build. The arc/needle follow `fraction` through a 260 ms
  `Behavior`, so a live run moves smoothly instead of jumping between samples. Full scale is 1000
  Mbps: on a 1 Gbps line the needle reads as "how much of the link am I getting" (~430 down, ~520
  up measured).
- WARP is one line: the `Cloudflare WARP` title with a compact state chip right next to it (7x7
  square + CONNECTED / OFF / NOT REGISTERED / CONNECTING / DISCONNECTING), and the chip is the
  toggle. A full-width row of its own wasted the space; the state still reads at a glance.

## Cloudflare WARP: never trust one status reading

- `warp-cli status` run immediately after `warp-cli connect` still prints
  `Status update: Disconnected` for a moment; the tunnel only reports Connected a few hundred ms
  later. The original code read the status once after the command and only kept polling while it
  saw the word "Connecting", so a normal connect ended with status Off - the chip dropped back to
  OFF although the tunnel was already up, and the next press looked like it "worked the second
  time". That was the whole two-clicks bug: the first press did connect, the UI just lied.
- Correct shape: remember what was asked (`warpExpected`: "On" / "Off"), then poll `status` every
  700 ms (12 rounds, ~8 s) and stop only when the reported state EQUALS the expected one. Keep
  `warpBusy` true meanwhile and show CONNECTING / DISCONNECTING on the chip, so it can never look
  OFF while it is coming up.
- Parse order matters: "Disconnected" contains "connected", so test /Registration Missing|Unable/,
  then /Connecting/, then /Disconnected/, then /Connected/.
- Fresh install: status reports `Registration Missing` ("Not registered"). One press must run
  `registration new` and then `connect` in the same chain (`warpQueue`), not one step per press.
- Banner "Registration Missing" is checked before everything else, otherwise a not-registered
  daemon reads as Off and the press only runs `connect`, which fails silently in the UI.
- Method: ask `api.fast.com` for Netflix OCA URLs (`curl` + `jq`, both in the system profile, so no
  new packages), run 8 parallel curl workers, and measure what actually crosses
  `/sys/class/net/<iface>/statistics/{rx,tx}_bytes`. That measures the LINK, not what one TCP
  stream happens to get.
- The token is the public one from Omarchy's `omarchy-network-speedtest`. A typo in it makes the
  API return nothing and the panel shows the script's stderr - that is how the first version failed
  silently, so keep it exact.
- On this connection the API resolves to MyRepublic Indonesia OCA targets, i.e. a local node:
  measured ~420-540 Mbps down and ~400-800 Mbps up on the 1 Gbps link, which is the real line rate
  and confirms the test works from Indonesia.
- The panel height is 860 (was 650): connection list + WARP chip + details + the two dials. A fixed
  height that is too small slices the bottom row instead of scrolling.

## Audio panel layout

- One page, no tabs and no sub-menus: OUTPUT (device, volume, meter, device list) then INPUT (the
  same). The tab bar only ever existed to host the equalizer and left with it.
- Panel height follows the content: `height: Math.ceil(mainColumn.implicitHeight) + 40` (18 px
  margins + the 2 px frame), so there is no dead space at the bottom.
- Meters sit BELOW the volume slider in both sections, and the bar spans exactly the slider width
  (`reserveRight: 131` = percent 36 + mute chip 65 + two 15 px gaps).

## Equalizer: tried, rejected - do not rebuild it without new evidence

The owner's decision: a system-wide equalizer is not worth its cost on this stack (his use case is
neutral listening with an occasional bass boost). What was measured, so this is not relitigated:

- `libpipewire-module-filter-chain` (0 packages, the ideal path): the graph loads, the plugins wire
  up and audio routes through the node, but nothing is filtered. A 1 kHz `bq_lowpass` left a 5 kHz
  tone at full level, also with an explicit `config = { rate = 48000 }`. Inert in this PipeWire build.
- camilladsp (8 MB): the nixpkgs build is ALSA-only (`Built with features: websocket`; devices are
  Alsa/RawFile/WavFile/Stdin/SignalGenerator and `type: Pulse` is rejected), so it would need a
  package override plus a virtual sink plus a service - three moving parts we would own.
- EasyEffects (600 MB): the DSP works, but its socket only loads presets it already knows. A preset
  written to disk - even a byte copy of a known good one - is ignored, so a custom band editor
  cannot drive it.

If this ever comes back, first re-test the filter-chain DSP with a lowpass and a tone. If it still
passes audio untouched, none of the rest matters.

## Audio panel: real level meters (popups/AudioMeter.qml)

- Peaks come from `Quickshell.Services.Pipewire`'s `PwNodePeakMonitor` (`node`, `enabled`, `peak`,
  `peaks`), NOT from ffmpeg/parec/pactl. The shell is already a PipeWire client, so a meter costs
  one monitor timer and nothing else. `pw-cat | ffmpeg astats` was prototyped and works, but it
  spawns processes and needs pipeline cleanup - do not do that.
- `peak` is a LINEAR amplitude; the meter converts with `20 * log10(peak)` and maps -60..0 dBFS to
  0..1. Segments are coloured by their position on the scale (warning above -6 dB), so the danger
  zone is visible even when unlit. The number on the right is a peak HOLD (decays 5 dB / 800 ms),
  which is what answers "is my mic hot or quiet".
- `enabled` is bound to `active: root.visible`: peak monitoring runs a timer per node, so it must
  not stay on with the panel closed.
- Verified with a -10 dBFS 440 Hz tone played through pw-cat: the output meter lit ~20/26 segments,
  and the INPUT meter also read about -10 dB because the USB adapter's mic picked the tone up
  through the speakers - i.e. the input meter really is the microphone signal, not the playback.
- The panel grew 620 -> 690 for the two meters.

## Niri window border: 2 px

- The compositor border was 5 px while every shell surface is 2 px, which is exactly the mismatch
  that makes popups look thin next to windows. Niri's border is now `width 2` so windows and panels
  share one weight. (Omarchy avoids the question entirely: its Hyprland runs `border_size = 0` -
  no window borders at all - and only the 2 px shell frames show.)

## No residue rule (owner requirement)

This repo is staging-friendly but NOT scratch-friendly. Before calling any change done:

- No test hooks, probe files, temporary configs, screenshots or scratch scripts left behind - not in
  the repo, not in /tmp, not under ~/.local/state. Delete them in the same session that created them.
- No half-dead code: a file, property, log line or branch that no longer does anything must be
  removed, not left "in case". Owner audits this.
- No logging that fires per event (per notification, per sound, per click). Lifecycle logs once per
  start/restore are fine; per-event noise is not.
- Debug/helper scripts live in the agent workspace, never in the repo, and are removed at the end.
- `/tmp/reload.sh` is a development helper, not part of the system: it must be gone when the work is
  finished.

## Border widths: one standard, copied from Omarchy

Reference (omarchy-quattro): Hyprland windows use `border_size = 0`, and every shell surface is drawn
by QML. Their rule is two values - `Border.surfaceSpec(..., Math.max(1, Style.space(2)))` = 2 px for
surfaces and cards, `Style.normalBorderWidth` = 1 px for controls, with hover/focus widths defaulting
to the same value so a state change never alters geometry.

Apply the same here:

- 2 px: panel and toast frames (`ShellPopup`, `AudioPopup`, `NetworkPopup`, `NetworkEditPopup`,
  `PowerPopup`, `SystemPopup`, every `NotificationToast` card) and selected-state emphasis (the
  calendar's today/selected cell outline).
- 1 px: every control inside a surface - chips, buttons, fields, tabs, nav arrows, action chips.
- Hover / active / critical change the COLOUR only, never `border.width`. A `hovered ? 2 : 1` border
  shifts the contents by a pixel, which is what made the panels feel slightly off next to each other.
- A notification card is a surface, so normal and critical cards both have a 2 px frame; critical
  only swaps the colour (muted -> `#cc241d`). Measured on screen: all frames 2 px.

## WARP chip: 120 x 34, fixed

- `Layout.preferredWidth: 120`, `Layout.preferredHeight: 34`, content left-anchored
  (`leftMargin: 12`, dot 7, gap 6). It was 98 px first and that read as too short next to the
  section title, so it is pinned wider - and pinned means it never resizes between OFF / CHECKING /
  REGISTER / CONNECTED / WORKING.
- The WARP row carries `Layout.topMargin: 8` + `Layout.bottomMargin: 8`, otherwise the section reads
  as a thin strip even with a 34 px chip. Panel height is 850 to keep the dials from being clipped.

## WARP chip: one content edge

- The chip is pinned to `33 + TextMetrics.advanceWidth("CONNECTED")` (98 px measured). Every other
  label fits inside that: CHECKING / OFF / CONNECTED / REGISTER / WORKING. Sizing it to the longest
  possible word ("DISCONNECTING") left ~27 px of dead space; letting the width follow the label made
  it grow the moment it said CONNECTED. Busy states say WORKING rather than CONNECTING/DISCONNECTING
  so nothing overflows the pinned width.
- Right edge = the panel's content edge, i.e. the same x as the section separators and the
  connection card borders. The EDIT / DISCONNECT chips sit ~10 px further in because they live
  inside the card's own padding - do not align the WARP chip to them.
- Inside the chip: left padding 10, dot 7, gap 6-8, label, right padding 10-11. Measured 10 / 8 / 63
  / 11 on the live theme.

## Fresh install: one press registers AND connects - verified live

- `warp-cli --accept-tos registration delete` leaves `Status update: Unable / Reason: Registration
  Missing`, which the parser maps to "Not registered" and the chip shows REGISTER.
- One press then runs `registration new` and, from `warpQueue`, `connect` immediately after - the
  whole first-run flow needed a single click, ending Connected with a new Device ID. Registration is
  free and takes about a second, so this path can be tested for real (it does consume one of the
  free plan's device slots and issues a new identity).

## Escape closes a panel (popups/PopupKeys.qml)

- `PopupKeys` is dropped at the end of every popup: a `Shortcut` for Escape ->
  `PopupManager.closeAll()`. A `Shortcut` is used instead of `Keys.onEscapePressed` because a
  focused `TextInput` (the network editor) would otherwise keep the key.
- The other half lives in each popup's root: `WlrLayershell.keyboardFocus: visible ? Exclusive :
  None`. Without a focused surface the key goes to the app underneath.
- Consequence to keep in mind: while a panel is open, the keyboard belongs to the panel. That is
  the price of Escape working, and it is why the compositor's close-window key can never be used for
  panels (a layer surface is not a window - it would close the app behind it).

## Diagnostics with two monitors

- The bar builds one DateTimePopup per output, so a diagnostic Timer inside the popup
  runs once per screen - and a toggle in it calls the service twice, which cancels
  itself out (arm then disarm). Guard diagnostics with
  `root.QsWindow.window.screen.name === "DP-2"`.
- The popup is 805 x 390 since the TIMER module landed (was 370): the module plus the
  selected-day line needed 18 px more than the 279 px the clock column had. Content box
  y 80..430, border inner edge y 448 on DP-2.
- The weather footer keeps its 35-40 px clearance through `Layout.bottomMargin: 16`.
  Re-measure it after any height change.
- `niri msg` needs NIRI_SOCKET exported, otherwise it fails with "not running within
  niri" even though niri owns the session.

## Popup architecture: one popup, three tabs

- `popups/ShellPopup.qml` is the ONLY popup for the bar's centre group: one window, one
  fixed size (805 x 376), one header, and a tab strip (DATE / CLOCK / WEATHER) in the
  header's top-right. The content below the header swaps; the window never resizes, so
  switching tabs cannot move it under the pointer.
- Content lives in `popups/tabs/{DateTab,ClockTab,WeatherTab}.qml` as plain `Item`
  components. They own no window, no screen, no size and no header: the popup owns those.
- `services/PopupManager.qml` carries the state: `activeName`/`activeScreen` plus
  `payload` = which tab. The bar's three segments all call
  `PopupManager.toggle(screenName, "popup", "<tab>")`, so one segment opens its own tab,
  clicking the same segment again closes the popup, and clicking another segment switches
  tabs WITHOUT closing. The `|` separators stay inert (no handler, no hover, no colour
  change) and sit outside every click target.
- `TimerService`, `Notifier` and `SoundFx` are independent of this structure: the
  countdown/alarm keeps running while the popup (or just its tab) is hidden.

### Pitfalls that cost real debugging time

1. **Never redeclare `screen` on a popup `PanelWindow`.** Even `required property var
   screen` shadows the layer-shell `screen` from the C++ side: the surface loses its
   output and never maps. The popup stays invisible while its QML still lays out and its
   state reads `visible: true` (so it looks like a logic bug). The bar passes `screen:`
   at the instantiation site instead.
2. **Use `implicitWidth`/`implicitHeight`, not `width`/`height`, on a panel window whose
   content has no implicit size.** `width`/`height` are deprecated there; with them the
   window falls back to the content's implicit size, so a popup whose content is a
   layout with no size hint came out 320 px wide instead of 805.
3. **A Layout child cannot be positioned with anchors, and `Layout.alignment` on a
   fixed-width column was ignored in practice.** To centre a fixed-width block, wrap it
   in a plain `Item` and anchor the block to that wrapper's centre. That is the pattern
   the DATE tab now uses for its 320 px calendar grid.
4. **Tabs are toggled with `visible`, never a `StackLayout`** (segfaults on Qt 6.11.2).
5. **A tab must not drive itself from `PopupManager`.** The popup passes `activeTab`
   (`isOpen && tab === "..."`), and the tabs gate their internal timers on it. When only
   the PARENT hides, a child's own `visible` stays true and `onVisibleChanged` never
   fires, so visibility-driven resets silently stop working; `activeTab` also covers
   "popup closed", which is exactly when timers must stop.
6. **Measuring screenshots: match the accent border colour, not the panel background.**
   The panel bg (#3c3836) also appears in the wallpaper, so a bg-based bounding box
   reports the whole desktop; the accent (#458588) is unique to the border and gives the
   panel rect exactly (805 x 376 at x878..1682 on DP-2).
7. **Launching quickshell needs the full session environment** (`XDG_RUNTIME_DIR`,
   `WAYLAND_DISPLAY`, `QT_QPA_PLATFORM=wayland`, `NIRI_SOCKET`). Without it Qt aborts
   with "could not connect to display" and Quickshell logs a crash. `pkill` patterns must
   be bracketed (`[q]uickshell -p`) and the literal path must never appear in the same
   ssh command, or the pattern matches the ssh session itself and kills it.

### Verified layout numbers (fixed popup, content area 765 x 285)

- Date tab: calendar column needs 276 px, anchored centred at 320 px wide; the month
  title and the arrow pairs carry `leftMargin: 26` so they line up with the seven day
  columns (week column excluded), not with the whole grid.
- Clock tab: two columns of equal `preferredWidth` (a real 50:50); `colW=323/322`
  measured before the merge, 360/360 in the shared popup's wider content area.
- Weather tab: 389 + 22 + divider + 22 + 331 = 765 exactly, so the approved 54:46 split
  is preserved; the left column needs 264 px; metrics rows are CONDITION, FEELS LIKE,
  WIND, HUMIDITY, UV INDEX, SUNRISE, SUNSET; heading centre vs icon/temperature centre
  measured 0.5 px.

## CLOCK / COUNTDOWN / ALARM numbers (measured)

Measured from screenshots after the revision; panel top y=60, content top y=131, right
column x1331..1662.

- Clock digit ink top vs `TIMER` heading ink top: **0 px** (verified twice with narrow
  windows; both start their ink on the same row). The group lift `Layout.topMargin: -5` on
  the clock column stays. Do not move the TIMER heading.
- CLOCK ink gaps: **23 / 13 / 18 / 15** (clock->date, date->week, week->progress,
  progress->caption). Margins: -1 / -2 / +2 / -1.
- The countdown's status start x is FIXED: the running display carries the same
  `Layout.preferredWidth: 170` the duration field has, so the 112 px status slot begins at
  the same x in every state (measured: identical start x for READY, RUNNING and the
  alarm's ARMED). Never leave the display at its natural width - that is what made the
  status appear to move.
- The alarm's time input uses the same 170 px time column + 112 px status slot, so the
  alarm's status starts at the same x as the countdown's (verified: same start x).
- The alarm's TODAY/TOMORROW detail lives on its OWN row (a fixed `Layout.preferredHeight:
  20` Item) below the time+status row: it can be long, so keeping it out of the status row
  is what stops the row widening. The fixed height keeps the action below from jumping when
  the alarm is armed/disarmed.
- The alarm's action row is NOT forced onto the countdown's preset row (the extra detail
  row legitimately changes the shape) and is never bottom-anchored: it sits one column
  spacing below the alarm block with a comfortable gap (measured ~54 px below the time
  row), well clear of the popup's bottom border.

## Alarm time row geometry

Verified by reading the live QML geometry at runtime (mapToItem), not by pixel scans alone:
the alarm time row is left-packed at the right column's left edge (row x = column left,
width 311) with these boxes:

- Time column: an `Item` with **`Layout.preferredWidth: 70` AND `implicitWidth: 70`** holding
  the `TextInput` anchored left/right/verticalCenter. 70 px covers the 65 px HH:MM advance
  plus the cursor. **A bare TextInput in a Layout cannot be pinned**: it keeps its implicit
  width (measured ~110 px) and `Layout.maximumWidth` alone does not win, which pushed the
  status ~45 px too far right. The anchored-Item wrapper is the fix; pin the implicitWidth
  too, or the Layout falls back to it.
- Status: fixed 112 px slot, 20 px, left aligned, `Layout.leftMargin: 8` -> its ink starts
  ~20 px after the time text's right edge (idx: the ink ends ~13 px inside the 70 px column).
  Measured ink-to-ink gap: 20 px.
- Target detail: ALWAYS visible on the same row, `Layout.leftMargin: 11` after the status
  slot, 13 px muted cream - the armed `alarmTargetLabel`, or a live preview (`TODAY HH:MM` /
  `TOMORROW HH:MM`) computed from `alarmTime` while the alarm is off. The preview is
  display-only; the service is untouched.
- The rows fit the 331 px column in ONE row (time 70 + 8 + status 112 + 11 + detail ~110 =
  311), so no second row and the action button stays right below the block.
- The alarm's status start x is deliberately NOT the countdown's (the countdown has a 170 px
  time column); only the countdown's own status x must be stable across states.

## Measurement pitfalls (learned the hard way)

- `magick` exists on the PC, not in the Hermes container: run pixel measurements via ssh.
- A pixel window that starts to the right of a glyph (e.g. x1380) silently deletes that text
  from the result and makes the remaining cluster look like the wrong element. Always start
  the window at or before the column's left edge.
- Dim text (opacity 0.7) and thin accent underlines (teal #458588, luma ~114) vanish under a
  threshold of 120; use ~100 for muted text and ~80 for accent hairlines.
- When a pixel scan and the QML geometry disagree, the QML geometry (logged with
  `mapToItem(null, 0, 0)`) is authoritative: it reports exact boxes, while scans depend on
  colour, opacity and window choice.
- A runtime-geometry probe placed in a tab must NOT test `root.QsWindow` - inside a tab
  component `root` is the tab's own Item, so the guard silently no-ops. Log unconditionally.
- Multi-line string concatenation inside a `console.log(...)` in QML JS can fail to parse
  ("Expected token `)`"); keep each log on a single line.

## 12-hour alarm UI (owner's revision)

- The alarm is now a **12-hour** UI: the field holds `HH:MM` ONLY (never the meridiem - putting
  "4:00 PM" in the field overflows it and breaks `/^(0?[1-9]|1[0-2]):[0-5][0-9]$/`), and an
  **AM/PM selector** of two 25x22 cells sits 6 px to its right, the active cell filled with the
  accent. The whole control is ONE `Item` (measured 160 px = 104 field + 6 + 50) with
  `Layout.preferredWidth` AND `implicitWidth` pinned - a bare TextInput in a Layout keeps its
  implicit width no matter what.
- **Field width is measurement-driven**: the HH:MM advance at 32 px is **19.2 px per glyph**
  (96 px for five glyphs), not the ~13 px a glyph-start reading suggests. 104 px leaves air, so
  the first digit can never clip. Re-measure with `TextInput.implicitWidth` after any font change.
- **The 12-hour conversion lives in the tab**, never in TimerService: `draftToHh24()` (12 AM ->
  00:00, 12 PM -> 12:00), `display12(h, mm)` -> "4:00 PM", `resetAlarmDraft()` (service -> field +
  selector), `commitAlarmDraft()` (field + selector -> service). The service keeps 24-hour
  "HH:MM", its deadline maths, the notifier and the system clock untouched.
- **Typing never commits.** `onTextEdited` only writes the local draft, so an ACTIVE alarm is
  never changed silently; `onAccepted` / `onEditingFinished` commit, and clicking an AM/PM cell
  commits too (an explicit choice). Escape restores from the service. An invalid field keeps the
  last valid target and shows the warning colour.
- **The NEXT row is its own row**, always present at `Layout.preferredHeight: 18` (OFF / ARMED /
  RINGING), 13 px below the time row (owner's 12-16) and 15 px above the shared action row
  (owner's 14-18, measured ink gap 19). Text: `NEXT: TODAY · 11:00 PM` - armed/ringing takes the
  service's own target label (converted to 12-hour), off is a preview computed from the COMMITTED
  time. TODAY/TOMORROW always follows the system's local clock, never the Weather city.
- Status: fixed 112 px slot, 20 px, left aligned, `Layout.leftMargin: 18` from the right edge of
  the WHOLE time control (owner's 18-22 band); measured 18. The alarm's status x is deliberately
  NOT the countdown's (the countdown has a 170 px time column).
- `PopupManager.payload` selects the tab; `ShellPopup.tab` maps "" to "date". To capture a tab
  over ssh you must force ALL THREE: the window's `visible` at its instantiation site
  (`bar/Center.qml`, NOT in ShellPopup.qml), `isOpen` inside ShellPopup (the tabs gate
  `activeTab` on `root.isOpen && ...`, so a visible window still renders an empty panel), and the
  payload/tab. Driving the state from a Timer inside the tab works, but `root.screenName` is ""
  there - the bar-side timer is the one that may call `PopupManager.toggle`.

## Power menu (SystemPopup.qml + SystemActions.qml)

- Order (owner): **power group first** - SUSPEND, RESTART, SHUTDOWN - then the divider, then the
  session group - LOCK SCREEN, LOGOUT. The group swap is done in BYTE mode by slicing the
  file between the ASCII anchors (the `// SESSION` comment, the divider Rectangle, the `// POWER`
  comment, the SHARED BUTTON STYLE comment) and re-concatenating power + divider + session; the
  icon lines carry Nerd Font PUA glyphs and must never be decoded or rewritten.
- Spacing model: `ColumnLayout.spacing: 0` plus an explicit `Layout.topMargin` per item, because
  the wanted gaps differ per boundary. Measured (window coords, panel top at y=60): panel padding
  16, header rule -> first card 9, card gap 9 (RESTART) and 10 (SHUTDOWN), last power card ->
  divider 13, divider -> LOCK 13, LOGOUT gap 9, last card bottom 393 with the panel 409 tall =
  16 px of bottom air. No spacer, nothing pushed to the bottom.
- Cards `implicitHeight: 56`, popup `implicitWidth: 360` / `implicitHeight: 409` (the deprecated
  `width`/`height` form is gone from this file). The five handlers were re-verified after the
  reorder with a SAFE test: every real command replaced by a logging stub in a /tmp copy, then
  each card's own `clicked()` signal driven by a probe - the log read back SUSPEND, RESTART,
  SHUTDOWN, LOCK, LOGOUT in that order, so no handler swapped.
- SUSPEND AUDIT (non-destructive): the UI path is intact (TapHandler -> `button.clicked()` ->
  `suspendRequested()` -> `runAction(["systemctl","suspend"])`), `qs-lock`/`systemctl`/`loginctl`
  exist, and the click shield does NOT block the panel (its `panelSlot` is right-aligned for this
  popup - `claimSlot(w,h)` without `centered`). The cause of "nothing happens" is the
  **logind/polkit integration**: `CanSuspend`/`CanReboot`/`CanPowerOff` all answer **"challenge"**
  and `pkcheck` reports **auth_admin_keep**, i.e. each action needs an interactive polkit
  authorisation. polkit-gnome's agent is running, so a prompt is expected - but the Process used to
  discard stdout/stderr and the exit code, so ANY failure (agent not prompting, denial, timeout)
  looked like a dead button. `SystemActions.qml` now logs the exit code and any stderr, and no
  longer restarts the Process in the same tick it is stopped.
- **A real suspend/reboot/poweroff has NOT been run** (owner's rule) - to be confirmed by the owner
  by hand. If a polkit prompt never appears, the clean fix is a NixOS rule allowing
  `org.freedesktop.login1.suspend|reboot|power-off` for the active user, which would then need an
  in-popup confirmation for the destructive two.

## Power actions: why they needed a polkit rule (and what was broken)

- Symptom: LOGOUT and LOCK worked, SUSPEND / RESTART / SHUTDOWN did nothing (the popup closed
  and that was all). The commands were fine - they are the standard
  `systemctl suspend|reboot|poweroff`, `niri msg action quit` and `qs-lock`.
- Real cause, from systemctl's own stderr captured by the Process logging:
  `Access denied as the requested operation requires interactive authentication. However,
  interactive authentication has not been enabled by the calling program.`
  The caller belongs to **no logind session**: this setup is greetd -> `niri.service`, i.e. niri
  runs as a systemd *user service*, so niri and every process it spawns sit in
  `user@1000.service/app.slice/...` instead of a `session-*.scope`
  (`GetSessionByPID` answers "does not belong to any known session" for quickshell, for niri
  itself and even for the polkit agent). polkit therefore cannot attach an authentication agent
  and refuses the action outright. LOCK (qs-lock) and LOGOUT (`niri msg action quit`) never go
  through polkit, which is exactly why they work. Any menu that shells out to `systemctl` from this
  sessionless context is silently dead for the same reason.
- Fix (documented approach for a compositor that is not a full DE): `modules/polkit.nix` grants
  the login1 power actions (suspend / hibernate / reboot / power-off and their
  `-multiple-sessions` variants) to the `wheel` group with `polkit.Result.YES` and returns
  `NOT_HANDLED` for everything else, so the rest of the policy is untouched. The polkit settings
  moved out of `modules/packages.nix` into that single-concern module, which `configuration.nix`
  imports.
- Because the rule removes the prompt, RESTART and SHUTDOWN now ask twice in the popup: the first
  tap arms the card (label becomes `RESTART?` / `SHUTDOWN?`, subtitle "Click again to confirm",
  border turns warning-red), the second fires it, and arming reverts by itself after 4 s.
- Keep the `Process` logging in `SystemActions.qml`: it prints the exit code and any stderr, which
  is how this was diagnosed. `Process.NormalExit` is NOT a reliable companion to an exit code in
  this build - it labelled successful runs "(abnormal exit)"; compare the exit code only.

## Never start a second instance of the main shell to "just check" QML

`main/shell.qml` writes `$XDG_RUNTIME_DIR/quickshell-shell.pid` at startup, and every keybind goes
through `scripts/qs-popup`, which writes one line into `$XDG_RUNTIME_DIR/quickshell-cmd-<pid>`.
Starting a second copy (`timeout 6 quickshell -p .../main`, a stray `qs -p`) overwrites that pid file
with a process that then exits, so every later keybind writes into a FIFO nobody reads: Super+D and
friends silently do nothing while the bar keeps working. `qs-popup` now validates the recorded pid
against `/proc` and rediscovers a live main shell, but the habit matters more than the guard - verify
QML by restarting the one running shell, not by starting another.

## Lock screen: Quickshell session lock

- **The lock client MUST quit when it unlocks.** Releasing the lock alone (`lock.locked = false`)
  leaves the process running, and `qs-lock` treats a live instance as "already locked" and returns
  immediately - so the SECOND lock request does nothing. That is how a resume from suspend came back
  unlocked. The client releases, then `Qt.quit()` after a short timer, so "an instance is running"
  always means "the session is locked".
- `Qt.quit()` is the call that works on Quickshell 0.3.2. `Quickshell.quit()` does not exist and fails
  with `Property 'quit' of object QuickshellGlobal ... is not a function` - it fails at runtime, not
  at load, so the config still reports "Configuration Loaded".
- `qs-lock` verifies the client actually came up (one retry, then a non-zero exit) so a failed start
  leaves a journal line instead of a silently unlocked machine after resume.

The lock screen is a **separate Quickshell instance** using `WlSessionLock`
(ext-session-lock-v1) and `Quickshell.Services.Pam`.

- `lock/shell.qml` - the session lock root. `WlSessionLockSurface.screen`, `.width`, `.height` and
  `.data` are READ-ONLY: Quickshell instantiates one surface per output itself. Assigning `screen`
  (or wrapping the surface in a Repeater) is a load error.
- `lock/LockContent.qml` - blurred wallpaper + clock + date + user + password field, all coloured
  from `$XDG_STATE_HOME/theme/theme.json`. Failed attempts shake the field and turn the border the
  palette `warning` colour; a CAPS LOCK hint comes from polling `/sys/class/leds/*capslock*/`.
- `scripts/qs-lock` - starts it. `qs-lock --test` renders the same screen as an ordinary full-screen
  surface (`QS_LOCK_TEST=1`) so the design can be reviewed without locking the session.
- `theme-apply` renders `state/lock-bg.jpg` (blurred wallpaper) on every theme switch, so the lock
  screen only has to display an image.
- PAM: `modules/lock.nix` declares `security.pam.services.qs-lock`, left at the NixOS default
  (`pam_unix` + `pam_env`). Do not hand-write that stack - it is the one thing that can lock the
  owner out. The QML signal is `pamMessage` (no arguments; read `pam.message` and
  `pam.messageIsError`), and `respond()` must be called from `responseRequiredChanged`.
- Idle and suspend: `services/PowerService.qml` generates the swayidle argument list; the lock and
  `before-sleep` entries both point at `qs-lock`. Display-off (`niri msg action power-off-monitors`)
  and auto-suspend (`systemctl suspend`) are untouched by the lock change.
- `qs-lock` exits immediately when a lock instance is already running. Killing a live instance would
  RELEASE the session lock for a moment, which must never happen on suspend.
- Kill switch, from a TTY or SSH: `pkill -f 'quickshell.*quickshell/lock'`.
- A real lock/unlock was exercised by the owner; `qs-lock --test` covers visual review.

## Theme palette: runtime, not Nix

- btop must run with `theme_background = false`. With it on, btop paints its own background and hides
  the terminal's transparency - the dark palettes then look almost black and nothing matches the
  popups. `theme-apply` writes the setting into `btop.conf` on every switch, because btop rewrites
  that file itself. Ghostty runs at 0.75 opacity and the shell surfaces at 60% (`#99` + palette
  background), so btop drawing "nothing" is what makes it match both.

The old design (`home/theme-palette.nix` + `home/theme-gruvbox.nix` + `home/theme-nordic.nix`, each
with its own colour list) is GONE. Colours now live in the runtime state dir and one script renders
every consumer; see "Themes: colours live in the state dir, never in Nix" above for the whole
architecture. What is worth remembering from the migration:

- Any file that a script writes at runtime must NOT also be a Home Manager file. Two writers for one
  path is what aborted the activation three times in a row:
  `Existing file '<path>' would be clobbered`.
  * GTK: HM owns `~/.config/gtk-{3,4}.0/gtk.css`; they only `@import` the palette from
    `$XDG_STATE_HOME/theme/gtk.css` (`gtk3.extraCss` / `gtk4.extraCss`). One writer per file.
  * The themes directory is an HM symlink with `force = true`, because anything already sitting
    there (a manual link made while testing) would otherwise block activation.
- The GUI cannot be verified before the rebuild: GTK apps read `settings.ini` (still the old theme)
  and XFCE apps launched over D-Bus inherit the session's old environment, so `GTK_THEME=` on a new
  process proves nothing. Check after the switch, on a freshly opened app.
- Starship keeps its layout and palette names in `home/starship.nix`, but `theme-apply` copies it
  to `state/starship.toml`, swaps `palette = "gruvbox_dark"` for `"qs"` and appends a `[palettes.qs]`
  block built from `colors.toml`. The prompt therefore follows the theme with no rebuild.

## Power menu: confirmation removed, panel +10%

- The owner does not want the two-step confirmation, so it is gone entirely (properties, border
  branch, label swaps, tap logic and the revert timer). One tap = one action. The polkit rule
  keeps the actions authorised without a prompt, and leaving passwords/sudo exactly as they are
  is an explicit owner decision - do not "fix" that.
- Panel is ~10% larger overall: `implicitWidth/Height` 360x409 -> **396x450**, panel padding
  18, card height **62**, intra-group gap **10**, divider gaps **14**, card inner padding 12,
  icon column 30, header-rule gap 10. Fonts are untouched (they come from Theme). Measured from
  a screenshot: panel 396x450, roomy, nothing clipped, divider between SHUTDOWN and LOCK SCREEN.

## Nix flake gotcha

- A NEW file under `~/System` must be `git add`ed before any `nixos-rebuild --flake`, or the
  build fails with `Path '...' does not exist in Git repository` (the flake only sees tracked
  files). Hit by both `modules/polkit.nix` and `home/theme-palette.nix`. Staging is enough; the
  owner still owns commits.

## Power management: two idle controls

- The popup has exactly TWO controls and no other power feature: **SCREEN OFF AFTER** (10M / 30M /
  1H / NEVER) and **SLEEP AFTER IDLE** (1H / 3H / 6H / NEVER), each one label + one chip row with
  NO description line under it. Stored in
  `~/.local/state/quickshell/power.json` as `displayMinutes` + `autoSuspendMinutes`; `0` = never.
  A stored value outside the offered options falls back to the default, so the UI can never show a
  selection the daemon is not using.
- The owner's current selection, preserved through the refactor: display **NEVER** (0) + suspend
  **NEVER** (0). With both at never the generated daemon line is only the fixed lock timeout. Do not
  silently turn automatic suspend on, and do not reset a timeout the owner set.
- `services/PowerService.qml` owns the ONE swayidle instance: it generates the argument list from
  those two values and restarts the daemon when one changes (0ms Timer between stop and start, 60s
  watchdog, `pkill -x swayidle` first so no older instance survives). Display off =
  `niri msg action power-off-monitors` with `resume` powering the monitors back on, so encoding,
  rendering and downloads keep running with the screen dark; suspend = `systemctl suspend`,
  idle-triggered only - never a shutdown, never a wall-clock or forced trigger.
- **swayidle ADDS its config-file events to the command-line events** ("specifying events in the
  config and as arguments is not mutually exclusive"). Measured: with the deployed config present,
  swayidle registered the file's 1h/2h/4h events ON TOP of the generated ones, i.e. the popup was
  not actually authoritative. The generated command therefore passes `-C /dev/null`, and the config
  file itself is gone: `.config/swayidle/config` deleted from the repo, its mapping removed from
  `home/files.nix`, and `spawn-at-startup "swayidle"` removed from `~/.config/niri/config.kdl`
  (Quickshell starts the daemon). `-C /dev/null` makes the popup authoritative immediately; the two
  Nix edits only take effect after a rebuild.
- The session lock timeout stays FIXED: 2h idle plus `before-sleep 'qs-lock -f'` - exactly what the
  old config file did. It is not part of the popup and must not be dropped.
- Panel: **320x270** (measured border rect x1107..1426, y60..329 with the launcher popup forced
  visible on DP-1; top 60 = `theme.popupTop`, right margin 13). Header (crescent + title), one rule,
  then two stacked 63px sections: label at **15px Bold** (`theme.fontSize + 1`) in `theme.fg`, i.e.
  exactly as bright as the panel title, directly followed by one chip row, no hint line. Chips are scaled as CONTAINERS - **34 px high**, 31 px of inner padding, 10 px apart, panel
  padding 23 - while the label inside them uses the `theme.fontSize` token, never a hardcoded size
  (that is what makes the choices easy to hit without breaking the shell's typography scale).
  Natural widths, one left-aligned group (display 57/57/55/73, suspend 55/55/55/73) - never
  stretched across the row. Chip labels are `theme.fg` as well and carry NO whole-chip opacity (the
  old 0.72 dimmed the label along with the border); the selected value is marked by the 2px accent
  border plus a 10% accent fill, which the owner reads as enough. Content is 274x224 (320-46 /
  270-46) and the rows sum to exactly 224; a
  QML walk reports 0 clamped items, so there is no dead space and no clipping.
- `anchors.margins` did NOT hold on the popup's ColumnLayout (measured 17 px side padding against
  23 px top/bottom). The panel uses explicit `anchors.leftMargin/rightMargin/topMargin/bottomMargin`
  like the other panels - check padding symmetry from a screenshot after any layout change here.
- Removed in this refactor, do NOT reintroduce: the one-time suspend timer (countdown, absolute
  deadline, 1H/2H/3H presets, cancel, persistence); the keep-awake override (timed and indefinite,
  its expiry, its "AUTO SUSPEND / SUPPRESSED" state); the service-side `systemctl suspend` process
  that bypassed swayidle; and the bar's `SuspendCountdown` indicator
  (`bar/modules/SuspendCountdown.qml` deleted, `Bar.qml` back to its original three sections with no
  id on the right group and no spacer).
- The bar launcher stays: `bar/modules/PowerManagement.qml`, Font Awesome crescent U+F186 (built with
  `String.fromCodePoint` - a `\uXXXX` escape takes only four hex digits), immediately left of the
  power menu, measured ink gaps 22/22 (`Layout.leftMargin: 24` here, 21 on `SystemActions`). Click
  path: `PopupManager.toggle(screenName, "power")`.
- `services/TimerService.qml` is a DIFFERENT feature (the clock tab's countdown + alarm). It shares
  the word "countdown" and nothing else - never delete it while cleaning up power code.

## Application launcher (`popups/Launcher.qml`)

- `Mod+D` spawns `.config/quickshell/scripts/qs-popup launcher`, which resolves the running shell by
  pid and calls IPC `shell.launcher()` -> `PopupManager.toggle(screen, "launcher")`. One window per
  screen, instantiated in `shell.qml` next to the toast module.
- Keyboard-first: while visible the surface sets `WlrLayershell.keyboardFocus: Exclusive` and the `TextInput`
  owns every key (arrows, Enter, Escape). An empty query shows EVERY application sorted A-Z by
  `name.toLowerCase()`, not by a frecency cache. Sorting compares `id` when names tie so the order
  stays stable.
- Scoring (`score()`): substring first (hit at index 0 = 2000, further in = 1200 - offset), then
  subsequence with +60 for a word start, +10 for a buried character and +25 for consecutive
  characters. `genericName` and `id` are scored too, with a penalty, so the row a user means wins.
- Launching: `entry.command` with the `%f/%u/%F/%U` field codes stripped, `runInTerminal` entries
  wrapped in `ghostty -e`, empty command falls back to `entry.execute()`. `PopupManager.closeAll()`
  runs BEFORE the exec, so the panel never stays up over the app it started.
- HIDDEN APPS: `main/launcher.hides`, one desktop id per line, `#` starts a comment. It is the ONLY
  hide list - the launcher filters on it, and `home/files.nix` generates one tombstone `.desktop`
  per line (`Hidden=true`) so GIO and anything else reading XDG hides the same set. Never hand-write
  tombstones again: add a line, rebuild. That is also why `.local/share/applications` is linked
  PER FILE in `files.nix` - a directory symlink cannot be extended with generated files.
- Measured geometry: 520 wide, centred on the SCREEN (vertical + horizontal, `margins.top: (screen.height - implicitHeight) / 2`), rows are icon + name only - the right-hand description column was removed
  (`margins.left: (screen.width - panelWidth) / 2`), 9 rows of 42 px, `height = col + 28`
  (12 px margins + 2 px border). Selection is a colour change to `theme.muted` only.
- `Qt.resolvedUrl()` does NOT resolve for `FileView` in this shell (it surfaces as
  `Read of qrc:/qs-blackhole failed` and the list silently parses to zero entries). Use
  `Quickshell.shellRoot + "/<file>"`. The hides file is read once with `blockLoading: true`;
  changing it needs a shell reload, which matches how rarely it changes.
- Verified live: 47 apps listed A-Z, `nvidia`/`cups`/`davinci` absent (18 ids), typing `calc` +
  Enter launched `gnome-calculator`, Escape closed the panel, one shell instance only.

## Popup latency: what actually costs time (measured)

Numbers below are wall-clock on this machine (DP-2 2560x1440), measured by polling
`niri msg layers` for the `exclusive` surface while timing the keybind helper.

| Slice | Before | After |
|---|---|---|
| keybind helper (`qs-popup` -> `qs ipc`) | ~85 ms | ~85 ms |
| IPC return -> surface on screen | ~180 ms | ~14-38 ms |
| total | ~275 ms (felt like 500) | ~110-130 ms |

- The 180 ms was NOT the launcher's code: EVERY panel measured the same, so it was the popup
  machinery. Two surfaces map on open - the popup itself and the fullscreen click shield - and
  mapping a fullscreen region-masked surface is the expensive one.
- Fix: both are now mapped ONCE at startup and only change properties on open.
  - shield (`shell.qml`): `visible: true` always, `mask: shield.active ? activeMask : idleMask`
    where `idleMask` is an empty `Region` (0x0 = no input, so the pointer behaves exactly like an
    unmapped surface).
  - launcher: `visible: true`, `opacity: 0` + `mask` over a null item when closed, and
    `keyboardFocus` switches to `Exclusive` only while open. Opacity (not `visible: false`) keeps
    the ColumnLayout laying out, so `implicitHeight` is already correct on the first open.
- The 85 ms left is process startup, not QML: `qs ipc` alone costs ~40 ms (a Qt binary), plus
  `niri msg focused-output` ~22 ms and the shell script. The shell writes its pid to
  `$XDG_RUNTIME_DIR/quickshell-shell.pid` at startup so the helper can `read` it instead of paying
  `pgrep -f` (~60 ms cold, ~10 ms warm).
- Remaining option if it still feels slow: replace `qs ipc` with a FIFO the shell reads in one
  long-lived process (`printf launcher > /run/user/$UID/qs.fifo` costs ~5 ms). Not done because it
  adds a resident reader and the current number is already good enough.
- Other panels (audio, network, power, system) are still mapped on demand and still pay ~180 ms;
  pre-mapping them the same way is the next step if the owner wants them instant too.

## Popup latency: the second half (FIFO + niri socket)

Measured after the pre-mapping work (see the latency section above): every panel still paid
~75-85 ms before the surface appeared. That was process startup, not QML, and it is now gone.

| Slice | Before | After |
|---|---|---|
| keybind helper | 85 ms (`pgrep` + `qs ipc`) | **4 ms** |
| IPC -> surface on screen | 180 ms | **9-14 ms** |
| **total** | ~275 ms | **13-19 ms** |

- The helper (`scripts/qs-popup`, see below) writes one word into a FIFO
  (`$XDG_RUNTIME_DIR/quickshell-cmd`) that `shell.qml` keeps open in a `Process` read loop
  (`while :; do while read -r line; do echo "$line"; done < "$fifo"; done`). `SplitParser` on its
  stdout calls `runCommand()`. `exec 3<>"$fifo"` in the helper opens read-write so a missing shell
  can never hang a keybind. `qs ipc` (~40 ms, it starts a Qt application for one word) is only the
  fallback for a shell without the pipe.
- `services/ScreenFocus.qml` now talks to niri's IPC socket directly (`Quickshell.Io.Socket` on
  `$NIRI_SOCKET`, kept connected): write `"FocusedOutput"\n`, read the reply, ~1 ms. The
  `niri msg focused-output` process (~22 ms) survives only as a 150 ms guard fallback when the
  socket is not connected. Reply shape: `{"Ok":{"FocusedOutput":{"name":"DP-2",...}}}`; event
  lines also arrive on that socket and are ignored.
- THE HELPER LIVES AT `scripts/qs-popup`, NOT in `~/.config/niri`: that directory (and
  `~/.config/quickshell`) is a home-manager symlink into the Nix store, so edits only land after a
  rebuild. The shell tree runs from the working copy, so helper edits take effect on the next
  keypress. niri's binds spawn the absolute path.
- Panels and the launcher now fade with `Behavior on opacity` at `theme.duration(theme.motion)`
  (110 ms). `Theme.animationsEnabled = false` collapses every duration to 0 - the same
  reduce-motion switch Omarchy implements as `Style.duration()`. Omarchy does NOT animate its menu
  open either; its animations are content transitions (180/260 ms fades) and bar colour fades.
- No open animation may delay input: the fade starts from the same frame the panel is already
  mapped and focused, so typing works immediately.

## Surface alpha (visual, not functional)

- `theme.bgPanel` = `#f23c3836` (95%) for the four popup panels. `theme.bgTranslucent` =
  `#cc3c3836` (80%) for the launcher only. `theme.bg` (opaque) stays for anything
  that must never show through.
- Measured why 95% reads as solid: with the theme base at (60, 56, 54), the sampled panel
  background came out at (61, 57, 55) for the network panel and (63, 59, 57) for audio - a shift of
  1-3 per channel, so the glass only shows over very bright content. If the look ever needs to be
  visibly glassy, 88-90% is the range; below that the 13-14 px panel text loses contrast, which is
  why the launcher (text-light, transient) is the only surface at 80%.

## Report dialogs: real windows, not layer surfaces (popups/DialogWindow.qml)

- The two report scripts (`modules/scripts/actions/inspect-file`, `modules/scripts/systems/smart-report`)
  write a text report and hand it to the shell, which shows it in a
  **`FloatingWindow`** - an actual xdg_toplevel, app-id `org.quickshell`. The compositor manages it
  like any other window: tile it, float it, resize it, lock it, close it with the close-window key.
  That is why the dialog is NOT a `PanelWindow`: a layer surface cannot be tiled, and the click
  shield plus exclusive keyboard focus would block the rest of the desktop while it is open.
- Contract: the script writes a report file whose FIRST line is `TITLE: <window title>`, then sends
  one line `dialog <kind> <path>` (`kind` = `inspect` | `smart`) into the shell FIFO
  (`$XDG_RUNTIME_DIR/quickshell-cmd`). `shell.qml` routes it to the matching `DialogWindow`; two
  instances exist so an inspect report and a SMART report can be open at once. Both scripts keep a
  print-to-stdout fallback for when the shell is not running (`show_report()` returns 1 -> `cat`).
- Rendering: monospace `TextEdit` with `RichText`, read-only, selectable, `NoWrap`, hand-drawn
  scrollbars (the shell does not import QtQuick.Controls). Colouring is PATTERN-BASED, not data:
  a line followed by a rule of box-drawing characters is a section header (accent + bold),
  `PASSED|OK|GOOD|HEALTHY` -> `theme.success` (#98971a), `FAILED|FAILING_NOW|BAD|CRITICAL` ->
  `theme.warning`, and `Label: value` dims the label. The scripts were NOT converted to JSON:
  colouring two verdict words did not justify rewriting 1200 lines of formatting.
- COPY runs `tail -n +2 <file> | wl-copy` (drops the TITLE line). CLOSE hides the window. Escape
  closes it through a `Shortcut`; the compositor close-window key works because it is a real window.
- niri: `window-rule { match app-id="org.quickshell"; open-floating true; fixed 900 / 700 }` - the
  same footprint the old dialog rule had. Confirm the app-id at runtime: it is `org.quickshell`, not
  `quickshell`.
- Traps: `niri msg windows --json` is invalid (flag first: `niri msg --json windows`). Niri reads its
  config from the home-manager store copy, so window rules and installed scripts only change after a
  `rebuild`; test the repo copies directly (`bash ~/System/modules/scripts/actions/inspect-file <file>`).

## Command channel: the FIFO rules (learned from a real outage)

Symptom the owner hit: the report dialogs opened once, then stopped, and different file types
behaved differently. Three separate bugs, all in the keybind FIFO:

1. **One shared pipe path meant two readers.** A reader (`sh` loop) left over from a previous shell
   instance stays alive, holding the FIFO open. The kernel hands each write to whichever reader
   wakes first, so lines arrive CUT IN HALF - the shell logged `CMDDBG raw=[0-ptrbt]` instead of the
   command. Fix: the path carries the pid (`$XDG_RUNTIME_DIR/quickshell-cmd-<pid>`), so a stale
   reader can only ever read its own dead pipe.
2. **`pkill -f 'read -r line; do echo'` killed the setup script itself.** The pattern matched the
   `sh -c` that contained it, so `mkfifo` never ran and the pipe silently never existed. Fix: the
   classic bracket trick, `read -r line; do ech[o]`. Any pkill whose pattern is also in its own
   command line is a self-kill.
3. **The pid file had no trailing newline.** `printf %s` writes `93059` with EOF right after, `read`
   returns non-zero, and every consumer (`|| pid=""`) wiped the value - so the helper computed
   `quickshell-cmd-0`, found no pipe and silently fell back to `qs ipc` (4 ms -> 70 ms per call).
   Fix: write `printf '%s\n'`, and consumers use `|| true` instead of `|| pid=""`.

Diagnose in one line: `ps -eo args | grep -c "[r]ead -r line"` must print exactly **1**, and
`ls $XDG_RUNTIME_DIR/quickshell-cmd-*` must show the pipe named after the running shell's pid.

Transport split, on purpose:

| Path | Used by | Why |
|---|---|---|
| FIFO `quickshell-cmd-<pid>` | keybinds (`scripts/qs-popup`) | ~4 ms, latency is the whole point |
| `qs ipc --pid <pid> call shell run "<cmd>"` | report dialogs | ~40 ms, but reports already take 100s of ms and delivery must be reliable |

Never add a second reader to the FIFO, and never `rm` a pipe that a reader may already have open.

## FloatingWindow rule: it needs a screen or it never appears

- A `FloatingWindow` (the report dialogs) belongs to ONE output and can only map once it has one.
  After a `nixos-rebuild switch` the shell can come up before the outputs are published, so the
  window was created with `screen: null`, `visible = true` did nothing, and inspecting a file looked
  like a no-op - with NO error anywhere. A manual shell reload "fixed" it, which is the tell.
- Fix: `screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null` as a binding, and
  `openReport()` re-assigns `root.screen` to the FOCUSED output (via `ScreenFocus`, ~1 ms over
  niri's socket) before setting `visible = true`, so the dialog opens where the owner is looking.
- Same lesson as the layer-shell panels: a window that is invisible with no errors is almost always
  a window that never got a screen.
- Verified after a rebuild with a fresh shell: txt, pdf, jpeg, mkv (including a filename with `&`),
  the SMART report next to it, repeated opens, floating 900x700 per the niri rule.

## FloatingWindow lifecycle: a closed toplevel is dead

- Report dialogs are created PER REQUEST: `shell.qml` keeps `Component { DialogWindow { } }` and
  `showReport(kind, path)` calls `createObject(null, { reportPath: path })`, replacing (and
  destroying) any previous window of that kind.
- Why: once a toplevel has been closed - compositor close key, CLOSE button, Escape - the backing
  window is gone. Quickshell emits `closed` and writing `visible = true` again is SILENTLY ignored,
  with no error. That is what made "inspect" work once and then do nothing until the shell was
  restarted.
- Do NOT destroy the window inside the `closed` handler: that made the window disappear instantly
  and the open path flaky (three identical opens, only the third showing). Let the closed window sit
  invisible until the next request destroys it.
- Windows are created with `visible: true` (one transition only) and need a screen before they can
  map: `screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null`, re-assigned to the
  focused output in `Component.onCompleted` via `ScreenFocus`.
- Verified after a reload with the INSTALLED script (not the repo copy): txt, pdf, jpeg, mkv (name
  containing `&`), each opened AFTER a compositor close, plus inspect and SMART side by side.

## Report dialog: line spacing (the "big gaps" bug)

- The body HTML is ONE block (`<div style="margin:0;white-space:pre">`) whose rows are joined with
  `<br/>`. Rows must NOT be joined with `"\n"` inside `<pre>`: Qt turns every newline there into its
  own paragraph, and an empty source line then cost about three line heights (measured 68 px against
  an 18 px pitch) - which read as random doubled blank lines between sections.
- Blank source lines are pushed as an EMPTY string, never as `<br>`: with a `<br>` plus the join the
  break was doubled on top of the paragraph spacing.
- Expected result: one blank line in the report = exactly one empty line on screen, so a section gap
  is 2 line pitches (blank + heading). Verified by zooming the rendered window: `Created:` ->
  `VIDEO` spans exactly two field-line spacings.
- `white-space:pre` is what keeps the scripts' padded `%-18s` label alignment; without it the columns
  collapse.

## Report dialog: CLOSE / leading blank (follow-up fixes)

- `closeReport()` used to only emit `closedByUser()`, and the receiver that destroyed the window was
  removed in the lifecycle rewrite - so CLOSE and Escape silently did nothing. It now sets
  `visible = false` directly, which is safe because the window is rebuilt per request.
- Reports must start on their first row. `inspect-file` emitted a blank BEFORE the first section
  (`section()` printed `echo` unconditionally), so the body opened with an empty line while
  `smart-report` opened straight on its heading. Fixed twice over: `section()` skips the leading
  blank (`SECTION_FIRST`), and the window trims leading blank lines from the body
  (`body.replace(/^\s*\n/, "")`) so any future script behaves.
- Verified: inspect body starts with `FILE INFO` directly under the header divider, exactly one
  blank line between sections, SMART Report unchanged (it already started on its heading).

## Job window: progress for the conversion scripts

The Thunar actions that used to open `ghostty -e <script>` now open a Quickshell progress window.
Same idea as the report dialogs: the script writes a file, the shell draws it. One way only.

**Flow**

1. Thunar runs `.config/quickshell/scripts/qs-job <script> %F`.
2. `qs-job` finds the shell pid in `$XDG_RUNTIME_DIR/quickshell-shell.pid`, starts the script
   detached (`setsid`, so its pid is its process-group id) with `QS_JOB_STATUS=<statusfile>`,
   stdout/stderr into `<statusfile>.log`, and records the pid in `<statusfile>.pid`.
3. It then writes `job <statusfile>` into the shell FIFO (same fast path as `qs-popup`).
4. `shell.qml` (`job` verb -> `showJob`) creates a `JobWindow` for that path, which polls the file
   every 250 ms plus `tail -n 5` of the log, and stops polling once the state is terminal.

**Status file** - `key=value`, rewritten atomically (`.tmp` + `mv`): `title`, `state`
(`running|done|failed|cancelled`), `file`, `detail`, `percent`, `speed`, `eta`, `message`.

**Cancel** - the button (and Escape) runs `kill -TERM -$(cat <statusfile>.pid)`. The scripts already
trap `INT TERM` in `cleanup()`, which deletes the partial output and reports `state=cancelled`.
A job that processed nothing (remuxing into the container it already is) still reports a terminal
state from the tail block, otherwise the window would poll forever.

**Fallback** - no shell pid, or the FIFO refused the line: `qs-job` execs `ghostty -e <script>` and
kills the detached job, so the action never dead-ends.

**Script side** - every script has a `job_write` helper next to `cleanup()` that is a no-op without
`QS_JOB_STATUS`, so running them from a terminal behaves exactly as before. The
`read -r -p "Press Enter to close..."` pauses are gone (nothing can press Enter in a detached job).

**Layout** - one card for every job type, 900x700 like the report dialogs: header (title, state
label, CANCEL/CLOSE), file name, VIDEO bar (percent + SPEED/ETA), a FILES bar for batches, and a LOG
pane that fills the rest. The log is not decoration: these files are not always clean (TS/MTS, mp4
with a broken header), and ffmpeg happily encodes anyway while dropping a stream - that only shows
up in the warnings. The pane follows the tail unless the user scrolls up.

**No progress spam in the log** - the scripts print their per-second `Progress: ...` line only when
stdout is a terminal (`if [[ -t 1 ]]`, `sys.stdout.isatty()` in Python). Under qs-job stdout is the
log file, so the log keeps headings, file names, ffmpeg warnings and the summary, and the bars carry
the live numbers. This is why the log pane is usable at all.

**ffmpeg warnings on success** - ffmpeg's stderr goes to `<tmp>.log` and the scripts used to print
it only when the encode failed. The success path now appends `FFmpeg warnings:` plus that file, so a
"successful" run that lost audio still says so in the job log.

**Chrome** - identical to the report dialogs: `theme.bg`, 2px `theme.accent` border, `radius: 0`,
buttons 88x28 with a 1px `#bdae93` border that fill with the accent on hover. niri already forces
`geometry-corner-radius 0` globally, so nothing rounded is left anywhere.

**Size** - the window is 900x700 via the existing `org.quickshell` niri rule; no per-job rules and no
title handshake are needed for sizing. (`qs-job` still passes `job <statusfile>|<title>` so the title
is set before the window maps - that keeps the window list readable, not the size.)

**COPY** - copies the whole `<statusfile>.log` with `wl-copy`, not just the visible tail: it is
what gets pasted into an AI when a run warned about a broken header. Same chip style as the report
dialogs (74x28).

**Python jobs** - two things only Python needs:
- `qs-job` launches the child with `PYTHONUNBUFFERED=1`. Redirected stdout is block buffered, so the
  log pane stayed empty for the whole run and then dumped everything at once.
- `transcribe-video` prints a checkpoint line per 10% when stdout is not a terminal (the per-second
  line would be spam), so the log still shows that something is happening during a long run.
- `wait_before_close()` returns immediately when stdin is not a tty. It used to call
  `input("Press Enter to close...")`, which raised EOFError in a detached job **after** a perfectly
  successful transcription, and the run was reported as FAILED with a partial SRT left behind.

**Status keys** - `title`, `state`, `file`, `detail`, `index`, `total`, `percent`, `speed`, `eta`,
`message`. `index` is the 1-based file being processed, so the FILES bar shows
`(index - 1) / total` while running and `total / total` once the job is done.

### QML pitfalls that cost real time here

- **Never split a binding across lines.** `readonly property color c: a ? x` newline `: b ? y : z`
  ends the binding at the newline; the component then fails to instantiate and `createObject`
  returns **null with no error in the log at all**. Keep every ternary on one line.
- `theme/Theme.qml` is NOT a singleton (no `pragma Singleton`): use `readonly property Theme theme:
  Theme { }` and read `root.theme.bg` / `.fg` / `.accent` / `.warning` / `.success` / `.fontFamily`
  (`bg0`, `bg1`, `mono`, `red`, `green`, `orange` do not exist).
- Toplevel windows must be created with `visible: true`; flipping `visible` to true after
  `createObject` is silently ignored, exactly like re-showing a closed dialog.
- `StdioCollector` needs `import Quickshell.Io`. A stray `ExclusionMode.Ignore` (no property name)
  is a parse error - the report dialogs do not set it at all.

### Deploying

`~/.config/Thunar/uca.xml` and the scripts in `modules/scripts/actions` reach PATH through Home
Manager, so a `rebuild` is required before the Thunar actions and `qs-job`-by-name see the changes.
The repo copy must stay executable (`chmod +x`) - `setsid <path>` needs it.

### Python: cancelling during the model load

`transcribe-video` handles SIGTERM by writing `state=cancelled` and calling `os._exit(130)`. With
`sys.exit` the exception is only raised after faster-whisper returns from its C call, so the job
stayed alive for minutes after CANCEL while the window already showed the cancelled state.

## Action menus in the launcher

Three scripts in `modules/scripts/launchers` hand a small choice list to the shell instead of running
their own menu program, so every menu on the machine is one UI:

| Script | Items | Opens |
|---|---|---|
| `nas-menu` | 3 | `qs-popup "menu nas"` |
| `system-menu` | 5 | `qs-popup "menu system"` |
| `power-menu` | - | `qs-popup power` (the shell's SystemPopup) |

**Protocol** - the script writes `$XDG_RUNTIME_DIR/qs-menu-<name>` with one `<label>|<command>` per
line and calls `qs-popup "menu <name>"`. `shell.qml` turns that into
`PopupManager.toggle(screen, "menu", name)` (a separate popup name, so the plain launcher's payload
cannot leak into a menu), and `Launcher.qml` builds entries from the file with the same shape as
desktop entries - search, keyboard, icons and look are the ones it already had. Commands run through
`sh -c`, so a line can be a whole pipeline.

**Two traps** already paid for:
- The `menuPath` readonly binding is NOT re-evaluated yet when `onMenuNameChanged` fires (it still
  carried the empty name, so the first read hit `/qs-menu-` and the list came back empty). Build the
  command inside the handler (`readMenu()`), never from that binding.
- `qs-popup` is not on PATH; the scripts call it by absolute path, like the niri binds do.

**No external menu program is installed any more**: the package, its dedicated home module and the
two per-theme blocks that styled it are gone. Scripts hand their items over and the shell renders
them.

## Themes: colours live in the state dir, never in Nix

Switching a theme must not need a rebuild. Home Manager writes read-only store symlinks, so nothing
at runtime can touch its files; theming is therefore split the way Omarchy splits it:

| | owner | what |
|---|---|---|
| static | Nix | packages, fonts, and a POINTER: ghostty's `theme = <absolute path>`, btop's `qs.theme` symlink, the shell's `theme.json` |
| runtime | `modules/scripts/themes/theme-apply` | the palette, the wallpaper, and every rendered app config under `$XDG_STATE_HOME/theme/` |

**Sources** - `themes/<name>/colors.toml` in the repo (Omarchy format: `background`, `foreground`,
`muted`, `selection`, `accent`, `red`, `green`, `yellow`, `blue`, `cyan`, `magenta`, bright variants)
shipped read-only to `/etc/qs-palettes/`, plus `~/.local/share/qs-palettes-user/` which is writable
and shadows an official theme of the same name. Adding a community theme needs no rebuild; adding an
official one does, because that directory is a store symlink.

**`theme-apply <name> [--no-rotate]`** writes `theme.json` (what the shell reads), `ghostty` (a theme
file, picked up through the absolute path), `btop.theme` (linked to `~/.config/btop/themes/qs.theme`),
the Obsidian snippet, and the wallpaper (per-theme, remembered in `state/wallpapers/<name>`; choosing
the ACTIVE theme again rotates to the next background, which is Omarchy's behaviour). Then it reloads:
`pkill -SIGUSR2 btop`, `ghostty +reload_config`, and `theme` into the shell FIFO.

**Shell side** - `theme/ThemeState.qml` is a SINGLETON that reads `theme.json`; `Theme.qml` keeps its
old surface (`bg`, `fg`, `muted`, `accent`, `warning`, `success`, `bgAlpha`) and simply binds them to
`ThemeState`, so the ~29 components that do `Theme { }` needed no change and update live when
`theme` arrives (`ThemeState.reload()`). `theme/WallpaperState.qml` is the same pattern for the
wallpaper path, watched instead of polled, and read by `wallpaper/Wallpaper.qml`.

**GTK** - ONE static theme (`Adwaita-dark`, set by `home/themes.nix`) recoloured from the palette by
`theme-apply` into `~/.config/gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` (43 `@define-color` roles:
libadwaita + GTK3 names). No per-theme GTK package and no patched theme: adding a theme can never
require packaging a GTK theme, and if the override ever fails the app just looks stock Adwaita instead
of breaking. Icons (`Papirus-Dark`) and cursor (`Bibata`) are deliberately neutral - they cannot be
recoloured, so a neutral set stops them clashing with any palette. GTK has no CSS hot reload: open
apps keep the old colours until restarted.

**GTK + icons are generated per palette** - palettes with `generate_gtk = "true"` /
`generate_icons = "true"` get a theme BUILT from the palette instead of a packaged one:

- GTK: a complete base theme (Nordic, 4 MB, text CSS) is copied to
  `~/.local/share/themes/qs-<palette>` and ~29 of its hex values are rewritten to palette roles. That
  is what makes a palette with no native theme reach GTK apps *and* browser chrome (Firefox/Chromium
  paint their UI with the GTK theme). A colour missing from the map shows up as one wrong shade, not
  as a broken theme; if the base theme is missing the palette falls back to its own `gtk_theme`.
- Icons: Papirus ships every folder icon as a symlink to a colour variant (`folder.svg` ->
  `folder-blue.svg`, `user-home.svg` -> `user-blue-home.svg`). The generated theme only RE-POINTS
  those ~1000 symlinks at the matching colour variant and inherits the rest. Nothing is recoloured, so
  the artwork cannot go muddy.
- Both are cached: the palette file's sha256 goes into `.qs-palette` / `.qs-keys` inside the generated
  theme. First generation ~10 s, a repeat switch ~0.4 s. Deleting those files forces a rebuild.
- The palette directory is `/etc/qs-palettes` (NOT `~/.local/share/themes`) EXACTLY because
  `~/.local/share/themes` is a path GTK searches: Home Manager owns `qs-palettes` read-only, and the
  `themes` dir has to stay writable for generated output.
- `pal` only reads QUOTED values, so every colours.toml key must be `"quoted"` - `generate_gtk = true`
  silently reads as empty.

**niri border** - the palette colours it through `include "~/.local/state/theme/niri.kdl"`
(the last line of `config.kdl`) and a generated file, so a switch recolours window borders without a
rebuild. TWO traps, both verified the hard way:

- niri has a documented "border special case": writing `layout { border { ... } }` in the MAIN config
  enables the border, but the same section in an INCLUDED file does nothing unless it contains an
  explicit `on`. Without that line the border silently disappears the moment it moves to the include.
- the colours must not be `foreground`/`muted`. `muted` is a text tone; a 2px dark-muted border on a
  dark wallpaper is invisible and reads as "the border is gone". The palettes carry `border_active`
  and `border_inactive` for this.
- a wrong colour and a missing border look identical on screen. Verify by counting exact-colour
  pixels in a `grim` screenshot, not by eyeballing: a 2px border around a large window is ~10k px.

**qs-lock** - the config is rendered by `theme-apply` (it removed `home/theme-palette.nix` and the
Nix-generated file). The rules from the hand-written version are preserved in the renderer: one
option per line with a literal value, comments only on their own line, no `ignore-empty-password`.

**starship** - stays on its own `gruvbox_dark` palette in `home/starship.nix`. Starship reads ONE
config file that Home Manager owns, so sharing the runtime palette would mean rendering the whole
prompt config from a template; not worth it until the prompt matters. It is the only colour surface
left that does not follow the theme.

**Obsidian** - a CSS SNIPPET in the vault (`.obsidian/snippets/qs-theme.css`), enabled once in
`appearance.json`; the community theme ("Obsidian gruvbox") stays installed and only its colours are
overridden. The vault is two-way synced through Syncthing, so `theme-apply` writes a `.stignore`
excluding `.obsidian/appearance.json` and `.obsidian/snippets/`: the styling is per-machine.

**Wallpaper** - drawn by the shell, not by a daemon. `main/wallpaper/Wallpaper.qml` creates one
layer-shell surface per output on the BACKGROUND layer (`WlrLayershell.layer: WlrLayer.Background`,
anchored to all four edges), and `main/theme/WallpaperState.qml` feeds it the path from
`$XDG_STATE_HOME/theme/wallpaper` - the same file `theme-apply` and `wallpaper-next` write. There is
no daemon to start, no socket to reconnect and no output that can appear "too late": a monitor
connected later simply gets its own surface from the Screen Variants.

**Persistence** - `wallpaper-session` runs at login only to SEED a state dir that does not exist yet
(fresh install): it calls `theme-apply "$(theme-current)" --no-rotate` when `theme.json`, the recorded
wallpaper path, or the image itself is missing, and exits in milliseconds otherwise. It no longer
applies an image - the shell does that from the state file the moment it exists.

**Traps paid for here**
- `QtObject` has no default property: a bare `Process { }` child in a singleton is a parse error
  ("Cannot assign to non-existent default property"). Declare it as `property Process reader:
  Process { ... }`.
- Qt only decodes an image format whose plugin is on `QT_PLUGIN_PATH`. The `quickshell` wrapper brings
  qtbase/qtsvg/qtwayland but NOT qtimageformats, so every `.webp` wallpaper failed with "Error
  decoding: Unsupported image format" and the background stayed empty. `home/quickshell.nix` adds
  `qt6.qtimageformats` to the unit's `QT_PLUGIN_PATH`; the wrapper prepends its own paths and keeps
  what is already there, so nothing else is lost.
- `FileView.watchChanges` fires `fileChanged` BEFORE the new contents are read: calling `text()` inside
  that handler returns the previous line, so a wallpaper switch looked like it did nothing. Treat
  `fileChanged` as "reload now" (`reload()`) and read the text in `onLoaded`.
- A singleton needs `theme/qmldir` listing it (`singleton ThemeState 1.0 ThemeState.qml`); without
  the qmldir `import "theme"` cannot resolve it and every component fails with "Type Theme unavailable".
- btop OWNS `btop.conf` (it rewrites the file on exit), so it must not be a Nix symlink. theme-apply
  only forces `color_theme = "qs"` into the writable file.
- Ghostty's `theme` accepts an absolute path to a custom theme file - that is what makes the static
  config possible.
