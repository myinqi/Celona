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

  // Window title
  property string windowTitleColor: "#00bee7"

  // Reset all theme colors to their built-in defaults
  function resetTheme() {
    // Bar
    barBgColor = "#40000000"
    barBorderColor = "#00bee7"
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
    // Window title
    windowTitleColor = "#00bee7"
  }

  // Apply keys from a loaded theme object safely
  function applyTheme(obj) {
    if (!obj) return
    function setIf(k) { if (obj[k] !== undefined) Globals[k] = String(obj[k]) }
    setIf("barBgColor")
    setIf("barBorderColor")
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
    setIf("windowTitleColor")
  }

  // Load theme from file on startup handled by loadThemeProc.running

  // Save current theme to file
  function saveTheme() {
    const obj = {
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
      windowTitleColor
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
