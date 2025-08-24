import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "root:/"

Item {
  id: page
  // Size provided by parent SwipeView; avoid setting anchors to prevent conflicts
  width: parent ? parent.width : 0
  height: parent ? parent.height : 0

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 10

    Label {
      text: "System"
      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
      font.bold: true
      font.pixelSize: 16
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 8
      color: "transparent"
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1
      Text {
        anchors.centerIn: parent
        text: "System settings will appear here"
        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
      }
    }
  }
}
