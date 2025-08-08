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
  property bool hasController: false
  property bool powered: false
  property bool blocked: false // rfkill soft blocked
  // Expose a simple on/off status for display
  property string status: ""   // on | off

  // Waybar-like: hide the block when status is off
  visible: status === "on"

  function updateStatus() {
    // Consider Bluetooth ON if it's powered and not rfkill-blocked
    status = (powered && !blocked) ? "on" : "off"
  }

  // UI
  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    // Bluetooth icon (Material Design Nerd Font) — more reliable in Symbols NF
    // Compose icon + space + status in symbolText, since BarText renders from symbolText
    symbolText: "" + (status.length ? (" " + status) : "")
    symbolSpacing: 1
  }

  // Click/hover
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
    onClicked: {
      // Open Bluetooth manager
      openProc.command = ["sh", "-c", "blueman-manager >/dev/null 2>&1 & disown || true"]
      openProc.running = true
    }
  }

  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: 158
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
      color: palette.active.toolTipBase
      border.color: palette.active.light
      border.width: 1
      radius: 8

      Text {
        anchors.fill: parent
        anchors.margins: 10
        text: "Bluetooth Manager"
        color: "#ffffff"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  // Processes
  // Poll both Powered and rfkill Soft blocked atomically to avoid flicker
  Process {
    id: btAllProc
    running: false
    command: [
      "sh", "-c",
      "p=$(bluetoothctl show 2>/dev/null | awk -F: '/Powered|Eingeschaltet/{gsub(/^ \\t+|^ +/,\"\",$2); print tolower($2); exit}'); " +
      "b=$(rfkill list bluetooth 2>/dev/null | awk -F: '/Soft blocked/{gsub(/^ \\t+|^ +/,\"\",$2); print tolower($2); exit}'); " +
      "echo p=$p b=$b"
    ]
    stdout: SplitParser {
      onRead: data => {
        const out = String(data).trim()
        const m = out.match(/p=([^\s]+)\s+b=([^\s]+)/)
        if (m) {
          const p = m[1]
          const b = m[2]
          const truthy = ["yes","ja","on","ein","1","true"]
          root.powered = truthy.indexOf(p) !== -1
          root.blocked = ["yes","ein","1","true"].indexOf(b) !== -1
          // If we received any powered token, assume controller present
          root.hasController = root.hasController || (p.length > 0)
          root.updateStatus()
        }
      }
    }
  }

  // Launch blueman-manager
  Process { id: openProc; running: false; command: ["sh", "-c", "true"] }

  // Poll
  Timer {
    interval: 10000 // refresh every 10s for quicker feedback
    repeat: true
    running: true
    onTriggered: { btAllProc.running = true }
  }

  Component.onCompleted: { btAllProc.running = true }
}
