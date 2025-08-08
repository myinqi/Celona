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
    implicitWidth: 950
    implicitHeight: 750
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

            // Helper component: one line editor with preview
            Repeater {
              model: [
                { label: "Bar Border", key: "barBorderColor" },
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
                    const re = /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
                    if (re.test(text)) {
                      Globals[modelData.key] = text
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
                }

                // take remaining space so alignment stays tidy
                Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }
              }
            }
          }
        }

        Button {
          text: "Close"
          onClicked: setupPopup.visible = false
          Layout.alignment: Qt.AlignRight
        }
      }
    }
  }
}
