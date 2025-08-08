import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../"
import "root:/"

BarBlock {
  id: root

  // Icon-only block using Nerd Font gear
  content: BarText {
    id: label
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: "" // gear
    symbolSpacing: 0
  }

  // Hover tooltip: "Bar Setup"
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false

    onClicked: (mouse) => {
      tipWindow.visible = false
      if (mouse.button === Qt.LeftButton) {
        setupPopup.visible = true
      }
    }
  }

  // Tooltip below the bar
  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: 90
    implicitHeight: 40
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Edges.Top
      gravity: Edges.Bottom
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          tipWindow.anchor.rect.y = win.height + 3
          tipWindow.anchor.rect.x = win.contentItem.mapFromItem(root, root.width / 2, 0).x
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
        text: "Bar Setup"
        color: "#ffffff"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  // Main popup (dummy), styled like Sound popup
  PopupWindow {
    id: setupPopup
    visible: false
    implicitWidth: 550
    implicitHeight: 350
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Edges.Top
      gravity: Edges.Bottom
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          setupPopup.anchor.rect.y = win.height + 6
          setupPopup.anchor.rect.x = win.contentItem.mapFromItem(root, root.width / 2, 0).x - setupPopup.implicitWidth / 2
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: palette.active.toolTipBase
      border.color: palette.active.light
      border.width: 1
      radius: 8

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
          text: "Bar Setup (Dummy)"
          color: "#ffffff"
          font.bold: true
          Layout.fillWidth: true
        }

        Text {
          text: "Hier können später Einstellungen für die Bar erfolgen."
          color: "#dddddd"
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }

        Button {
          text: "Close"
          onClicked: setupPopup.visible = false
          Layout.alignment: Qt.AlignRight
        }
      }
    }
  }
}
