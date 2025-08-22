import QtQuick
import "../utils" as Utils
import "root:/"

Item {
  id: root

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  property color activeColor: Globals.workspaceActiveBg
  property color inactiveColor: Globals.workspaceInactiveBg
  property color activeBorder: Globals.workspaceActiveBorder
  property color inactiveBorder: Globals.workspaceInactiveBorder
  property color activeText: Globals.workspaceTextColor
  property color inactiveText: Globals.workspaceTextColor

  Row {
    id: row
    spacing: 5

    Repeater {
      model: Utils.CompositorUtils.workspaces

      Rectangle {
        width: 35
        height: 22
        radius: 8
        color: modelData.active ? root.activeColor : root.inactiveColor
        border.color: modelData.active ? root.activeBorder : root.inactiveBorder
        border.width: 1

        MouseArea {
          anchors.fill: parent
          onClicked: Utils.CompositorUtils.switchWorkspace(modelData.id)
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
      visible: (Utils.CompositorUtils.workspaces.length || 0) === 0
      text: "No workspaces"
      color: Globals.workspaceTextColor
      font.pixelSize: 12
      font.family: "JetBrains Mono Nerd Font, sans-serif"
    }
  }
}
