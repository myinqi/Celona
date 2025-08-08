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

        // Left: window title module
        Blocks.WindowTitle {
          id: windowTitle
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 16
          }
          maxWidth: Math.max(200, barRect.width * 0.35)
        }

        // Center: workspaces module
        Blocks.Workspaces {
          id: workspaces
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
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
          Blocks.Updates { id: updatesBlk }          
          Blocks.Network {
            id: networkBlk
            onToggleNmAppletRequested: systemTray.toggleNetworkApplet()
          }
          Blocks.Bluetooth { id: bluetoothBlk }
          Blocks.CPU { id: cpuBlk }
          Blocks.GPU { id: gpuBlk }
          Blocks.Memory { id: memoryBlk }
          Blocks.PowerProfiles { id: powerProfilesBlk }
          Blocks.Clipboard { id: clipboardBlk }
          Blocks.Notifications { id: notificationsBlk }
          Blocks.Sound { id: soundBlk }
          Blocks.Battery { id: batteryBlk }
          Blocks.Date { id: dateBlk }
          Blocks.Time { id: timeBlk }
          Blocks.Power { id: powerBlk }
          Blocks.Welcome { id: welcomeBlk; Layout.leftMargin: 8 }
        }
      }
    }
  }

  // (removed) Custom toast overlay; using swaync for notifications now
}

