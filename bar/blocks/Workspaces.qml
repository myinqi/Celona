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
        width: (Globals.workspaceButtonWidth !== undefined ? Globals.workspaceButtonWidth : 35)
        height: (Globals.workspaceButtonHeight !== undefined ? Globals.workspaceButtonHeight : 22)
        radius: (Globals.workspaceButtonRadius !== undefined ? Globals.workspaceButtonRadius : 8)
        color: modelData.active ? root.activeColor : root.inactiveColor
        border.color: modelData.active ? root.activeBorder : root.inactiveBorder
        border.width: (Globals.workspaceButtonBorderWidth !== undefined ? Globals.workspaceButtonBorderWidth : 1)

        MouseArea {
          anchors.fill: parent
          onClicked: Utils.CompositorUtils.switchWorkspace(modelData.id)
        }

        Text {
          text: modelData.id
          anchors.centerIn: parent
          color: modelData.active ? root.activeText : root.inactiveText
          font.pixelSize: Globals.mainFontSize
          font.bold: modelData.active
          font.family: Globals.mainFontFamily
        }
      }
    }

    Text {
      visible: (Utils.CompositorUtils.workspaces.length || 0) === 0
      text: "No workspaces"
      color: Globals.workspaceTextColor
      font.pixelSize: Globals.mainFontSize
      font.family: Globals.mainFontFamily
    }
  }
}
