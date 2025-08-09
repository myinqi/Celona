import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root
  // Enlarge hitbox so hover/click are easy even around the image edges
  implicitWidth: 30
  // In RowLayout, implicitWidth may be ignored. Use Layout.* to enforce width.
  Layout.preferredWidth: 20
  Layout.minimumWidth: 20
  Layout.alignment: Qt.AlignVCenter

  // Appearance
  // Use custom image instead of font glyph
  // Path relative to this file (bar/blocks -> bar/assets)
  property url iconSource: "../assets/hyprland-icon.png"
  // Fine-tune visual alignment to match glyph-based icons
  property int iconSize: 20   // typical visual size matching text glyphs
  property int iconYOffset: 0 // nudge up/down if needed
  property int iconXOffset: 5 // nudge left/right if needed

  // Render image centered, with consistent size relative to 34px bar height
  content: Item {
    id: iconItem
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true

    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false

    onClicked: (mouse) => {
      tipWindow.visible = false
      if (mouse.button === Qt.LeftButton) {
        sidebarProc.running = true
      } else if (mouse.button === Qt.RightButton) {
        rofiProc.running = true
      }
    }
  }

  // Tooltip below the bar, consistent with CPU/GPU/Network
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
          // Match Power: only adjust x/y to avoid polish loops
          const gap = 3
          tipWindow.anchor.rect.y = (Globals.barPosition === "top")
            ? (tipWindow.anchor.window.height + gap)
            : (-gap)
          tipWindow.anchor.rect.x = win.contentItem.mapFromItem(root, root.width / 2 + root.iconXOffset, 0).x
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
        text: "Left: Settings APP\nRight: Applauncher"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
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

  // Right-click: rofi app launcher (Waybar-like behavior)
  Process {
    id: rofiProc
    running: false
    command: ["sh", "-c", "sleep 0.2; pkill rofi || rofi -show drun -replace >/dev/null 2>&1 & disown || true"]
  }
}
