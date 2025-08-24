import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"
import "./setup" as Pages

PopupWindow {
  id: dialog
  visible: false
  color: "transparent"

  // Centered on screen
  implicitWidth: 820
  implicitHeight: 560

  // Attach to window and position in the center safely
  anchor {
    window: dialog.QsWindow?.window
    onAnchoring: {
      const win = dialog.QsWindow?.window
      if (win) {
        const w = dialog.implicitWidth
        const h = dialog.implicitHeight
        const x = Math.max(0, (win.width - w) / 2)
        const y = Math.max(0, (win.height - h) / 2)
        dialog.anchor.rect = Qt.rect(x, y, w, h)
      }
    }
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
          text: "Close"
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
          model: [
            { name: "Theme", comp: "ThemePage" },
            { name: "Layout", comp: "LayoutPage" },
            { name: "Modules", comp: "ModulesPage" },
            { name: "Wallpaper", comp: "WallpapersPage" },
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
          onCurrentIndexChanged: {
            switch (currentIndex) {
              case 0: stack.currentIndex = 0; break
              case 1: stack.currentIndex = 1; break
              case 2: stack.currentIndex = 2; break
              case 3: stack.currentIndex = 3; break
              case 4: stack.currentIndex = 4; break
            }
          }
        }

        // Pages (non-swipe, to avoid internal ListView polish loops)
        StackLayout {
          id: stack
          Layout.fillWidth: true
          Layout.fillHeight: true
          currentIndex: 0

          Pages.ThemePage {}
          Pages.LayoutPage {}
          Pages.ModulesPage {}
          Pages.WallpapersPage {}
          Pages.SystemPage {}
        }
      }
    }
  }
}
