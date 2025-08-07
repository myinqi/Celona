import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

BarBlock {
  id: text
  content: BarText {
    // Template literals can be finicky depending on Qt version; use string concat
    symbolText: "- " + Math.floor(percentUsed) + "%"
  }

  // Show used memory percent based on MemTotal and MemAvailable
  property real percentUsed: 0

  Process {
    id: memProc
    // More robust across locales: compute from /proc/meminfo and output an integer percent
    command: [
      "sh", "-c",
      "awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf(\"%.0f\\n\", (t-a)/t*100)}' /proc/meminfo"
    ]
    running: true

    stdout: SplitParser {
      onRead: data => percentUsed = Number(data)
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: memProc.running = true
  }
}
