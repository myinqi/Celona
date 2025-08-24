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
      text: "Modules"
      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
      font.bold: true
      font.pixelSize: 16
    }

    // Header controls: Reorder toggle
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Label {
        text: "Modules:"
        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
        font.bold: true
        font.italic: true
      }
      Item { Layout.fillWidth: true }
      Button {
        id: reorderBtn
        text: Globals.reorderMode ? "Finish" : "Reorder"
        onClicked: Globals.reorderMode = !Globals.reorderMode
        leftPadding: 12
        rightPadding: 12
        contentItem: Label {
          text: parent.text
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
          radius: 6
          color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button
          border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
          border.width: 1
        }
        ToolTip {
          id: reorderTip
          visible: reorderBtn.hovered
          text: Globals.reorderMode ? "Finish: order will be saved" : "Enable: reorder modules directly in the bar"
          contentItem: Text { text: reorderTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          background: Rectangle { color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase; border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
        }
      }
    }

    // Module toggles list
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 6
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        // Left column group
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Welcome"; Layout.preferredWidth: 110; color: Globals.popupText }
          Item { width: 0 }
          Switch { checked: Globals.showWelcome; onToggled: { Globals.showWelcome = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Window Title"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showWindowTitle; onToggled: { Globals.showWindowTitle = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Workspaces"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showWorkspaces; onToggled: { Globals.showWorkspaces = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "System Tray"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showSystemTray; onToggled: { Globals.showSystemTray = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Updates"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showUpdates; onToggled: { Globals.showUpdates = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Network"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showNetwork; onToggled: { Globals.showNetwork = checked; Globals.saveTheme() } }
        }

        // Right/remaining items
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Bluetooth"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showBluetooth; onToggled: { Globals.showBluetooth = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "CPU"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showCPU; onToggled: { Globals.showCPU = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "GPU"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showGPU; onToggled: { Globals.showGPU = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Memory"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showMemory; onToggled: { Globals.showMemory = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Power Profiles"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showPowerProfiles; onToggled: { Globals.showPowerProfiles = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Clipboard"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showClipboard; onToggled: { Globals.showClipboard = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Keybinds"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showKeybinds; onToggled: { Globals.showKeybinds = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Notifications"; Layout.preferredWidth: 110; color: Globals.popupText }
          Item { width: 0 }
          Switch { checked: Globals.showNotifications; onToggled: { Globals.showNotifications = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Sound"; Layout.preferredWidth: 110; color: Globals.popupText }
          Item { width: 0 }
          Switch { checked: Globals.showSound; onToggled: { Globals.showSound = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Weather"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showWeather; onToggled: { Globals.showWeather = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Battery"; Layout.preferredWidth: 110; color: Globals.popupText }
          Item { width: 0 }
          Switch { checked: Globals.showBattery; onToggled: { Globals.showBattery = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Date"; Layout.preferredWidth: 110; color: Globals.popupText }
          Item { width: 0 }
          Switch { checked: Globals.showDate; onToggled: { Globals.showDate = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Time"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showTime; onToggled: { Globals.showTime = checked; Globals.saveTheme() } }
        }
        RowLayout {
          Layout.fillWidth: true
          Label { text: "Power"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
          Item { width: 0 }
          Switch { checked: Globals.showPower; onToggled: { Globals.showPower = checked; Globals.saveTheme() } }
        }
      }
    }
  }
}
