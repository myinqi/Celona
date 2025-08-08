pragma Singleton

import Quickshell

Singleton {
  // Global popup context used by Tooltip.qml
  property PopupContext popupContext: PopupContext {}

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
    // Window title
    windowTitleColor = "#00bee7"
  }
}
