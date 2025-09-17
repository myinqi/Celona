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
  // Track a compact hash of the last applied list to avoid unnecessary model resets (prevents scroll jumps)
  property string _lastListHash: ""
  // Map: workspace internal id -> displayed index (per-output)
  property var _niriWsIndexById: ({})
  property string _niriWsBuf: ""
  // Map: window-id -> workspace index (derived from tree)
  property var _winIdToWsIndex: ({})
  property string _niriTreeBuf: ""
  // Map: window-id -> workspace id (derived from tree)
  property var _winIdToWsId: ({})
  // Map: workspace id -> 1-based order index (built from workspaces JSON, sorted by number/index)
  property var _wsIdToOrderIndex: ({})

  // Map common app classes/titles to Nerd Font glyphs for a small icon in the list
  function iconForApp(appName, titleText) {
    const a = String(appName || "").toLowerCase()
    const t = String(titleText || "").toLowerCase()
    // Common mappings; extend as needed
    if (a.includes("firefox")) return "󰈹"
    if (a.includes("zen")) return ""    
    if (a.includes("chromium") || a.includes("chrome")) return ""
    if (a.includes("vscode") || a.includes("code")) return ""
    if (a.includes("windsurf")) return ""    
    if (a.includes("kitty")) return ""
    if (a.includes("alacritty")) return ""
    if (a.includes("ghostty")) return ""
    // Celona Setup: match either app id/class or window title
    if (a.includes("celona") || t.includes("celona")) return ""    
    if (a.includes("wezterm")) return "󰮤"
    if (a.includes("foot")) return "󰆍"
    if (a.includes("terminal") || a.includes("term")) return ""
    if (a.includes("thunar") || a.includes("nautilus") || a.includes("dolphin") || a.includes("nemo")) return "󰉋"
    if (a.includes("spotify")) return "󰓇"
    if (a.includes("discord")) return "󰙯"
    if (a.includes("steam")) return ""
    if (a.includes("haruna")) return ""    
    if (a.includes("gimp")) return ""      
    if (a.includes("vlc")) return "󰕼"
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
    mainFont: Globals.mainFontFamily
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
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
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
    // Max height: ~70% of window height minus margins; fallback if window not available
    property int maxListHeight: Math.max(180, Math.floor(((root.QsWindow && root.QsWindow.window) ? root.QsWindow.window.height : 900) * 0.7) - 80)
    // Dynamic list height: up to maxListHeight, otherwise fit rows
    property int listHeight: Math.min(maxListHeight, Math.max(1, contentModel.count) * rowHeight)
    implicitWidth: 360
    // Account for header + margins by using the Column's implicitHeight
    // (Column includes headerRow + spacing + ListView height, plus we have 20px outer padding)
    implicitHeight: contentCol ? (contentCol.implicitHeight + 20) : (listHeight + 60)
    color: "transparent"
    // While true, periodic/compositor refreshes are deferred to avoid interrupting user scroll/hover
    property bool deferRefresh: false
    // Debounce timer to release the defer flag shortly after user interaction
    Timer { id: deferRelease; interval: 700; repeat: false; onTriggered: menuWindow.deferRefresh = false }
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
      // Do not consume clicks/wheel so ListView can scroll and receive interactions
      acceptedButtons: Qt.NoButton
      onWheel: (event) => { menuWindow.deferRefresh = true; deferRelease.restart(); event.accepted = false }
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

          // Header similar to Clipboard
          RowLayout {
            id: headerRow
            spacing: 10
            Layout.fillWidth: true
            Text {
              text: "Window selector"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
              font.bold: true
              color: Globals.popupText !== "" ? Globals.popupText : "#ddd"
              Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true }
          }

          // Window list
          ListView {
            id: list
            width: menuWindow.width - 20
            height: menuWindow.listHeight
            clip: true
            model: contentModel
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            onMovementStarted: { menuWindow.deferRefresh = true; deferRelease.restart() }
            onFlickStarted: { menuWindow.deferRefresh = true; deferRelease.restart() }
            onMovementEnded: { deferRelease.restart() }
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
                  text: iconForApp(app, title)
                  color: (Globals.visualizerBarColorEffective && Globals.visualizerBarColorEffective !== "")
                           ? Globals.visualizerBarColorEffective
                           : (Globals.visualizerBarColor !== "" ? Globals.visualizerBarColor : "#00bee7")
                  font.family: "Symbols Nerd Font Mono"
                  font.pixelSize: Globals.mainFontSize
                  verticalAlignment: Text.AlignVCenter
                  width: 18
                }
                Text {
                  text: `${title || app || "Window"}`
                  color: Globals.popupText
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                  width: parent.width - wsText.width - iconText.width - 16
                }
                Text {
                  id: wsText
                  text: workspace !== undefined && workspace !== null ? `ws ${workspace}` : ""
                  color: (Globals.visualizerBarColorEffective && Globals.visualizerBarColorEffective !== "")
                           ? Globals.visualizerBarColorEffective
                           : (Globals.visualizerBarColor !== "" ? Globals.visualizerBarColor : "#00bee7")
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
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

  // Query windows on Niri; robust mapping of workspace using tree (preferred) or workspaces (fallback)
  function refreshWindows() {
    if (isHyprland) {
      winQueryBuf = ""
      hyprListProc.command = ["bash", "-lc", "hyprctl clients -j 2>/dev/null || true"]
      hyprListProc.running = true
      return
    }
    if (isNiri) {
      // Reset caches to avoid stale mappings across rapid layout changes
      _niriWsIndexById = ({})
      _wsIdToOrderIndex = ({})
      _niriWsBuf = ""
      winQueryBuf = ""
      // List windows in JSON (array) and map their workspace ids -> display idx using workspaces JSON
      niriListProc.command = ["bash", "-lc", "niri msg -j windows 2>/dev/null || true"]
      niriListProc.running = true
    }
  }

  // Pending Niri windows until we build the mapping
  property var _pendingNiriWindows: []

  function setWindows(arr) {
    windows = arr || []
    // Build a compact hash to detect no-op updates and avoid resetting the model (prevents scroll jumps)
    try {
      const compact = []
      for (let i = 0; i < windows.length; i++) {
        const w = windows[i] || {}
        compact.push([w.id, w.title, w.app, w.workspace])
      }
      const h = Qt.md5(JSON.stringify(compact))
      if (menuWindow.visible && (menuWindow.deferRefresh || h === _lastListHash)) {
        // Skip updating while user interacts or when content is unchanged
        return
      }
      _lastListHash = h
    } catch (e) { /* ignore hashing errors and proceed */ }

    // Preserve scroll position if visible
    const keepY = (menuWindow.visible && list) ? list.contentY : 0
    contentModel.clear()
    // Helper: derive workspace display index for a Niri window using workspaces JSON
    function mapNiriWsFromWorkspaceId(wsId) {
      if (!root.isNiri) return wsId
      if (wsId === undefined || wsId === null) return wsId
      const idNum = Number(wsId)
      if (!isNaN(idNum) && _wsIdToOrderIndex && _wsIdToOrderIndex[idNum] !== undefined)
        return _wsIdToOrderIndex[idNum]
      if (!isNaN(idNum) && _niriWsIndexById && _niriWsIndexById[idNum] !== undefined)
        return _niriWsIndexById[idNum]
      return wsId
    }
    for (let i = 0; i < windows.length; i++) {
      const w = windows[i]
      const wsFinal = mapNiriWsFromWorkspaceId(w.workspace)
      contentModel.append({ id: w.id, title: w.title, app: w.app, workspace: wsFinal })
    }
    // Restore scroll position
    if (menuWindow.visible && list) {
      Qt.callLater(() => { list.contentY = keepY })
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
          // Fallback: windows array (will need a separate mapping for workspace numbers)
          const arr = JSON.parse(txt)
          for (let i = 0; i < arr.length; i++) {
            const w = arr[i] || {}
            list.push({ id: w.id ?? w.window_id ?? w.handle ?? null, title: w.title || w.name || "", app: w.app_id || w.class || "", workspace: w.workspace ?? w.workspace_id ?? w.ws ?? null })
          }
        } else {
          // Plain text fallback: one window per line
          const lines = txt.split(/\r?\n/)
          for (let i = 0; i < lines.length; i++) {
            const s = lines[i].trim()
            if (!s) continue
            list.push({ id: null, title: s, app: "", workspace: null })
          }
        }
        // Build mapping via workspaces JSON then set windows
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

  // Parse `niri msg -j workspaces` to build id->index fallback
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
          const order = []
          for (let i = 0; i < arr.length; i++) {
            const ws = arr[i] || {}
            const wsId = (ws.id !== undefined) ? ws.id : ws.workspace_id
            // Prefer 'idx' (observed schema). Fallbacks: 'number' (1-based) or 'index' (0-based => +1)
            let idx = undefined
            if (ws.idx !== undefined) idx = Number(ws.idx)
            else if (ws.number !== undefined) idx = Number(ws.number)
            else if (ws.index !== undefined) idx = Number(ws.index) + 1
            if (wsId !== undefined && idx !== undefined) {
              const idNum = Number(wsId)
              map[idNum] = idx
              order.push({ id: idNum, idx })
            }
          }
          root._niriWsIndexById = map
          // Build stable order map (sorted by idx ascending) => 1-based positions
          order.sort((a,b) => a.idx - b.idx)
          const idToOrder = {}
          for (let i = 0; i < order.length; i++) idToOrder[order[i].id] = i + 1
          root._wsIdToOrderIndex = idToOrder
        }
      } catch (e) {
        // ignore; keep mapping empty
      }
      root.setWindows(root._pendingNiriWindows)
      root._pendingNiriWindows = []
    }
  }

  // (Removed tree mapping: not supported on this Niri version)

  Process { id: niriActionProc; running: false }
  Process { id: niriActionProc2; running: false }
  Process { id: hyprWsProc; running: false }
  Process { id: hyprFocusProc; running: false }

  // Periodic refresh while the popup is visible to track rapid changes (e.g., renumbering)
  Timer {
    id: menuRefresh
    interval: 700
    repeat: true
    running: menuWindow.visible && isNiri && !menuWindow.deferRefresh
    onTriggered: if (!menuWindow.deferRefresh) refreshWindows()
  }

  // Keep in sync with compositor events (reuse CompositorUtils event stream)
  Connections {
    target: Utils.CompositorUtils
    enabled: isNiri || isHyprland
    function onWorkspacesChanged() { if (menuWindow.visible && !menuWindow.deferRefresh) refreshWindows() }
    function onActiveTitleChanged() { if (menuWindow.visible && !menuWindow.deferRefresh) refreshWindows() }
  }
}
