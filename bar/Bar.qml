import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "root:/"
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

      implicitHeight: 38
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
        color: Globals.barBgColor
        radius: 11
        border.color: Globals.barBorderColor
        border.width: 2

        // Left: Welcome + Setup + WindowTitle (use RowLayout so BarBlock sizing is respected)
        RowLayout {
          id: leftRow
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 12
          }
          spacing: 12
          z: 2

          Blocks.Welcome { id: welcomeBlkLeft; z: 3; visible: Globals.showWelcome }
          Blocks.Setup { id: setupBlkLeft }

          Blocks.WindowTitle {
            id: windowTitle
            maxWidth: Math.max(200, barRect.width * 0.35)
            z: 1
            Layout.preferredWidth: implicitWidth
            visible: Globals.showWindowTitle
          }
        }

        // Center: workspaces module
        Blocks.Workspaces {
          id: workspaces
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          visible: Globals.showWorkspaces
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

          Blocks.SystemTray { id: systemTray; visible: Globals.showSystemTray }
          Blocks.Updates { id: updatesBlk; visible: Globals.showUpdates }          
          Blocks.Network {
            id: networkBlk
            onToggleNmAppletRequested: systemTray.toggleNetworkApplet()
            visible: Globals.showNetwork
          }
          Blocks.Bluetooth { id: bluetoothBlk; visible: Globals.showBluetooth }
          Blocks.CPU { id: cpuBlk; visible: Globals.showCPU }
          Blocks.GPU { id: gpuBlk; visible: Globals.showGPU }
          Blocks.Memory { id: memoryBlk; visible: Globals.showMemory }
          Blocks.PowerProfiles { id: powerProfilesBlk; visible: Globals.showPowerProfiles }
          Blocks.Clipboard { id: clipboardBlk; visible: Globals.showClipboard }
          Blocks.Notifications { id: notificationsBlk; visible: Globals.showNotifications }
          Blocks.Sound { id: soundBlk; visible: Globals.showSound }
          Blocks.Battery { id: batteryBlk; visible: Globals.showBattery }
          Blocks.Date { id: dateBlk; visible: Globals.showDate }
          Blocks.Time { id: timeBlk; visible: Globals.showTime }
          Blocks.Power { id: powerBlk; visible: Globals.showPower }
          // Welcome moved to leftRow
        }
      }
    }
  }

  // (removed) Custom toast overlay; using swaync for notifications now
}

