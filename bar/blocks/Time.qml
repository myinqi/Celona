import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: timeBlock
  // Timer state
  // Duration as hours/minutes with arrow controls (no text input)
  property int timerHours: 0
  property int timerMinutes: 0
  // Which part is currently active for keyboard arrows: 'h' or 'm'
  property string adjustPart: 'h'
  property bool timerRunning: false
  property int remainingSec: 0
  property double _targetEpochSec: 0
  // Store the originally set duration as text for notifications
  property string originalDurationText: ""
  // Icon name for notifications (freedesktop icon theme name or absolute path)
  // Examples: 'alarm-symbolic', 'alarm', 'alarm-clock', 'appointment-new', 'preferences-system-time', 'clock'
  property string notifyIcon: "alarm-symbolic"
  // Last used duration in seconds (used when user presses Start with 00:00)
  property int lastDurationSec: 0
  property string remainingText: {
    const s = Math.max(0, remainingSec|0)
    const hh = Math.floor(s/3600)
    const mm = Math.floor((s%3600)/60)
    const ss = s%60
    return z2(hh) + ':' + z2(mm) + ':' + z2(ss)
  }

  content: BarText {
    mainFont: Globals.mainFontFamily
    symbolFont: "Symbols Nerd Font Mono"
    symbolSpacing: 0
    symbolText: ` ${Datetime.time}`
  }

  function _parseDurationHHMM(s) {
    try {
      const m = String(s||"").trim().match(/^\s*(\d{1,2}):(\d{2})\s*$/)
      if (!m) return 0
      const hh = Math.max(0, parseInt(m[1], 10) || 0)
      const mm = Math.max(0, Math.min(59, parseInt(m[2], 10) || 0))
      return (hh*3600 + mm*60)
    } catch (e) { return 0 }
  }
  function startTimer() {
    var secs = Math.max(0, (timerHours|0) * 3600 + (timerMinutes|0) * 60)
    if (secs <= 0 && (lastDurationSec|0) > 0) {
      // Use the last duration if no time is set
      secs = (lastDurationSec|0)
    }
    if (secs <= 0) return
    // Build human-readable text from the duration actually used (secs)
    var hh = (timerHours|0)
    var mm = (timerMinutes|0)
    if (hh === 0 && mm === 0) {
      // Derive from secs when starting via lastDurationSec
      hh = Math.floor(secs/3600)
      mm = Math.floor((secs%3600)/60)
    }
    const hhText = hh > 0 ? (hh + ' hour' + (hh === 1 ? '' : 's')) : ''
    const mmText = mm > 0 ? (mm + ' minute' + (mm === 1 ? '' : 's')) : ''
    originalDurationText = hh > 0 && mm > 0 ? (hhText + ' ' + mmText) : (hh > 0 ? hhText : mmText)
    remainingSec = secs
    timerRunning = true
    lastDurationSec = secs
  }
  function stopTimer() {
    // Pause: only toggle the state flag. Do NOT write tickTimer.running directly,
    // otherwise we break its binding (running: timeBlock.timerRunning)
    timerRunning = false
  }
  function resumeTimer() {
    if ((remainingSec|0) > 0) {
      timerRunning = true
    }
  }
  function z2(n) {
    const s = String(Math.max(0, n | 0))
    return s.length < 2 ? '0' + s : s
  }
  function incHour() { timerHours = Math.min(99, (timerHours|0) + 1) }
  function decHour() { timerHours = Math.max(0, (timerHours|0) - 1) }
  function incMinute() {
    let m = (timerMinutes|0) + 1
    if (m >= 60) { m = 0; incHour() }
    timerMinutes = m
  }
  function decMinute() {
    let m = (timerMinutes|0) - 1
    if (m < 0) { m = 59; if (timerHours > 0) decHour() }
    timerMinutes = m
  }

  // Click + tooltip
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onEntered: {
      if (!timeWindow.visible && (!Globals.popupContext || !Globals.popupContext.popup)) {
        tipWindow.visible = true
      }
    }
    onExited: tipWindow.visible = false
    function positionPopup() {
      const win = timeBlock.QsWindow?.window
      if (win && win.contentItem) {
        const gap = 5
        if (Globals.barPosition === "top") {
          const y = timeBlock.height + gap
          timeWindow.anchor.rect = win.contentItem.mapFromItem(timeBlock, 0, y, timeBlock.width, timeBlock.height)
        } else {
          const y = -(timeBlock.height + gap)
          timeWindow.anchor.rect = win.contentItem.mapFromItem(timeBlock, 0, y, timeBlock.width, timeBlock.height)
        }
      }
    }
    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        tipWindow.visible = false
        positionPopup()
        timeWindow.visible = !timeWindow.visible
      }
    }
  }

  // Hover tooltip under the bar
  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: tipLabel.implicitWidth + 20
    implicitHeight: tipLabel.implicitHeight + 20
    color: "transparent"

    anchor {
      window: timeBlock.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = timeBlock.QsWindow?.window
        if (win) {
          const gap = 3
          tipWindow.anchor.rect.y = (Globals.barPosition === "top")
            ? (tipWindow.anchor.window.height + gap)
            : (-gap)
          tipWindow.anchor.rect.x = win.contentItem.mapFromItem(timeBlock, timeBlock.width / 2, 0).x
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
        text: "Time"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }

  // Persistent popup (content to be filled later)
  PopupWindow {
    id: timeWindow
    visible: false
    implicitWidth: contentCol.implicitWidth + 20
    implicitHeight: contentCol.implicitHeight + 20
    color: "transparent"

    anchor {
      window: timeBlock.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        // Recompute position when anchoring changes
        const win = timeBlock.QsWindow?.window
        if (win && win.contentItem) {
          const gap = 5
          if (Globals.barPosition === "top") {
            const y = timeBlock.height + gap
            timeWindow.anchor.rect = win.contentItem.mapFromItem(timeBlock, 0, y, timeBlock.width, timeBlock.height)
          } else {
            const y = -(timeBlock.height + gap)
            timeWindow.anchor.rect = win.contentItem.mapFromItem(timeBlock, 0, y, timeBlock.width, timeBlock.height)
          }
        }
      }
    }

    onVisibleChanged: {
      if (visible) {
        tipWindow.visible = false
        if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== timeWindow) {
          if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
        }
        if (Globals.popupContext) Globals.popupContext.popup = timeWindow
        mouseArea.positionPopup()
        posFixTimer.start()
      } else {
        if (Globals.popupContext && Globals.popupContext.popup === timeWindow) Globals.popupContext.popup = null
      }
    }

    // After becoming visible, implicitHeight becomes accurate; adjust position once more
    Timer {
      id: posFixTimer
      interval: 1
      repeat: false
      onTriggered: mouseArea.positionPopup()
    }

    Rectangle {
      id: bgRect
      anchors.fill: parent
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1
      radius: 8
      focus: true
      Keys.onPressed: (e) => {
        switch (e.key) {
          case Qt.Key_Left: timeBlock.adjustPart = 'h'; e.accepted = true; break;
          case Qt.Key_Right: timeBlock.adjustPart = 'm'; e.accepted = true; break;
          case Qt.Key_Up:
            if (timeBlock.adjustPart === 'h') timeBlock.incHour(); else timeBlock.incMinute();
            e.accepted = true; break;
          case Qt.Key_Down:
            if (timeBlock.adjustPart === 'h') timeBlock.decHour(); else timeBlock.decMinute();
            e.accepted = true; break;
          case Qt.Key_Escape: timeWindow.visible = false; e.accepted = true; break;
        }
      }

      Column {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        // Header
        Text { text: "Timer"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; font.bold: true }
        // Input row (fixed hh:mm with arrow buttons)
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          // Hours control
          Column {
            spacing: 2
            Text {
              id: hoursHeader
              text: "hh"
              width: 28
              horizontalAlignment: Text.AlignHCenter
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            Button {
              text: "▲"; width: 28; height: 27
              onClicked: timeBlock.incHour()
              contentItem: Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: parent.text
                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              }
              background: Rectangle { radius: 4; color: "transparent"; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
            }
            Rectangle {
              width: 32; height: 27; color: "transparent"
              Text { anchors.centerIn: parent; text: timeBlock.z2(timeBlock.timerHours); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: 16 }
            }
            Button {
              text: "▼"; width: 28; height: 27
              onClicked: timeBlock.decHour()
              contentItem: Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: parent.text
                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              }
              background: Rectangle { radius: 4; color: "transparent"; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
            }
          }
          Text { text: ""; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          // Minutes control
          Column {
            spacing: 2
            Text {
              id: minutesHeader
              text: "mm"
              width: 28
              horizontalAlignment: Text.AlignHCenter
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            Button {
              text: "▲"; width: 28; height: 27
              onClicked: timeBlock.incMinute()
              contentItem: Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: parent.text
                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              }
              background: Rectangle { radius: 4; color: "transparent"; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
            }
            Rectangle {
              width: 32; height: 27; color: "transparent"
              Text { anchors.centerIn: parent; text: timeBlock.z2(timeBlock.timerMinutes); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: 16 }
            }
            Button {
              text: "▼"; width: 28; height: 27
              onClicked: timeBlock.decMinute()
              contentItem: Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: parent.text
                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              }
              background: Rectangle { radius: 4; color: "transparent"; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
            }
          }
          Item { Layout.fillWidth: true }
          // Right-side control column with three slots aligned to ▲ / value / ▼ rows
          Column {
            spacing: 2
            // Header spacer to align with 'hh/mm' labels on the left
            Item { width: 70; height: Math.max(hoursHeader.implicitHeight, minutesHeader.implicitHeight) }
            // Match the left columns' spacing between header and up-arrows
            Item { width: 70; height: 2 }
            // Top slot (align with up-arrow row)
            Item {
              width: 70; height: 27
              Button {
                id: startPauseBtn
                anchors.fill: parent
                text: timeBlock.timerRunning ? "Pause" : (timeBlock.remainingSec > 0 ? "Resume" : "Start")
                onClicked: {
                  if (timeBlock.timerRunning) {
                    // Pause
                    timeBlock.stopTimer()
                  } else if (timeBlock.remainingSec > 0) {
                    // Resume
                    timeBlock.resumeTimer()
                  } else {
                    // Start new
                    timeBlock.startTimer()
                  }
                }
                contentItem: Text {
                  anchors.fill: parent
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: parent.text
                  color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
                }
                background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
              }
            }
            // Middle slot (align with value row) – intentionally empty to keep alignment
            Item { width: 70; height: 27 }
            // Bottom slot (align with down-arrow row)
            Item {
              width: 70; height: 27
              Button {
                id: resetBtn
                anchors.fill: parent
                visible: timeBlock.timerRunning
                text: "Reset"
                onClicked: {
                  timeBlock.timerRunning = false
                  timeBlock.remainingSec = 0
                  timeBlock.timerHours = 0
                  timeBlock.timerMinutes = 0
                }
                contentItem: Text {
                  anchors.fill: parent
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: parent.text
                  color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
                }
                background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
              }
            }
          }
        }
        // Remaining display
        RowLayout {
          Layout.fillWidth: true
          spacing: 2
          Label { text: "Remaining:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          Item { Layout.fillWidth: true }
          RowLayout {
            spacing: 2
            // Hours
            Text { text: timeBlock.z2(Math.floor((timeBlock.remainingSec|0)/3600)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: "monospace"; font.pixelSize: Globals.mainFontSize }
            Text { text: "h"; color: Globals.hoverHighlightColor !== "" ? Globals.hoverHighlightColor : "#6c7086"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            // Minutes
            Text { text: timeBlock.z2(Math.floor(((timeBlock.remainingSec|0)%3600)/60)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: "monospace"; font.pixelSize: Globals.mainFontSize }
            Text { text: "m"; color: Globals.hoverHighlightColor !== "" ? Globals.hoverHighlightColor : "#6c7086"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            // Seconds
            Text { text: timeBlock.z2((timeBlock.remainingSec|0)%60); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: "monospace"; font.pixelSize: Globals.mainFontSize }
            Text { text: "s"; color: Globals.hoverHighlightColor !== "" ? Globals.hoverHighlightColor : "#6c7086"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          }
        }
      }
    }
  }

  // Close popup when bar position flips (top <-> bottom)
  Connections {
    target: Globals
    function onBarPositionChanged() {
      if (timeWindow.visible) timeWindow.visible = false
      if (tipWindow.visible) tipWindow.visible = false
    }
  }

  // Tick and notify
  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    running: timeBlock.timerRunning
    onTriggered: {
      if (!timeBlock.timerRunning) { return }
      const next = Math.max(0, (timeBlock.remainingSec|0) - 1)
      timeBlock.remainingSec = next
      if (next <= 0) {
        timeBlock.timerRunning = false
        // Set dynamic notification text with the originally set duration
        notifyProc.command = [
          "bash","-lc",
          "notify-send -u normal -i '" + timeBlock.notifyIcon + "' 'Timer' '" + timeBlock.originalDurationText + " expired' || true"
        ]
        notifyProc.running = true
      }
    }
  }

  Process {
    id: notifyProc
    running: false
    command: ["bash","-lc","notify-send -u normal -i 'alarm-symbolic' 'Timer' 'Timer expired' || true"]
  }
}
