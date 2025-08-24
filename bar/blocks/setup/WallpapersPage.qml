import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "root:/"
import QtQuick.Dialogs
import QtCore

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
                color: (Globals.tooltipText && Globals.tooltipText !== "") ? Globals.tooltipText : "#FFFFFF"
              }
              background: Rectangle {
                color: (Globals.tooltipBg && Globals.tooltipBg !== "") ? Globals.tooltipBg : palette.active.toolTipBase
                border.color: (Globals.tooltipBorder && Globals.tooltipBorder !== "") ? Globals.tooltipBorder : palette.active.light
                border.width: 1
                radius: 6
              }
            }
          }
        }

        // Static wallpaper selector
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Static:"
            Layout.preferredWidth: 110
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          TextField {
            id: staticPathField
            Layout.fillWidth: true
            text: String(Globals.wallpaperStaticPath || "")
          }
          Button {
            id: browseStaticBtn
            text: "Browse…"
            onClicked: staticFileDialog.open()
          }
          Button {
            id: applyStaticBtn
            text: "Apply"
            enabled: staticPathField.text && staticPathField.text.trim().length > 0
            onClicked: {
              Globals.wallpaperStaticPath = staticPathField.text
              // Force static apply: turn off animated and set static now
              Globals.wallpaperAnimatedEnabled = false
              Globals.stopAnimatedAndSetStatic()
              Globals.saveTheme()
            }
            ToolTip {
              id: staticApplyTip
              visible: applyStaticBtn.hovered
              text: "Set static wallpaper path and save"
              contentItem: Text { text: staticApplyTip.text; color: (Globals.tooltipText && Globals.tooltipText !== "") ? Globals.tooltipText : "#FFFFFF" }
              background: Rectangle { color: (Globals.tooltipBg && Globals.tooltipBg !== "") ? Globals.tooltipBg : palette.active.toolTipBase; border.color: (Globals.tooltipBorder && Globals.tooltipBorder !== "") ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
            }
          }
        }

        // Animated wallpaper selector
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Animated:"
            Layout.preferredWidth: 110
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          TextField {
            id: animatedPathField
            Layout.fillWidth: true
            text: String(Globals.wallpaperAnimatedPath || "")
          }
          Button {
            id: browseAnimatedBtn
            text: "Browse…"
            onClicked: animatedFileDialog.open()
          }
          Button {
            id: applyAnimatedBtn
            text: "Apply"
            enabled: animatedPathField.text && animatedPathField.text.trim().length > 0
            onClicked: {
              Globals.wallpaperAnimatedPath = animatedPathField.text
              if (Globals.wallpaperAnimatedEnabled) {
                Globals.startAnimatedWallpaper()
              }
              Globals.saveTheme()
            }
            ToolTip {
              id: animatedApplyTip
              visible: applyAnimatedBtn.hovered
              text: "Set animated wallpaper path and save"
              contentItem: Text { text: animatedApplyTip.text; color: (Globals.tooltipText && Globals.tooltipText !== "") ? Globals.tooltipText : "#FFFFFF" }
              background: Rectangle { color: (Globals.tooltipBg && Globals.tooltipBg !== "") ? Globals.tooltipBg : palette.active.toolTipBase; border.color: (Globals.tooltipBorder && Globals.tooltipBorder !== "") ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
            }
          }
        }

        

        // File dialogs
        FileDialog {
          id: staticFileDialog
          title: "Choose static wallpaper"
          // Default to Home when no prior path exists to avoid empty watcher warnings
          currentFolder: {
            const p = String(Globals.wallpaperStaticPath || "")
            if (p.startsWith("/")) {
              const i = p.lastIndexOf("/")
              return "file://" + (i > 0 ? p.substring(0, i) : "/")
            }
            const home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
            return home ? ("file://" + home) : "file:///"
          }
          nameFilters: [
            "Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)",
            "All files (*)"
          ]
          onAccepted: {
            // selectedFile is a url; convert to local path
            var p = selectedFile.toString()
            if (p.startsWith("file://")) p = p.substring(7)
            staticPathField.text = p
          }
        }

        FileDialog {
          id: animatedFileDialog
          title: "Choose animated wallpaper"
          // Default to Home when no prior path exists to avoid empty watcher warnings
          currentFolder: {
            const p = String(Globals.wallpaperAnimatedPath || "")
            if (p.startsWith("/")) {
              const i = p.lastIndexOf("/")
              return "file://" + (i > 0 ? p.substring(0, i) : "/")
            }
            const home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
            return home ? ("file://" + home) : "file:///"
          }
          nameFilters: [
            "Videos (*.mp4 *.mkv *.webm *.mov *.avi *.m4v)",
            "All files (*)"
          ]
          onAccepted: {
            var p = selectedFile.toString()
            if (p.startsWith("file://")) p = p.substring(7)
            animatedPathField.text = p
          }
        }

        // Spacer to keep content at the top and use remaining space
        Item { Layout.fillHeight: true }
      }
    }
  }
}
