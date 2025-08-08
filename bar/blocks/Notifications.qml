import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // swaync state from `swaync-client -swb` (JSON lines)
  property string stateClass: "none"
  property int notifCount: 0
  property bool dnd: false

  // Always visible; dim when no notifications
  visible: true

  function updateFromJson(line) {
    try {
      const obj = JSON.parse(line)
      if (obj.class) stateClass = obj.class
      if (obj.dnd !== undefined) dnd = !!obj.dnd
      if (obj.count !== undefined) notifCount = Number(obj.count) || 0
      else if (obj.text && /^\d+$/.test(obj.text)) notifCount = Number(obj.text)
      // fallthrough keeps previous values if fields missing
    } catch (e) {
      // ignore parse errors (partial lines)
    }
  }

  // Watch swaync status (streaming JSON lines)
  Process {
    id: swayncWatch
    command: ["bash", "-lc", "swaync-client -swb"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const str = String(data)
        const lines = str.split(/\r?\n/)
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i].trim()
          if (line.length > 0) updateFromJson(line)
        }
      }
    }
  }

  // Click actions
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        swayncToggle.running = true
      } else if (mouse.button === Qt.RightButton) {
        swayncDnd.running = true
      }
    }
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
  }

  Process { id: swayncToggle; command: ["sh", "-c", "swaync-client -t -sw >/dev/null 2>&1 & disown || true"]; running: false }
  Process { id: swayncDnd; command: ["sh", "-c", "swaync-client -d -sw >/dev/null 2>&1 & disown || true"]; running: false }

  // Icon mapping like Waybar
  function iconForState() {
    // Prefer explicit DND flag if provided
    if (dnd) return ""; // bell-slash / DND
    switch (stateClass) {
      case "dnd-none":
      case "dnd-notification":
      case "dnd-inhibited-notification":
        return ""; // DND icon
      case "notification":
      case "inhibited-notification":
        return ""; // bell
      case "none":
      default:
        return "";
    }
  }

  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    // Show icon + optional count
    symbolText: notifCount > 0 ? (iconForState() + "  " + notifCount) : iconForState()
    symbolSpacing: 5
    opacity: notifCount > 0 ? 1.0 : 0.9
  }

  // Tooltip under the bar
  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: 170
    implicitHeight: 60
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Edges.Top
      gravity: Edges.Bottom
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          tipWindow.anchor.rect.y = tipWindow.anchor.window.height + 3
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
        anchors.fill: parent
        anchors.margins: 10
        text: "Left: Notifications\nRight: Do not disturb"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}

