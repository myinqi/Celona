import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // State
  property int count: 0
  property string raw: ""
  // Right-click tooltip content
  property string updatesText: ""
  // Formatted into aligned columns (monospace)
  property string updatesTextColumns: ""
  // Loading state for list fetch
  property bool updatesLoading: false
  // Parsed rows for table view: [{name, oldv, newv}, ...]
  property var updatesRows: []

  // Waybar-like: hide if no updates
  visible: count > 0

  // UI
  content: BarText {
    id: txt
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    // Fixed-width numeric area (0–999): pad to 3 chars to prevent layout shifts
    property string count3: String(count).padStart(3, " ")
    symbolText: " " + count3
    symbolSpacing: 5
  }

  function parseUpdatesRows(raw) {
    try {
      const lines = String(raw).split(/\r?\n/).map(l => l.trim()).filter(l => l.length > 0 && !l.startsWith(":: "))
      const rows = []
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i]
        const parts = line.split(/\s+->\s+/)
        if (parts.length === 2) {
          const left = parts[0].trim()
          const right = parts[1].trim()
          const lp = left.split(/\s+/)
          if (lp.length >= 2) {
            const oldv = lp.pop()
            const name = lp.join(" ")
            rows.push({ name: name, oldv: oldv, newv: right })
          }
        }
      }
      return rows
    } catch (e) {
      return []
    }
  }

  // Fetch list of pending updates on demand (right-click)
  Process {
    id: listProc
    running: false
    command: ["sh", "-c", "$HOME/.config/quickshell/Celona/scripts/list-updates.sh 2>/dev/null"]
    stdout: SplitParser {
      onRead: data => {
        // Accumulate all chunks
        if (updatesLoading && (updatesText === "(Fetching updates...)" || updatesText === "(Lade Liste...)" || updatesText === "")) {
          updatesText = ""
        }
        // SplitParser emits tokens without trailing newlines; reinsert line breaks
        updatesText += String(data) + "\n"
        updatesTextColumns = formatUpdatesColumns(updatesText)
        updatesRows = parseUpdatesRows(updatesText)
      }
    }
    onRunningChanged: {
      if (running) {
        updatesLoading = true
      }
      if (!running) {
        updatesLoading = false
        updatesTextColumns = formatUpdatesColumns(updatesText)
        updatesRows = parseUpdatesRows(updatesText)
      }
    }
  }

  function toggleUpdatesMenu() {
    const win = root.QsWindow?.window
    if (win && win.contentItem) {
      const gap = 5
      const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(root.height + gap))
      listWindow.anchor.rect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
      const willShow = !listWindow.visible
      listWindow.visible = willShow
      if (willShow) {
        updatesLoading = true
        updatesText = ""
        updatesTextColumns = ""
        updatesRows = []
        listProc.running = true
      }
    }
  }

  function formatUpdatesColumns(raw) {
    try {
      const lines = String(raw).split(/\r?\n/).map(l => l.trim()).filter(l => l.length > 0 && !l.startsWith(":: "))
      const rows = []
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i]
        const parts = line.split(/\s+->\s+/)
        if (parts.length === 2) {
          const left = parts[0].trim()
          const right = parts[1].trim()
          const lp = left.split(/\s+/)
          if (lp.length >= 2) {
            const oldv = lp.pop()
            const name = lp.join(" ")
            rows.push({ name: name, oldv: oldv, newv: right })
          }
        }
      }
      if (rows.length === 0) return ""
      let maxName = "Package".length
      let maxOld = "Version".length
      for (let i = 0; i < rows.length; i++) {
        if (rows[i].name.length > maxName) maxName = rows[i].name.length
        if (rows[i].oldv.length > maxOld) maxOld = rows[i].oldv.length
      }
      const header = `${"Package".padEnd(maxName + 2)} ${"Version".padEnd(maxOld)} -> New`
      const sep = `${"".padEnd(maxName, "-")}  ${"".padEnd(maxOld, "-")}    ${"".padEnd(Math.max(3, 3), "-")}`
      const body = rows.map(r => `${r.name.padEnd(maxName + 2)} ${r.oldv.padEnd(maxOld)} -> ${r.newv}`).join("\n")
      return `${header}\n${sep}\n${body}`
    } catch (e) {
      return ""
    }
  }

  // Right-click popup listing pending updates
  PopupWindow {
    id: listWindow
    visible: false
    implicitWidth: listContent.implicitWidth + 20
    implicitHeight: listContent.implicitHeight + 20
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          const gap = 5
          const y = (Globals.barPosition === "top")
            ? (root.height + gap)
            : (-(root.height + gap))
          const rect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
          listWindow.anchor.rect = rect
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
        id: listContent
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        Text {
          text: "Pending updates"
          font.bold: true
          color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        }

        // Scrollable area for the list
        ScrollView {
          clip: true
          // Auto-size to content, with gentle caps to avoid oversizing
          implicitWidth: Math.min(600, updatesPlain.implicitWidth)
          implicitHeight: Math.min(400, updatesPlain.implicitHeight)
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          // Simple newline-separated list
          Text {
            id: updatesPlain
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            font.family: "JetBrains Mono Nerd Font"
            font.pixelSize: 12
            color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
            text: updatesLoading
                    ? "(Fetching updates...)"
                    : (updatesText && updatesText.trim().length > 0 ? updatesText : "No updates")
          }
        }

        
      }
    }
  }

  // Tooltip
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        openInstall.command = [
          "sh", "-c",
          "$HOME/.config/quickshell/Celona/scripts/run-in-terminal.sh $HOME/.config/quickshell/Celona/scripts/update-packages.sh"
        ]
        openInstall.running = true
        // Immediately request a count refresh and start a short polling window
        refreshNow()
        quickRefreshTries = 0
        quickRefreshTimer.running = true
      } else if (mouse.button === Qt.RightButton) {
        // Toggle updates menu popup (package list)
        toggleUpdatesMenu()
      }
    }
  }

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
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "Left: Update system\nRight: Show list"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }

  // Processes
  Process {
    id: updatesProc
    running: false
    command: ["sh", "-c", "~/.config/ml4w/scripts/updates.sh 2>/dev/null"]
    stdout: SplitParser {
      onRead: data => {
        raw = String(data)
        // Try JSON first (Waybar return-type json)
        try {
          const obj = JSON.parse(raw)
          if (obj && (typeof obj.text === 'string' || typeof obj.text === 'number')) {
            const n = parseInt(obj.text)
            if (!isNaN(n)) root.count = n
            return
          }
        } catch (e) {}
        // Fallback: first integer in the output
        const m = raw.match(/\b(\d+)\b/)
        root.count = m ? parseInt(m[1]) : 0
      }
    }
  }

  // Launchers
  Process { id: openInstall; running: false; command: ["sh", "-c", "true"] }
  Process { id: openSoftware; running: false; command: ["sh", "-c", "true"] }

  function refreshNow() {
    updatesProc.running = true
  }

  // Polling like Waybar (30 min)
  Timer {
    interval: 1800000
    repeat: true
    running: true
    onTriggered: refreshNow()
  }

  // Short polling after user-triggered updates to reflect new count quickly
  property int quickRefreshTries: 0
  Timer {
    id: quickRefreshTimer
    interval: 10000 // 10s
    repeat: true
    running: false
    onTriggered: {
      refreshNow()
      quickRefreshTries += 1
      if (count === 0 || quickRefreshTries >= 24) { // up to ~4 minutes
        quickRefreshTimer.running = false
      }
    }
  }

  Component.onCompleted: refreshNow()
}
