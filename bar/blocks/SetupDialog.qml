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
  // Item in the bar to which this dialog should align (e.g., the Setup block root)
  property Item anchorItem

  // Dialog size
  implicitWidth: 820
  implicitHeight: 560

  // Attach to window and position like the old Setup popup (right section, offset from bar)
  anchor {
    window: dialog.QsWindow?.window
    edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
    gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
    onAnchoring: {
      const win = dialog.QsWindow?.window
      if (!win || !dialog.anchorItem) return
      const gap = 6
      const yLocal = (Globals.barPosition === "top")
        ? (dialog.anchorItem.height + gap)
        : (-(dialog.implicitHeight + gap))
      const xLocal = -(dialog.implicitWidth - dialog.anchorItem.width) / 2
      const rect = win.contentItem.mapFromItem(dialog.anchorItem, xLocal, yLocal, dialog.implicitWidth, dialog.implicitHeight)
      dialog.anchor.rect = rect
    }
  }

  // Re-anchor on show and when size changes
  function reanchor() {
    const win = dialog.QsWindow?.window
    if (!win || !dialog.anchorItem) return
    const gap = 6
    const yLocal = (Globals.barPosition === "top")
      ? (dialog.anchorItem.height + gap)
      : (-(dialog.implicitHeight + gap))
    const xLocal = -(dialog.implicitWidth - dialog.anchorItem.width) / 2
    const rect = win.contentItem.mapFromItem(dialog.anchorItem, xLocal, yLocal, dialog.implicitWidth, dialog.implicitHeight)
    dialog.anchor.rect = rect
  }

  onVisibleChanged: if (visible) Qt.callLater(reanchor)
  onImplicitHeightChanged: if (visible) reanchor()
  onImplicitWidthChanged: if (visible) reanchor()

  Connections {
    target: Globals
    function onBarPositionChanged() {
      if (dialog.visible) dialog.visible = false
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
            { name: "Dock", comp: "DockPage" },
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
              case 0: stack.currentIndex = 0; break // Theme
              case 1: stack.currentIndex = 1; break // Layout
              case 2: stack.currentIndex = 2; break // Modules
              case 3: stack.currentIndex = 3; break // Wallpaper
              case 4: stack.currentIndex = 4; break // Dock
              case 5: stack.currentIndex = 5; break // System
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
          Pages.DockPage {}
          Pages.SystemPage {}
        }
      }
    }
  }
}
