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
    implicitWidth: 90
    implicitHeight: 40
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Edges.Top
      gravity: Edges.Bottom
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          tipWindow.anchor.rect.y = win.height + 3
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
        anchors.fill: parent
        anchors.margins: 10
        text: "Bar Setup"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  // Main popup (dummy), styled like Sound popup
  PopupWindow {
    id: setupPopup
    visible: false
    implicitWidth: 330
    implicitHeight: 800
    color: "transparent"

    anchor {
      window: root.QsWindow?.window
      edges: Edges.Top
      gravity: Edges.Bottom
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          setupPopup.anchor.rect.y = win.height + 6
          setupPopup.anchor.rect.x = win.contentItem.mapFromItem(root, root.width / 2, 0).x - setupPopup.implicitWidth / 2
        }
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

        Text {
          text: "Colors:"
          color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
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
                implicitHeight: 280

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
                { label: "Bar Bg", key: "barBgColor" },
                { label: "Bar Border", key: "barBorderColor" },
                { label: "Hover Highlight", key: "hoverHighlightColor" },
                { label: "Module Icon", key: "moduleIconColor" },
                { label: "Module Value", key: "moduleValueColor" },
                { label: "WS Active Bg", key: "workspaceActiveBg" },
                { label: "WS Active Border", key: "workspaceActiveBorder" },
                { label: "WS Inactive Bg", key: "workspaceInactiveBg" },
                { label: "WS Inactive Border", key: "workspaceInactiveBorder" },
                { label: "WS Text", key: "workspaceTextColor" },
                { label: "Tooltip Bg", key: "tooltipBg" },
                { label: "Tooltip Text", key: "tooltipText" },
                { label: "Tooltip Border", key: "tooltipBorder" },
                { label: "Popup Bg", key: "popupBg" },
                { label: "Popup Text", key: "popupText" },
                { label: "Popup Border", key: "popupBorder" },
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
          // push buttons to the right
          Item { Layout.fillWidth: true }
          Button {
            text: "Reset"
            onClicked: Globals.resetTheme()
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
