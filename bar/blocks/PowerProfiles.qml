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
  property string profile: "unknown"      // performance | balanced | power-saver | unknown
  property string driver: ""              // parsed from powerprofilesctl list
  property var availableProfiles: []       // detected from powerprofilesctl list

  // Helpers
  function orderedProfiles() {
    return ["performance", "balanced", "power-saver"]
  }
  function nextProfile() {
    const avail = root.availableProfiles.length ? root.availableProfiles.slice() : orderedProfiles()
    // ensure order according to preferred order
    const order = orderedProfiles().filter(p => avail.indexOf(p) !== -1)
    const cur = root.profile
    const idx = Math.max(0, order.indexOf(cur))
    const next = order[(idx + 1) % order.length]
    return next || cur
  }

  // Icon mapping like Waybar
  function iconForProfile(p) {
    switch (p) {
      case "performance": return ""
      case "balanced": return ""
      case "power-saver": return ""
      default: return ""
    }
  }

  // UI
  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    // No text after the icon -> avoid extra gap from letter-spacing
    symbolSpacing: 0
    symbolText: root.iconForProfile(root.profile)
  }

  // Hover tooltip
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
    onClicked: {
      const np = root.nextProfile()
      if (np && np !== root.profile) {
        setProc.command = ["sh", "-c", "powerprofilesctl set " + np + " 2>/dev/null || true"]
        setProc.running = true
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
        anchors.fill: parent
        anchors.margins: 10
        text: "Power profile: " + root.profile
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }

  // Processes
  // Detect available profiles (parse in JS to avoid shell quoting issues)
  Process {
    id: listProc
    running: false
    command: ["sh", "-c", "powerprofilesctl list 2>/dev/null"]
    onStarted: root.availableProfiles = []
    stdout: SplitParser {
      onRead: data => {
        const text = String(data)
        const lines = text.split(/\n/)
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i]
          const m = line.match(/\b(performance|balanced|power-saver)\b/)
          if (m && root.availableProfiles.indexOf(m[1]) === -1) {
            root.availableProfiles.push(m[1])
          }
        }
      }
    }
  }

  // Get current profile
  Process {
    id: getProc
    running: false
    command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || echo unknown"]
    stdout: SplitParser {
      onRead: data => {
        const out = String(data).trim()
        if (out) root.profile = out
      }
    }
  }

  // Get driver (from list header) - parse in JS
  Process {
    id: drvProc
    running: false
    command: ["sh", "-c", "powerprofilesctl list 2>/dev/null"]
    stdout: SplitParser {
      onRead: data => {
        const text = String(data)
        const first = text.split(/\n/)[0] || ""
        const m = first.match(/Driver:\s*([^)]*)\)/)
        if (m && m[1]) root.driver = m[1].trim()
      }
    }
  }

  // Set next profile
  Process {
    id: setProc
    running: false
    command: ["sh", "-c", "true"]
    onExited: {
      // refresh after setting
      getProc.running = true
      drvProc.running = true
      listProc.running = true
    }
  }

  // Periodic refresh
  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: { getProc.running = true; drvProc.running = true; listProc.running = true }
  }

  // Initial fetch
  Component.onCompleted: { getProc.running = true; drvProc.running = true; listProc.running = true }
}
