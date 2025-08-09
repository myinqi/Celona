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
    implicitWidth: 150
    implicitHeight: 60
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          // Dynamic spacing and centering: 3px below (top bar) or 3px above (bottom bar)
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
        anchors.fill: parent
        anchors.margins: 10
        text: "Left: Power menu\nRight: Lock screen"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
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
