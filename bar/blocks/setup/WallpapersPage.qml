import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "root:/"

Item {
  id: page
  // Size provided by parent SwipeView; avoid anchors to prevent conflicts
  width: parent ? parent.width : 0
  height: parent ? parent.height : 0

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 10

    Label {
      text: "Wallpaper"
      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
      font.bold: true
      font.pixelSize: 17
    }

    // Content (framed)
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
        spacing: 10

        // Top row: Animated wallpaper toggle aligned like module rows
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Animated Wallpaper:"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Item { Layout.fillWidth: true }
          Text {
            text: wpSwitch.checked ? "On (mpvpaper)" : "Off (static)"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Switch {
            id: wpSwitch
            checked: Globals.wallpaperAnimatedEnabled
            onToggled: {
              Globals.wallpaperAnimatedEnabled = checked
              if (checked) {
                Globals.startAnimatedWallpaper()
              } else {
                Globals.stopAnimatedAndSetStatic()
              }
              Globals.saveTheme()
            }
            ToolTip {
              id: wpTip
              visible: wpSwitch.hovered
              text: wpSwitch.checked ? ("Stop to set static wallpaper via " + Globals.wallpaperTool) : "Start animated wallpaper via mpvpaper"
              contentItem: Text {
                text: wpTip.text
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              }
              background: Rectangle {
                color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                border.width: 1
                radius: 6
              }
            }
          }
        }

        // Spacer to keep top row at the top of the frame
        Item { Layout.fillHeight: true }
      }
    }
  }
}
