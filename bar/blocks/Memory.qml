import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

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
  }

  Tooltip {
    relativeItem: hoverArea.containsMouse ? hoverArea : null

    Column {
      spacing: 2
      Label {
        readonly property real usedGB: (Math.max(totalKB - availKB, 0)) / 1024.0 / 1024.0
        readonly property real totalGB: totalKB / 1024.0 / 1024.0
        text: usedGB.toFixed(1) + " / " + totalGB.toFixed(1) + " GB"
      }
      Label {
        text: Math.floor(percentUsed) + "%"
      }
    }
  }
}
