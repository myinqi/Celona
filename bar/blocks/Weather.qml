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
  // forecast (today + next days). Each item: { label, glyph, min, max }
  property var forecast: []
  // anti-flap & retry
  property int _retryCount: 0
  property bool _debounceBusy: false
  property bool _ipReady: true
  property bool _pendingReload: false
  // extra metadata from wttr.in
  property string regionName: ""
  property string population: ""

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

  // Geocode a place name via Open-Meteo and then fetch fallback forecast
  function fetchGeoAndFallback(name) {
    if (!name || String(name).length === 0) return
    const q = encodeURIComponent(String(name))
    const url = `https://geocoding-api.open-meteo.com/v1/search?name=${q}&count=1&language=en&format=json`
    httpGet(url, text => {
      try {
        const g = JSON.parse(text)
        if (!g || !g.results || !g.results[0]) { if (root.debugWeather) console.log('[Weather] geocode: no results'); return }
        const r = g.results[0]
        const lat = r.latitude
        const lon = r.longitude
        if (typeof lat === 'number' && typeof lon === 'number') {
          if (root.debugWeather) console.log('[Weather] geocode found coords', lat, lon)
          fetchForecastFallback(lat, lon)
        } else {
          if (root.debugWeather) console.log('[Weather] geocode invalid coords', lat, lon)
        }
      } catch (e) { if (root.debugWeather) console.log('[Weather] geocode parse error', e) }
    })
  }

  // WMO weathercode to glyph (Open-Meteo)
  function iconForWmo(code) {
    const n = parseInt(code, 10) || 0
    // Clear
    if (n === 0) return "󰖙"
    // Mainly clear / partly cloudy
    if ([1,2].indexOf(n) !== -1) return "󰖚"
    // Overcast
    if (n === 3) return "󰖚"
    // Fog
    if ([45,48].indexOf(n) !== -1) return "󰖒"
    // Drizzle
    if ([51,53,55,56,57].indexOf(n) !== -1) return "󰖖"
    // Rain
    if ([61,63,65,66,67,80,81,82].indexOf(n) !== -1) return "󰼳"
    // Snow
    if ([71,73,75,77,85,86].indexOf(n) !== -1) return "󰖘"
    // Thunder
    if ([95,96,99].indexOf(n) !== -1) return "󰖗"
    return "󰖕"
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
          text: root.loading ? "Weather" : (root.regionName && root.regionName.length > 0 ? `${root.placeText} (${root.regionName})` : `${root.placeText}`)
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.pixelSize: 12
          elide: Text.ElideRight
        }
        Text {
          visible: !root.loading && (root.population && root.population.length > 0)
          text: `Population: ${root.population}`
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.pixelSize: 12
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
        }
        Text {
          text: root.loading ? "Loading…" : `${root.description}`
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.pixelSize: 12
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
        }
        Text {
          text: root.loading ? "--°" : `Now: ${root.tempText}  Min: ${root.minText}  Max: ${root.maxText}`
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.pixelSize: 12
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
        }

        // Forecast list
        Item { height: 6; width: 1 }
        Text {
          visible: root.forecast && root.forecast.length > 0
          text: "Forecast"
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.pixelSize: 12
          font.bold: true
        }
        Text {
          visible: !root.loading && (!root.forecast || root.forecast.length === 0)
          text: "No forecast available"
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.pixelSize: 12
        }
        Repeater {
          model: root.forecast
          delegate: Row {
            spacing: 8
            Text {
              text: modelData.label
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.pixelSize: 12
              width: 80
              wrapMode: Text.NoWrap
              elide: Text.ElideNone
            }
            Text {
              text: modelData.glyph
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.pixelSize: 12
            }
            Text {
              text: `${modelData.min} / ${modelData.max}`
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.pixelSize: 12
            }
          }
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

    // Build forecast list from json.weather (today + next days)
    try {
      const days = Array.isArray(json.weather) ? json.weather : []
      if (root.debugWeather) console.log('[Weather] days in json.weather:', days.length)
      const items = []
      // Build forecast starting from tomorrow (index 1)
      const start = 1
      const futureCount = Math.min(Math.max(days.length - start, 0), 3)
      for (let j = 0; j < futureCount; j++) {
        try {
          const i = start + j
          const d = days[i]
          if (!d) { if (root.debugWeather) console.log('[Weather] empty day at', i); continue }
          const minRaw = (u === "F") ? d.mintempF : d.mintempC
          const maxRaw = (u === "F") ? d.maxtempF : d.maxtempC
          if (minRaw === undefined || maxRaw === undefined) { if (root.debugWeather) console.log('[Weather] no min/max at', i); continue }
          const min = minRaw
          const max = maxRaw
          // Pick a middle hourly slot for icon when available, guarding for non-array hourly
          const hourlyArr = (d && Array.isArray(d.hourly)) ? d.hourly : []
          const h = hourlyArr.length ? hourlyArr[Math.min(4, hourlyArr.length - 1)] : null
          let wcode = code
          if (h && typeof h === 'object' && h.weatherCode) {
            wcode = h.weatherCode
          } else if (hourlyArr.length && typeof hourlyArr[0] === 'object' && hourlyArr[0].weatherCode) {
            wcode = hourlyArr[0].weatherCode
          }
          // Labels in English: Tomorrow, then date string
          let label = (i === 1) ? "Tomorrow" : (d && d.date ? String(d.date) : `Day ${i}`)
          items.push({
            label: label,
            glyph: iconFor(wcode),
            min: `${parseFloat(min)}°${u}`,
            max: `${parseFloat(max)}°${u}`
          })
        } catch (ie) {
          if (root.debugWeather) console.log('[Weather] skip day index', i, ie)
        }
      }
      root.forecast = items
      if (root.debugWeather) console.log('[Weather] forecast items:', items.length)
    } catch (e) {
      // leave forecast empty on error
      root.forecast = []
    }
    root.loading = false
  }

  function httpGet(url, cb, errCb) {
    try {
      const xhr = new XMLHttpRequest()
      xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
          if (root.debugWeather) console.log('[Weather] HTTP', xhr.status, url)
          if (xhr.status >= 200 && xhr.status < 300) cb(xhr.responseText)
          else {
            if (typeof errCb === 'function') {
              errCb(xhr.status, url)
              return
            }
            // transient retry
            if (_retryCount < 2) { _retryCount++; if (retryTimer.running) retryTimer.stop(); retryTimer.start() }
            else loading = false
          }
        }
      }
      xhr.onerror = function() {
        if (root.debugWeather) console.log('[Weather] XHR network error', url)
        if (typeof errCb === 'function') {
          errCb(0, url)
          return
        }
        if (_retryCount < 2) { _retryCount++; if (retryTimer.running) retryTimer.stop(); retryTimer.start() }
        else loading = false
      }
      xhr.open('GET', url)
      xhr.send()
    } catch (e) { if (root.debugWeather) console.log('[Weather] xhr error', e) }
  }

  function fetchWeather(loc) {
    if (!loc) return
    // clear metadata until new data arrives
    root.regionName = ""
    root.population = ""
    // Pre-set display name for manual entries
    if (root.manualLoc) {
      root.placeText = String(loc).trim()
    }
    const q = encodeURIComponent(String(loc).trim())
    // Use http (not https) to avoid Qt HTTP/2 GOAWAY warnings from wttr.in
    httpGet(`http://wttr.in/${q}?format=j1&num_of_days=5`, text => {
      try {
        const json = JSON.parse(text)
        applyCurrent(json)
        // Resolve pretty area name if available
        const area = json.nearest_area && json.nearest_area[0]
        const city = area && area.areaName && area.areaName[0] ? area.areaName[0].value : ""
        const region = area && area.region && area.region[0] ? area.region[0].value : ""
        const country = area && area.country && area.country[0] ? area.country[0].value : ""
        // set extra metadata when available
        root.regionName = region || ""
        root.population = area && area.population ? String(area.population).trim() : ""
        if (!root.manualLoc) {
          root.placeText = [city, (region || country)].filter(function(s){ return s && s.length > 0 }).join(", ")
        }
        // Fallback: ensure at least 3 future days. Use nearest_area coords with Open-Meteo when wttr returns only 3 total days
        if (!root.forecast || root.forecast.length < 3) {
          if (root.debugWeather) console.log('[Weather] forecast too short from wttr:', (root.forecast ? root.forecast.length : 0))
          function parseCoord(v) {
            try {
              let x = v
              if (Array.isArray(x)) x = x[0] && (x[0].value !== undefined ? x[0].value : x[0])
              if (x === undefined || x === null) return NaN
              x = String(x).trim().replace(/[NESW]/gi, '')
              const n = parseFloat(x)
              return isNaN(n) ? NaN : n
            } catch (_) { return NaN }
          }
          const lat = area ? parseCoord(area.latitude) : NaN
          const lon = area ? parseCoord(area.longitude) : NaN
          if (!isNaN(lat) && !isNaN(lon)) {
            if (root.debugWeather) console.log('[Weather] using wttr coords for fallback', lat, lon)
            fetchForecastFallback(lat, lon)
          } else {
            const name = root.manualLoc ? String(loc).trim() : (root.placeText || String(loc).trim())
            if (root.debugWeather) console.log('[Weather] no coords from wttr, geocoding', name)
            fetchGeoAndFallback(name)
          }
        }
      } catch (e) {
        if (root.debugWeather) console.log('[Weather] parse error', e)
        if (_retryCount < 2) { _retryCount++; if (retryTimer.running) retryTimer.stop(); retryTimer.start() }
        else loading = false
      }
    })
  }

  // Fallback daily forecast via Open-Meteo to ensure >=3 future days
  function fetchForecastFallback(lat, lon) {
    try {
      const days = 5
      const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=${days}`
      httpGet(url, text => {
        try {
          const o = JSON.parse(text)
          if (!o || !o.daily || !o.daily.time) return
          const u = unitSuffix()
          const items = []
          const times = o.daily.time
          const tmax = o.daily.temperature_2m_max
          const tmin = o.daily.temperature_2m_min
          const w = o.daily.weathercode
          // Start from tomorrow index 1, take up to 3
          const count = Math.min(3, times.length - 1)
          for (let j = 0; j < count; j++) {
            const i = 1 + j
            const label = (j === 0) ? "Tomorrow" : String(times[i])
            const max = tmax && tmax[i] !== undefined ? tmax[i] : "-"
            const min = tmin && tmin[i] !== undefined ? tmin[i] : "-"
            const wc = w && w[i] !== undefined ? w[i] : 0
            items.push({
              label: label,
              glyph: iconForWmo(wc),
              min: `${parseFloat(min)}°${u}`,
              max: `${parseFloat(max)}°${u}`
            })
          }
          if (items.length >= 3) {
            root.forecast = items
            if (root.debugWeather) console.log('[Weather] fallback forecast items (open-meteo):', items.length)
          }
        } catch (e) { if (root.debugWeather) console.log('[Weather] fallback parse error', e) }
      })
    } catch (e) { if (root.debugWeather) console.log('[Weather] fallback error', e) }
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
          } catch (e) { if (root.debugWeather) console.log('[Weather] ipinfo parse error', e) }
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
