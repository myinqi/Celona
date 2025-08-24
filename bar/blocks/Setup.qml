import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root
  // Feature flag to use the new multi-page centered setup dialog
  property bool useNewSetupUI: false
  property string currentMatugenMode: ""

  // Icon-only block using Nerd Font gear
  content: BarText {
    id: label
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: "" // gear
    symbolSpacing: 0
  }

  // Read config flag from root:/config.json
  FileView {
    id: configView
    path: Qt.resolvedUrl("root:/config.json")
    onLoaded: {
      try {
        const txt = configView.text()
        const obj = JSON.parse(txt)
        root.useNewSetupUI = obj && obj.useNewSetupUI === true
      } catch (e) { root.useNewSetupUI = false }
    }
  }

  // New Setup dialog (positioned like old popup, anchored to this block)
  SetupDialog { id: setupDialog; anchorItem: root }

  // Hover tooltip: "Bar Setup"
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false

    onClicked: (mouse) => {
      tipWindow.visible = false
      if (mouse.button === Qt.LeftButton) {
        // Toggle like Sound.qml: clicking the icon again closes the settings
        if (root.useNewSetupUI) {
          setupDialog.visible = !setupDialog.visible
          if (setupDialog.visible) Qt.callLater(() => setupDialog.reanchor && setupDialog.reanchor())
        } else {
          setupPopup.visible = !setupPopup.visible
        }
      }
    }
  }

  // Tooltip below the bar
  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: tipLabel.implicitWidth + 20
    implicitHeight: tipLabel.implicitHeight + 20
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          const gap = 3
          tipWindow.anchor.rect.y = (Globals.barPosition === "top")
            ? (tipWindow.anchor.window.height + gap)
            : (-gap)
          tipWindow.anchor.rect.x = win.contentItem.mapFromItem(root, root.width / 2, 0).x
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
      border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
      border.width: 1
      radius: 8

      Text {
        id: tipLabel
        anchors.fill: parent
        anchors.margins: 10
        text: "Bar Setup"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }

  // Main popup (dummy), styled like Sound popup
  PopupWindow {
    id: setupPopup
    visible: false
    implicitWidth: 565
    implicitHeight: 950
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          const gap = 6
          const y = (Globals.barPosition === "top")
            ? (root.height + gap)
            : (-(setupPopup.implicitHeight + gap))
          const x = -(setupPopup.implicitWidth - root.width) / 2
          const rect = win.contentItem.mapFromItem(root, x, y, setupPopup.implicitWidth, setupPopup.implicitHeight)
          setupPopup.anchor.rect = rect
        }
      }
    }

    // Re-anchor after showing and when size or barPosition changes
    function reanchor() {
      const win = root.QsWindow?.window
      if (!win) return
      const gap = 6
      const y = (Globals.barPosition === "top")
        ? (root.height + gap)
        : (-(setupPopup.implicitHeight + gap))
      const x = -(setupPopup.implicitWidth - root.width) / 2
      const rect = win.contentItem.mapFromItem(root, x, y, setupPopup.implicitWidth, setupPopup.implicitHeight)
      setupPopup.anchor.rect = rect
    }

    onVisibleChanged: if (visible) Qt.callLater(reanchor)
    onImplicitHeightChanged: if (visible) reanchor()
    onImplicitWidthChanged: if (visible) reanchor()
    Connections {
      target: Globals
      function onBarPositionChanged() {
        // If user flips bar position while popup is open, close it to prevent it from being pushed under the bar
        if (setupPopup.visible) setupPopup.visible = false
        if (tipWindow.visible) tipWindow.visible = false
      }
    }

    Rectangle {
      id: setupBody
      anchors.fill: parent
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1
      radius: 8

      // Read current Matugen mode written by matugen-toggle.sh (repo-local)
      FileView {
        id: matugenModeView
        path: Qt.resolvedUrl("root:/colors.mode")
        onLoaded: {
          try {
            const t = String(matugenModeView.text()).trim()
            root.currentMatugenMode = (t === "light" || t === "dark") ? t : ""
          } catch (e) { root.currentMatugenMode = "" }
        }
      }
      // Runner to toggle Matugen light/dark
      Process {
        id: matugenProc
        running: false
        onRunningChanged: if (!running) {
          // Re-read mode and re-apply colors
          if (matugenModeView) matugenModeView.reload()
          if (Globals.useMatugenColors) Globals.applyMatugenColors()
        }
      }

      // Ensure initial mode file is read when the setup popup is created
      Component.onCompleted: {
        if (configView) configView.reload()
        if (matugenModeView) matugenModeView.reload()
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

//        Text {
//          text: "Bar Settings"
//          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
//          font.bold: true
//          Layout.fillWidth: true
//        }

        // Headings row: Colors (left) — Bar position (center) — Modules (right)
        RowLayout {
          Layout.fillWidth: true
          spacing: 4
          Label {
            text: "Colors:"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.bold: true
            font.italic: true
            Layout.preferredWidth: 80 // left column width
          }
          // Matugen toggle next to Colors label
          RowLayout {
            spacing: 0
            visible: true
            CheckBox {
              id: matugenBox
              text: ""
              enabled: Globals.matugenAvailable
              checked: Globals.useMatugenColors
              Layout.alignment: Qt.AlignVCenter
              onToggled: {
                Globals.useMatugenColors = checked
                if (checked) {
                  Globals.applyMatugenColors()
                } else {
                  // Only reset color-related properties from defaults file; keep layout and visibility settings
                  Globals.resetColorsFromDefaults()
                }
                Globals.saveTheme()
              }
              ToolTip {
                id: matugenTip
                visible: matugenBox.hovered
                text: Globals.matugenAvailable ? (matugenBox.checked ? "Matugen colors applied from colors.css" : "Disable to reset to defaults") : "colors.css not found in project"
                contentItem: Text {
                  text: matugenTip.text
                  color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
                }
                background: Rectangle {
                  color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                  border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                  border.width: 1
                  radius: 6
                }
              }
            }
            Label {
              text: "Use Matugen colors"
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
              Layout.alignment: Qt.AlignVCenter
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: matugenBox.checked = !matugenBox.checked
              }
            }
          }
          // Center spacer
          Item { Layout.fillWidth: true }
          Item { Layout.fillWidth: true }
          Label {
            text: "Modules:"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.bold: true
            font.italic: true
          }
          Item { width: 20 }
          Button {
            id: reorderBtn
            text: Globals.reorderMode ? "Finish" : "Reorder"
            onClicked: Globals.reorderMode = !Globals.reorderMode
            leftPadding: 12
            rightPadding: 12
            // Themed label/background to ensure contrast in light/dark Matugen themes
            contentItem: Label {
              text: parent.text
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
              radius: 6
              color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button
              border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
              border.width: 1
            }
            // Themed tooltip
            ToolTip {
              id: reorderTip
              visible: reorderBtn.hovered
              text: Globals.reorderMode ? "Finish: order will be saved" : "Enable: reorder modules directly in the bar"
              contentItem: Text {
                text: reorderTip.text
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              }
              background: Rectangle {
                color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                border.width: 1
                radius: 6
              }
            }
          }
        }

        // THEME EDITOR
        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: parent.width
          clip: true

          ColumnLayout {
            id: editor
            spacing: 10
            width: parent.width

            // Helpers to convert between HEX and RGBA
            function hexToRgba(hex) {
              if (!hex || hex.length < 7) return { r: 255, g: 255, b: 255, a: 255 }
              const h = hex.replace('#','')
              const r = parseInt(h.slice(0,2), 16)
              const g = parseInt(h.slice(2,4), 16)
              const b = parseInt(h.slice(4,6), 16)
              const a = h.length >= 8 ? parseInt(h.slice(6,8), 16) : 255
              return { r, g, b, a }
            }

            // Helper: fallback color per key
            function getColor(key) {
              const v = Globals[key]
              if (v !== undefined && v !== "") return String(v)
              if (key === "visualizerBarColor") return "#00bee7"
              return "#FFFFFF"
            }

          // --- Module Toggles ---
          Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 360
            radius: 6
            color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
            border.width: 1
            anchors.margins: 0
            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 4
              spacing: 2
              // heading moved to the shared header row above
              GridLayout {
                Layout.fillWidth: true
                columns: 1
                rowSpacing: 0
                columnSpacing: 10

                // Left column
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Welcome"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showWelcome; onToggled: { Globals.showWelcome = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Window Title"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showWindowTitle; onToggled: { Globals.showWindowTitle = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Workspaces"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showWorkspaces; onToggled: { Globals.showWorkspaces = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Barvisualizer"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showBarvisualizer; onToggled: { Globals.showBarvisualizer = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "System Tray"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showSystemTray; onToggled: { Globals.showSystemTray = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Updates"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showUpdates; onToggled: { Globals.showUpdates = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Network"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showNetwork; onToggled: { Globals.showNetwork = checked; Globals.saveTheme() } }
                }

                // Right column
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Bluetooth"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showBluetooth; onToggled: { Globals.showBluetooth = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "CPU"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showCPU; onToggled: { Globals.showCPU = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "GPU"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showGPU; onToggled: { Globals.showGPU = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Memory"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showMemory; onToggled: { Globals.showMemory = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Power Profiles"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showPowerProfiles; onToggled: { Globals.showPowerProfiles = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Clipboard"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showClipboard; onToggled: { Globals.showClipboard = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Keybinds"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showKeybinds; onToggled: { Globals.showKeybinds = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Notifications"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showNotifications; onToggled: { Globals.showNotifications = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Sound"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showSound; onToggled: { Globals.showSound = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Weather"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showWeather; onToggled: { Globals.showWeather = checked; Globals.saveTheme() } }
                }
                // (moved) Swap Title & Workspaces toggle now lives under the Bar Position section
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Battery"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showBattery; onToggled: { Globals.showBattery = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Date"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showDate; onToggled: { Globals.showDate = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Time"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showTime; onToggled: { Globals.showTime = checked; Globals.saveTheme() } }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Power"; Layout.preferredWidth: 110; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                  Item { width: 0 }
                  Switch { checked: Globals.showPower; onToggled: { Globals.showPower = checked; Globals.saveTheme() } }
                }
              }
            }
          }

          // Reorder button moved to Modules header row
            function rgbaToHex(r,g,b,a) {
              function cc(v){ return ("0" + Math.max(0, Math.min(255, v|0)).toString(16)).slice(-2) }
              return "#" + cc(r) + cc(g) + cc(b) + (a === 255 ? "" : cc(a))
            }

            // Small color picker popup shown when clicking the swatch
            Component {
              id: colorPicker
              Item {
                id: picker
                property int r: 255
                property int g: 255
                property int b: 255
                property int a: 255
                // optional callback from creator
                property var onApply

                visible: false
                width: 380
                height: 320
                z: 1000

                Rectangle {
                  anchors.fill: parent
                  color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
                  border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                  border.width: 1
                  radius: 8

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Preview
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 32
                      radius: 4
                      color: Qt.rgba(picker.r/255, picker.g/255, picker.b/255, picker.a/255)
                      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                    }

                    // Sliders
                    Repeater {
                      model: [
                        { label: "R", key: "r" },
                        { label: "G", key: "g" },
                        { label: "B", key: "b" },
                        { label: "A", key: "a" }
                      ]
                      delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: modelData.label; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 14 }
                        Slider {
                          from: 0; to: 255; stepSize: 1
                          Layout.fillWidth: true
                          value: picker[modelData.key]
                          onValueChanged: picker[modelData.key] = Math.round(value)
                        }
                        Text { text: String(picker[modelData.key]); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
                      }
                    }

                    // Hex out + actions
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      TextField {
                        id: hexOut
                        Layout.preferredWidth: 160
                        text: editor.rgbaToHex(picker.r, picker.g, picker.b, picker.a)
                        readOnly: true
                      }
                      Item { Layout.fillWidth: true }
                      Button {
                        text: "set color"
                        leftPadding: 12
                        rightPadding: 12
                        onClicked: {
                          if (picker.onApply) picker.onApply(hexOut.text)
                          picker.visible = false
                        }
                        contentItem: Label {
                          text: parent.text
                          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                          horizontalAlignment: Text.AlignHCenter
                          verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                          radius: 6
                          color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button
                          border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                          border.width: 1
                        }
                      }
                      Button {
                        text: "cancel"
                        leftPadding: 12
                        rightPadding: 12
                        onClicked: picker.visible = false
                        contentItem: Label {
                          text: parent.text
                          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                          horizontalAlignment: Text.AlignHCenter
                          verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                          radius: 6
                          color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button
                          border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                          border.width: 1
                        }
                      }
                    }
                  }
                }
              }
            }

            // Helper component: one line editor with preview
            Repeater {
              model: [
                { label: "Bar Background", key: "barBgColor" },
                { label: "Bar Border", key: "barBorderColor" },
                { label: "Hover Highlight", key: "hoverHighlightColor" },
                { label: "Module Icon", key: "moduleIconColor" },
                { label: "Module Value", key: "moduleValueColor" },
                { label: "Workspace Active Bg", key: "workspaceActiveBg" },
                { label: "Workspace Active Border", key: "workspaceActiveBorder" },
                { label: "Workspace Inactive Bg", key: "workspaceInactiveBg" },
                { label: "Workspace Inactive Border", key: "workspaceInactiveBorder" },
                { label: "Workspace Text", key: "workspaceTextColor" },
                { label: "Tooltip Bg", key: "tooltipBg" },
                { label: "Tooltip Text", key: "tooltipText" },
                { label: "Tooltip Border", key: "tooltipBorder" },
                { label: "Popup Bg", key: "popupBg" },
                { label: "Popup Text", key: "popupText" },
                { label: "Popup Border", key: "popupBorder" },
                { label: "Tray Icon", key: "trayIconColor" },
                { label: "Window Title", key: "windowTitleColor" },
                { label: "Visualizer Bars", key: "visualizerBarColor" }
              ]
              delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Elementname
                Text {
                  text: modelData.label
                  color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                  elide: Text.ElideRight
                  wrapMode: Text.NoWrap
                  horizontalAlignment: Text.AlignLeft
                  Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                  Layout.preferredWidth: 189 
                  Layout.minimumWidth: 189  
                  Layout.maximumWidth: 189
                }

                // Hexcode Anzeige (nicht editierbar)
                Item {
                  Layout.preferredWidth: 95
                  Layout.minimumWidth: 95
                  Layout.maximumWidth: 95
                  width: 95; height: 24
                  Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
                    border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                  }
                  Label {
                    anchors.fill: parent
                    anchors.margins: 6
                    text: editor.getColor(modelData.key)
                    color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: "monospace"
                    elide: Text.ElideRight
                    Accessible.role: Accessible.StaticText
                    focusPolicy: Qt.NoFocus
                  }
                }

                // Farbanzeige
                Rectangle {
                  width: 30; height: 22
                  radius: 4
                  color: editor.getColor(modelData.key)
                  border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                  Layout.alignment: Qt.AlignVCenter
                  Layout.preferredWidth: 30
                  Layout.minimumWidth: 30
                  Layout.maximumWidth: 30
                  MouseArea {
                    anchors.fill: parent
                    enabled: !Globals.useMatugenColors
                    onClicked: {
                      const cur = editor.hexToRgba(editor.getColor(modelData.key))
                      const p = colorPicker.createObject(setupBody, {
                        r: cur.r, g: cur.g, b: cur.b, a: cur.a,
                        onApply: function(hex) { Globals[modelData.key] = hex; Globals.saveTheme() }
                      })
                      // Position picker below the swatch within the setup body, clamped to edges
                      const pos = parent.mapToItem(setupBody, 0, parent.height)
                      p.x = Math.max(6, Math.min(setupBody.width - p.width - 6, pos.x))
                      p.y = Math.max(6, Math.min(setupBody.height - p.height - 6, pos.y))
                      p.visible = true
                    }
                  }
                }

                // take remaining space so alignment stays tidy
                Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }
              }
            }
          }
        }

        // Animated Wallpaper toggle
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
              text: wpSwitch.checked ? "Stop to set static wallpaper via " + Globals.wallpaperTool : "Start animated wallpaper via mpvpaper"
              contentItem: Text {
                text: wpTip.text
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              }
              background: Rectangle {
                color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                border.width: 1
                radius: 6
              }
            }
          }
        }

        // Swap Title & Workspaces — aligned like Bar Position row
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Title & Workspaces order:"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Item { Layout.fillWidth: true }
          Text {
            text: swapSwitch.checked ? "Title center, WS left" : "Title left, WS center"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Switch {
            id: swapSwitch
            checked: Globals.swapTitleAndWorkspaces
            onToggled: { Globals.swapTitleAndWorkspaces = checked; Globals.saveTheme() }
          }
        }

        // Bar position control (top/bottom)
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Bar Position (top/bottom):"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Item { Layout.fillWidth: true }
          Text {
            text: posSwitch.checked ? "Bottom" : "Top"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Switch {
            id: posSwitch
            checked: Globals.barPosition === "bottom"
            onToggled: {
              Globals.barPosition = checked ? "bottom" : "top"
              Globals.saveTheme()
            }
            // Themed tooltip
            ToolTip {
              id: posTip
              visible: posSwitch.hovered
              text: posSwitch.checked ? "Bottom" : "Top"
              contentItem: Text {
                text: posTip.text
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              }
              background: Rectangle {
                color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                border.width: 1
                radius: 6
              }
            }
          }
        }

        // Bar base height (visual bar height)
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Bar Height:"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Item { Layout.fillWidth: true }
          Text {
            id: barHeightValue
            text: String(Globals.baseBarHeight !== undefined ? Globals.baseBarHeight : 38) + " px"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            Layout.preferredWidth: 60
            horizontalAlignment: Text.AlignRight
          }
          Slider {
            id: barHeightSlider
            from: 30
            to: 40
            stepSize: 1
            wheelEnabled: true
            Layout.preferredWidth: 180
            value: Globals.baseBarHeight !== undefined ? Globals.baseBarHeight : 38
            onMoved: {
              const v = Math.round(value)
              if (Globals.baseBarHeight !== v) {
                Globals.baseBarHeight = v
                Globals.saveTheme()
              }
            }
            onValueChanged: barHeightValue.text = String(Math.round(value)) + " px"
            ToolTip {
              id: heightTip
              visible: parent.hovered
              text: "Visual bar height"
              contentItem: Text {
                text: heightTip.text
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              }
              background: Rectangle {
                color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                border.width: 1
                radius: 6
              }
            }
          }
        }

        

        // Bar edge margin (distance from screen edge to bar)
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Bar Margin (" + (Globals.barPosition === "top" ? "top" : "bottom") + "):"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Item { Layout.fillWidth: true }
          Text {
            id: marginValue
            text: String(Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0) + " px"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            Layout.preferredWidth: 60
            horizontalAlignment: Text.AlignRight
          }
          Slider {
            id: marginSlider
            from: 0
            to: 12
            stepSize: 1
            wheelEnabled: true
            Layout.preferredWidth: 180
            value: Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0
            onMoved: {
              const v = Math.round(value)
              if (Globals.barEdgeMargin !== v) {
                Globals.barEdgeMargin = v
                Globals.saveTheme()
              }
            }
            onValueChanged: marginValue.text = String(Math.round(value)) + " px"
            ToolTip {
              id: edgeTip
              visible: parent.hovered
              text: (Globals.barPosition === "top" ? "Margin from top" : "Margin from bottom")
              contentItem: Text {
                text: edgeTip.text
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              }
              background: Rectangle {
                color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                border.width: 1
                radius: 6
              }
            }
          }
        }

        // Bar side margins (shorten from left/right)
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: "Bar Margin (left/right):"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          }
          Item { Layout.fillWidth: true }
          Text {
            id: sideMarginValue
            text: String(Globals.barSideMargin !== undefined ? Globals.barSideMargin : 0) + " px"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            Layout.preferredWidth: 60
            horizontalAlignment: Text.AlignRight
          }
          Slider {
            id: sideMarginSlider
            from: 0
            to: 200
            stepSize: 1
            wheelEnabled: true
            Layout.preferredWidth: 180
            value: Globals.barSideMargin !== undefined ? Globals.barSideMargin : 0
            onMoved: {
              const v = Math.round(value)
              if (Globals.barSideMargin !== v) {
                Globals.barSideMargin = v
                Globals.saveTheme()
              }
            }
            onValueChanged: sideMarginValue.text = String(Math.round(value)) + " px"
            ToolTip {
              id: sideTip
              visible: parent.hovered
              text: "Margin from left/right"
              contentItem: Text {
                text: sideTip.text
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              }
              background: Rectangle {
                color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                border.width: 1
                radius: 6
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          // Theme Mode toggle (visible only when Matugen is enabled), Hide Bar (Game mode) Mitte, Close rechts
          Button {
            id: themeModeBtn
            visible: Globals.useMatugenColors
            enabled: Globals.useMatugenColors && !matugenProc.running
            text: "Theme Mode: " + (root.currentMatugenMode !== "" ? root.currentMatugenMode : (Globals.useMatugenColors ? "unknown" : "disabled"))
            onClicked: {
              // Optimistically reflect next mode in the label
              let next = (root.currentMatugenMode === "light") ? "dark" : (root.currentMatugenMode === "dark" ? "light" : "dark")
              root.currentMatugenMode = next
              const scriptPath = String(Qt.resolvedUrl("root:/scripts/matugen-toggle.sh")).replace(/^file:\/\//, "")
              matugenProc.command = ["bash", "-lc", '"' + scriptPath.replace(/"/g,'\\"') + '"']
              matugenProc.running = true
            }
            leftPadding: 12
            rightPadding: 12
            contentItem: Label {
              text: parent.text
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
              radius: 6
              color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button
              border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
              border.width: 1
            }
          }
          Item { Layout.fillWidth: true }
          CheckBox {
            id: hideBarChk
            text: "Hide Bar (Game mode)"
            checked: Globals.barHidden
            onToggled: { Globals.barHidden = checked; Globals.saveTheme() }
            spacing: 6
            // Colorize internal label while preserving default layout
            Component.onCompleted: {
              const c = (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF")
              if (hideBarChk.contentItem && hideBarChk.contentItem.color !== undefined) hideBarChk.contentItem.color = c
            }
            Connections {
              target: Globals
              function onPopupTextChanged() {
                const c = (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF")
                if (hideBarChk.contentItem && hideBarChk.contentItem.color !== undefined) hideBarChk.contentItem.color = c
              }
            }
            // Themed tooltip
            ToolTip {
              id: hideTip
              visible: hideBarChk.hovered
              text: hideBarChk.checked ? "Bar hidden, only gear icon" : "Bar visible"
              contentItem: Text {
                text: hideTip.text
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              }
              background: Rectangle {
                color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
                border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
                border.width: 1
                radius: 6
              }
            }
          }
          Item { Layout.fillWidth: true }
          Button {
            text: "Close"
            onClicked: setupPopup.visible = false
            leftPadding: 12
            rightPadding: 12
            // Themed label/background
            contentItem: Label {
              text: parent.text
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
              radius: 6
              color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button
              border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
              border.width: 1
            }
          }
        }
      }
    }
  }
}
