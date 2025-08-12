import Quickshell
import QtQuick
import QtQuick.Layouts
import "../"
import "root:/"

BarBlock {
  id: root
  // presentation
  property string tempText: "--°"
  property string glyph: "󰖕" // default: cloudy
  property string placeText: ""
  property string description: ""
  property string minText: "--°"
  property string maxText: "--°"
  property bool loading: true
  property string lastLoc: ""
  property bool manualLoc: false
  // anti-flap & retry
  property int _retryCount: 0
  property bool _debounceBusy: false
  property bool _ipReady: true
  property bool _pendingReload: false

  // Sizing similar to other blocks
  readonly property int pad: 6
  implicitHeight: 24
  Layout.preferredHeight: implicitHeight

  // If the block becomes visible (e.g., recreated/moved in reorder), ensure we have data
  onVisibleChanged: {
    if (visible && (tempText === "--°" || loading)) {
      reload()
    }
  }

  // Consistent module text using BarText (icon + value colors from Globals)
  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolSpacing: 0
    symbolText: `${root.glyph} ${root.tempText}`
  }

  // Tooltip
  PopupWindow {
    id: tip
    visible: false
    color: "transparent"
    // size to content like other modules
    implicitWidth: tipCol.implicitWidth + 20
    implicitHeight: tipCol.implicitHeight + 20

    anchor {
      window: root.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          const gap = 3
          // anchor similarly to Sound tooltip
          tip.anchor.rect.y = (Globals.barPosition === "top")
            ? (tip.anchor.window.height + gap)
            : (-gap)
          tip.anchor.rect.x = win.contentItem.mapFromItem(root, root.width / 2, 0).x
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: 8
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1

      Column {
        id: tipCol
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        Text {
          text: root.loading ? "Weather" : `${root.placeText}`
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.pixelSize: 12
          elide: Text.ElideRight
        }
        Text {
          text: root.loading ? "Lade…" : `${root.description}`
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.pixelSize: 12
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
        }
        Text {
          text: root.loading ? "--°" : `Aktuell: ${root.tempText}  Min: ${root.minText}  Max: ${root.maxText}`
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.pixelSize: 12
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: tip.visible = true
    onExited: tip.visible = false
  }

  // Close tooltip when bar position flips (top <-> bottom)
  Connections {
    target: Globals
    function onBarPositionChanged() { if (tip.visible) tip.visible = false }
  }

  // Fetch logic using wttr.in
  function iconFor(code) {
    // Map wttr weatherCode to Nerd Font weather glyphs (fallback: cloudy)
    const n = parseInt(code, 10) || 0
    // Sunny / Clear
    if (n === 113) return "󰖙"
    // Partly cloudy / Cloudy
    if ([116,119,122].indexOf(n) !== -1) return "󰖚"
    // Mist / Fog
    if ([143,248,260].indexOf(n) !== -1) return "󰖒"
    // Light rain
    if ([176,263,266,293,296,299,302].indexOf(n) !== -1) return "󰖖"
    // Heavy rain
    if ([305,308].indexOf(n) !== -1) return "󰼳"
    // Thunder
    if ([200,386,389].indexOf(n) !== -1) return "󰖗"
    // Snow
    if ([179,182,227,230,338,368,371].indexOf(n) !== -1) return "󰖘"
    // Default cloudy
    return "󰖕"
  }

  function unitSuffix() { return Globals.weatherUnit === "F" ? "F" : "C" }

  function applyCurrent(json) {
    const cur = json.current_condition && json.current_condition[0] ? json.current_condition[0] : null
    const day0 = json.weather && json.weather[0] ? json.weather[0] : null
    if (!cur) return
    const u = unitSuffix()
    const t = u === "F" ? cur.temp_F : cur.temp_C
    root.tempText = `${parseFloat(t)}°${u}`
    root.description = cur.weatherDesc && cur.weatherDesc[0] ? cur.weatherDesc[0].value : ""
    if (day0) {
      const min = u === "F" ? day0.mintempF : day0.mintempC
      const max = u === "F" ? day0.maxtempF : day0.maxtempC
      root.minText = `${parseFloat(min)}°${u}`
      root.maxText = `${parseFloat(max)}°${u}`
    }
    const code = cur.weatherCode
    root.glyph = iconFor(code)
    root.loading = false
  }

  function httpGet(url, cb) {
    try {
      const xhr = new XMLHttpRequest()
      xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
          if (xhr.status >= 200 && xhr.status < 300) cb(xhr.responseText)
          else {
            console.log('[Weather] HTTP', xhr.status, url)
            // transient retry
            if (_retryCount < 2) { _retryCount++; if (retryTimer.running) retryTimer.stop(); retryTimer.start() }
            else loading = false
          }
        }
      }
      xhr.open('GET', url)
      xhr.send()
    } catch (e) { console.log('[Weather] xhr error', e) }
  }

  function fetchWeather(loc) {
    if (!loc) return
    // Pre-set display name for manual entries
    if (root.manualLoc) {
      root.placeText = String(loc).trim()
    }
    const q = encodeURIComponent(String(loc).trim())
    httpGet(`https://wttr.in/${q}?format=j1`, text => {
      try {
        const json = JSON.parse(text)
        applyCurrent(json)
        // Resolve pretty area name if available
        const area = json.nearest_area && json.nearest_area[0]
        const city = area && area.areaName && area.areaName[0] ? area.areaName[0].value : ""
        const region = area && area.region && area.region[0] ? area.region[0].value : ""
        const country = area && area.country && area.country[0] ? area.country[0].value : ""
        if (!root.manualLoc) {
          root.placeText = [city, (region || country)].filter(function(s){ return s && s.length > 0 }).join(", ")
        }
      } catch (e) {
        console.log('[Weather] parse error', e)
        if (_retryCount < 2) { _retryCount++; if (retryTimer.running) retryTimer.stop(); retryTimer.start() }
        else loading = false
      }
    })
  }

  function reload() {
    // Debounce excessive reloads during reorder moves; queue a trailing call
    if (_debounceBusy) { _pendingReload = true; return }
    _debounceBusy = true
    if (debounceTimer.running) debounceTimer.stop();
    debounceTimer.start()
    _retryCount = 0
    loading = true
    const loc = (Globals.weatherLocation && Globals.weatherLocation.length > 0) ? Globals.weatherLocation : ""
    if (loc) {
      root.lastLoc = loc
      root.manualLoc = true
      fetchWeather(loc)
    } else {
      // Auto via IP at most every 15 minutes using cooldown timer
      if (_ipReady) {
        httpGet("https://ipinfo.io/json", text => {
          try {
            const o = JSON.parse(text)
            root.lastLoc = o.loc || ""
            fetchWeather(root.lastLoc)
            _ipReady = false
            if (ipCooldown.running) ipCooldown.stop();
            ipCooldown.start()
            root.manualLoc = false
          } catch (e) { console.log('[Weather] ipinfo parse error', e) }
        })
      } else {
        loading = false
      }
    }
  }

  // Refresh every 10 minutes
  Timer { interval: 10 * 60 * 1000; running: true; repeat: true; onTriggered: reload() }
  // Re-fetch when unit/location changes; ensure debouncer won't swallow it
  Connections {
    target: Globals
    function onWeatherUnitChanged() {
      if (debounceTimer.running) debounceTimer.stop();
      _debounceBusy = false; _pendingReload = false; reload()
    }
    function onWeatherLocationChanged() {
      root.manualLoc = (Globals.weatherLocation && Globals.weatherLocation.length > 0)
      if (root.manualLoc) { root.placeText = String(Globals.weatherLocation).trim() }
      if (debounceTimer.running) debounceTimer.stop();
      _debounceBusy = false; _pendingReload = false; reload()
    }
  }

  Component.onCompleted: {
    if (Globals.weatherLocation && Globals.weatherLocation.length > 0) {
      root.manualLoc = true
      root.placeText = String(Globals.weatherLocation).trim()
    }
    reload()
  }

  Timer { id: retryTimer; interval: 2000; repeat: false; onTriggered: reload() }
  Timer {
    id: debounceTimer
    interval: 1500
    repeat: false
    onTriggered: {
      _debounceBusy = false
      if (_pendingReload) { _pendingReload = false; reload() }
    }
  }
  Timer { id: ipCooldown; interval: 15 * 60 * 1000; repeat: false; onTriggered: _ipReady = true }
}
