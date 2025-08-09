import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: text
  content: BarText {
    // Symbol für Arbeitsspeicher aus Symbols Nerd Font (nf-mdi-memory: )
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: " " + Math.floor(percentUsed) + "%"
  }

  // Show used memory percent based on MemTotal and MemAvailable
  property real percentUsed: 0
  property int totalKB: 0
  property int availKB: 0

  Process {
    id: memProc
    // Robust über /proc/meminfo: gib TotalKB und AvailableKB aus (space-separated)
    command: [
      "sh", "-c",
      "awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf(\"%d %d\\n\", t, a)}' /proc/meminfo"
    ]
    running: true

    stdout: SplitParser {
      onRead: data => {
        const parts = String(data).trim().split(/\s+/);
        if (parts.length >= 2) {
          totalKB = Number(parts[0]);
          availKB = Number(parts[1]);
          if (totalKB > 0 && !isNaN(availKB)) {
            percentUsed = Math.round(((totalKB - availKB) / totalKB) * 100);
          }
        }
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: memProc.running = true
  }

  // Tooltip mit detaillierten Infos (verwendet/gesamt in GB, 1 Nachkommastelle)
  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
  }

  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: contentCol.implicitWidth + 20
    implicitHeight: contentCol.implicitHeight + 20
    color: "transparent"

    anchor {
      window: text.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = text.QsWindow?.window
        if (win) {
          const gap = 3
          tipWindow.anchor.rect.y = (Globals.barPosition === "top")
            ? (tipWindow.anchor.window.height + gap)
            : (-gap)
          tipWindow.anchor.rect.x = win.contentItem.mapFromItem(text, text.width / 2, 0).x
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
      border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
      border.width: 1
      radius: 8

      Column {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2
        Text {
          // compute GB inline: KB -> GB (divide by 1024^2)
          text: ((Math.max(totalKB - availKB, 0)) / 1048576).toFixed(1)
                + " / " + (totalKB / 1048576).toFixed(1) + " GB"
          color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        }
        Text {
          text: Math.floor(percentUsed) + "%"
          color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        }
      }
    }
  }
}
