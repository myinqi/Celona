import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: text
  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: ` ${Datetime.date}`
  }

  // Click + tooltip
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
    onClicked: (mouse) => {
      tipWindow.visible = false
      if (mouse.button === Qt.LeftButton) calendarProc.running = true
    }
  }

  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: 128
    implicitHeight: 40
    color: "transparent"

    anchor {
      window: text.QsWindow?.window
      edges: Edges.Top
      gravity: Edges.Bottom
      onAnchoring: {
        const win = text.QsWindow?.window
        if (win) {
          tipWindow.anchor.rect.y = tipWindow.anchor.window.height + 3
          tipWindow.anchor.rect.x = win.contentItem.mapFromItem(text, text.width / 2, 0).x
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: palette.active.toolTipBase
      border.color: palette.active.light
      border.width: 1
      radius: 8

      Text {
        anchors.fill: parent
        anchors.margins: 10
        text: "Open Calendar"
        color: "#ffffff"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  Process {
    id: calendarProc
    running: false
    command: ["sh", "-c", "flatpak run com.ml4w.calendar"]
    stdout: SplitParser { onRead: data => console.log(`[Date] OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Date] ERR: ${String(data)}`) }
  }
}

