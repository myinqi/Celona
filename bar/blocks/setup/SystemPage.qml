import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "root:/"

Item {
  id: page
  width: parent ? parent.width : 0
  height: parent ? parent.height : 0
  Component.onCompleted: {
    try {
      if (avatarRow) {
        // Lightweight reader for defaults file
      }
    } catch (e) {}
  }
  // Toggle for viewing all release notes
  property bool showReleaseNotes: false
  onVisibleChanged: {
    if (visible) {
      // Optionally, reload version file to catch external updates
      // versionView.reload()
    }
  }
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
      "if pgrep -x Hyprland >/dev/null 2>&1; then echo NAME=Hyprland; (hyprctl version 2>/dev/null || Hyprland --version 2>/dev/null) | head -n1; exit 0; fi; " +
      "if command -v niri >/dev/null 2>&1; then echo NAME=Niri; niri --version 2>/dev/null | head -n1; exit 0; fi; " +
      "if command -v hyprctl >/dev/null 2>&1; then echo NAME=Hyprland; hyprctl version 2>/dev/null | head -n1; exit 0; fi; " +
      "if command -v Hyprland >/dev/null 2>&1; then echo NAME=Hyprland; Hyprland --version 2>/dev/null | head -n1; exit 0; fi; " +
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
        if (line.length) {
          // Normalize to: "<Name> <X.Y.Z>" if possible
          try {
            const name = page.compositorName || ""
            const m = line.match(/\b\d+(?:\.\d+)+\b/)
            if (name && m && m[0]) {
              page.compositorVersion = name + " " + m[0]
            } else {
              // Fallback to the first line as-is
              page.compositorVersion = line
            }
          } catch (e) {
            page.compositorVersion = line
          }
        }
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

          // Release Notes header row
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
              enabled: Globals.celonaVersionHistory && Globals.celonaVersionHistory.length > 0
              onClicked: page.showReleaseNotes = !page.showReleaseNotes
              contentItem: Label { 
                text: parent.text
                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                font.family: Globals.mainFontFamily
                font.pixelSize: Globals.mainFontSize
              }
              background: Rectangle { 
                radius: 6
                color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button
                border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                border.width: 1
              }
            }
          }

          // All Release Notes (collapsible)
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: page.showReleaseNotes ? allNotesColumn.implicitHeight + 24 : 0
            visible: page.showReleaseNotes && Globals.celonaVersionHistory && Globals.celonaVersionHistory.length > 0
            Layout.bottomMargin: 12
            radius: 6
            color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
            border.width: 1
            clip: true

            Flickable {
              anchors.fill: parent
              anchors.margins: 12
              contentHeight: allNotesColumn.implicitHeight
              clip: true
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

              ColumnLayout {
                id: allNotesColumn
                width: parent.width
                spacing: 16

                Repeater {
                  model: Globals.celonaVersionHistory
                  delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Version header
                    Label {
                      text: modelData.version
                      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                      font.family: "monospace"
                      font.pixelSize: 14
                      font.bold: index === 0 // Bold for latest version
                    }

                    // Release notes text
                    Text {
                      Layout.fillWidth: true
                      text: modelData.notes || "(no notes)"
                      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                      wrapMode: Text.Wrap
                      font.pixelSize: 12
                      opacity: 0.9
                    }

                    // Separator (except for last item)
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 1
                      color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                      opacity: 0.3
                      visible: index < Globals.celonaVersionHistory.length - 1
                    }
                  }
                }
              }
            }
          }

          // Main font configuration
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Main Font:"
              Layout.preferredWidth: 150
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            TextField {
              id: mainFontField
              Layout.fillWidth: true
              text: String(Globals.mainFontFamily || "JetBrains Mono Nerd Font")
              // Commit on Enter / editing finished
              onEditingFinished: {
                const v = String(text).trim()
                if (v && v !== Globals.mainFontFamily) {
                  Globals.mainFontFamily = v
                  Globals.saveTheme()
                }
              }
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

          // Main font size configuration
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

          // Weather Location (immediately persisted)
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Weather Location:"
              Layout.preferredWidth: 150
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            TextField {
              id: weatherLocationField
              Layout.fillWidth: true
              text: String(Globals.weatherLocation || "")
              placeholderText: "90587, Obermichelbach, DE"
              onEditingFinished: {
                const v = String(text).trim()
                if (v !== Globals.weatherLocation) {
                  Globals.weatherLocation = v
                  Globals.saveTheme()
                }
              }
            }
          }

          // Weather Unit (C/F)
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Weather Unit:"
              Layout.preferredWidth: 150
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            ComboBox {
              id: weatherUnitCombo
              model: ["C", "F"]
              implicitWidth: 50
              Component.onCompleted: {
                const cur = String(Globals.weatherUnit || "C")
                const idx = model.indexOf(cur)
                weatherUnitCombo.currentIndex = (idx >= 0) ? idx : 0
              }
              onActivated: (index) => {
                const v = String(model[index])
                if (v !== Globals.weatherUnit) {
                  Globals.weatherUnit = v
                  Globals.saveTheme()
                }
              }
            }
          }

          // Keybinds Path (immediately persisted)
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label {
              text: "Keybinds Path:"
              Layout.preferredWidth: 150
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            TextField {
              id: keybindsPathField
              Layout.fillWidth: true
              text: String(Globals.keybindsPath || "")
              placeholderText: "~/.config/niri/config.kdl"
              onEditingFinished: {
                const v = String(text).trim()
                if (v !== Globals.keybindsPath) {
                  Globals.keybindsPath = v
                  Globals.saveTheme()
                }
              }
            }
          }

          // User Icon (browse + preview + apply via script)
          RowLayout {
            id: avatarRow
            Layout.fillWidth: true
            spacing: 10
            // State
            property string _user: ""
            property string _filePath: ""
            property string _currentPath: ""
            // Detect current user once
            Process {
              id: whoamiProc
              running: true
              command: ["bash","-lc",
                'u="$([ -x /usr/bin/id ] && /usr/bin/id -un 2>/dev/null)"; ' +
                '[ -n "$u" ] || u="$([ -x /usr/bin/getent ] && [ -x /usr/bin/id ] && /usr/bin/getent passwd "$(/usr/bin/id -u 2>/dev/null)" 2>/dev/null | cut -d: -f1)"; ' +
                '[ -n "$u" ] || u="$([ -x /usr/bin/printenv ] && /usr/bin/printenv USER 2>/dev/null)"; ' +
                '[ -n "$u" ] || u="$([ -x /usr/bin/whoami ] && /usr/bin/whoami 2>/dev/null)"; ' +
                '[ -n "$u" ] || u="$([ -x /usr/bin/basename ] && /usr/bin/basename "$HOME" 2>/dev/null)"; ' +
                'printf "%s" "$u"'
              ]
              stdout: SplitParser { onRead: (data) => { const s = String(data).trim(); if (s.length) { avatarRow._user = s } } }
            }
            // Retry once shortly after load if user is still empty
            Timer {
              interval: 800
              repeat: false
              running: true
              onTriggered: { if (!avatarRow._user || !avatarRow._user.length) whoamiProc.running = true }
            }
            // Second retry in rare cases
            Timer {
              interval: 1800
              repeat: false
              running: true
              onTriggered: { if (!avatarRow._user || !avatarRow._user.length) whoamiProc.running = true }
            }
            // Probe current avatar path (~/.face or AccountsService icon)
            Process {
              id: curAvatarProc
              running: true
              command: ["bash","-lc",
                'u="${USER:-$(id -un)}"; for f in "$HOME/.face" "$HOME/.face.icon" "/var/lib/AccountsService/icons/$u" "/usr/share/sddm/faces/$u.face.icon"; do [ -r "$f" ] && { printf "%s\n" "$f"; exit 0; }; done; uf="/var/lib/AccountsService/users/$u"; iconPath=""; if [ -r "$uf" ]; then while IFS= read -r line; do case "$line" in Icon=*) iconPath="${line#Icon=}"; break;; esac; done < "$uf"; fi; [ -n "$iconPath" ] && [ -r "$iconPath" ] && { printf "%s\n" "$iconPath"; exit 0; }; echo'
              ]
              stdout: SplitParser { onRead: (data) => { const s = String(data).trim(); if (s.length) { avatarRow._currentPath = s; curAvatar.source = Qt.resolvedUrl(s) } } }
            }
            Label {
              text: "Change user icon:"
              Layout.preferredWidth: 150
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
            }
            // Username (read-only, from $USER)
            Label {
              id: userText
              Layout.preferredWidth: 150
              text: (avatarRow._user && avatarRow._user.length) ? avatarRow._user : "unknown"
              color: Globals.moduleValueColor !== "" ? Globals.moduleValueColor : (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF")
              font.family: Globals.mainFontFamily
              font.pixelSize: Globals.mainFontSize
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignLeft
              verticalAlignment: Text.AlignVCenter
              ToolTip.visible: false
              ToolTip.text: text
            }
            // Current avatar next to username (left side)
            Image {
              id: curAvatar
              source: ""
              sourceSize.width: 32; sourceSize.height: 32
              width: 32; height: 32
              fillMode: Image.PreserveAspectFit
              smooth: true; antialiasing: true
              visible: !!source
            }
            Button {
              id: browseBtn
              text: "browse"
              onClicked: fileDialog.open()
              contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
              background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
              ToolTip {
                id: browseTip
                visible: parent.hovered
                text: "Pick image for new user icon"
                delay: 600
                contentItem: Text {
                  text: browseTip.text
                  color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
                }
                background: Rectangle {
                  color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                  border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                  border.width: 1
                  radius: 6
                }
              }
            }
            // Preview: only the new selection on the right to avoid confusion
            ColumnLayout {
              spacing: 2
              RowLayout {
                spacing: 12
                Image { id: newAvatar; source: avatarRow._filePath ? Qt.resolvedUrl(avatarRow._filePath) : ""; sourceSize.width: 48; sourceSize.height: 48; width: 48; height: 48; fillMode: Image.PreserveAspectFit; smooth: true; antialiasing: true; visible: !!source }
              }
              RowLayout {
                spacing: 12
                Label { text: "    new"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.pixelSize: 10 }
              }
            }
            // Apply button: always launch terminal using run-in-terminal.sh
            Button {
              id: applyAvatarBtn
              text: "apply"
              enabled: (String(avatarRow._user||"").length > 0 && String(avatarRow._filePath||"").length > 0)
              onClicked: {
                const u = String(avatarRow._user||"").trim()
                const p = String(avatarRow._filePath||"").trim()
                if (!u.length || !p.length) return
                const runner = Qt.resolvedUrl("root:/scripts/run-in-terminal.sh")
                const script = Qt.resolvedUrl("root:/scripts/change_avatar.sh")
                openAvatarTerminal.command = [
                  "bash", "-lc",
                  "RUNNER=\"" + runner + "\"; RUNNER=${RUNNER#file://}; AVSH=\"" + script + "\"; AVSH=${AVSH#file://}; " +
                  "sh \"$RUNNER\" sudo \"$AVSH\" '" + u + "' '" + p + "'"
                ]
                openAvatarTerminal.running = true
              }
              contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
              background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
              ToolTip {
                id: applyTip
                visible: parent.hovered
                text: "Open terminal and apply (sudo)"
                delay: 600
                contentItem: Text {
                  text: applyTip.text
                  color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
                }
                background: Rectangle {
                  color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                  border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                  border.width: 1
                  radius: 6
                }
              }
            }
            // File dialog (images)
            FileDialog {
              id: fileDialog
              title: "Choose an avatar image"
              nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.svg *.gif *.bmp)"]
              onAccepted: {
                try {
                  const url = String(selectedFile)
                  let path = url
                  if (url.startsWith("file://")) path = url.replace(/^file:\/\//, "")
                  avatarRow._filePath = path
                  newAvatar.source = Qt.resolvedUrl(path)
                } catch (e) { /* ignore */ }
              }
            }
            // Terminal runner and refresh (uses scripts/run-in-terminal.sh)
            Process {
              id: openAvatarTerminal
              running: false
              stdout: SplitParser { onRead: _ => {} }
              onRunningChanged: if (!running) {
                curAvatarProc.running = true
              }
            }
          }

          // Spacer to keep some breathing room at bottom
          Item { Layout.fillWidth: true; Layout.preferredHeight: 4 }
        }
      }
    }
  }
}
