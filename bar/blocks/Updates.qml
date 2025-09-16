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
    mainFont: Globals.mainFontFamily
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
    // Use repo-local script path; convert file:// URL to a real path
    command: [
      "bash", "-lc",
      "LIST_SH=\"" + Qt.resolvedUrl("root:/scripts/list-updates.sh") + "\"; " +
      "LIST_SH=${LIST_SH#file://}; " +
      "sh \"$LIST_SH\" 2>/dev/null"
    ]
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
    onVisibleChanged: {
      if (visible) {
        tipWindow.visible = false
        if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== listWindow) {
          if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
        }
        if (Globals.popupContext) Globals.popupContext.popup = listWindow
      } else {
        if (Globals.popupContext && Globals.popupContext.popup === listWindow) Globals.popupContext.popup = null
      }
    }

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
            font.family: String(Globals.mainFontFamily || "JetBrains Mono Nerd Font")
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
    onEntered: {
      if (!Globals.popupContext || !Globals.popupContext.popup) {
        tipWindow.visible = true
      }
    }
    onExited: tipWindow.visible = false
    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        // Launch via helper to leverage Hyprland exec and terminal probing
        // Also log diagnostics (PATH, ghostty) for race conditions
        const updSh = Qt.resolvedUrl("root:/scripts/update-packages.sh")
        openInstall.command = [
          "bash", "-lc",
          "{ date; echo 'Left-click received'; echo \"PATH=$PATH\"; echo \"DISPLAY=${DISPLAY:-} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-} XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}\"; printf 'ghostty: '; command -v ghostty || echo 'not found'; } >> \"${XDG_RUNTIME_DIR:-/tmp}/celona-upd.log\" 2>&1; " +
          "UPD_SH=\"" + updSh + "\"; UPD_SH=${UPD_SH#file://}; " +
          "LOG=\"${XDG_RUNTIME_DIR:-/tmp}/celona-upd.log\"; " +
          "if command -v hyprctl >/dev/null 2>&1 && [ -n \"${HYPRLAND_INSTANCE_SIGNATURE:-}\" ]; then \
             if command -v ghostty >/dev/null 2>&1; then hypr=1; echo 'qml-direct: launch -> hyprctl+ghostty' >> \"$LOG\"; hyprctl dispatch exec -- ghostty -e bash -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v kitty >/dev/null 2>&1; then hypr=1; echo 'qml-direct: launch -> hyprctl+kitty' >> \"$LOG\"; hyprctl dispatch exec -- kitty sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v alacritty >/dev/null 2>&1; then hypr=1; echo 'qml-direct: launch -> hyprctl+alacritty' >> \"$LOG\"; hyprctl dispatch exec -- alacritty -e sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v wezterm >/dev/null 2>&1; then hypr=1; echo 'qml-direct: launch -> hyprctl+wezterm' >> \"$LOG\"; hyprctl dispatch exec -- wezterm start -- sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v foot >/dev/null 2>&1; then hypr=1; echo 'qml-direct: launch -> hyprctl+foot' >> \"$LOG\"; hyprctl dispatch exec -- foot sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v gnome-terminal >/dev/null 2>&1; then hypr=1; echo 'qml-direct: launch -> hyprctl+gnome-terminal' >> \"$LOG\"; hyprctl dispatch exec -- gnome-terminal -- sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v konsole >/dev/null 2>&1; then hypr=1; echo 'qml-direct: launch -> hyprctl+konsole' >> \"$LOG\"; hyprctl dispatch exec -- konsole -e sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v xfce4-terminal >/dev/null 2>&1; then hypr=1; echo 'qml-direct: launch -> hyprctl+xfce4-terminal' >> \"$LOG\"; hyprctl dispatch exec -- xfce4-terminal -e \"sh -lc '\\\\''\"$UPD_SH\"'\\\\''\" & disown; \
             else hypr=0; fi; \
           fi; \
           if [ -z \"${hypr:-}\" ]; then \
             if command -v ghostty >/dev/null 2>&1; then echo 'qml-direct: launch -> ghostty' >> \"$LOG\"; ghostty -e bash -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v kitty >/dev/null 2>&1; then echo 'qml-direct: launch -> kitty' >> \"$LOG\"; kitty sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v alacritty >/dev/null 2>&1; then echo 'qml-direct: launch -> alacritty' >> \"$LOG\"; alacritty -e sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v wezterm >/dev/null 2>&1; then echo 'qml-direct: launch -> wezterm' >> \"$LOG\"; wezterm start -- sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v foot >/dev/null 2>&1; then echo 'qml-direct: launch -> foot' >> \"$LOG\"; foot sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v gnome-terminal >/dev/null 2>&1; then echo 'qml-direct: launch -> gnome-terminal' >> \"$LOG\"; gnome-terminal -- sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v konsole >/dev/null 2>&1; then echo 'qml-direct: launch -> konsole' >> \"$LOG\"; konsole -e sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             elif command -v xfce4-terminal >/dev/null 2>&1; then echo 'qml-direct: launch -> xfce4-terminal' >> \"$LOG\"; xfce4-terminal -e \"sh -lc '\\\\''\"$UPD_SH\"'\\\\''\" & disown; \
             elif command -v xterm >/dev/null 2>&1; then echo 'qml-direct: launch -> xterm' >> \"$LOG\"; xterm -e sh -lc \"\\\"$UPD_SH\\\"; echo; echo '[Finished] Press Enter to close...'; read _\" & disown; \
             else echo 'qml-direct: no terminal found' >> \"$LOG\"; ( command -v notify-send >/dev/null 2>&1 && notify-send 'Celona Updates' 'Kein Terminal gefunden' ) >/dev/null 2>&1 || true; fi; \
           fi"
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
        text: "Left: Update\nRight: Show list"
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
    // Prefer our list-updates script and count non-empty lines reliably; fallback to ml4w updates.sh
    // Outputs a single integer so downstream parsing works across environments
    command: ["bash", "-lc",
      "LIST_SH=\"" + Qt.resolvedUrl("root:/scripts/list-updates.sh") + "\"; " +
      "LIST_SH=${LIST_SH#file://}; " +
      "( \"$LIST_SH\" 2>/dev/null | sed '/^$/d' | wc -l ) || ( ~/.config/ml4w/scripts/updates.sh 2>/dev/null || true )"
    ]
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

  // Ensure initial refresh; sometimes early onCompleted can race, so we do one immediate and one delayed
  Component.onCompleted: refreshNow()
  Timer {
    interval: 1200
    running: true
    repeat: false
    onTriggered: refreshNow()
  }
}
