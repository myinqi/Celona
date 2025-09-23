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
  // Dynamic compositor version (Niri or Hyprland)
  property string compositorName: ""
  property string compositorVersion: ""
  readonly property string compositorLabel: (compositorName && compositorName.length ? (compositorName + " Version:") : "Compositor Version:")

  // Detect active compositor and fetch version once
  Process {
    id: compositorVersionProc
    running: true
    command: ["bash","-lc",
      // Prefer the active session process, then fall back to installed binaries
      "if pgrep -x niri >/dev/null 2>&1; then echo NAME=Niri; niri --version 2>/dev/null | head -n1; exit 0; fi; " +
      "if pgrep -x Hyprland >/dev/null 2>&1; then echo NAME=Hyprland; (hyprctl -v 2>/dev/null || Hyprland -v 2>/dev/null) | head -n1; exit 0; fi; " +
      "if command -v niri >/dev/null 2>&1; then echo NAME=Niri; niri --version 2>/dev/null | head -n1; exit 0; fi; " +
      "if command -v hyprctl >/dev/null 2>&1; then echo NAME=Hyprland; hyprctl -v 2>/dev/null | head -n1; exit 0; fi; " +
      "if command -v Hyprland >/dev/null 2>&1; then echo NAME=Hyprland; Hyprland -v 2>/dev/null | head -n1; exit 0; fi; " +
      "echo NAME=Unknown; echo __MISSING__"
    ]
    stdout: SplitParser {
      onRead: (data) => {
        const line = String(data).trim()
        if (line.startsWith("NAME=")) {
          page.compositorName = line.slice(5)
          return
        }
        if (line === '__MISSING__') {
          page.compositorVersion = 'not found'
          compositorVersionProc.running = false
          return
        }
        if (line.length) page.compositorVersion = line
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 10

    Label {
      text: "System"
      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
      font.bold: true
      font.family: Globals.mainFontFamily
      font.pixelSize: Globals.mainFontSize
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

          // Compositor Version row (Niri or Hyprland)
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Wayland compositor:"
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            Item { Layout.fillWidth: true }
            Text {
              text: page.compositorVersion
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: "monospace"
            }
          }

          // Row aligned and styled similar to WallpapersPage's "Animated Wallpaper:" row
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Celona Version:"
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
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
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            Item { Layout.fillWidth: true }
            Button {
              id: toggleNotesBtn
              text: page.showReleaseNotes ? "hide" : "show"
              enabled: (Globals.celonaReleaseNotes && Globals.celonaReleaseNotes.length > 0)
              onClicked: page.showReleaseNotes = !page.showReleaseNotes
              contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
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

          // Main font configuration
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Main Font:"
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            TextField {
              id: mainFontField
              Layout.fillWidth: true
              text: String(Globals.mainFontFamily || "JetBrains Mono Nerd Font")
            }
            Button {
              id: applyFontBtn
              text: "apply"
              enabled: mainFontField.text && mainFontField.text.trim().length > 0
              onClicked: {
                Globals.mainFontFamily = mainFontField.text.trim()
                Globals.saveTheme()
              }
              contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
              background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
            }
            Button {
              id: resetFontBtn
              text: "reset"
              onClicked: {
                mainFontField.text = "JetBrains Mono Nerd Font"
                Globals.mainFontFamily = "JetBrains Mono Nerd Font"
                Globals.saveTheme()
              }
              contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
              background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
            }
          }

          // (moved) Live preview for main font appears below the size slider

          // Tooltip font size configuration
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Main Font Size:"
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            Item { Layout.fillWidth: true }
            // Slider gives immediate visual feedback; range clamped to 11–17
            Slider {
              id: mainFontSizeSlider
              from: 11; to: 17; stepSize: 1
              value: Math.max(10, Math.min(17, Number(Globals.mainFontSize || 12)))
              Layout.preferredWidth: 220
              onValueChanged: Globals.mainFontSize = Math.round(value)
              onPressedChanged: if (!pressed) Globals.saveTheme()
            }
            // Current value indicator
            Text {
              text: String(Math.round(mainFontSizeSlider.value))
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              Layout.preferredWidth: 28
              // Keep this label size fixed so it doesn't jump while sliding
              font.pixelSize: 12
            }
          }

          // Spacer to keep some breathing room at bottom
          Item { Layout.fillWidth: true; Layout.preferredHeight: 4 }
        }
      }
    }
  }
}
