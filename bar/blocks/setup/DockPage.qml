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
        anchors.margins: 8
        clip: true
        contentWidth: flick.width
        contentHeight: editor.childrenRect.height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
          id: editor
          spacing: 12
          width: flick.width

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
            Label { text: "Autohide In (ms)"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 330; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider {
              id: inDur
              from: 0; to: 1000; stepSize: 10
              value: Number(Globals.dockAutoHideInDurationMs || 100)
              Layout.preferredWidth: 220
              onMoved: { Globals.dockAutoHideInDurationMs = Math.round(value); save() }
            }
            Text { text: String(Math.round(inDur.value)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Autohide Out (ms)"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 330; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider {
              id: outDur
              from: 0; to: 1500; stepSize: 10
              value: Number(Globals.dockAutoHideOutDurationMs || 300)
              Layout.preferredWidth: 220
              onMoved: { Globals.dockAutoHideOutDurationMs = Math.round(value); save() }
            }
            Text { text: String(Math.round(outDur.value)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }

          // Row: Icon geometry
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Icon Size (px)"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 330; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider { from: 32; to: 128; stepSize: 1; value: Number(Globals.dockIconSizePx||64); Layout.preferredWidth: 220; onMoved: { Globals.dockIconSizePx = Math.round(value); save() } }
            Text { text: String(Math.round(Globals.dockIconSizePx||0)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Icon Radius"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 330; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider { from: 0; to: 32; stepSize: 1; value: Number(Globals.dockIconRadius||10); Layout.preferredWidth: 220; onMoved: { Globals.dockIconRadius = Math.round(value); save() } }
            Text { text: String(Math.round(Globals.dockIconRadius||0)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Icon Border (px)"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 330; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider { from: 0; to: 6; stepSize: 1; value: Number(Globals.dockIconBorderPx||1); Layout.preferredWidth: 220; onMoved: { Globals.dockIconBorderPx = Math.round(value); save() } }
            Text { text: String(Math.round(Globals.dockIconBorderPx||0)); color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
            Item { width: 20; Layout.preferredWidth: 20 }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Label { text: "Icon Spacing"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; Layout.preferredWidth: 330; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
            Slider { from: 0; to: 24; stepSize: 1; value: Number(Globals.dockIconSpacing||0); Layout.preferredWidth: 220; onMoved: { Globals.dockIconSpacing = Math.round(value); save() } }
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
            // Ensure this section contributes to total content height
            implicitHeight: dockItemsContainer.implicitHeight
            radius: 6
            color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
            border.width: 0
            ColumnLayout {
              id: dockItemsContainer
              anchors.fill: parent
              anchors.margins: 8
              // Expose content height
              implicitHeight: childrenRect.height
              spacing: 8

              RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 16
                Layout.rightMargin: 20
                Label { text: "Dock Items:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.bold: true; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                // Flexible spacer pushes the button to the right edge
                Item { Layout.fillWidth: true }
                Button {
                  id: addDockItemBtn
                  text: "new dock item"
                  onClicked: {
                    try {
                      const arr = Array.isArray(Globals.dockItems) ? Globals.dockItems.slice(0) : []
                      arr.push({
                        label: "new label",
                        cmd: "set your command here",
                        icon: "~/.config/quickshell/Celona/bar/assets/dock icons/celona_sample.png",
                        iconSizeRatio: 0.55,
                        iconOffsetYPx: -8
                      })
                      Globals.dockItems = arr
                      save()
                    } catch (e) {
                      console.warn("Failed to add dock item:", e)
                    }
                  }
                  leftPadding: 12
                  rightPadding: 12
                  contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                  background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
                }
              }

              // Simple read-only list (labels only) using Column for robust sizing in Flickable
              Column {
                id: dockList
                width: flick.width
                spacing: 6
                Repeater {
                  // Show items in reverse order (last in config first on screen)
                  model: (Array.isArray(Globals.dockItems) ? Globals.dockItems.slice().reverse() : [])
                  delegate: Rectangle {
                    //width: dockList.width
                    height: 36
                    width: 200
                    radius: 6
                    color: "transparent"
                    border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                    border.width: 1
                    RowLayout {
                      anchors.fill: parent
                      anchors.margins: 6
                      spacing: 8
                      Text {
                        text: String(modelData && modelData.label ? modelData.label : "(no label)")
                        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                        font.family: Globals.mainFontFamily
                        font.pixelSize: Globals.mainFontSize
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
                // Placeholder when empty
                Text {
                  visible: !(Array.isArray(Globals.dockItems) && Globals.dockItems.length > 0)
                  text: "No Dock items defined in config.json"
                  color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
                }
              }
            }
          }

          // Bottom spacer to allow last item to scroll fully into view
          Item { width: 1; height: 24 }

        }
      }
    }
  }
}
