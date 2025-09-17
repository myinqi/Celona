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

  // Helpers
  function expandHome(p) {
    try {
      const s = String(p||"")
      if (s.startsWith("~/") && Globals.homeReady) return Globals.homeDir + s.slice(1)
      return s
    } catch (e) { return String(p||"") }
  }

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
      font.family: Globals.mainFontFamily
      font.pixelSize: Globals.mainFontSize
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
        id: contentCol
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10
        // Outputs state and sync helper at the container level
        property var availableOutputs: []
        function syncSelectedFromGlobals() {
          try {
            const cur = Array.isArray(Globals.wallpaperOutputs) ? Globals.wallpaperOutputs.slice() : []
            const star = cur.indexOf("*") >= 0 || cur.length === 0
            if (outputsCombo) {
              if (star) outputsCombo.currentIndex = 0
              else {
                const name = cur[0]
                const idx = 1 + Math.max(0, contentCol.availableOutputs.indexOf(name))
                outputsCombo.currentIndex = (idx >= 1) ? idx : 0
              }
            }
          } catch (e) { /* no-op */ }
        }

        // Outputs selector (simple row, aligned with other rows)
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Outputs:"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
            horizontalAlignment: Text.AlignHLeft
            Layout.alignment: Qt.AlignVCenter
            // Align with "Static:" and "Animated:" label columns
            Layout.preferredWidth: 110
          }
          ComboBox {
            id: outputsCombo
            textRole: "text"
            model: outputsListModel
            //Layout.fillWidth: true
            Layout.preferredWidth: 120
            onCurrentIndexChanged: {
              const item = (model && model.get && currentIndex >= 0 && currentIndex < model.count) ? model.get(currentIndex) : null
              const name = item ? String(item.text) : "All (*)"
              if (name === "All (*)") Globals.wallpaperOutputs = ["*"]
              else Globals.wallpaperOutputs = [name]
              Globals.saveTheme()
              if (Globals.wallpaperAnimatedEnabled) Globals.startAnimatedWallpaper(); else Globals.stopAnimatedAndSetStatic()
            }
          }
          Item { Layout.fillWidth: true }
          Button {
            id: refreshOutputsBtn
            text: "refresh"
            onClicked: outputsProc.running = true
            leftPadding: 12; rightPadding: 12
            contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
          }
        }

        // Tool selector (swww / hyprpaper)
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Tool:"
            Layout.preferredWidth: 110
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
            horizontalAlignment: Text.AlignHLeft
            Layout.alignment: Qt.AlignVCenter
          }
          ComboBox {
            id: toolCombo
            model: ["swww", "hyprpaper"]
            Component.onCompleted: {
              const cur = String(Globals.wallpaperTool || "swww")
              const idx = model.indexOf(cur)
              toolCombo.currentIndex = (idx >= 0) ? idx : 0
            }
            onActivated: (index) => {
              const val = String(model[index])
              if (val && val !== Globals.wallpaperTool) {
                Globals.wallpaperTool = val
                Globals.saveTheme()
                if (Globals.wallpaperAnimatedEnabled) Globals.startAnimatedWallpaper(); else Globals.stopAnimatedAndSetStatic()
              }
            }
          }
          Item { Layout.fillWidth: true }
        }

        // mpvpaper options (applies when animated wallpaper is enabled)
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "mpv Options:"
            Layout.preferredWidth: 110
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
            horizontalAlignment: Text.AlignHLeft
            Layout.alignment: Qt.AlignVCenter
          }
          TextField {
            id: mpvOptsField
            Layout.preferredWidth: 210
            //Layout.fillWidth: true
            text: String(Globals.mpvpaperOptions || "")
            placeholderText: "--loop --no-audio"
            onEditingFinished: {
              const v = String(text)
              if (v !== Globals.mpvpaperOptions) {
                Globals.mpvpaperOptions = v
                Globals.saveTheme()
                if (Globals.wallpaperAnimatedEnabled) Globals.startAnimatedWallpaper()
              }
            }
          }
        }

        // Spacer: visually separate Outputs from following sections (about two text lines)
        Item { Layout.preferredHeight: Globals.mainFontSize * 0 }



        // Static wallpaper selector
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Static:"
            Layout.preferredWidth: 110
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
            horizontalAlignment: Text.AlignHLeft
            Layout.alignment: Qt.AlignVCenter
          }
          TextField {
            id: staticPathField
            Layout.fillWidth: true
            text: String(Globals.wallpaperStaticPath || "")
          }
          Button {
            text: "browse"
            onClicked: {
              staticFileDialog.open()
            }
            leftPadding: 12
            rightPadding: 12
            contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
          }
          Button {
            id: applyStaticBtn
            text: "apply"
            enabled: staticPathField.text && staticPathField.text.trim().length > 0
            onClicked: {
              // Store tilde-relative path in config.json, expand to absolute on apply time in Globals
              Globals.wallpaperStaticPath = Globals.toTildePath(staticPathField.text)
              // Force static apply: turn off animated and set static now
              Globals.wallpaperAnimatedEnabled = false
              wpSwitch.checked = false  // Update UI switch
              Globals.stopAnimatedAndSetStatic()
              Globals.saveTheme()
              // Ensure Niri focus ring colors are applied immediately (independent of Matugen flow)
              if (Globals.updateNiriColorsFromTheme) Globals.updateNiriColorsFromTheme()
              // Ensure Hyprland colors are also updated immediately if Matugen is active
              if (Globals.updateHyprlandColorsFromMap && Globals.useMatugenColors && Globals._lastMatugenMap)
                Globals.updateHyprlandColorsFromMap(Globals._lastMatugenMap)
              // Regenerate Matugen colors without changing final mode: run toggle twice
              const togglePath = String(Qt.resolvedUrl("root:/scripts/matugen-toggle.sh")).replace(/^file:\/\//, "")
              matugenProc._pendingSecond = true
              matugenProc.command = ["bash", "-lc", '"' + togglePath.replace(/"/g,'\\"') + '"']
              matugenProc.running = true
            }
            leftPadding: 12
            rightPadding: 12
            contentItem: Label { text: parent.text.toLowerCase(); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
            ToolTip {
              id: staticApplyTip
              visible: applyStaticBtn.hovered
              text: "Set static wallpaper path and save"
              contentItem: Text {
                text: staticApplyTip.text
                color: (Globals.tooltipText && Globals.tooltipText !== "") ? Globals.tooltipText : "#FFFFFF"
                font.family: Globals.mainFontFamily
                font.pixelSize: Globals.mainFontSize
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

        // Animated wallpaper selector
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Animated:"
            Layout.preferredWidth: 110
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
            horizontalAlignment: Text.AlignHLeft
            Layout.alignment: Qt.AlignVCenter
          }
          TextField {
            id: animatedPathField
            Layout.fillWidth: true
            text: String(Globals.wallpaperAnimatedPath || "")
          }
          Button {
            text: "browse"
            onClicked: {
              animatedFileDialog.open()
            }
            leftPadding: 12
            rightPadding: 12
            contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
          }
          Button {
            id: applyAnimatedBtn
            text: "apply"
            enabled: animatedPathField.text && animatedPathField.text.trim().length > 0
            onClicked: {
              // Store tilde-relative path; `startAnimatedWallpaper()` expands ~ to $HOME internally
              Globals.wallpaperAnimatedPath = Globals.toTildePath(animatedPathField.text)
              if (Globals.wallpaperAnimatedEnabled) {
                Globals.startAnimatedWallpaper()
              }
              Globals.saveTheme()
              // Also update Niri focus ring colors right away
              if (Globals.updateNiriColorsFromTheme) Globals.updateNiriColorsFromTheme()
              // Also update Hyprland colors right away if Matugen is active
              if (Globals.updateHyprlandColorsFromMap && Globals.useMatugenColors && Globals._lastMatugenMap)
                Globals.updateHyprlandColorsFromMap(Globals._lastMatugenMap)
              // Regenerate Matugen colors without changing final mode: run toggle twice
              const togglePath2 = String(Qt.resolvedUrl("root:/scripts/matugen-toggle.sh")).replace(/^file:\/\//, "")
              matugenProc._pendingSecond = true
              matugenProc.command = ["bash", "-lc", '"' + togglePath2.replace(/"/g,'\\"') + '"']
              matugenProc.running = true
            }
            leftPadding: 12
            rightPadding: 12
            contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
            ToolTip {
              id: animatedApplyTip
              visible: applyAnimatedBtn.hovered
              text: "Set animated wallpaper path and save"
              contentItem: Text { text: animatedApplyTip.text; color: (Globals.tooltipText && Globals.tooltipText !== "") ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
              background: Rectangle { color: (Globals.tooltipBg && Globals.tooltipBg !== "") ? Globals.tooltipBg : palette.active.toolTipBase; border.color: (Globals.tooltipBorder && Globals.tooltipBorder !== "") ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
            }
          }
        }

        // Top row: Animated wallpaper toggle aligned like module rows
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Animated Wallpaper:"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignVCenter
          }
          Item { Layout.fillWidth: true }
          Text {
            text: wpSwitch.checked ? "On (mpvpaper)" : "Off (static)"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
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
                font.family: Globals.mainFontFamily
                font.pixelSize: Globals.mainFontSize
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

        // Discover outputs via swww (fallback: empty -> all)
        // Backing model for outputs dropdown
        ListModel { id: outputsListModel }

        Process {
          id: outputsProc
          running: true
          command: ["bash","-lc","swww query 2>/dev/null | cut -d: -f1 | sed 's/^ *//;s/ *$//' | grep -v '^$' || true"]
          property string _buf: ""
          stdout: SplitParser { onRead: data => { outputsProc._buf += String(data) } }
          onRunningChanged: {
            if (running) {
              // Reset buffer at start of each run
              outputsProc._buf = ""
            } else {
              const lines = outputsProc._buf.split(/\n/).map(s => s.trim()).filter(s => s.length>0)
              const uniq = Array.from(new Set(lines))
              if (uniq.length > 0) {
                outputsListModel.clear()
                outputsListModel.append({ text: "All (*)" })
                contentCol.availableOutputs = uniq
                for (let i = 0; i < uniq.length; i++) outputsListModel.append({ text: String(uniq[i]) })
                contentCol.syncSelectedFromGlobals()
                outputsProc._buf = ""
              } else {
                // Seed from config if we have named outputs there
                const cfg = Array.isArray(Globals.wallpaperOutputs) ? Globals.wallpaperOutputs.slice() : []
                const seeded = cfg.filter(x => x && x !== "*")
                if (seeded.length > 0) {
                  const merged = Array.from(new Set(seeded))
                  outputsListModel.clear()
                  outputsListModel.append({ text: "All (*)" })
                  contentCol.availableOutputs = merged
                  for (let i = 0; i < merged.length; i++) outputsListModel.append({ text: String(merged[i]) })
                  contentCol.syncSelectedFromGlobals()
                }
                // Try compositor-specific fallback: Hyprland -> Niri -> wlroots
                hyprProc.running = true
              }
            }
          }
        }

        // Fallback 1: Hyprland monitors
        Process {
          id: hyprProc
          running: false
          command: ["bash","-lc","hyprctl monitors 2>/dev/null | awk '/^[[:space:]]*Monitor /{print $2}' | grep -v '^$' || true"]
          property string _buf: ""
          stdout: SplitParser { onRead: data => { hyprProc._buf += String(data) } }
          onRunningChanged: {
            if (running) {
              hyprProc._buf = ""
            } else {
              const lines = hyprProc._buf.split(/\n/).map(s => s.trim()).filter(s => s.length>0)
              const uniq = Array.from(new Set(lines))
              if (uniq.length > 0) {
                outputsListModel.clear()
                outputsListModel.append({ text: "All (*)" })
                contentCol.availableOutputs = uniq
                for (let i = 0; i < uniq.length; i++) outputsListModel.append({ text: String(uniq[i]) })
                contentCol.syncSelectedFromGlobals()
              } else {
                // Seed from config if we have named outputs there
                const cfg = Array.isArray(Globals.wallpaperOutputs) ? Globals.wallpaperOutputs.slice() : []
                const seeded = cfg.filter(x => x && x !== "*")
                if (seeded.length > 0) {
                  const merged = Array.from(new Set(seeded))
                  outputsListModel.clear()
                  outputsListModel.append({ text: "All (*)" })
                  contentCol.availableOutputs = merged
                  for (let i = 0; i < merged.length; i++) outputsListModel.append({ text: String(merged[i]) })
                  contentCol.syncSelectedFromGlobals()
                }
                // Fallback 2: Niri (JSON outputs)
                niriProc.running = true
              }
              hyprProc._buf = ""
            }
          }
        }

        // Fallback 2: Niri outputs
        Process {
          id: niriProc
          running: false
          command: ["bash","-lc","niri msg -j outputs 2>/dev/null | awk -F\" '/\"name\"[[:space:]]*:/ {print $4}' | grep -v '^$' || true"]
          property string _buf: ""
          stdout: SplitParser { onRead: data => { niriProc._buf += String(data) } }
          onRunningChanged: {
            if (running) {
              niriProc._buf = ""
            } else {
              const lines = niriProc._buf.split(/\n/).map(s => s.trim()).filter(s => s.length>0)
              const uniq = Array.from(new Set(lines))
              if (uniq.length > 0) {
                outputsListModel.clear()
                outputsListModel.append({ text: "All (*)" })
                contentCol.availableOutputs = uniq
                for (let i = 0; i < uniq.length; i++) outputsListModel.append({ text: String(uniq[i]) })
                contentCol.syncSelectedFromGlobals()
              } else {
                // Seed from config if we have named outputs there
                const cfg = Array.isArray(Globals.wallpaperOutputs) ? Globals.wallpaperOutputs.slice() : []
                const seeded = cfg.filter(x => x && x !== "*")
                if (seeded.length > 0) {
                  const merged = Array.from(new Set(seeded))
                  outputsListModel.clear()
                  outputsListModel.append({ text: "All (*)" })
                  contentCol.availableOutputs = merged
                  for (let i = 0; i < merged.length; i++) outputsListModel.append({ text: String(merged[i]) })
                  contentCol.syncSelectedFromGlobals()
                }
                // Fallback 3: generic wlroots via wlr-randr
                wlrProc.running = true
              }
              niriProc._buf = ""
            }
          }
        }

        // Fallback 3: wlr-randr
        Process {
          id: wlrProc
          running: false
          command: ["bash","-lc","wlr-randr 2>/dev/null | awk '$2==\"connected\"{print $1}' | grep -v '^$' || true"]
          property string _buf: ""
          stdout: SplitParser { onRead: data => { wlrProc._buf += String(data) } }
          onRunningChanged: {
            if (running) {
              wlrProc._buf = ""
            } else {
              const lines = wlrProc._buf.split(/\n/).map(s => s.trim()).filter(s => s.length>0)
              const uniq = Array.from(new Set(lines))
              // Always rebuild model; prefer detected outputs, else seed from config
              let finalList = []
              if (uniq.length > 0) finalList = uniq
              else {
                const cfg = Array.isArray(Globals.wallpaperOutputs) ? Globals.wallpaperOutputs.slice() : []
                finalList = cfg.filter(x => x && x !== "*")
              }
              outputsListModel.clear()
              outputsListModel.append({ text: "All (*)" })
              if (finalList.length > 0) {
                const merged = Array.from(new Set(finalList))
                contentCol.availableOutputs = merged
                for (let i = 0; i < merged.length; i++) outputsListModel.append({ text: String(merged[i]) })
              }
              contentCol.syncSelectedFromGlobals()
              wlrProc._buf = ""
            }
          }
        }

        // Preview of currently selected static wallpaper
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Preview:"
            Layout.preferredWidth: 110
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
            horizontalAlignment: Text.AlignHLeft
            Layout.alignment: Qt.AlignTop
          }
          Rectangle {
            id: previewBox
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: 6
            color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
            border.width: 1
            clip: true
            Image {
              id: staticPreview
              anchors.fill: parent
              anchors.margins: 0
              source: {
                const t = String(staticPathField && staticPathField.text ? staticPathField.text : Globals.wallpaperStaticPath || "")
                const p = page.expandHome(t)
                return (p && p.startsWith("/")) ? ("file://" + p) : ""
              }
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: false
              smooth: true
            }
            // Error/empty overlay
            Item {
              anchors.fill: parent
              visible: (!staticPreview.source || staticPreview.source.length === 0 || staticPreview.status === Image.Error)
              Rectangle { anchors.fill: parent; color: "#00000000" }
              Label {
                anchors.centerIn: parent
                text: "No preview"
                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                font.family: Globals.mainFontFamily
                font.pixelSize: Globals.mainFontSize
              }
            }
          }
        }

        // Native file dialogs (platform dialogs should open as floating windows)
        Platform.FileDialog {
          id: staticFileDialog
          title: "Choose static wallpaper"
          // Remember last visited dir: prefer current text, then config; expand ~ to absolute
          folder: {
            const src = (staticPathField.text && staticPathField.text.trim().length)
                        ? staticPathField.text : String(Globals.wallpaperStaticPath||"")
            const abs = page.expandHome(src)
            if (abs && abs.indexOf("/") >= 0 && abs.startsWith("/")) {
              const dir = abs.substring(0, abs.lastIndexOf("/"))
              return "file://" + dir
            }
            return "file://" + Platform.StandardPaths.writableLocation(Platform.StandardPaths.PicturesLocation)
          }
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
          // Remember last visited dir: prefer current text, then config; expand ~ to absolute
          folder: {
            const src = (animatedPathField.text && animatedPathField.text.trim().length)
                        ? animatedPathField.text : String(Globals.wallpaperAnimatedPath||"")
            const abs = page.expandHome(src)
            if (abs && abs.indexOf("/") >= 0 && abs.startsWith("/")) {
              const dir = abs.substring(0, abs.lastIndexOf("/"))
              return "file://" + dir
            }
            return "file://" + Platform.StandardPaths.writableLocation(Platform.StandardPaths.MoviesLocation)
          }
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
