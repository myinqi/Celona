import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // keep compact
  leftPadding: 0
  rightPadding: 0
  // Let child buttons receive clicks (do not consume at BarBlock level)
  passClicks: true

  // expose state for play/pause icon
  property bool isPlaying: false

  content: Row {
    id: mediaCtl
    spacing: 8
    anchors.verticalCenter: parent.verticalCenter
    // Match Barvisualizer bar color (adaptive via visualizerBarColorEffective)
    property string baseColor: (
      (Globals.visualizerBarColorEffective && Globals.visualizerBarColorEffective !== "")
        ? Globals.visualizerBarColorEffective
        : (Globals.visualizerBarColor !== "" ? Globals.visualizerBarColor : "#00bee7")
    )

    // previous
    Item {
      width: 22; height: 22
      Text { anchors.centerIn: parent; text: "󰒮"; font.family: "Symbols Nerd Font Mono"; color: mediaCtl.baseColor; font.pixelSize: 16 }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: prevProc.running = true }
    }

  // Hover tooltip under the bar like other modules
  PopupWindow {
    id: tipWindow
    visible: root.mouseArea.containsMouse
    implicitWidth: tipLabel.implicitWidth + 20
    implicitHeight: tipLabel.implicitHeight + 14
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
        anchors.margins: 8
        text: "prev / next"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }
    // play/pause (dynamic)
    Item {
      width: 22; height: 22
      Text {
        anchors.centerIn: parent
        text: root.isPlaying ? "󰏤" : "󰐊"
        font.family: "Symbols Nerd Font Mono"
        color: mediaCtl.baseColor
        font.pixelSize: 16
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { toggleProc.running = true } }
    }
    // next
    Item {
      width: 22; height: 22
      Text { anchors.centerIn: parent; text: "󰒭"; font.family: "Symbols Nerd Font Mono"; color: mediaCtl.baseColor; font.pixelSize: 16 }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: nextProc.running = true }
    }
  }

  // Follow player status to toggle play/pause icon dynamically
  Process {
    id: statusProc
    running: root.visible
    command: ["sh", "-c",
      `if command -v playerctl >/dev/null 2>&1; then \\
         playerctl -F status; \\
       else \\
         echo '__PLAYERCTL_MISSING__'; \\
       fi`
    ]
    stdout: SplitParser {
      onRead: data => {
        const line = String(data).trim()
        if (line === '__PLAYERCTL_MISSING__') { statusProc.running = false; return }
        if (line === 'Playing') root.isPlaying = true
        else if (line === 'Paused' || line === 'Stopped') root.isPlaying = false
      }
    }
    stderr: SplitParser { onRead: data => console.log(`[MediaControls] status stderr: ${String(data)}`) }
  }

  // Media control processes (playerctl)
  Process { id: prevProc; running: false; command: ["sh","-c","playerctl previous || true"] }
  Process { id: toggleProc; running: false; command: ["sh","-c","playerctl play-pause || true"] }
  Process { id: nextProc; running: false; command: ["sh","-c","playerctl next || true"] }
}
