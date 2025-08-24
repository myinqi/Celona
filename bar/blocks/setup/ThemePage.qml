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

  // Track current Matugen mode from root:/colors.mode
  property string currentMatugenMode: ""

  // Read current Matugen mode written by scripts/matugen-toggle.sh
  FileView {
    id: matugenModeView
    path: Qt.resolvedUrl("root:/colors.mode")
    onLoaded: {
      try {
        const t = String(matugenModeView.text()).trim()
        page.currentMatugenMode = (t === "light" || t === "dark") ? t : ""
      } catch (e) { page.currentMatugenMode = "" }
    }
  }

  // Runner to toggle Matugen light/dark
  Process {
    id: matugenProc
    running: false
    onRunningChanged: if (!running) {
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
      text: "Theme"
      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
      font.bold: true
      font.pixelSize: 17
    }

    // Header row: Colors + Matugen toggle
    RowLayout {
      Layout.fillWidth: true
      spacing: 6
      Label {
        text: "Colors:"
        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
        font.bold: true
        font.italic: true
        Layout.preferredWidth: 80
      }
      RowLayout {
        spacing: 0
        CheckBox {
          id: matugenBox
          enabled: Globals.matugenAvailable
          checked: Globals.useMatugenColors
          onToggled: {
            Globals.useMatugenColors = checked
            if (checked) {
              Globals.applyMatugenColors()
            } else {
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
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: matugenBox.checked = !matugenBox.checked }
        }
        // Theme Mode toggle moved here next to the checkbox
        Button {
          id: themeModeBtn
          visible: Globals.useMatugenColors
          enabled: Globals.useMatugenColors && !matugenProc.running
          text: "Theme Mode: " + (page.currentMatugenMode !== "" ? page.currentMatugenMode : (Globals.useMatugenColors ? "unknown" : "disabled"))
          onClicked: {
            let next = (page.currentMatugenMode === "light") ? "dark" : (page.currentMatugenMode === "dark" ? "light" : "dark")
            page.currentMatugenMode = next
            const scriptPath = String(Qt.resolvedUrl("root:/scripts/matugen-toggle.sh")).replace(/^file:\/\//, "")
            matugenProc.command = ["bash", "-lc", '"' + scriptPath.replace(/"/g,'\\"') + '"']
            matugenProc.running = true
          }
          leftPadding: 12
          rightPadding: 12
          Layout.leftMargin: 80
          contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
          background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
        }
      }
      Item { Layout.fillWidth: true }
    }

    // THEME EDITOR (framed)
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
        contentWidth: flick.width
        contentHeight: editor.childrenRect.height

      ColumnLayout {
        id: editor
        spacing: 10
        width: flick.width

        function hexToRgba(hex) {
          if (!hex || hex.length < 7) return { r: 255, g: 255, b: 255, a: 255 }
          const h = hex.replace('#','')
          const r = parseInt(h.slice(0,2), 16)
          const g = parseInt(h.slice(2,4), 16)
          const b = parseInt(h.slice(4,6), 16)
          const a = h.length >= 8 ? parseInt(h.slice(6,8), 16) : 255
          return { r, g, b, a }
        }

        function getColor(key) {
          const v = Globals[key]
          if (v !== undefined && v !== "") return String(v)
          if (key === "visualizerBarColor") return "#00bee7"
          return "#FFFFFF"
        }

        function rgbaToHex(r,g,b,a) {
          function cc(v){ return ("0" + Math.max(0, Math.min(255, v|0)).toString(16)).slice(-2) }
          return "#" + cc(r) + cc(g) + cc(b) + (a === 255 ? "" : cc(a))
        }

        // Color picker popup
        Component {
          id: colorPicker
          Item {
            id: picker
            property int r: 255
            property int g: 255
            property int b: 255
            property int a: 255
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

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 32
                  radius: 4
                  color: Qt.rgba(picker.r/255, picker.g/255, picker.b/255, picker.a/255)
                  border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                }

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
                    Slider { from: 0; to: 255; stepSize: 1; Layout.fillWidth: true; value: picker[modelData.key]; onValueChanged: picker[modelData.key] = Math.round(value) }
                    Text { text: String(picker[modelData.key]); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8
                  TextField { id: hexOut; Layout.preferredWidth: 160; text: editor.rgbaToHex(picker.r, picker.g, picker.b, picker.a); readOnly: true }
                  Item { Layout.fillWidth: true }
                  Button {
                    text: "set color"
                    onClicked: { if (picker.onApply) picker.onApply(hexOut.text); picker.visible = false }
                    contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                    background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
                  }
                  Button {
                    text: "cancel"
                    onClicked: picker.visible = false
                    contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF" }
                    background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
                  }
                }
              }
            }
          }
        }

        // Color list
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

            Rectangle {
              width: 30; height: 22
              radius: 4
              color: editor.getColor(modelData.key)
              border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
              Layout.alignment: Qt.AlignVCenter
              Layout.preferredWidth: 95
              Layout.minimumWidth: 95
              Layout.maximumWidth: 95
              MouseArea {
                anchors.fill: parent
                enabled: !Globals.useMatugenColors
                onClicked: {
                  const cur = editor.hexToRgba(editor.getColor(modelData.key))
                  const p = colorPicker.createObject(page, {
                    r: cur.r, g: cur.g, b: cur.b, a: cur.a,
                    onApply: function(hex) { Globals[modelData.key] = hex; Globals.saveTheme() }
                  })
                  const pos = parent.mapToItem(page, 0, parent.height)
                  p.x = Math.max(6, Math.min(page.width - p.width - 6, pos.x))
                  p.y = Math.max(6, Math.min(page.height - p.height - 6, pos.y))
                  p.visible = true
                }
              }
            }

            Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }
          }
        }
      }
    }

      }
  }
}
