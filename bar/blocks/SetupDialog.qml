import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../"
import "root:/"
import "./setup" as Pages

Window {
  id: dialog
  visible: false
  // Optional: property kept for API compatibility; no longer used for anchoring
  property Item anchorItem

  // Window size (use width/height for managed window)
  width: 820
  height: 560
  minimumWidth: 680
  minimumHeight: 480
  title: "Celona Setup"
  flags: Qt.Window

  // Center on the current screen when shown
  onVisibleChanged: if (visible) {
    try {
      const geom = dialog.screen?.geometry
      if (geom) {
        dialog.x = geom.x + Math.round((geom.width - dialog.width) / 2)
        dialog.y = geom.y + Math.round((geom.height - dialog.height) / 2)
      }
    } catch (e) { /* ignore */ }
  }

  Rectangle {
    anchors.fill: parent
    radius: 10
    color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
    border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Label {
          text: "Setup"
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.bold: true
          font.pixelSize: 18
        }
        Item { Layout.fillWidth: true }
        Button {
          id: closeBtn
          text: " X "
          onClicked: dialog.visible = false
          contentItem: Label {
            text: parent.text
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          background: Rectangle {
            radius: 6
            color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
            border.width: 1
          }
        }
      }

      // Body
      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        // Nav
        ListView {
          id: nav
          Layout.preferredWidth: 180
          Layout.fillHeight: true
          currentIndex: 0
          model: [
            { name: "Layout", comp: "LayoutPage" },            
            { name: "Theme", comp: "ThemePage" },
            { name: "Wallpaper", comp: "WallpapersPage" },
            { name: "Modules", comp: "ModulesPage" },
            { name: "Dock", comp: "DockPage" },
            { name: "Compositor", comp: "CompositorPage" },
            { name: "System", comp: "SystemPage" }
          ]
          delegate: Rectangle {
            width: ListView.view.width
            height: 36
            radius: 6
            color: ListView.isCurrentItem ? (Globals.hoverHighlightColor || "#33ffffff") : "transparent"
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
            border.width: ListView.isCurrentItem ? 1 : 0
            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: 10
              text: modelData.name
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            }
            MouseArea { anchors.fill: parent; onClicked: nav.currentIndex = index }
          }
          onCurrentIndexChanged: stack.currentIndex = currentIndex
        }

        // Pages (non-swipe, to avoid internal ListView polish loops)
        StackLayout {
          id: stack
          Layout.fillWidth: true
          Layout.fillHeight: true
          currentIndex: 0

          Pages.LayoutPage {}
          Pages.ThemePage {}
          Pages.WallpapersPage {}
          Pages.ModulesPage {}
          Pages.DockPage {}
          Pages.CompositorPage {}
          Pages.SystemPage {}
        }
      }
    }
  }
}
