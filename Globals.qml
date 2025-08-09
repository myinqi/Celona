pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
  // Global popup context used by Tooltip.qml
  property PopupContext popupContext: PopupContext {}
  readonly property string themeFile: "~/.config/quickshell/Celona/theme.json"
  property string _themeBuf: ""

  // THEME COLORS (defaults reflect current bar style)
  // Bar
  property string barBgColor: "#40000000"
  property string barBorderColor: "#00bee7"
  // Bar position: "top" or "bottom"
  property string barPosition: "top"
  // Distance (px) from chosen screen edge to the bar (0–10 typical)
  property int barEdgeMargin: 0
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
  property bool showBattery: true
  property bool showDate: true
  property bool showTime: true
  property bool showPower: true

  // Reorder mode: when true, bar shows drag UI and allows reordering directly
  property bool reorderMode: false

  // Custom order for right-side modules (used for dynamic rendering)
  // Default matches current static order
  property var rightModulesOrder: [
    "SystemTray","Updates","Network","Bluetooth","CPU","GPU","Memory",
    "PowerProfiles","Clipboard","Notifications","Sound","Battery","Date","Time","Power"
  ]

  // Window title
  property string windowTitleColor: "#00bee7"

  // Reset all theme colors to their built-in defaults
  function resetTheme() {
    // Bar
    barBgColor = "#40000000"
    barBorderColor = "#00bee7"
    barPosition = "top"
    barEdgeMargin = 0
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
    // SystemTray
    trayIconColor = ""
    // Module toggles
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
    rightModulesOrder = [
      "SystemTray","Updates","Network","Bluetooth","CPU","GPU","Memory",
      "PowerProfiles","Clipboard","Notifications","Sound","Battery","Date","Time","Power"
    ]
    // Window title
    windowTitleColor = "#00bee7"
  }

  // Apply keys from a loaded theme object safely
  function applyTheme(obj) {
    if (!obj) return
    // Preserve original types from JSON (booleans must stay booleans)
    function setIf(k) { if (obj[k] !== undefined) Globals[k] = obj[k] }
    setIf("barBgColor")
    setIf("barBorderColor")
    setIf("barPosition")
    setIf("barEdgeMargin")
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
    setIf("showBattery")
    setIf("showDate")
    setIf("showTime")
    setIf("showPower")
    setIf("windowTitleColor")
  }

  // Load theme from file on startup handled by loadThemeProc.running

  // Save current theme to file
  function saveTheme() {
    const obj = {
      // Preferred top-level positioning keys
      barPosition,
      barEdgeMargin,
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
      // Layout & behavior
      reorderMode,
      rightModulesOrder,
      // Module toggles
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
      showBattery,
      showDate,
      showTime,
      showPower
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
    }
  }

  Process { id: saveThemeProc; running: false }

  // Note: we don't use Component.onCompleted in Singleton context
}
