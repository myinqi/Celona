import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Io
import "../../"
import "root:/"

Item {
  id: page
  width: parent ? parent.width : 0
  height: parent ? parent.height : 0

  function save() { Globals.saveTheme() }
  function touchDockItems() { Globals.dockItems = Globals.dockItems ? Globals.dockItems.slice(0) : [] }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 10

    Label {
      text: "Dock"
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

      Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        anchors.rightMargin: 8
        clip: true
        contentWidth: flick.width
        contentHeight: editor.childrenRect.height
        // Hide vertical scrollbar for current menu scope
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

        ColumnLayout {
          id: editor
          width: flick.width
          spacing: 12

          // Row: ShowDock
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Show Dock:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 140; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Item { Layout.fillWidth: true }
            Switch {
              id: showDockSwitch
              Layout.preferredWidth: 70
              checked: Globals.showDock
              onToggled: { Globals.showDock = checked; save() }
            }
            Text { text: showDockSwitch.checked ? "On" : "Off"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignLeft }
            Item { width: 20; Layout.preferredWidth: 20 }
          }

          // Row: Positions
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Position:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 110; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Label { text: "Horizontal"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            ComboBox {
              id: posH
              model: ["left", "right"]
              currentIndex: Math.max(0, model.indexOf(Globals.dockPositionHorizontal || "right"))
              onActivated: { Globals.dockPositionHorizontal = model[currentIndex]; save() }
            }
            Label { text: "Vertical"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            ComboBox {
              id: posV
              model: ["top", "center", "bottom"]
              currentIndex: Math.max(0, model.indexOf(Globals.dockPositionVertical || "top"))
              onActivated: { Globals.dockPositionVertical = model[currentIndex]; save() }
            }
            Item { Layout.fillWidth: true }
            Item { width: 20; Layout.preferredWidth: 20 }
          }

          // Row: Layer mode
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Auto Hide:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 110; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Switch {
              id: autoHideSwitch
              checked: (Globals.dockLayerPosition === "autohide")
              onToggled: {
                Globals.dockLayerPosition = checked ? "autohide" : "on top"
                save()
              }
            }
            Text { text: autoHideSwitch.checked ? "On" : "Off"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignLeft }
            Item { Layout.fillWidth: true }
          }

          // Row: Autohide durations
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Autohide In (ms)"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 140; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider {
              id: inDur
              from: 0; to: 1000; stepSize: 10
              value: Number(Globals.dockAutoHideInDurationMs || 100)
              Layout.fillWidth: true
              onMoved: { Globals.dockAutoHideInDurationMs = Math.round(value); save() }
            }
            Text { text: String(Math.round(inDur.value)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Autohide Out (ms)"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 140; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider {
              id: outDur
              from: 0; to: 1500; stepSize: 10
              value: Number(Globals.dockAutoHideOutDurationMs || 300)
              Layout.fillWidth: true
              onMoved: { Globals.dockAutoHideOutDurationMs = Math.round(value); save() }
            }
            Text { text: String(Math.round(outDur.value)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }

          // Row: Icon geometry
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Icon Size (px)"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 140; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider { from: 32; to: 128; stepSize: 1; value: Number(Globals.dockIconSizePx||64); Layout.fillWidth: true; onMoved: { Globals.dockIconSizePx = Math.round(value); save() } }
            Text { text: String(Math.round(Globals.dockIconSizePx||0)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Icon Radius"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 140; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider { from: 0; to: 32; stepSize: 1; value: Number(Globals.dockIconRadius||10); Layout.fillWidth: true; onMoved: { Globals.dockIconRadius = Math.round(value); save() } }
            Text { text: String(Math.round(Globals.dockIconRadius||0)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Icon Border (px)"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 140; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider { from: 0; to: 6; stepSize: 1; value: Number(Globals.dockIconBorderPx||1); Layout.fillWidth: true; onMoved: { Globals.dockIconBorderPx = Math.round(value); save() } }
            Text { text: String(Math.round(Globals.dockIconBorderPx||0)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Icon Spacing"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 140; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider { from: 0; to: 24; stepSize: 1; value: Number(Globals.dockIconSpacing||0); Layout.fillWidth: true; onMoved: { Globals.dockIconSpacing = Math.round(value); save() } }
            Text { text: String(Math.round(Globals.dockIconSpacing||0)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }

          // Row: Labels + movement
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Show Labels"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 110; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Switch { checked: Globals.dockIconLabel; onToggled: { Globals.dockIconLabel = checked; save() } }
            Item { Layout.fillWidth: true }
            Label { text: "Allow Reorder"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Switch { checked: Globals.allowDockIconMovement; onToggled: { Globals.allowDockIconMovement = checked; save() } }
            Item { Layout.fillWidth: true }
          }

          // Dock items editor
          Rectangle {
            Layout.fillWidth: true
            radius: 6
            color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
            border.width: 1

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 8

              RowLayout {
                Layout.fillWidth: true
                Label { text: "Dock Items:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.bold: true; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                Item { Layout.fillWidth: true }
                Text {
                  text: "New items must be defined in the config.json file."
                  color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
                  horizontalAlignment: Text.AlignRight
                  wrapMode: Text.WordWrap
                }
              }

              ListView {
                id: items
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Model is an index array to decouple from the dockItems object identity
                model: (Array.isArray(Globals.dockItems)
                        ? Globals.dockItems.map(function(_, i) { return i })
                        : [])
                // Avoid aggressive reuse while we mutate the array during edits
                reuseItems: false
                delegate: Rectangle {
                  width: ListView.view.width
                  height: 130
                  radius: 6
                  color: "transparent"
                  border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                  border.width: 1
                  // Access item by index to avoid model/object binding loops
                  property int idx: modelData
                  property var itemRef: (Array.isArray(Globals.dockItems) && idx < Globals.dockItems.length) ? Globals.dockItems[idx] : ({})

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      Label { text: "Label"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 70; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                      TextField {
                        Layout.fillWidth: true
                        text: String(itemRef.label||"")
                        onTextEdited: {
                          if (itemRef.label !== text) {
                            itemRef.label = text; touchDockItems(); save()
                          }
                        }
                      }
                      Button { text: "Remove"; onClicked: {
                        const arr = Globals.dockItems ? Globals.dockItems.slice(0) : []
                        arr.splice(idx, 1)
                        Globals.dockItems = arr
                        save()
                      }}
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      Label { text: "Command"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 70; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                      TextField {
                        Layout.fillWidth: true
                        text: String(itemRef.cmd||"")
                        onTextEdited: {
                          if (itemRef.cmd !== text) {
                            itemRef.cmd = text; touchDockItems(); save()
                          }
                        }
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      Label { text: "Icon"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 70; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                      TextField {
                        id: iconField
                        Layout.fillWidth: true
                        text: String(itemRef.icon||"")
                        onTextEdited: {
                          if (itemRef.icon !== text) {
                            itemRef.icon = text; touchDockItems(); save()
                          }
                        }
                      }
                      Button { text: "Browse..."; onClicked: iconDialog.open() }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      Label { text: "Size Ratio"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 70; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                      Slider { from: 0.1; to: 1.0; stepSize: 0.01; value: Number(itemRef.iconSizeRatio||0.55); Layout.fillWidth: true; onMoved: { itemRef.iconSizeRatio = Number(value.toFixed(2)); touchDockItems(); save() } }
                      Text { text: String((itemRef.iconSizeRatio||0.55).toFixed(2)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
                      Item { width: 20; Layout.preferredWidth: 20 }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      Label { text: "Offset Y"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 70; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                      Slider { from: -24; to: 24; stepSize: 1; value: Number(itemRef.iconOffsetYPx||0); Layout.fillWidth: true; onMoved: { itemRef.iconOffsetYPx = Math.round(value); touchDockItems(); save() } }
                      Text { text: String(Math.round(itemRef.iconOffsetYPx||0)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
                      Item { width: 20; Layout.preferredWidth: 20 }
                    }

                  }

                  // File dialog per delegate
                  Platform.FileDialog {
                    id: iconDialog
                    title: "Choose icon (PNG)"
                    nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)", "All files (*)"]
                    folder: (String(iconField.text||"").startsWith("/"))
                              ? "file://" + String(iconField.text).substring(0, String(iconField.text).lastIndexOf("/"))
                              : "file://" + Platform.StandardPaths.writableLocation(Platform.StandardPaths.PicturesLocation)
                    onAccepted: {
                      const list = files && files.length ? files : (file ? [file] : [])
                      if (list.length > 0) {
                        const p = list[0].toString().replace("file://", "")
                        itemRef.icon = p
                        iconField.text = p
                        touchDockItems(); save()
                      }
                    }
                  }
                }
              }
            }
          }

          // Spacer
          Item { Layout.fillHeight: true }
        }
      }
    }
  }
}
