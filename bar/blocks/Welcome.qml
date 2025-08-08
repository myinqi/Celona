import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // Appearance
  // Use custom image instead of font glyph
  // Path relative to this file (bar/blocks -> bar/assets)
  property url iconSource: "../assets/hyprland-icon.png"
  // Fine-tune visual alignment to match glyph-based icons
  property int iconSize: 22   // typical visual size matching text glyphs
  property int iconYOffset: 0 // nudge up/down if needed
  property int iconXOffset: -6 // nudge left/right if needed

  // Render image centered, with consistent size relative to 34px bar height
  content: Item {
    width: root.iconSize
    height: root.iconSize
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: root.iconXOffset
    anchors.verticalCenterOffset: root.iconYOffset
    Image {
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      source: root.iconSource
      smooth: true
      antialiasing: true
    }
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
    implicitWidth: 155
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
