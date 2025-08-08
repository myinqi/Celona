import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // Appearance
  // Using the same Nerd Font icon you use in Waybar: ""
  // If you prefer another glyph (e.g. nf-md-power), let me know.
  property string iconGlyph: ""

  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: root.iconGlyph
  }

  // Click handling: left -> wlogout script, right -> hyprlock
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true

    // Show tooltip below the bar (like CPU/Sound) to avoid covering the icon
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false

    onClicked: (mouse) => {
      tipWindow.visible = false
      if (mouse.button === Qt.LeftButton) {
        powerProc.running = true
      } else if (mouse.button === Qt.RightButton) {
        lockProc.running = true
      }
    }
  }

  // Tooltip style and positioning (under the bar)
  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: 220
    implicitHeight: 60
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Edges.Top
      gravity: Edges.Bottom
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          // Match bar/Tooltip.qml spacing and centering: 3px below bar, centered under block
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
        text: "Left: Power menu\nRight: Lock screen"
        color: "#ffffff"
        wrapMode: Text.NoWrap
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  // Processes to trigger actions
  Process {
    id: powerProc
    running: false
    // Use sh -c so ~ expansion works
    command: ["sh", "-c", "~/.config/ml4w/scripts/wlogout.sh"]
    stdout: SplitParser { onRead: data => console.log(`[Power] OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Power] ERR: ${String(data)}`) }
  }

  Process {
    id: lockProc
    running: false
    command: ["sh", "-c", "hyprlock"]
    stdout: SplitParser { onRead: data => console.log(`[Power] LOCK OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Power] LOCK ERR: ${String(data)}`) }
  }
}
