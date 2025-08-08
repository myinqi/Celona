import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // Appearance
  // Use a settings gear icon. Change via iconGlyph if you prefer another symbol.
  property string iconGlyph: "" // Nerd Font gear

  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: root.iconGlyph
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true

    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false

    onClicked: (mouse) => {
      tipWindow.visible = false
      if (mouse.button === Qt.LeftButton) sidebarProc.running = true
    }
  }

  // Tooltip below the bar, consistent with CPU/GPU/Network
  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: 200
    implicitHeight: 44
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
        text: "Open Settings App"
        color: "#ffffff"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  Process {
    id: sidebarProc
    running: false
    command: ["sh", "-c", "flatpak run com.ml4w.sidebar"]
    stdout: SplitParser { onRead: data => console.log(`[Welcome] OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Welcome] ERR: ${String(data)}`) }
  }
}
