import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "../../utils" as Utils
import "root:/"

Item {
  id: page
  width: parent ? parent.width : 0
  height: parent ? parent.height : 0

  // Detect compositor
  readonly property bool isHyprland: Utils.CompositorUtils.isHyprland
  readonly property bool isNiri: !isHyprland
  
  // Config path based on compositor
  readonly property string configPath: isHyprland 
    ? (Globals.homeDir + "/.config/hypr/hyprland.conf")
    : (Globals.homeDir + "/.config/niri/config.kdl")
  
  property string configContent: ""
  property string configSnapshot: "" // Snapshot taken when page becomes visible
  property bool hasUnsavedChanges: false
  property bool saveSuccess: false
  property string saveMessage: ""

  // Load config file
  FileView {
    id: configFile
    path: "file://" + page.configPath
    onLoaded: {
      try {
        const newContent = String(configFile.text())
        page.configContent = newContent
        // Update TextArea explicitly (binding is broken after user edits)
        if (textArea) textArea.text = newContent
        page.hasUnsavedChanges = false
        console.log("[CompositorPage] Loaded config from:", page.configPath, "(" + newContent.length + " bytes)")
      } catch (e) {
        console.warn("[CompositorPage] Error loading config:", e)
        const errorMsg = "# Error loading config file\n# Path: " + page.configPath
        page.configContent = errorMsg
        if (textArea) textArea.text = errorMsg
      }
    }
    onLoadFailed: (error) => {
      console.warn("[CompositorPage] Failed to load config:", error)
      const errorMsg = "# Failed to load config file\n# Path: " + page.configPath + "\n# Error: " + error
      page.configContent = errorMsg
      if (textArea) textArea.text = errorMsg
    }
  }

  // Save process
  Process {
    id: saveProc
    running: false
    onExited: (code, status) => {
      if (code === 0) {
        page.saveSuccess = true
        page.saveMessage = "Config saved successfully"
        page.hasUnsavedChanges = false
        configFile.reload()
      } else {
        page.saveSuccess = false
        page.saveMessage = "Failed to save config (exit code: " + code + ")"
      }
      saveMessageTimer.restart()
    }
  }

  // Auto-hide save message
  Timer {
    id: saveMessageTimer
    interval: 3000
    repeat: false
    onTriggered: page.saveMessage = ""
  }

  Component.onCompleted: {
    if (configFile) configFile.reload()
    // Take initial snapshot after reload
    Qt.callLater(function() {
      page.configSnapshot = page.configContent
    })
  }

  // Reload config whenever this page becomes the current item in the StackLayout
  StackLayout.onIsCurrentItemChanged: {
    if (StackLayout.isCurrentItem && configFile && !page.hasUnsavedChanges) {
      console.log("[CompositorPage] Reloading config (tab switched to Compositor)")
      configFile.reload()
      // Take snapshot after reload completes
      Qt.callLater(function() {
        page.configSnapshot = page.configContent
      })
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 10

    // Header
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Label {
        text: "Compositor Configuration"
        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
        font.bold: true
        font.pixelSize: 16
      }

      Item { Layout.fillWidth: true }

      // Compositor indicator (simple text, no button style)
      Label {
        id: compositorLabel
        text: page.isHyprland ? "Hyprland" : "Niri"
        color: Globals.barBorderColor !== "" ? Globals.barBorderColor : "#00bee7"
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
        font.bold: true
      }
    }

    // Info text
    Label {
      Layout.fillWidth: true
      text: "Editing: " + page.configPath
      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
      font.family: "monospace"
      font.pixelSize: 11
      elide: Text.ElideMiddle
    }

    // Editor area
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 6
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1

      Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        contentWidth: textArea.implicitWidth
        contentHeight: textArea.implicitHeight
        ScrollBar.vertical: ScrollBar { 
          policy: ScrollBar.AlwaysOn 
          width: 12
        }
        ScrollBar.horizontal: ScrollBar { 
          policy: ScrollBar.AsNeeded 
          height: 12
        }

        TextArea {
          id: textArea
          width: flick.width
          text: page.configContent
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.family: "monospace"
          font.pixelSize: 12
          wrapMode: TextArea.NoWrap
          selectByMouse: true
          
          background: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.2)
            radius: 4
          }

          onTextChanged: {
            if (text !== page.configContent) {
              page.hasUnsavedChanges = true
            }
          }
        }
      }
    }

    // Bottom bar with save button and status
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      // Unsaved changes indicator
      Label {
        visible: page.hasUnsavedChanges
        text: "● Unsaved changes"
        color: "#ff9800"
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
      }

      // Save message
      Label {
        visible: page.saveMessage !== ""
        text: page.saveMessage
        color: page.saveSuccess ? "#4caf50" : "#f44336"
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
      }

      Item { Layout.fillWidth: true }

      // Reload button
      Button {
        text: "Refresh"
        enabled: !page.hasUnsavedChanges
        onClicked: {
          if (configFile) configFile.reload()
        }
        contentItem: Label {
          text: parent.text
          color: parent.enabled ? (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF") : "#888888"
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
          radius: 6
          color: parent.enabled ? (Globals.popupBg !== "" ? Globals.popupBg : palette.active.button) : "#333333"
          border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
          border.width: 1
        }
      }

      // Reset button (revert to snapshot taken when page was opened)
      Button {
        text: "Reset to Initial"
        enabled: page.configSnapshot !== "" && textArea.text !== page.configSnapshot
        onClicked: {
          try {
            // Revert to snapshot
            textArea.text = page.configSnapshot
            
            // Save the reverted config immediately
            const tmpPath = page.configPath + ".tmp"
            const content = page.configSnapshot
            const escapedContent = content.replace(/'/g, "'\\''")
            saveProc.command = [
              "bash", "-c",
              "printf '%s' '" + escapedContent + "' > '" + tmpPath + "' && mv '" + tmpPath + "' '" + page.configPath + "'"
            ]
            saveProc.running = true
            
            page.hasUnsavedChanges = false
            page.saveMessage = "Reverted to initial state and saved"
            page.saveSuccess = true
            saveMessageTimer.restart()
          } catch (e) {
            console.warn("[CompositorPage] Reset error:", e)
            page.saveSuccess = false
            page.saveMessage = "Error reverting: " + String(e)
            saveMessageTimer.restart()
          }
        }
        contentItem: Label {
          text: parent.text
          color: parent.enabled ? (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF") : "#888888"
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
          radius: 6
          color: parent.enabled ? (Globals.barBorderColor !== "" ? Globals.barBorderColor : "#00bee7") : "#333333"
          border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
          border.width: 1
          opacity: parent.enabled ? 1.0 : 0.3
        }
      }

      // Save button
      Button {
        text: "Save Config"
        enabled: page.hasUnsavedChanges
        onClicked: {
          try {
            // Use printf instead of echo to handle multi-line content safely
            const tmpPath = page.configPath + ".tmp"
            const content = textArea.text
            // Escape single quotes by replacing ' with '\''
            const escapedContent = content.replace(/'/g, "'\\''")
            saveProc.command = [
              "bash", "-c",
              "printf '%s' '" + escapedContent + "' > '" + tmpPath + "' && mv '" + tmpPath + "' '" + page.configPath + "'"
            ]
            saveProc.running = true
          } catch (e) {
            console.warn("[CompositorPage] Save error:", e)
            page.saveSuccess = false
            page.saveMessage = "Error: " + String(e)
            saveMessageTimer.restart()
          }
        }
        contentItem: Label {
          text: parent.text
          color: parent.enabled ? (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF") : "#888888"
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
          radius: 6
          color: parent.enabled ? (Globals.barBorderColor !== "" ? Globals.barBorderColor : "#00bee7") : "#333333"
          border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
          border.width: 1
          opacity: parent.enabled ? 1.0 : 0.3
        }
      }
    }
  }
}
