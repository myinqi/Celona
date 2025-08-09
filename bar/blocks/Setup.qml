import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../"
import "root:/"

BarBlock {
  id: root

  // Icon-only block using Nerd Font gear
  content: BarText {
    id: label
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: "" // gear
    symbolSpacing: 0
  }

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
        setupPopup.visible = true
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
    implicitHeight: 840
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
      anchors.fill: parent
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1
      radius: 8

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
          text: "Bar Settings"
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          font.bold: true
          Layout.fillWidth: true
        }

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
          // Center control: Bar position (top/bottom)
          Item { Layout.fillWidth: true }
          RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter
            Label {
              text: "Bar position (top/bottom):"
              color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            }
            Switch {
              // checked = bottom, unchecked = top
              checked: Globals.barPosition === "bottom"
              onToggled: Globals.barPosition = checked ? "bottom" : "top"
              ToolTip.visible: hovered
              ToolTip.text: checked ? "Bottom" : "Top"
            }
          }
          Item { Layout.fillWidth: true }
          Label {
            text: "Modules:"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            font.bold: true
            font.italic: true
          }
          Item { width: 8 }
          Button {
            text: Globals.reorderMode ? "Finish" : "Reorder"
            onClicked: Globals.reorderMode = !Globals.reorderMode
            ToolTip.visible: hovered
            ToolTip.text: Globals.reorderMode ? "Finish: order will be saved" : "Enable: reorder modules directly in the bar"
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
              anchors.margins: 10
              spacing: 8
              // heading moved to the shared header row above
              GridLayout {
                Layout.fillWidth: true
                columns: 1
                rowSpacing: 6
                columnSpacing: 10

                // Left column
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Welcome"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showWelcome; onToggled: Globals.showWelcome = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Window Title"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showWindowTitle; onToggled: Globals.showWindowTitle = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Workspaces"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showWorkspaces; onToggled: Globals.showWorkspaces = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "System Tray"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showSystemTray; onToggled: Globals.showSystemTray = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Updates"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showUpdates; onToggled: Globals.showUpdates = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Network"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showNetwork; onToggled: Globals.showNetwork = checked }
                }

                // Right column
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Bluetooth"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showBluetooth; onToggled: Globals.showBluetooth = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "CPU"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showCPU; onToggled: Globals.showCPU = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "GPU"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showGPU; onToggled: Globals.showGPU = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Memory"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showMemory; onToggled: Globals.showMemory = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Power Profiles"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showPowerProfiles; onToggled: Globals.showPowerProfiles = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Clipboard"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showClipboard; onToggled: Globals.showClipboard = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Notifications"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showNotifications; onToggled: Globals.showNotifications = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Sound"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showSound; onToggled: Globals.showSound = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Battery"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showBattery; onToggled: Globals.showBattery = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Date"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showDate; onToggled: Globals.showDate = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Time"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showTime; onToggled: Globals.showTime = checked }
                }
                RowLayout {
                  Layout.fillWidth: true
                  Label { text: "Power"; Layout.preferredWidth: 110; color: Globals.popupText }
                  Item { width: 0 }
                  Switch { checked: Globals.showPower; onToggled: Globals.showPower = checked }
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
              PopupWindow {
                id: picker
                property int r: 255
                property int g: 255
                property int b: 255
                property int a: 255
                // optional callback from creator
                property var onApply

                visible: false
                color: "transparent"
                implicitWidth: 380
                implicitHeight: 320

                anchor.window: setupPopup.QsWindow?.window

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
                        Layout.preferredWidth: 140
                        text: editor.rgbaToHex(picker.r, picker.g, picker.b, picker.a)
                        readOnly: true
                      }
                      Item { Layout.fillWidth: true }
                      Button {
                        text: "Abbrechen"
                        onClicked: picker.visible = false
                      }
                      Button {
                        text: "Übernehmen"
                        onClicked: {
                          if (picker.onApply) picker.onApply(hexOut.text)
                          picker.visible = false
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
                { label: "Window Title", key: "windowTitleColor" }
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
                  Layout.preferredWidth: 140
                  Layout.minimumWidth: 140
                  Layout.maximumWidth: 140
                }

                // Hexcode Eingabefeld
                TextField {
                  id: tf
                  text: String(Globals[modelData.key])
                  Layout.preferredWidth: 100
                  Layout.minimumWidth: 100
                  Layout.maximumWidth: 100
                  // Manual hex validation (#RRGGBB or #RRGGBBAA)
                  onEditingFinished: {
                    let t = text.trim()
                    // allow plain 6/8 hex without '#'
                    const plain = /^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
                    if (plain.test(t)) t = '#' + t
                    const re = /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
                    if (re.test(t)) {
                      text = t
                      Globals[modelData.key] = t
                    } else {
                      text = String(Globals[modelData.key])
                    }
                  }
                  onAccepted: {
                    let t = text.trim()
                    const plain = /^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
                    if (plain.test(t)) t = '#' + t
                    const re = /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
                    if (re.test(t)) {
                      text = t
                      Globals[modelData.key] = t
                    } else {
                      text = String(Globals[modelData.key])
                    }
                  }
                }

                // Farbanzeige
                Rectangle {
                  width: 40; height: 22
                  radius: 4
                  color: Globals[modelData.key]
                  border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                  Layout.alignment: Qt.AlignVCenter
                  Layout.preferredWidth: 40
                  Layout.minimumWidth: 40
                  Layout.maximumWidth: 40
                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      const cur = editor.hexToRgba(String(Globals[modelData.key]))
                      const p = colorPicker.createObject(setupPopup, {
                        r: cur.r, g: cur.g, b: cur.b, a: cur.a,
                        onApply: function(hex) { Globals[modelData.key] = hex }
                      })
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

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          // Reset links, Save/Close rechts
          Button {
            text: "Reset"
            onClicked: Globals.resetTheme()
          }
          Item { Layout.fillWidth: true }
          Button {
            text: "Save"
            onClicked: Globals.saveTheme()
          }
          Button {
            text: "Close"
            onClicked: setupPopup.visible = false
          }
        }
      }
    }
  }
}
