import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // UI content: sun icon + percent (padded to 3 chars like Sound)
  content: BarText {
    id: label
    mainFont: Globals.mainFontFamily
    symbolFont: "Symbols Nerd Font Mono"
    // Numeric brightness value (0-100); -1 means unknown
    property int percentVal: -1
    // Padded percent text like Sound: 3 characters wide
    property string percent3: (percentVal >= 0 ? String(Math.round(percentVal)).padStart(3, " ") : " --")
    // Show Nerd Font sun icon + padded percent (same spacing as Sound)
    symbolText: `󰃠 ${percent3}%`
  }

  // Mouse handling: left click opens popup, wheel adjusts via script for all monitors
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onEntered: {
      if (!Globals.popupContext || !Globals.popupContext.popup) tipWindow.visible = true
    }
    onExited: tipWindow.visible = false
    onClicked: (mouse) => {
      tipWindow.visible = false
      if (mouse.button === Qt.LeftButton) toggleMenu()
    }
    onWheel: function(event) {
      const step = event.angleDelta.y > 0 ? "+5" : "-5"
      setProc.command = ["bash","-lc", `~/.config/quickshell/Celona/scripts/monitor-brightness.sh "${step}" all || true`]
      setProc.running = true
      // Optimistically update label from current percent
      try {
        const cur = (label.percentVal >= 0 ? label.percentVal : NaN)
        const delta = step.startsWith("+") ? parseInt(step.slice(1)) : -parseInt(step.slice(1))
        if (!isNaN(cur) && !isNaN(delta)) {
          const tgt = Math.max(0, Math.min(100, cur + delta))
          label.percentVal = Math.round(tgt)
        }
      } catch (e) { /* ignore */ }
    }
  }

  // Tooltip like other modules
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
          tipWindow.anchor.rect.y = (Globals.barPosition === "top") ? (tipWindow.anchor.window.height + gap) : (-gap)
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
        text: "Monitor brightness"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }

  // Slider popup (left-click)
  PopupWindow {
    id: menuWindow
    visible: false
    implicitWidth: 220
    implicitHeight: 70
    color: "transparent"

    onVisibleChanged: {
      if (visible) {
        if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== menuWindow) {
          if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
        }
        if (Globals.popupContext) Globals.popupContext.popup = menuWindow
        // Load current value if available
        readCurrentProc.running = true
      } else {
        if (Globals.popupContext && Globals.popupContext.popup === menuWindow) Globals.popupContext.popup = null
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
          const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(root.height + gap))
          const rect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
          menuWindow.anchor.rect = rect
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1
      radius: 8

      Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Match Sound.qml slider visuals/colors
        Slider {
          id: brightSlider
          anchors.fill: parent
          from: 0
          to: 100
          stepSize: 1
          value: 50
          onMoved: debounceTimer.restart()

          background: Rectangle {
            x: brightSlider.leftPadding
            y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
            width: brightSlider.availableWidth
            height: 4
            radius: 2
            color: "#3c3c3c"

            Rectangle {
              width: brightSlider.visualPosition * parent.width
              height: parent.height
              color: "#4a9eff"
              radius: 2
            }
          }

          handle: Rectangle {
            x: brightSlider.leftPadding + brightSlider.visualPosition * (brightSlider.availableWidth - width)
            y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
            width: 16
            height: 16
            radius: 8
            color: brightSlider.pressed ? "#4a9eff" : "#ffffff"
            border.color: "#3c3c3c"
          }
        }
      }
    }
  }

  function toggleMenu() {
    const win = root.QsWindow?.window
    if (!win) return
    const gap = 5
    const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(root.height + gap))
    menuWindow.anchor.rect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
    menuWindow.visible = !menuWindow.visible
  }

  // Debounce before calling the script
  Timer { id: debounceTimer; interval: 120; repeat: false; onTriggered: {
    const v = Math.round(brightSlider.value)
    setProc.command = ["bash","-lc", `~/.config/quickshell/Celona/scripts/monitor-brightness.sh "${v}" all || true`]
    setProc.running = true
    label.percentVal = Math.round(v)
  } }

  // Processes
  Process { id: setProc; running: false; command: ["sh","-c","true"] }
  Process {
    id: readCurrentProc
    running: false
    command: ["bash","-lc", 'f="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/celona-brightness/monitor-brightness.last_val"; [ -r "$f" ] && cat "$f" || echo ""']
    stdout: SplitParser {
      onRead: (data) => {
        const s = String(data).trim()
        const n = parseInt(s)
        if (!isNaN(n) && n >= 0 && n <= 100) {
          brightSlider.value = n
          label.percentVal = Math.round(n)
        }
      }
    }
  }

  // Lightweight poll to keep the label in sync while the popup is closed
  Timer {
    id: pollTimer
    interval: 1500
    repeat: true
    running: true
    onTriggered: if (!readPollProc.running && !menuWindow.visible) readPollProc.running = true
  }
  Process {
    id: readPollProc
    running: false
    command: ["bash","-lc", 'f="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/celona-brightness/monitor-brightness.last_val"; [ -r "$f" ] && cat "$f" || echo ""']
    stdout: SplitParser {
      onRead: (data) => {
        const s = String(data).trim()
        const n = parseInt(s)
        if (!isNaN(n) && n >= 0 && n <= 100) label.percentVal = Math.round(n)
      }
    }
  }

  // Close popups when bar position flips
  Connections {
    target: Globals
    function onBarPositionChanged() {
      if (menuWindow.visible) menuWindow.visible = false
      if (tipWindow.visible) tipWindow.visible = false
    }
  }

  // Kick an initial read to populate percent on startup
  Component.onCompleted: {
    if (!readPollProc.running) readPollProc.running = true
  }
}
