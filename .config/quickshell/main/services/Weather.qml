pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "WeatherIcons.js" as WeatherIcons

// Live weather from wttr.in: no API key, no account. The bar segment and the
// weather tab of the date & time panel both read this singleton, so there is
// exactly one fetch loop.
//
// City search uses Photon (komoot, OpenStreetMap data) - a geocoder built for
// type-ahead. Open-Meteo's geocoder was tried first and answered "Jak" with
// Jakmel and "New" with Nnewi, which is useless while typing. A picked city is
// stored WITH its coordinates so wttr.in cannot land on a same-named village
// somewhere else.
//
// A failed fetch keeps the last reading - a dropped packet must not blank the
// bar - and raises `failed` so the panel can mark the reading as stale.
Singleton {
  id: root

  // ------------------------------------------------------------------- state
  // One line of JSON:
  //   {"name":"New York","detail":"New York · United States","lat":40.71,"lon":-74.01,"coords":true}
  //
  // A plain name is accepted too (the older format, and what free text typed
  // without picking a suggestion produces). An empty or missing file means "let
  // wttr.in pick the city from the public IP address".
  //
  // A plain XDG path rather than Quickshell.statePath("..."): that helper is a
  // METHOD (using it as a property stringifies the function and writes to a
  // file literally named "function() { [native code] }"), and it also
  // namespaces every path per shell root under state/quickshell/by-shell/
  // <hash>/, which makes the file impossible to find by hand.
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
  readonly property string stateFile: root.stateDir + "/weather.txt"

  property string placeName: ""
  property string placeDetail: ""
  property double placeLat: 0
  property double placeLon: 0
  property bool placeHasCoords: false

  readonly property bool hasPlace: placeName !== ""

  property var current: null        // { temp, feels, humidity, wind, windDir, desc, code, area }
  property var forecast: []         // [{ date, hi, lo, code }]
  property bool failed: false
  property bool fetching: false
  property bool refreshPending: false
  property double updatedAt: 0

  // Type-ahead results, each { name, detail, lat, lon }.
  property var suggestions: []
  property string suggestionQuery: ""

  readonly property bool ready: current !== null
  readonly property string place: hasPlace ? placeName : (current ? current.area : "")
  readonly property string tempText: current ? current.temp + "\u00B0" : ""
  readonly property string icon: current ? WeatherIcons.icon(current.code) : ""

  readonly property string url: root.placeHasCoords
    ? "https://wttr.in/" + root.placeLat + "," + root.placeLon + "?format=j1"
    : "https://wttr.in/" + encodeURIComponent(root.placeName.replace(/\s+/g, "+")) + "?format=j1"

  // ------------------------------------------------------------ fetch cycle
  Process {
    id: fetch

    command: ["curl", "-fsS", "--max-time", "12", root.url]

    onStarted: root.fetching = true

    stdout: StdioCollector {
      onStreamFinished: root.parse(this.text)
    }

    onExited: (code) => {
      root.fetching = false

      if (code !== 0)
        root.failed = true

      // A refresh asked for while this fetch was in flight would otherwise be
      // swallowed - which is exactly what happened after a location change.
      if (root.refreshPending) {
        root.refreshPending = false
        root.refresh()
      }
    }
  }

  // wttr.in is not built for hammering: a quarter-hour refresh is plenty for a
  // bar label, and the panel reads the same cached reading.
  Timer {
    interval: 900000
    running: true
    repeat: true

    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()

  function refresh() {
    if (fetch.running) {
      root.refreshPending = true
      return
    }

    fetch.running = true
  }

  // ------------------------------------------------------------------ parse
  function parse(payload) {
    if (!payload || payload.trim() === "")
      return

    let data = null
    try {
      data = JSON.parse(payload)
    } catch (error) {
      root.failed = true
      return
    }

    const reading = data.current_condition && data.current_condition[0]
    if (!reading)
      return

    const area = data.nearest_area && data.nearest_area[0]
    const astro = data.weather && data.weather[0] && data.weather[0].astronomy
      ? data.weather[0].astronomy[0]
      : null

    root.current = {
      "temp": reading.temp_C,
      "feels": reading.FeelsLikeC,
      "humidity": reading.humidity,
      "wind": reading.windspeedKmph,
      "windDir": reading.winddir16Point,
      "uv": reading.uvIndex,
      "sunrise": astro && astro.sunrise ? astro.sunrise : "-",
      "sunset": astro && astro.sunset ? astro.sunset : "-",
      "desc": reading.weatherDesc && reading.weatherDesc[0] ? reading.weatherDesc[0].value : "",
      "code": reading.weatherCode,
      "area": area && area.areaName ? area.areaName[0].value : ""
    }

    const days = data.weather || []
    const parsed = []

    for (let i = 0; i < days.length; i++) {
      parsed.push({
        "date": days[i].date,
        "hi": days[i].maxtempC,
        "lo": days[i].mintempC,
        "code": root.noonCode(days[i]),
        "rain": root.rainChance(days[i])
      })
    }

    root.forecast = parsed
    root.failed = false
    root.updatedAt = Date.now()
  }

  // One icon per day: the noon observation represents the day better than the
  // first or the last hourly entry.
  function noonCode(day) {
    const hours = day.hourly || []

    for (let i = 0; i < hours.length; i++)
      if (hours[i].time === "1200")
        return hours[i].weatherCode

    return hours.length > 0 ? hours[hours.length - 1].weatherCode : ""
  }

  // Highest chance of rain reported for that day: one number that answers "do I
  // need to plan around rain", which a hi/lo pair alone does not.
  function rainChance(day) {
    const hours = day.hourly || []
    let max = 0

    for (let i = 0; i < hours.length; i++) {
      const value = Number(hours[i].chanceofrain)
      if (isFinite(value) && value > max)
        max = value
    }

    return max
  }

  // Same glyph table, for a forecast entry that only carries a code.
  function forecastIcon(code) {
    return WeatherIcons.icon(code)
  }

  // ------------------------------------------------------- city type-ahead
  Process {
    id: suggestFetch

    command: ["curl", "-fsS", "--max-time", "8",
      "https://photon.komoot.io/api/?q=" + encodeURIComponent(root.suggestionQuery) + "&limit=6&lang=en"]

    stdout: StdioCollector {
      onStreamFinished: root.parseSuggestions(this.text)
    }
  }

  // Called for every keystroke; the popup owns the debounce delay.
  function suggest(query) {
    const cleaned = String(query === undefined || query === null ? "" : query).trim()

    if (cleaned.length < 2) {
      root.suggestions = []
      return
    }

    root.suggestionQuery = cleaned
    suggestFetch.running = false
    suggestFetch.running = true
  }

  function clearSuggestions() {
    root.suggestions = []
  }

  function parseSuggestions(payload) {
    if (!payload || payload.trim() === "")
      return

    let data = null
    try {
      data = JSON.parse(payload)
    } catch (error) {
      return
    }

    const features = data.features || []
    const out = []

    for (let i = 0; i < features.length; i++) {
      const props = features[i].properties || {}
      const coords = features[i].geometry ? features[i].geometry.coordinates : null

      if (!props.name || !coords || coords.length < 2)
        continue

      const parts = []
      if (props.state && props.state !== props.name)
        parts.push(props.state)
      if (props.country && props.country !== props.name)
        parts.push(props.country)

      out.push({
        "name": props.name,
        "detail": parts.join(" \u00B7 "),
        "lat": coords[1],
        "lon": coords[0]
      })
    }

    root.suggestions = out
  }

  // Picking a suggestion stores the coordinates, so the reading is that exact
  // place even when the name exists in several countries.
  function chooseSuggestion(item) {
    if (!item)
      return

    root.placeName = String(item.name)
    root.placeDetail = String(item.detail === undefined ? "" : item.detail)
    root.placeLat = Number(item.lat)
    root.placeLon = Number(item.lon)
    root.placeHasCoords = isFinite(root.placeLat) && isFinite(root.placeLon)
    root.suggestions = []
    root.persist()
    root.refresh()
  }

  // ------------------------------------------------------------------ place
  // Free text: no coordinates, wttr.in resolves the name itself.
  function setLocation(name) {
    // Newlines would break the one-line state file; everything else passes
    // through, so a name like "New York, NY" keeps working.
    const cleaned = String(name === undefined || name === null ? "" : name)
      .replace(/[\r\n]+/g, " ")
      .trim()

    root.placeName = cleaned
    root.placeDetail = ""
    root.placeLat = 0
    root.placeLon = 0
    root.placeHasCoords = false
    root.suggestions = []
    root.persist()
    root.refresh()
  }

  function persist() {
    if (root.placeName === "") {
      stateWriter.write("")
      return
    }

    stateWriter.write(JSON.stringify({
      "name": root.placeName,
      "detail": root.placeDetail,
      "lat": root.placeLat,
      "lon": root.placeLon,
      "coords": root.placeHasCoords
    }))
  }

  // Persisted through a command instead of FileView's writer: the state
  // directory does not exist on a fresh install and only a command can create
  // it. The value travels as a positional argument, never interpolated into the
  // script, so quotes and spaces in a place name cannot break the write.
  Process {
    id: stateWriter

    function write(value) {
      running = false
      command = ["sh", "-c",
        "mkdir -p \"$1\" && printf '%s\\n' \"$2\" > \"$3\"",
        "sh", root.stateDir, value, root.stateFile]
      running = true
    }
  }

  FileView {
    id: locationFile

    path: root.stateFile
    blockLoading: true
    watchChanges: false
    printErrors: false

    onLoaded: {
      const text = locationFile.text().trim()
      if (text === "")
        return

      let stored = null
      try {
        stored = JSON.parse(text)
      } catch (error) {
        stored = null
      }

      if (stored && stored.name) {
        root.placeName = String(stored.name)
        root.placeDetail = String(stored.detail === undefined ? "" : stored.detail)
        root.placeLat = Number(stored.lat === undefined ? 0 : stored.lat)
        root.placeLon = Number(stored.lon === undefined ? 0 : stored.lon)
        root.placeHasCoords = stored.coords === true
      } else {
        // Older format: one bare place name.
        root.placeName = text
        root.placeDetail = ""
        root.placeHasCoords = false
      }

      root.refresh()
    }

    // A missing file is the normal first run, not a problem: wttr.in then
    // picks the city from the public IP.
    onLoadFailed: (error) => {
    }
  }
}
