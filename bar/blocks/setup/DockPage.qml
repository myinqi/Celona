import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt.labs.platform 1.1 as Platform
import "../../"
import "root:/"

Item {
  id: page
  width: parent ? parent.width : 0
  height: parent ? parent.height : 0

  // Header column horizontal fine-tuning (in pixels)
  // Adjust these to shift header labels horizontally over their columns
  property int headerLabelDx: 0
  property int headerCmdDx: 20
  property int headerIconDx: 0
  property int headerRatioDx: 0
  property int headerOffsetYDx: 0

  function save() { Globals.saveTheme() }
  // Avoid unnecessary reassignments that can recreate delegates; we mutate in place and then save
  // Update the dock subset hash so the live watcher doesn't revert our in-memory changes before save completes
  function syncDockHash() {
    try {
      const subset = {
        ShowDock: Globals.showDock,
        DockPositionHorizontal: Globals.dockPositionHorizontal,
        DockPositionVertical: Globals.dockPositionVertical,
        DockLayerPosition: Globals.dockLayerPosition,
        DockAutoHideInDurationMs: Globals.dockAutoHideInDurationMs,
        DockAutoHideOutDurationMs: Globals.dockAutoHideOutDurationMs,
        DockItems: Globals.dockItems
      }

      Globals._dockConfigHash = Qt.md5(JSON.stringify(subset))
    } catch (e) { /* no-op */ }
  }

  // Helpers (mirror WallpapersPage semantics)
  function expandHome(p) {
    try {
      const s = String(p||"")
      if (s.startsWith("~/") && Globals.homeReady) return Globals.homeDir + s.slice(1)
      return s
    } catch (e) { return String(p||"") }
  }

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
                        cmd: "command",
                        icon: "~/.config/quickshell/Celona/bar/assets/dock icons/celona_sample.png",
                        iconSizeRatio: 0.55,
                        iconOffsetYPx: -8
                      })
                      Globals.dockItems = arr
                      syncDockHash(); save()
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

              // Header row for columns
              RowLayout {
                Layout.fillWidth: true
                spacing: 0
                // Keep widths aligned with editor fields
                Label { text: "label"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Math.max(10, Globals.mainFontSize - 2); Layout.preferredWidth: 92; Layout.leftMargin: page.headerLabelDx; Layout.rightMargin: 20 }
                Label { text: "cmd"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Math.max(10, Globals.mainFontSize - 2); Layout.preferredWidth: 140; Layout.leftMargin: page.headerCmdDx; Layout.rightMargin: 20 }
                Label { text: "icon"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Math.max(10, Globals.mainFontSize - 2); Layout.preferredWidth: 34; Layout.leftMargin: page.headerIconDx; Layout.rightMargin: 20 }
                Label { text: "ratio"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Math.max(10, Globals.mainFontSize - 2); Layout.preferredWidth: 50; Layout.leftMargin: page.headerRatioDx; Layout.rightMargin: 20 }
                Label { text: "offsetY"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Math.max(10, Globals.mainFontSize - 2); Layout.preferredWidth: 35; Layout.leftMargin: page.headerOffsetYDx; Layout.rightMargin: 20 }
                Item { Layout.fillWidth: true }
              }

              // Simple editable list (five fields per item) using Column
              Column {
                id: dockList
                width: flick.width
                spacing: 6
                Repeater {
                  // Show items in reverse order (last in config first on screen)
                  model: (Array.isArray(Globals.dockItems) ? Globals.dockItems.slice().reverse() : [])
                  delegate: Rectangle {
                    width: dockList.width
                    height: 44
                    radius: 6
                    color: "transparent"
                    border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                    border.width: 1
                    // Map reversed view index back to real array index
                    property int realIdx: (Array.isArray(Globals.dockItems) ? (Globals.dockItems.length - 1 - index) : -1)
                    // Keep desired icon to re-assert if watcher rolls back
                    property string pendingIcon: ""
                    function doRetrySave() {
                      try {
                        if (realIdx >= 0 && pendingIcon && Globals.dockItems && Globals.dockItems[realIdx]) {
                          if (String(Globals.dockItems[realIdx].icon||"") !== String(pendingIcon)) {
                            const arr = Array.isArray(Globals.dockItems) ? Globals.dockItems.slice(0) : []
                            if (!arr[realIdx]) arr[realIdx] = {}
                            arr[realIdx].icon = String(pendingIcon)
                            Globals.dockItems = arr
                            touchDockItems(); syncDockHash()
                          }
                        }
                      } catch (e) { /* no-op */ }
                      save()
                    }
                    // Retry savers to avoid race if save process is busy; re-assert pending icon if needed
                    Timer { id: saveRetry; interval: 250; repeat: false; onTriggered: doRetrySave() }
                    Timer { id: saveRetry2; interval: 800; repeat: false; onTriggered: doRetrySave() }
                    RowLayout {
                      anchors.fill: parent
                      anchors.margins: 6
                      spacing: 0
                      // label
                      TextField {
                        Layout.preferredWidth: 92
                        Layout.rightMargin: 20
                        placeholderText: "label"
                        text: (realIdx >= 0 && Globals.dockItems[realIdx] && Globals.dockItems[realIdx].label) ? String(Globals.dockItems[realIdx].label) : ""
                        ToolTip {
                          id: labelTip
                          visible: parent.hovered
                          text: "Display label shown under the icon"
                          contentItem: Text { text: labelTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                          background: Rectangle { color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase; border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
                        }
                        onAccepted: {
                          if (realIdx >= 0 && Array.isArray(Globals.dockItems)) {
                            if (!Globals.dockItems[realIdx]) Globals.dockItems[realIdx] = {}
                            Globals.dockItems[realIdx].label = String(text)
                            syncDockHash(); save(); saveRetry.restart()
                          }
                        }
                        onEditingFinished: {
                          if (realIdx >= 0 && Array.isArray(Globals.dockItems)) {
                            if (!Globals.dockItems[realIdx]) Globals.dockItems[realIdx] = {}
                            Globals.dockItems[realIdx].label = String(text)
                            syncDockHash(); save(); saveRetry.restart()
                          }
                        }
                      }
                      // cmd
                      TextField {
                        Layout.preferredWidth: 230
                        Layout.rightMargin: 20
                        placeholderText: "cmd"
                        text: (realIdx >= 0 && Globals.dockItems[realIdx] && Globals.dockItems[realIdx].cmd) ? String(Globals.dockItems[realIdx].cmd) : ""
                        ToolTip {
                          id: cmdTip
                          visible: parent.hovered
                          text: "Command to run when clicking the icon"
                          contentItem: Text { text: cmdTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                          background: Rectangle { color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase; border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
                        }
                        onAccepted: {
                          if (realIdx >= 0 && Array.isArray(Globals.dockItems)) {
                            if (!Globals.dockItems[realIdx]) Globals.dockItems[realIdx] = {}
                            Globals.dockItems[realIdx].cmd = String(text)
                            syncDockHash(); save(); saveRetry.restart()
                          }
                        }
                        onEditingFinished: {
                          if (realIdx >= 0 && Array.isArray(Globals.dockItems)) {
                            if (!Globals.dockItems[realIdx]) Globals.dockItems[realIdx] = {}
                            Globals.dockItems[realIdx].cmd = String(text)
                            syncDockHash(); save(); saveRetry.restart()
                          }
                        }
                      }
                      // icon preview (clickable to browse)
                      Rectangle {
                        width: 30; height: 30; radius: 4
                        Layout.rightMargin: 20
                        color: "transparent"
                        border.width: 1
                        border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                        clip: true
                        property bool hovered: false
                        opacity: hovered ? 0.9 : 1.0
                        Image {
                          anchors.fill: parent
                          fillMode: Image.PreserveAspectFit
                          source: {
                            const ic = (realIdx >= 0 && Globals.dockItems[realIdx] && Globals.dockItems[realIdx].icon)
                                       ? String(Globals.dockItems[realIdx].icon) : ""
                            const abs = page.expandHome(ic)
                            return (abs && abs.startsWith("/")) ? ("file://" + abs) : (ic.startsWith("file://") ? ic : "")
                          }
                          asynchronous: true
                          cache: false
                          id: iconPreviewImg
                        }
                        // Error/empty overlay like WallpapersPage
                        Item {
                          anchors.fill: parent
                          visible: (!iconPreviewImg.source || iconPreviewImg.source.length === 0 || iconPreviewImg.status === Image.Error)
                          Rectangle { anchors.fill: parent; color: "#00000000" }
                          Label {
                            anchors.centerIn: parent
                            text: "No preview"
                            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                            font.family: Globals.mainFontFamily
                            font.pixelSize: Globals.mainFontSize
                          }
                        }
                        MouseArea {
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onEntered: parent.hovered = true
                          onExited: parent.hovered = false
                          onClicked: iconFileDialog.open()
                          ToolTip {
                            id: iconTip
                            visible: parent.containsMouse
                            text: "Click to choose icon"
                            contentItem: Text {
                              text: iconTip.text
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
                      }
                      Platform.FileDialog {
                        id: iconFileDialog
                        title: "Choose icon image"
                        nameFilters: [
                          "Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)",
                          "All files (*)"
                        ]
                        folder: {
                          try {
                            const cur = (realIdx >= 0 && Globals.dockItems[realIdx] && Globals.dockItems[realIdx].icon) ? String(Globals.dockItems[realIdx].icon) : ""
                            if (cur && cur.indexOf("/") >= 0) {
                              const abs = cur.startsWith("~/") && Globals.homeReady ? (Globals.homeDir + cur.slice(1)) : cur
                              const dir = abs.substring(0, abs.lastIndexOf("/"))
                              return "file://" + dir
                            }
                          } catch (e) {}
                          return "file://" + Platform.StandardPaths.writableLocation(Platform.StandardPaths.PicturesLocation)
                        }
                        onAccepted: {
                          try {
                            const list = files && files.length ? files : (file ? [file] : [])
                            if (list.length > 0 && realIdx >= 0) {
                              const picked = String(list[0]).replace("file://", "")
                              console.log('[DockPage] picked icon for idx', realIdx, '->', picked)
                              const store = (Globals.toTildePath ? Globals.toTildePath(picked) : picked)
                              if (Array.isArray(Globals.dockItems)) {
                                if (!Globals.dockItems[realIdx]) Globals.dockItems[realIdx] = {}
                                Globals.dockItems[realIdx].icon = store
                              }
                              pendingIcon = store
                              syncDockHash(); Qt.callLater(doRetrySave); saveRetry.restart(); saveRetry2.restart()
                            }
                          } catch (e) {
                            console.warn("Icon selection failed:", e)
                          }
                        }
                      }
                      // iconSizeRatio
                      TextField {
                        Layout.preferredWidth: 50
                        Layout.rightMargin: 20
                        placeholderText: "ratio"
                        text: (realIdx >= 0 && Globals.dockItems[realIdx] && Globals.dockItems[realIdx].iconSizeRatio !== undefined)
                              ? String(Globals.dockItems[realIdx].iconSizeRatio)
                              : "0.55"
                        inputMethodHints: Qt.ImhPreferNumbers
                        ToolTip {
                          id: ratioTip
                          visible: parent.hovered
                          text: "Icon image size ratio (0..1) relative to tile"
                          contentItem: Text { text: ratioTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                          background: Rectangle { color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase; border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
                        }
                        onAccepted: {
                          if (realIdx >= 0 && Array.isArray(Globals.dockItems)) {
                            const v = Number(String(text).trim())
                            if (!Globals.dockItems[realIdx]) Globals.dockItems[realIdx] = {}
                            Globals.dockItems[realIdx].iconSizeRatio = isNaN(v) ? 0.55 : v
                            syncDockHash(); save(); saveRetry.restart()
                          }
                        }
                        onEditingFinished: {
                          if (realIdx >= 0 && Array.isArray(Globals.dockItems)) {
                            const v = Number(String(text).trim())
                            if (!Globals.dockItems[realIdx]) Globals.dockItems[realIdx] = {}
                            Globals.dockItems[realIdx].iconSizeRatio = isNaN(v) ? 0.55 : v
                            syncDockHash(); save(); saveRetry.restart()
                          }
                        }
                      }
                      // iconOffsetYPx
                      TextField {
                        Layout.preferredWidth: 35
                        Layout.rightMargin: 20
                        placeholderText: "offsetY"
                        text: (realIdx >= 0 && Globals.dockItems[realIdx] && Globals.dockItems[realIdx].iconOffsetYPx !== undefined)
                              ? String(Globals.dockItems[realIdx].iconOffsetYPx)
                              : "-8"
                        inputMethodHints: Qt.ImhPreferNumbers
                        ToolTip {
                          id: offsetTip
                          visible: parent.hovered
                          text: "Vertical pixel offset of the icon"
                          contentItem: Text { text: offsetTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                          background: Rectangle { color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase; border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
                        }
                        onAccepted: {
                          if (realIdx >= 0 && Array.isArray(Globals.dockItems)) {
                            const v = parseInt(String(text).trim())
                            if (!Globals.dockItems[realIdx]) Globals.dockItems[realIdx] = {}
                            Globals.dockItems[realIdx].iconOffsetYPx = isNaN(v) ? -8 : v
                            syncDockHash(); save(); saveRetry.restart()
                          }
                        }
                        onEditingFinished: {
                          if (realIdx >= 0 && Array.isArray(Globals.dockItems)) {
                            const v = parseInt(String(text).trim())
                            if (!Globals.dockItems[realIdx]) Globals.dockItems[realIdx] = {}
                            Globals.dockItems[realIdx].iconOffsetYPx = isNaN(v) ? -8 : v
                            syncDockHash(); save(); saveRetry.restart()
                          }
                        }
                      }
                      // remove item
                      Button {
                        id: removeItemBtn
                        text: "delete"
                        leftPadding: 8; rightPadding: 8
                        onClicked: {
                          if (realIdx >= 0 && Array.isArray(Globals.dockItems)) {
                            const arr = Globals.dockItems.slice(0)
                            arr.splice(realIdx, 1)
                            Globals.dockItems = arr
                            syncDockHash(); save(); if (saveRetry) saveRetry.restart(); if (saveRetry2) saveRetry2.restart()
                          }
                        }
                        contentItem: Label { text: parent.text; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 6; color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.button; border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light; border.width: 1 }
                        ToolTip {
                          id: removeTip
                          visible: removeItemBtn.hovered
                          text: "Remove this dock item"
                          contentItem: Text { text: removeTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
                          background: Rectangle { color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase; border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
                        }
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
