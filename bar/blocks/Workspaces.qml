import QtQuick
import Quickshell.Hyprland
import "../utils" as Utils

Item {
  id: root

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  property color activeColor: "#00bee7"
  property color inactiveColor: "#333333"
  property color activeBorder: "#00d6d8"
  property color inactiveBorder: "#575757"
  property color activeText: "#000000"
  property color inactiveText: "#cccccc"

  Row {
    id: row
    spacing: 5

    Repeater {
      model: Utils.HyprlandUtils.workspaces

      Rectangle {
        width: 35
        height: 22
        radius: 8
        color: modelData.active ? root.activeColor : root.inactiveColor
        border.color: modelData.active ? root.activeBorder : root.inactiveBorder
        border.width: 1

        MouseArea {
          anchors.fill: parent
          onClicked: Utils.HyprlandUtils.switchWorkspace(modelData.id)
        }

        Text {
          text: modelData.id
          anchors.centerIn: parent
          color: modelData.active ? root.activeText : root.inactiveText
          font.pixelSize: 14
          font.bold: modelData.active
          font.family: "JetBrains Mono Nerd Font, sans-serif"
        }
      }
    }

    Text {
      visible: Utils.HyprlandUtils.workspaces.length === 0
      text: "No workspaces"
      color: "#cccccc"
      font.pixelSize: 12
      font.family: "JetBrains Mono Nerd Font, sans-serif"
    }
  }
}
