import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: text
  content: BarText {
    mainFont: Globals.mainFontFamily
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: ` ${Datetime.date}`
  }

  // Click + tooltip
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onEntered: {
      if (!calWindow.visible && (!Globals.popupContext || !Globals.popupContext.popup)) {
        tipWindow.visible = true
      }
    }
    onExited: tipWindow.visible = false
    function positionCal() {
      const win = text.QsWindow?.window
      if (win && win.contentItem) {
        const gap = 5
        if (Globals.barPosition === "top") {
          const y = text.height + gap
          calWindow.anchor.rect = win.contentItem.mapFromItem(text, 0, y, text.width, text.height)
        } else {
          const y = -(text.height + gap)
          calWindow.anchor.rect = win.contentItem.mapFromItem(text, 0, y, text.width, text.height)
        }
      }
    }
    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        tipWindow.visible = false
        positionCal()
        calWindow.visible = !calWindow.visible
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

      Text {
        id: tipLabel
        anchors.fill: parent
        anchors.margins: 10
        text: "Calendar"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }

  // Persistent popup (not hover tooltip)
  PopupWindow {
    id: calWindow
    visible: false
    implicitWidth: contentCol.implicitWidth + 20
    implicitHeight: contentCol.implicitHeight + 20
    color: "transparent"

    anchor {
      window: text.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        // Recompute position when anchoring changes
        const win = text.QsWindow?.window
        if (win && win.contentItem) {
          const gap = 5
          if (Globals.barPosition === "top") {
            const y = text.height + gap
            calWindow.anchor.rect = win.contentItem.mapFromItem(text, 0, y, text.width, text.height)
          } else {
            const y = -(text.height + gap)
            calWindow.anchor.rect = win.contentItem.mapFromItem(text, 0, y, text.width, text.height)
          }
        }
      }
    }

    onVisibleChanged: {
      if (visible) {
        tipWindow.visible = false
        if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== calWindow) {
          if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
        }
        if (Globals.popupContext) Globals.popupContext.popup = calWindow
        bgRect.forceActiveFocus()
        mouseArea.positionCal()
        posFixTimer.start()
      } else {
        if (Globals.popupContext && Globals.popupContext.popup === calWindow) Globals.popupContext.popup = null
      }
    }

    // After becoming visible, implicitHeight becomes accurate; adjust position once more
    Timer {
      id: posFixTimer
      interval: 1
      repeat: false
      onTriggered: mouseArea.positionCal()
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
        case Qt.Key_Left: calendar.prevMonth(); e.accepted = true; break
        case Qt.Key_Right: calendar.nextMonth(); e.accepted = true; break
        case Qt.Key_Up: calendar.prevYear(); e.accepted = true; break
        case Qt.Key_Down: calendar.nextYear(); e.accepted = true; break
        case Qt.Key_Home:
        case Qt.Key_T: calendar.toToday(); e.accepted = true; break
        case Qt.Key_Escape: calWindow.visible = false; e.accepted = true; break
        }
      }

      Column {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // Header: month navigation
        RowLayout {
          id: headerRow
          width: parent.width
          spacing: 8
          property var months: ["January","February","March","April","May","June","July","August","September","October","November","December"]
          Button {
            text: "⟨"
            onClicked: calendar.prevMonth()
            contentItem: Text { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
            background: Rectangle { color: "transparent" }
          }
          Button {
            text: "⟪"
            onClicked: calendar.prevYear()
            contentItem: Text { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
            background: Rectangle { color: "transparent" }
          }
          Item { width: 6; height: 1 }
          Text {
            text: headerRow.months[calendar.displayMonth].slice(0, 3) + " " + calendar.displayYear
            font.bold: true
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Item { width: 6; height: 1 }
          Button {
            text: "⟫"
            onClicked: calendar.nextYear()
            contentItem: Text { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
            background: Rectangle { color: "transparent" }
          }
          Button {
            text: "⟩"
            onClicked: calendar.nextMonth()
            contentItem: Text { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
            background: Rectangle { color: "transparent" }
          }
          Item { Layout.fillWidth: true; height: 1 }
          Button {
            text: "Now"
            onClicked: calendar.toToday()
            contentItem: Text { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
            background: Rectangle { radius: 4; color: Globals.hoverHighlightColor !== "" ? Globals.hoverHighlightColor : "#6c7086" }
          }
        }

        // Weekday header (ISO: Mon..Sun) with KW label
        Row {
          spacing: 6
          Repeater {
            model: ["CW","Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
            delegate: Text {
              text: modelData
              width: 28
              horizontalAlignment: Text.AlignHCenter
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            }
          }
        }

        // Calendar weeks
        Column {
          id: calendarGrid
          spacing: 4
          Repeater {
            id: weekRepeater
            model: calendar.weeks.length
            delegate: Row {
              property int weekIndex: index
              spacing: 6
              // ISO week number
              Text {
                text: (calendar.weeks[weekIndex] && calendar.weeks[weekIndex].isoWeek) ? calendar.weeks[weekIndex].isoWeek : ""
                width: 28
                horizontalAlignment: Text.AlignHCenter
                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              }
              Repeater {
                model: 7
                delegate: Rectangle {
                  width: 28; height: 24; radius: 4
                  property var dayObj: (calendar.weeks[weekIndex] && calendar.weeks[weekIndex].days) ? calendar.weeks[weekIndex].days[index] : null
                  color: dayObj && dayObj.isToday ? (Globals.workspaceActiveBg !== "" ? Globals.workspaceActiveBg : "#4000bee7") : "transparent"
                  border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                  border.width: dayObj && dayObj.inMonth ? 1 : 0
                  Text {
                    anchors.centerIn: parent
                    text: dayObj ? dayObj.day : ""
                    color: dayObj && dayObj.inMonth ? (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF") : "#808080"
                  }
                }
              }
            }
          }
        }
      }
    }

    // Close popup when bar position flips (top <-> bottom)
    Connections {
      target: Globals
      function onBarPositionChanged() {
        if (calWindow.visible) calWindow.visible = false
        if (tipWindow.visible) tipWindow.visible = false
      }
    }
  }

  // Calendar logic
  QtObject {
    id: calendar
    property int displayYear: 1970
    property int displayMonth: 0  // 0..11
    property var weeks: []  // array of { isoWeek: int, days: [{day,inMonth,isToday}] }
    // today components to avoid JS Date collision
    property int todayYear: 1970
    property int todayMonth0: 0
    property int todayDay: 1

    function toToday() {
      displayYear = todayYear
      displayMonth = todayMonth0
      rebuild()
    }
    function prevMonth() {
      if (displayMonth === 0) { displayMonth = 11; displayYear -= 1 } else displayMonth -= 1
      rebuild()
    }
    function nextMonth() {
      if (displayMonth === 11) { displayMonth = 0; displayYear += 1 } else displayMonth += 1
      rebuild()
    }
    function prevYear() { displayYear -= 1; rebuild() }
    function nextYear() { displayYear += 1; rebuild() }

    

    // Math helpers (no JS Date)
    function isLeap(y) { return (y % 4 === 0 && y % 100 !== 0) || (y % 400 === 0) }
    function daysInMonth(y, m0) {
      switch (m0) {
      case 0: case 2: case 4: case 6: case 7: case 9: case 11: return 31
      case 3: case 5: case 8: case 10: return 30
      case 1: return isLeap(y) ? 29 : 28
      }
      return 30
    }
    // Sakamoto, returns ISO 1..7 (Mon..Sun); m0 = 0..11
    function weekdayISO(y, m0, d) {
      var t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
      y -= (m0 < 2) ? 1 : 0
      var w = (y + Math.floor(y/4) - Math.floor(y/100) + Math.floor(y/400) + t[m0] + d) % 7
      if (w === 0) return 7
      return w
    }
    function dayOfYear(y, m0, d) {
      var md = [31,28,31,30,31,30,31,31,30,31,30,31]
      if (isLeap(y)) md[1] = 29
      var n = d
      for (var i=0;i<m0;i++) n += md[i]
      return n
    }
    function weeksInYear(y) {
      var w = weekdayISO(y, 0, 1)
      if (w === 4) return 53
      if (w === 3 && isLeap(y)) return 53
      return 52
    }
    function isoWeekNumberYMD(y, m0, d) {
      var n = dayOfYear(y, m0, d)
      var w = weekdayISO(y, m0, d)
      var week = Math.floor((n - w + 10) / 7)
      if (week < 1) return weeksInYear(y-1)
      var wi = weeksInYear(y)
      if (week > wi) return 1
      return week
    }

    function rebuild() {
      var result = []
      var y = displayYear
      var m0 = displayMonth
      var firstIso = weekdayISO(y, m0, 1)
      var startDay = 1 - (firstIso - 1)
      for (var w = 0; w < 6; w++) {
        var days = []
        // compute Thursday of week and its ISO week number
        var tmpY = y, tmpM0 = m0, tmpD = startDay + w*7 + 3
        while (tmpD < 1) { tmpM0 -= 1; if (tmpM0 < 0) { tmpM0 = 11; tmpY -= 1 } tmpD += daysInMonth(tmpY, tmpM0) }
        while (tmpD > daysInMonth(tmpY, tmpM0)) { tmpD -= daysInMonth(tmpY, tmpM0); tmpM0 += 1; if (tmpM0 > 11) { tmpM0 = 0; tmpY += 1 } }
        var iso = isoWeekNumberYMD(tmpY, tmpM0, tmpD)
        for (var d = 0; d < 7; d++) {
          var cY = y, cM0 = m0, cD = startDay + w*7 + d
          while (cD < 1) { cM0 -= 1; if (cM0 < 0) { cM0 = 11; cY -= 1 } cD += daysInMonth(cY, cM0) }
          while (cD > daysInMonth(cY, cM0)) { cD -= daysInMonth(cY, cM0); cM0 += 1; if (cM0 > 11) { cM0 = 0; cY += 1 } }
          var inMonth = (cY === y && cM0 === m0)
          var isT = (cY === todayYear && cM0 === todayMonth0 && cD === todayDay)
          days.push({ day: cD, inMonth: inMonth, isToday: isT })
        }
        result.push({ isoWeek: iso, days: days })
      }
      weeks = result
    }

    Component.onCompleted: {} // wait for external today
  }

  // Fetch current date once (YYYY MM DD)
  Process {
    id: dateProc
    running: true
    command: ["sh", "-c", "date +%Y' '%m' '%d"]
    stdout: SplitParser {
      onRead: data => {
        var s = String(data).trim().split(/\s+/)
        if (s.length >= 3) {
          calendar.todayYear = Number(s[0])
          calendar.todayMonth0 = Number(s[1]) - 1
          calendar.todayDay = Number(s[2])
          calendar.toToday()
        }
      }
    }
  }
}

