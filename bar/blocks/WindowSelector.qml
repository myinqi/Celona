import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"
import "../utils" as Utils

BarBlock {
  id: root

  // Appearance
  property string iconGlyph: "󰍉" // magnifier; adjust if desired

  // Internal model of windows
  property var windows: [] // [{ id, title, app, workspace }]
  // Map: workspace internal id -> displayed index (per-output)
  property var _niriWsIndexById: ({})
  property string _niriWsBuf: ""

  // Map common app classes to Nerd Font glyphs for a small icon in the list
  function iconForApp(appName) {
    const a = String(appName || "").toLowerCase()
    // Common mappings; extend as needed
    if (a.includes("firefox")) return "󰈹"
    if (a.includes("chromium") || a.includes("chrome")) return ""
    if (a.includes("vscode") || a.includes("code")) return ""
    if (a.includes("kitty")) return "󰄛"
    if (a.includes("alacritty")) return "󰞷"
    if (a.includes("ghostty")) return "󱘖"
    if (a.includes("wezterm")) return "󰮤"
    if (a.includes("foot")) return "󰆍"
    if (a.includes("terminal") || a.includes("term")) return ""
    if (a.includes("thunar") || a.includes("nautilus") || a.includes("dolphin") || a.includes("nemo")) return "󰉋"
    if (a.includes("spotify")) return "󰓇"
    if (a.includes("discord")) return "󰙯"
    if (a.includes("steam")) return ""
    if (a.includes("vlc")) return "󰕼"
    if (a.includes("gimp")) return ""
    if (a.includes("inkscape")) return ""
    if (a.includes("libreoffice") || a.includes("writer")) return "󰈬"
    if (a.includes("signal")) return "󰍩"
    if (a.includes("thunderbird")) return "󰇰"
    if (a.includes("obsidian")) return "󰠮"
    if (a.includes("obs")) return "󰐰"
    if (a.includes("gcolor") || a.includes("color")) return "󰏘"
    // Fallback generic window icon
    return "󰣆"
  }

  // Niri integration only for now
  readonly property bool isHyprland: Utils.CompositorUtils.isHyprland
  readonly property bool isNiri: !isHyprland

  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolSpacing: 0
    symbolText: root.iconGlyph
  }

  // Hover tooltip (label)
  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: tipLabel.implicitWidth + 20
    implicitHeight: tipLabel.implicitHeight + 20
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          const gap = 3
          tipWindow.anchor.rect.y = (Globals.barPosition === "top")
            ? (tipWindow.anchor.window.height + gap)
            : (-gap)
          tipWindow.anchor.rect.x = win.contentItem.mapFromItem(root, root.width / 2, 0).x
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
      border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
      border.width: 1
      radius: 8

      Text {
        id: tipLabel
        anchors.fill: parent
        anchors.margins: 10
        text: "Window selector"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        wrapMode: Text.NoWrap
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  // Hyprland: list clients and map to windows
  Process {
    id: hyprListProc
    running: false
    stdout: SplitParser { onRead: data => { root.winQueryBuf += String(data) } }
    onRunningChanged: if (!running) {
      try {
        const txt = String(root.winQueryBuf || "").trim()
        let list = []
        if (txt) {
          const arr = JSON.parse(txt)
          for (let i = 0; i < arr.length; i++) {
            const c = arr[i] || {}
            // Hyprland client has address, class, title, workspace: { id }
            const addr = c.address || c.addr || null
            const title = c.title || ""
            const app = c.class || c.app || ""
            const ws = (c.workspace && (c.workspace.id !== undefined)) ? c.workspace.id : null
            list.push({ id: addr, title: title, app: app, workspace: ws })
          }
        }
        root.setWindows(list)
      } catch (e) {
        root.setWindows([])
      }
    }
  }

  // Click handler
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    onEntered: {
      if (!menuWindow.visible && (!Globals.popupContext || !Globals.popupContext.popup)) {
        tipWindow.visible = true
      }
    }
    onExited: tipWindow.visible = false
    onClicked: () => { tipWindow.visible = false; togglePopup() }
  }

  // Popup with window list
  PopupWindow {
    id: menuWindow
    visible: false
    // Size explicitly based on rows (avoid relying on Layout implicit sizing)
    property int rowHeight: 34
    property int listHeight: Math.max(160, Math.min(480, Math.max(1, contentModel.count) * rowHeight))
    implicitWidth: 360
    implicitHeight: listHeight + 20
    color: "transparent"
    onVisibleChanged: {
      if (visible) {
        tipWindow.visible = false
        if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== menuWindow) {
          if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
        }
        if (Globals.popupContext) Globals.popupContext.popup = menuWindow
      } else {
        if (Globals.popupContext && Globals.popupContext.popup === menuWindow) Globals.popupContext.popup = null
      }
    }

    anchor {
      window: root.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          const gap = 5
          const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(root.height + gap))
          menuWindow.anchor.rect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onExited: { if (!containsMouse) closeTimer.start() }
      onEntered: closeTimer.stop()
      Timer { id: closeTimer; interval: 500; onTriggered: menuWindow.visible = false }

      Rectangle {
        anchors.fill: parent
        color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
        border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
        border.width: 1
        radius: 8

        Column {
          id: contentCol
          anchors.fill: parent
          anchors.margins: 10
          spacing: 8

          // Window list
          ListView {
            id: list
            width: menuWindow.width - 20
            height: menuWindow.listHeight
            clip: true
            model: contentModel
            delegate: Rectangle {
              width: list.width
              height: menuWindow.rowHeight
              radius: 6
              color: mouse.containsMouse ? Globals.hoverHighlightColor : "transparent"
              Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                // Small app icon glyph
                Text {
                  id: iconText
                  text: iconForApp(app)
                  color: Globals.moduleIconColor !== "" ? Globals.moduleIconColor : (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF")
                  font.family: "Symbols Nerd Font Mono"
                  font.pixelSize: 14
                  verticalAlignment: Text.AlignVCenter
                  width: 18
                }
                Text {
                  text: `${title || app || "Window"}`
                  color: Globals.popupText
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                  width: parent.width - wsText.width - iconText.width - 16
                }
                Text {
                  id: wsText
                  text: workspace !== undefined && workspace !== null ? `ws ${workspace}` : ""
                  color: Globals.moduleIconColor
                  verticalAlignment: Text.AlignVCenter
                  horizontalAlignment: Text.AlignRight
                  width: 54
                }
              }
              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: () => focusWindow({ id: id, workspace: workspace })
              }
            }
          }
        }
      }
    }
  }

  // Backing model and filtering
  ListModel { id: contentModel }

  function togglePopup() {
    if (root.QsWindow?.window?.contentItem) {
      refreshWindows()
      menuWindow.visible = !menuWindow.visible
    }
  }

  // Query windows on Niri; robust mapping of workspace IDs using JSON workspaces
  function refreshWindows() {
    if (isHyprland) {
      winQueryBuf = ""
      hyprListProc.command = ["bash", "-lc", "hyprctl clients -j 2>/dev/null || true"]
      hyprListProc.running = true
      return
    }
    if (isNiri) {
      winQueryBuf = ""
      // First gather windows; then we will fetch JSON workspaces to build a mapping
      niriListProc.command = ["bash", "-lc", "niri msg -j windows 2>/dev/null || niri msg -j tree 2>/dev/null || true"]
      niriListProc.running = true
    }
  }

  // Pending Niri windows until we build the workspace map
  property var _pendingNiriWindows: []

  function setWindows(arr) {
    windows = arr || []
    contentModel.clear()
    // Helper: normalize Niri workspace numbers using a mapping from `niri msg -j workspaces`
    function mapNiriWs(ws) {
      const n = Number(ws)
      if (!root.isNiri || isNaN(n)) return ws
      if (_niriWsIndexById && _niriWsIndexById[n] !== undefined) return _niriWsIndexById[n]
      return ws
    }
    for (let i = 0; i < windows.length; i++) {
      const w = windows[i]
      const wsFinal = (w.workspace !== undefined && w.workspace !== null) ? mapNiriWs(w.workspace) : w.workspace
      contentModel.append({ id: w.id, title: w.title, app: w.app, workspace: wsFinal })
    }
  }

  // Focus using Niri actions (subject to installed version capabilities)
  function focusWindow(model) {
    const id = model.id
    const ws = model.workspace
    if (isHyprland) {
      if (ws !== undefined && ws !== null) {
        hyprWsProc.command = ["bash", "-lc", `hyprctl dispatch workspace ${ws} || true`]
        hyprWsProc.running = true
      }
      if (id !== undefined && id !== null) {
        // id carries the client's address for Hyprland
        hyprFocusProc.command = ["bash", "-lc", `hyprctl dispatch focuswindow address:${id} || true`]
        hyprFocusProc.running = true
      }
      menuWindow.visible = false
      return
    }
    if (isNiri) {
      if (ws !== undefined && ws !== null) {
        niriActionProc.command = ["bash", "-lc", `niri msg action focus-workspace ${ws} || true`]
        niriActionProc.running = true
      }
      if (id !== undefined && id !== null) {
        niriActionProc2.command = ["bash", "-lc", `niri msg action focus-window ${id} || true`]
        niriActionProc2.running = true
      }
      Qt.callLater(() => refreshWindows())
      menuWindow.visible = false
    }
  }

  // Processes
  property string winQueryBuf: ""
  Process {
    id: niriListProc
    running: false
    stdout: SplitParser { onRead: data => { root.winQueryBuf += String(data) } }
    onRunningChanged: if (!running) {
      try {
        const txt = String(root.winQueryBuf || "").trim()
        let list = []
        if (txt && txt[0] === '[') {
          // Expecting array of windows
          const arr = JSON.parse(txt)
          for (let i = 0; i < arr.length; i++) {
            const w = arr[i] || {}
            list.push({ id: w.id ?? w.window_id ?? w.handle ?? null, title: w.title || w.name || "", app: w.app_id || w.class || "", workspace: w.workspace ?? w.workspace_id ?? w.ws ?? null })
          }
        } else if (txt && txt[0] === '{') {
          // Tree object; attempt to traverse generically
          const obj = JSON.parse(txt)
          function walk(node, ws) {
            if (!node) return
            const kind = node.kind || node.type || ""
            const title = node.title || node.name || ""
            const app = node.app_id || node.class || ""
            const id = node.id || node.window_id || node.handle || null
            const wsId = node.workspace || node.workspace_id || ws || null
            if (kind.toLowerCase().indexOf("window") !== -1 && (title || app)) {
              list.push({ id: id, title: title, app: app, workspace: wsId })
            }
            const ch = node.children || node.nodes || []
            for (let i = 0; i < ch.length; i++) walk(ch[i], wsId)
          }
          walk(obj, null)
        } else {
          // Plain text fallback: one window per line
          const lines = txt.split(/\r?\n/)
          for (let i = 0; i < lines.length; i++) {
            const s = lines[i].trim()
            if (!s) continue
            list.push({ id: null, title: s, app: "", workspace: null })
          }
        }
        // For Niri: fetch workspace mapping before filling model
        if (root.isNiri) {
          root._pendingNiriWindows = list
          root._niriWsBuf = ""
          niriWsJsonProc.command = ["bash", "-lc", "niri msg -j workspaces 2>/dev/null || true"]
          niriWsJsonProc.running = true
        } else {
          root.setWindows(list)
        }
      } catch (e) {
        root.setWindows([])
      }
    }
  }

  Process {
    id: niriWsJsonProc
    running: false
    stdout: SplitParser { onRead: data => { root._niriWsBuf += String(data) } }
    onRunningChanged: if (!running) {
      try {
        const txt = String(root._niriWsBuf || "").trim()
        if (txt && txt[0] === '[') {
          const arr = JSON.parse(txt)
          const map = {}
          for (let i = 0; i < arr.length; i++) {
            const ws = arr[i] || {}
            map[ws.id] = ws.index
          }
          root._niriWsIndexById = map
          root.setWindows(root._pendingNiriWindows)
        }
      } catch (e) {
        root.setWindows(root._pendingNiriWindows)
      }
    }
  }

  Process { id: niriActionProc; running: false }
  Process { id: niriActionProc2; running: false }
  Process { id: hyprWsProc; running: false }
  Process { id: hyprFocusProc; running: false }

  // Keep in sync with compositor events (reuse CompositorUtils event stream)
  Connections {
    target: Utils.CompositorUtils
    enabled: isNiri || isHyprland
    function onWorkspacesChanged() { if (menuWindow.visible) refreshWindows() }
    function onActiveTitleChanged() { if (menuWindow.visible) refreshWindows() }
  }
}
