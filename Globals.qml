pragma Singleton

import Quickshell
import Quickshell.Io
import QtQml

Singleton {
  // Global popup context used by Tooltip.qml
  property PopupContext popupContext: PopupContext {}
  readonly property string themeFile: "~/.config/quickshell/Celona/config.json"
  readonly property string defaultsFile: Qt.resolvedUrl("root:/defaults")
  property string _themeBuf: ""
  // internal flags for async operations
  property bool _resetFromDefaultsRequested: false

  // THEME COLORS (defaults reflect current bar style)
  // Bar
  property string barBgColor: "#40000000"
  property string barBorderColor: "#00bee7"
  // Bar position: "top" or "bottom"
  property string barPosition: "top"
  // Visual bar height in pixels
  property int baseBarHeight: 38
  // Distance (px) from chosen screen edge to the bar (0–10 typical)
  property int barEdgeMargin: 0
  // Horizontal side margins (px) to shorten the bar from left and right equally (0–10 typical)
  property int barSideMargin: 0
  // When true, hide the full bar and only show the Setup gear window
  property bool barHidden: false
  // Hover highlight for blocks (e.g., Time)
  property string hoverHighlightColor: "#00bee7"

  // Modules (icons vs values)
  property string moduleIconColor: "#FFFFFF"
  property string moduleValueColor: "#FFFFFF"

  // Workspaces
  property string workspaceActiveBg: "#4000bee7"   // translucent cyan
  property string workspaceActiveBorder: "#00bee7"
  property string workspaceInactiveBg: "#00000000"
  property string workspaceInactiveBorder: "#00bee7"
  property string workspaceTextColor: "#FFFFFF"

  // Tooltips (leave empty to fallback to component palette)
  property string tooltipBg: ""
  property string tooltipText: "#FFFFFF"
  property string tooltipBorder: ""

  // Popups (menus) (leave empty to fallback to component palette)
  property string popupBg: ""
  property string popupText: "#FFFFFF"
  property string popupBorder: ""

  // SystemTray icons tint (empty = no tint)
  property string trayIconColor: ""

  // Module visibility toggles (default: shown)
  // Left/center
  property bool showWelcome: true
  property bool showWindowTitle: true
  property bool showWorkspaces: true
  // Right side
  property bool showSystemTray: true
  property bool showUpdates: true
  property bool showNetwork: true
  property bool showBluetooth: true
  property bool showCPU: true
  property bool showGPU: true
  property bool showMemory: true
  property bool showPowerProfiles: true
  property bool showClipboard: true
  property bool showNotifications: true
  property bool showSound: true
  // Keybinds cheatsheet
  property bool showKeybinds: false
  property bool showBattery: true
  property bool showDate: true
  property bool showTime: true
  property bool showPower: true

  // Reorder mode: when true, bar shows drag UI and allows reordering directly
  property bool reorderMode: false

  // Swap positions of WindowTitle and Workspaces (false: WindowTitle left, Workspaces center; true: Workspaces left, WindowTitle center)
  property bool swapTitleAndWorkspaces: false

  // Matugen integration
  // When true and colors.css exists in the Celona root, we apply mapped colors from it
  property bool useMatugenColors: false
  // Computed availability of colors.css
  property bool matugenAvailable: false
  // last applied colors.css content hash to detect changes
  property string _matugenHash: ""

  // Custom order for right-side modules (used for dynamic rendering)
  // Default matches current static order
  property var rightModulesOrder: [
    "SystemTray","Updates","Network","Bluetooth","CPU","GPU","Memory",
    "PowerProfiles","Clipboard","Keybinds","Notifications","Sound","Battery","Date","Time","Power"
  ]

  // Window title
  property string windowTitleColor: "#00bee7"
  // Visualizer bars color
  property string visualizerBarColor: "#00bee7"
  // Weather settings
  // Location can be "lat,lon" or a city name recognized by wttr.in
  property string weatherLocation: "" // empty => auto by IP
  // "C" or "F"
  property string weatherUnit: "C"
  // Toggle for Weather module visibility
  property bool showWeather: false

  // Keybinds cheatsheet: configurable path to Hyprland keybindings file
  // Example: "/home/USER/.config/hypr/conf/keybindings/khrom.conf"
  property string keybindsPath: ""

  // --- Matugen colors handling ---
  // Helper: convert rgba(r,g,b,a) or #RRGGBB to #AARRGGBB
  function toArgb(hexOrRgba, alphaOverride) {
    try {
      const s = String(hexOrRgba).trim()
      const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x))
      const hx = n => (n.toString(16).padStart(2, '0'))
      if (s.startsWith('rgba')) {
        const m = s.match(/rgba\(([^)]+)\)/i)
        if (!m) return '#ff000000'
        const parts = m[1].split(',').map(p => p.trim())
        let r = clamp(parseInt(parts[0], 10), 0, 255)
        let g = clamp(parseInt(parts[1], 10), 0, 255)
        let b = clamp(parseInt(parts[2], 10), 0, 255)
        let a = parts[3] !== undefined ? clamp(Math.round(parseFloat(parts[3]) * 255), 0, 255) : 255
        if (typeof alphaOverride === 'number') a = clamp(alphaOverride, 0, 255)
        return '#' + hx(a) + hx(r) + hx(g) + hx(b)
      }
      if (s.startsWith('#') && s.length === 7) {
        const a = (typeof alphaOverride === 'number') ? alphaOverride : 255
        return '#' + hx(a) + s.slice(1)
      }
      return '#ff000000'
    } catch (e) { return '#ff000000' }
  }

  function applyMatugenMap(map) {
    // Map Matugen names to our config keys
    // Fallbacks if a key is missing
    const pick = (k, d) => (map[k] !== undefined ? map[k] : d)
    const bg = pick('background', '#111318')
    const onSurf = pick('on_surface', '#e2e2e9')
    const onSurfVar = pick('on_surface_variant', '#c4c6d0')
    const invPrim = pick('inverse_primary', '#415e91')
    const hoverVar = pick('on_secondary_fixed_variant', '#3e4759')
    const blur8 = pick('blur_background8', 'rgba(17,19,24,0.8)')

    barBgColor = toArgb(blur8)
    popupBg = toArgb(bg)
    tooltipBg = toArgb(bg)
    popupText = toArgb(onSurf)
    tooltipText = toArgb(onSurf)
    popupBorder = toArgb(invPrim)
    tooltipBorder = toArgb(invPrim)
    moduleValueColor = toArgb(onSurf)
    windowTitleColor = toArgb(onSurf)
    workspaceTextColor = toArgb(onSurf)
    workspaceActiveBorder = toArgb(invPrim)
    workspaceInactiveBorder = toArgb(invPrim)
    barBorderColor = toArgb(invPrim)
    moduleIconColor = toArgb(onSurfVar)
    trayIconColor = toArgb(onSurfVar)
    hoverHighlightColor = toArgb(hoverVar)
    // active bg: inverse_primary with 0x40 alpha
    workspaceActiveBg = toArgb(invPrim, 0x40)
    workspaceInactiveBg = '#00000000'
    // visualizer bars align with border/accent
    visualizerBarColor = toArgb(invPrim)
  }

  function applyMatugenColors() {
    if (!useMatugenColors) return
    if (matugenView) matugenView.reload()
  }

  // Reset all theme colors to their built-in defaults
  function resetTheme() {
    // Prefer loading from external defaults file; fallback to built-in defaults
    _resetFromDefaultsRequested = true
    if (defaultsView) defaultsView.reload()
  }

  // Built-in defaults as a fallback when defaults file is missing/invalid
  function applyBuiltinDefaults() {
    // Bar
    barBgColor = "#40000000"
    barBorderColor = "#00bee7"
    barPosition = "top"
    baseBarHeight = 38
    barEdgeMargin = 6
    barSideMargin = 12
    barHidden = false
    hoverHighlightColor = "#00bee7"
    // Modules
    moduleIconColor = "#FFFFFF"
    moduleValueColor = "#FFFFFF"
    // Workspaces
    workspaceActiveBg = "#4000bee7"
    workspaceActiveBorder = "#00bee7"
    workspaceInactiveBg = "#00000000"
    workspaceInactiveBorder = "#00bee7"
    workspaceTextColor = "#FFFFFF"
    // Tooltips
    tooltipBg = ""
    tooltipText = "#FFFFFF"
    tooltipBorder = ""
    // Popups
    popupBg = ""
    popupText = "#FFFFFF"
    popupBorder = ""
    // System tray
    trayIconColor = ""
    // Title & visualizer
    windowTitleColor = "#00bee7"
    // Visualizer bars
    visualizerBarColor = "#00bee7"
    useMatugenColors = false
    // Weather
    weatherLocation = ""
    weatherUnit = "C"
    showWeather = true
    // Keybinds path
    keybindsPath = ""
    // Keybinds
    showKeybinds = true
    // Toggles
    showWelcome = true
    showWindowTitle = true
    showWorkspaces = true
    showSystemTray = true
    showUpdates = true
    showNetwork = true
    showBluetooth = true
    showCPU = true
    showGPU = true
    showMemory = true
    showPowerProfiles = true
    showClipboard = true
    showNotifications = true
    showSound = true
    showBattery = true
    showDate = true
    showTime = true
    showPower = true
    // Reorder defaults
    reorderMode = false
    swapTitleAndWorkspaces = false
    rightModulesOrder = [
      "SystemTray","Updates","Network","Bluetooth","CPU","GPU","Memory",
      "PowerProfiles","Battery","Clipboard","Notifications","Sound","Weather",
      "Date","Time","Keybinds","Power"
    ]
    // Window title
    windowTitleColor = "#00bee7"
    // Visualizer bars
    visualizerBarColor = "#00bee7"
    useMatugenColors = false
    // Weather
    weatherLocation = ""
    weatherUnit = "C"
    showWeather = false
    // Keybinds path
    keybindsPath = ""
    // Keybinds
    showKeybinds = false
  }

  // Apply keys from a loaded theme object safely
  function applyTheme(obj) {
    if (!obj) return
    // Preserve original types from JSON (booleans must stay booleans)
    function setIf(k) { if (obj[k] !== undefined) Globals[k] = obj[k] }
    setIf("barBgColor")
    setIf("barBorderColor")
    setIf("barPosition")
    setIf("baseBarHeight")
    setIf("barEdgeMargin")
    setIf("barSideMargin")
    setIf("barHidden")
    setIf("useMatugenColors")
    setIf("hoverHighlightColor")
    setIf("moduleIconColor")
    setIf("moduleValueColor")
    setIf("workspaceActiveBg")
    setIf("workspaceActiveBorder")
    setIf("workspaceInactiveBg")
    setIf("workspaceInactiveBorder")
    setIf("workspaceTextColor")
    setIf("tooltipBg")
    setIf("tooltipText")
    setIf("tooltipBorder")
    setIf("popupBg")
    setIf("popupText")
    setIf("popupBorder")
    setIf("trayIconColor")
    setIf("reorderMode")
    setIf("swapTitleAndWorkspaces")
    setIf("useMatugenColors")
    setIf("rightModulesOrder")
    // toggles
    setIf("showWelcome")
    setIf("showWindowTitle")
    setIf("showWorkspaces")
    setIf("showSystemTray")
    setIf("showUpdates")
    setIf("showNetwork")
    setIf("showBluetooth")
    setIf("showCPU")
    setIf("showGPU")
    setIf("showMemory")
    setIf("showPowerProfiles")
    setIf("showClipboard")
    setIf("showNotifications")
    setIf("showSound")
    setIf("showKeybinds")
    setIf("showBattery")
    setIf("showDate")
    setIf("showTime")
    setIf("showPower")
    setIf("windowTitleColor")
    setIf("visualizerBarColor")
    setIf("weatherLocation")
    setIf("weatherUnit")
    setIf("showWeather")
    setIf("keybindsPath")
  }

  // Load theme from file on startup handled by loadThemeProc.running

  // Save current theme to file
  function saveTheme() {
    const obj = {
      // Layout
      barPosition,
      baseBarHeight,
      barEdgeMargin,
      barSideMargin,
      barHidden,
      // Persist Matugen flag right after barHidden as requested
      useMatugenColors,
      // Colors
      barBgColor,
      barBorderColor,
      hoverHighlightColor,
      moduleIconColor,
      moduleValueColor,
      workspaceActiveBg,
      workspaceActiveBorder,
      workspaceInactiveBg,
      workspaceInactiveBorder,
      workspaceTextColor,
      tooltipBg,
      tooltipText,
      tooltipBorder,
      popupBg,
      popupText,
      popupBorder,
      trayIconColor,
      windowTitleColor,
      visualizerBarColor,
      // Layout & behavior
      reorderMode,
      swapTitleAndWorkspaces,
      rightModulesOrder,
      // toggles
      showWelcome,
      showWindowTitle,
      showWorkspaces,
      showSystemTray,
      showUpdates,
      showNetwork,
      showBluetooth,
      showCPU,
      showGPU,
      showMemory,
      showPowerProfiles,
      showClipboard,
      showNotifications,
      showSound,
      showKeybinds,
      showBattery,
      showDate,
      showTime,
      showPower,
      showWeather,
      // Weather (keep at end)
      weatherLocation,
      weatherUnit,
      // Keybinds (path at end for clarity)
      keybindsPath
    }
    const json = JSON.stringify(obj, null, 2)
    // Avoid complex shell escaping by writing base64 and decoding
    const b64 = Qt.btoa(json)
    saveThemeProc.command = [
      "bash", "-lc",
      "mkdir -p ~/.config/quickshell/Celona && printf '%s' '" + b64 + "' | base64 -d > " + themeFile
    ]
    saveThemeProc.running = true
  }

  Process {
    id: loadThemeProc
    // Read as base64 (single line) to avoid line-splitting issues
    command: ["bash", "-lc", "base64 -w0 " + Globals.themeFile + " 2>/dev/null || true"]
    running: true
    stdout: SplitParser {
      onRead: (data) => { Globals._themeBuf += String(data) }
    }
    onRunningChanged: if (!running) {
      if (Globals._themeBuf && Globals._themeBuf.length) {
        try {
          const jsonText = Qt.atob(Globals._themeBuf)
          Globals.applyTheme(JSON.parse(jsonText))
        } catch (e) { /* ignore parse errors */ }
      }
      Globals._themeBuf = ""
      if (Globals.useMatugenColors) Globals.applyMatugenColors()
    }
  }

  Process { id: saveThemeProc; running: false }

  // Read colors.css if present
  // Lightweight reader for defaults file
  FileView {
    id: defaultsView
    path: defaultsFile
    onLoaded: {
      if (!_resetFromDefaultsRequested) return
      _resetFromDefaultsRequested = false
      try {
        const text = defaultsView.text()
        const obj = JSON.parse(text)
        Globals.applyTheme(obj)
        Globals.saveTheme()
      } catch (e) {
        Globals.applyBuiltinDefaults()
      }
    }
    onLoadFailed: (error) => {
      if (_resetFromDefaultsRequested) {
        _resetFromDefaultsRequested = false
        Globals.applyBuiltinDefaults()
      }
    }
  }
  FileView {
    id: matugenView
    path: Qt.resolvedUrl("root:/colors.css")
    onLoaded: {
      Globals.matugenAvailable = true
      if (!Globals.useMatugenColors) return
      try {
        const text = matugenView.text()
        const hash = Qt.md5(text)
        const changed = (hash !== Globals._matugenHash)
        const lines = text.split(/\r?\n/)
        const map = {}
        for (let raw of lines) {
          const m = raw.match(/@define-color\s+([a-zA-Z0-9_\-]+)\s+([^;]+);/)
          if (m) map[m[1]] = m[2].trim()
        }
        if (changed) {
          Globals.applyMatugenMap(map)
          Globals._matugenHash = hash
          Globals.saveTheme()
        }
      } catch (e) { /* ignore */ }
    }
    onLoadFailed: (error) => { Globals.matugenAvailable = false }
  }

  // Watcher: periodically reload colors.css when Matugen is enabled to auto-apply on changes
  Timer {
    id: matugenWatch
    interval: 3000
    repeat: true
    running: Globals.useMatugenColors && Globals.matugenAvailable
    onTriggered: {
      if (Globals.useMatugenColors) matugenView.reload()
    }
  }

  // Note: we don't use Component.onCompleted in Singleton context
}
