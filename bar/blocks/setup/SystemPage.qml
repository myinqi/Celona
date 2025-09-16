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
  // Toggle for viewing release notes
  property bool showReleaseNotes: false

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 10

    Label {
      text: "System"
      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
      font.bold: true
      font.pixelSize: 16
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 8
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1
      // Make the entire frame scrollable like in ThemePage.qml
      Flickable {
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        contentWidth: width
        contentHeight: contentCol.childrenRect.height
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
          id: contentCol
          width: parent.width
          spacing: 10

          // Row aligned and styled similar to WallpapersPage's "Animated Wallpaper:" row
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Celona Version:"
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            }
            Item { Layout.fillWidth: true }
            Text {
              text: Globals.celonaVersion
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: "monospace"
            }
          }

          // Release Notes header row (aligned to other rows)
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Release Notes:"
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            }
            Item { Layout.fillWidth: true }
            Button {
              id: toggleNotesBtn
              text: page.showReleaseNotes ? "hide" : "show"
              enabled: (Globals.celonaReleaseNotes && Globals.celonaReleaseNotes.length > 0)
              onClicked: page.showReleaseNotes = !page.showReleaseNotes
              contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
              background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
            }
          }

          // Release Notes body (collapsible)
          Rectangle {
            Layout.fillWidth: true
            // Height depends on content length; add 24px padding (12 top + 12 bottom)
            Layout.preferredHeight: page.showReleaseNotes ? (notesText.paintedHeight + 24) : 0
            visible: page.showReleaseNotes && (Globals.celonaReleaseNotes && Globals.celonaReleaseNotes.length > 0)
            // Add space below the release notes block
            Layout.bottomMargin: 12
            radius: 6
            color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
            border.width: 1
            clip: true

            Text {
              id: notesText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              anchors.topMargin: 12
              text: Globals.celonaReleaseNotes
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              wrapMode: Text.Wrap
              font.pixelSize: 13
            }
          }

          // Spacer to keep some breathing room at bottom
          Item { Layout.fillWidth: true; Layout.preferredHeight: 4 }
        }
      }
    }
  }
}
