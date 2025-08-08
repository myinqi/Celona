import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // State
  property int count: 0
  property string raw: ""

  // Waybar-like: hide if no updates
  visible: count > 0

  // UI
  content: BarText {
    id: txt
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: " " + count
    symbolSpacing: 5
  }

  // Tooltip
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        openInstall.command = ["sh", "-c", "~/.config/ml4w/settings/installupdates.sh >/dev/null 2>&1 & disown || true"]
        openInstall.running = true
      } else if (mouse.button === Qt.RightButton) {
        openSoftware.command = ["sh", "-c", "~/.config/ml4w/settings/software.sh >/dev/null 2>&1 & disown || true"]
        openSoftware.running = true
      }
    }
  }

  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: 110
    implicitHeight: 40
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
        text: count > 0 ? `Updates: ${count}` : "No updates"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  // Processes
  Process {
    id: updatesProc
    running: false
    command: ["sh", "-c", "~/.config/ml4w/scripts/updates.sh 2>/dev/null"]
    stdout: SplitParser {
      onRead: data => {
        raw = String(data)
        // Try JSON first (Waybar return-type json)
        try {
          const obj = JSON.parse(raw)
          if (obj && (typeof obj.text === 'string' || typeof obj.text === 'number')) {
            const n = parseInt(obj.text)
            if (!isNaN(n)) root.count = n
            return
          }
        } catch (e) {}
        // Fallback: first integer in the output
        const m = raw.match(/\b(\d+)\b/)
        root.count = m ? parseInt(m[1]) : 0
      }
    }
  }

  // Launchers
  Process { id: openInstall; running: false; command: ["sh", "-c", "true"] }
  Process { id: openSoftware; running: false; command: ["sh", "-c", "true"] }

  function refreshNow() {
    updatesProc.running = true
  }

  // Polling like Waybar (30 min)
  Timer {
    interval: 1800000
    repeat: true
    running: true
    onTriggered: refreshNow()
  }

  Component.onCompleted: refreshNow()
}
