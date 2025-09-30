import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../utils" as Utils
import "root:/"
import Qt5Compat.GraphicalEffects

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
  // Dynamic compositor icon
  property url iconSource: Utils.CompositorUtils.isHyprland ? "../assets/hyprland.svg" : "../assets/niri.svg"
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
    // Render original SVG into an offscreen source
    Image {
      id: iconImg
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      source: root.iconSource
      smooth: true
      antialiasing: true
      visible: false // hidden; ColorOverlay displays the tinted result
    }
    // Apply a color overlay to tint the icon to the active border color
    ColorOverlay {
      anchors.fill: iconImg
      source: iconImg
      color: Globals.barBorderColor || "#00bee7"
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
        fuzzelProc.running = true
      } else if (mouse.button === Qt.RightButton) {
        ghosttyProc.running = true
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
        text: "Left: Fuzzel\nRight: Ghostty"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }


  // Left click: fuzzel launcher
  Process {
    id: fuzzelProc
    running: false
    command: ["bash", "-lc", "sleep 0.2; pkill fuzzel || fuzzel >/dev/null 2>&1 & disown || true"]
  }

  // Right click: open Ghostty terminal
  Process {
    id: ghosttyProc
    running: false
    command: ["bash", "-lc", "ghostty >/dev/null 2>&1 & disown || true"]
  }
}
