import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "blocks" as Blocks
import "root:/"

Scope {
  IpcHandler {
    target: "bar"

    function toggleVis(): void {
      // Toggle visibility of all bar instances
      for (let i = 0; i < Quickshell.screens.length; i++) {
        barInstances[i].visible = !barInstances[i].visible;
      }
    }
  }

  property var barInstances: []

  Variants {
    model: Quickshell.screens
  
    PanelWindow {
      id: bar
      property var modelData
      screen: modelData

      Component.onCompleted: {
        barInstances.push(bar);
      }

      color: "transparent"

      implicitHeight: 34
      visible: true
      anchors {
        top: true
        left: true
        right: true
      }

      Rectangle {
        id: barRect
        anchors.fill: parent
        anchors.margins: 2
        color: "#40000000"
        radius: 11
        border.color: "#00bee7"
        border.width: 2

        Row {
          id: workspacesRow
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 16
          }
          spacing: 5

          Repeater {
            model: Hyprland.workspaces

            Rectangle {
              width: 35
              height: 22
              radius: 10
              color: modelData.active ? "#00bee7" : "#333333"
              border.color: modelData.active ? "#00d6d8" : "#575757"
              border.width: 1

              MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
              }

              Text {
                text: modelData.id
                anchors.centerIn: parent
                color: modelData.active ? "#000000" : "#cccccc"
                font.pixelSize: 14
                font.bold: modelData.active
                font.family: "JetBrains Mono Nerd Font, sans-serif"
              }
            }
          }

          Text {
            visible: Hyprland.workspaces.length === 0
            text: "No workspaces"
            color: "#cccccc"
            font.pixelSize: 12
            font.family: "JetBrains Mono Nerd Font, sans-serif"
          }
        }

        Text {
          id: windowTitle
          anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
          }
          text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "Desktop"
          color: "#ffffff"
          font.bold: true
          font.pixelSize: 14
          font.family: "JetBrains Mono Nerd Font, sans-serif"
          width: Math.min(implicitWidth, parent.width - 300)
          elide: Text.ElideRight
        }

        // Right side: use RowLayout so BarBlock.Layout.* sizing is respected
        RowLayout {
          id: rightBlocks
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 12
          }
          spacing: 8

          Blocks.SystemTray { id: systemTray }
          Blocks.Network { id: networkBlk }
          Blocks.CPU { id: cpuBlk }
          Blocks.GPU { id: gpuBlk }
          Blocks.Memory { id: memoryBlk }
          Blocks.Sound { id: soundBlk }
          Blocks.Battery { id: batteryBlk }
          Blocks.Date { id: dateBlk }
          Blocks.Time { id: timeBlk }
        }
      }
    }
  }
}

