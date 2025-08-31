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

  // Niri integration only for now
  readonly property bool isNiri: !Utils.CompositorUtils.isHyprland

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

  // Click handler
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    onEntered: { if (!menuWindow.visible) tipWindow.visible = true }
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
    onVisibleChanged: if (visible) tipWindow.visible = false

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
                Text {
                  text: `${title || app || "Window"}`
                  color: Globals.popupText
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                  width: parent.width - wsText.width - 16
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

  // Query windows on Niri; best-effort parsing and graceful fallback
  function refreshWindows() {
    if (!isNiri) return
    winQueryBuf = ""
    niriListProc.command = ["bash", "-lc", "niri msg -j windows 2>/dev/null || niri msg -j tree 2>/dev/null || true"]
    niriListProc.running = true
  }

  function setWindows(arr) {
    windows = arr || []
    contentModel.clear()
    for (let i = 0; i < windows.length; i++) {
      const w = windows[i]
      contentModel.append({ id: w.id, title: w.title, app: w.app, workspace: w.workspace })
    }
  }

  // Focus using Niri actions (subject to installed version capabilities)
  function focusWindow(model) {
    if (!isNiri) return
    const id = model.id
    const ws = model.workspace
    // Try to focus workspace first (if provided)
    if (ws !== undefined && ws !== null) {
      niriActionProc.command = ["bash", "-lc", `niri msg action focus-workspace ${ws} || true`]
      niriActionProc.running = true
    }
    // Try focus-window by id (if available)
    if (id !== undefined && id !== null) {
      niriActionProc2.command = ["bash", "-lc", `niri msg action focus-window ${id} || true`]
      niriActionProc2.running = true
    }
    // Short refresh
    Qt.callLater(() => refreshWindows())
    menuWindow.visible = false
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
        root.setWindows(list)
      } catch (e) {
        root.setWindows([])
      }
    }
  }

  Process { id: niriActionProc; running: false }
  Process { id: niriActionProc2; running: false }

  // Keep in sync with compositor events (reuse CompositorUtils event stream)
  Connections {
    target: Utils.CompositorUtils
    enabled: isNiri
    function onWorkspacesChanged() { if (menuWindow.visible) refreshWindows() }
    function onActiveTitleChanged() { if (menuWindow.visible) refreshWindows() }
  }
}
