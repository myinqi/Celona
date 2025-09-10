import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Io
import "../../"
import "root:/"
import QtCore

Item {
  id: page
  // Size provided by parent SwipeView; avoid anchors to prevent conflicts
  width: parent ? parent.width : 0
  height: parent ? parent.height : 0

  // Track current Matugen mode from root:/matugen_mode (canonical)
  property string currentMatugenMode: ""

  // Read current Matugen mode (source of truth)
  FileView {
    id: matugenModeView
    path: Qt.resolvedUrl("root:/matugen_mode")
    onLoaded: {
      try {
        const t = String(matugenModeView.text()).trim()
        page.currentMatugenMode = (t === "light" || t === "dark") ? t : ""
      } catch (e) { page.currentMatugenMode = "" }
    }
  }

  // Runner to force-generate Matugen colors for current mode
  Process {
    id: matugenProc
    running: false
    property bool _pendingSecond: false
    onRunningChanged: if (!running) {
      if (matugenProc._pendingSecond) {
        // Run second toggle to return to original mode but regenerate colors
        matugenProc._pendingSecond = false
        const togglePath = String(Qt.resolvedUrl("root:/scripts/matugen-toggle.sh")).replace(/^file:\/\//, "")
        matugenProc.command = ["bash", "-lc", '"' + togglePath.replace(/"/g,'\\"') + '"']
        matugenProc.running = true
        return
      }
      if (matugenModeView) matugenModeView.reload()
      if (Globals.useMatugenColors) Globals.applyMatugenColors()
    }
  }

  Component.onCompleted: {
    if (matugenModeView) matugenModeView.reload()
  }

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
            text: "Browse..."
            onClicked: {
              staticFileDialog.open()
            }
          }
          Button {
            id: applyStaticBtn
            text: "Apply"
            enabled: staticPathField.text && staticPathField.text.trim().length > 0
            onClicked: {
              Globals.wallpaperStaticPath = staticPathField.text
              // Force static apply: turn off animated and set static now
              Globals.wallpaperAnimatedEnabled = false
              wpSwitch.checked = false  // Update UI switch
              Globals.stopAnimatedAndSetStatic()
              Globals.saveTheme()
              // Ensure Niri focus ring colors are applied immediately (independent of Matugen flow)
              if (Globals.updateNiriColorsFromTheme) Globals.updateNiriColorsFromTheme()
              // Regenerate Matugen colors without changing final mode: run toggle twice
              const togglePath = String(Qt.resolvedUrl("root:/scripts/matugen-toggle.sh")).replace(/^file:\/\//, "")
              matugenProc._pendingSecond = true
              matugenProc.command = ["bash", "-lc", '"' + togglePath.replace(/"/g,'\\"') + '"']
              matugenProc.running = true
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
            text: "Browse..."
            onClicked: {
              animatedFileDialog.open()
            }
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
              // Also update Niri focus ring colors right away
              if (Globals.updateNiriColorsFromTheme) Globals.updateNiriColorsFromTheme()
              // Regenerate Matugen colors without changing final mode: run toggle twice
              const togglePath2 = String(Qt.resolvedUrl("root:/scripts/matugen-toggle.sh")).replace(/^file:\/\//, "")
              matugenProc._pendingSecond = true
              matugenProc.command = ["bash", "-lc", '"' + togglePath2.replace(/"/g,'\\"') + '"']
              matugenProc.running = true
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

        

        // Native file dialogs (platform dialogs should open as floating windows)
        Platform.FileDialog {
          id: staticFileDialog
          title: "Choose static wallpaper"
          folder: (Globals.wallpaperStaticPath && Globals.wallpaperStaticPath.startsWith("/"))
                    ? "file://" + Globals.wallpaperStaticPath.substring(0, Globals.wallpaperStaticPath.lastIndexOf("/"))
                    : "file://" + Platform.StandardPaths.writableLocation(Platform.StandardPaths.PicturesLocation)
          nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)", "All files (*)"]
          onAccepted: {
            const list = files && files.length ? files : (file ? [file] : [])
            if (list.length > 0)
              staticPathField.text = list[0].toString().replace("file://", "")
          }
        }
        
        Platform.FileDialog {
          id: animatedFileDialog
          title: "Choose animated wallpaper"
          folder: (Globals.wallpaperAnimatedPath && Globals.wallpaperAnimatedPath.startsWith("/"))
                    ? "file://" + Globals.wallpaperAnimatedPath.substring(0, Globals.wallpaperAnimatedPath.lastIndexOf("/"))
                    : "file://" + Platform.StandardPaths.writableLocation(Platform.StandardPaths.MoviesLocation)
          nameFilters: ["Videos (*.mp4 *.mkv *.webm *.mov *.avi *.m4v)", "All files (*)"]
          onAccepted: {
            const list = files && files.length ? files : (file ? [file] : [])
            if (list.length > 0)
              animatedPathField.text = list[0].toString().replace("file://", "")
          }
        }

        // Spacer to keep content at the top and use remaining space
        Item { Layout.fillHeight: true }
      }
    }
  }
}
