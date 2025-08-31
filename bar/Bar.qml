import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "root:/"
import "blocks" as Blocks
import "root:/"

Scope {
  IpcHandler {
    target: "bar"

    function toggleVis(): void {
      // Toggle visibility of all bar instances
      for (let i = 0; i < Quickshell.screens.length; i++) {
        barInstances[i].visible = !barInstances[i].visible;
      }
    }
  }
  property var barInstances: []

  Variants {
    model: Quickshell.screens
  
    PanelWindow {
      id: bar
      property var modelData
      screen: modelData

      Component.onCompleted: {
        barInstances.push(bar);
      }

      color: "transparent"

      // Keep actual bar height constant and grow the window by the edge margin so the bar shifts
      implicitHeight: (Globals.baseBarHeight !== undefined ? Globals.baseBarHeight : 38)
                      + (Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0)
      visible: !Globals.barHidden
      anchors {
        top: Globals.barPosition === "top"
        bottom: Globals.barPosition === "bottom"
        left: true
        right: true
      }

      Rectangle {
        id: barRect
        anchors.fill: parent
        // Apply visual gap inside the window: extra top/bottom margin depending on bar position
        anchors.leftMargin: (Globals.barSideMargin !== undefined ? Globals.barSideMargin : 0) + 2
        anchors.rightMargin: (Globals.barSideMargin !== undefined ? Globals.barSideMargin : 0) + 2
        anchors.topMargin: (Globals.barPosition === "top" ? ((Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0) + 2) : 2)
        anchors.bottomMargin: (Globals.barPosition === "bottom" ? ((Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0) + 2) : 2)
        color: Globals.barBgColor
        radius: 11
        border.color: Globals.barBorderColor
        border.width: 2

        // Auto-save order when leaving reorder mode
        Connections {
          target: Globals
          function onReorderModeChanged() {
            if (!Globals.reorderMode) Globals.saveTheme()
          }
        }

        // Visual insert marker during drag
        Rectangle {
          id: insertMarker
          visible: Globals.reorderMode && dynamicRight.dragging
          x: rightArea.x + dynamicRight.insertX() - 1
          y: rightArea.y
          width: 2
          height: rightArea.height
          z: 1000
          radius: 1
          color: Globals.hoverHighlightColor || barRect.border.color
        }

        // Left: Welcome + Setup + WindowTitle (use RowLayout so BarBlock sizing is respected)
        RowLayout {
          id: leftRow
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 12
          }
          spacing: 12
          z: 2

          Blocks.Welcome { id: welcomeBlkLeft; z: 3; visible: Globals.showWelcome }
          Blocks.Setup { id: setupBlkLeft }

          // Title/Workspaces + Barvisualizer group with tight spacing
          RowLayout {
            id: titleGroup
            Layout.alignment: Qt.AlignVCenter
            // No leading gap before Barvisualizer when both left title/workspaces are hidden
            spacing: (windowTitleLeft.visible || workspacesLeft.visible) ? 14 : 0

            // Left-side variant of WindowTitle (default when not swapped)
            Blocks.WindowTitle {
              id: windowTitleLeft
              maxWidth: Math.max(200, barRect.width * 0.35)
              z: 1
              Layout.preferredWidth: visible ? implicitWidth : 0
              visible: Globals.showWindowTitle && !Globals.swapTitleAndWorkspaces
            }
            // Left-side variant of Workspaces (when swapped)
            Blocks.Workspaces {
              id: workspacesLeft
              Layout.alignment: Qt.AlignVCenter
              Layout.preferredWidth: visible ? implicitWidth : 0
              visible: Globals.showWorkspaces && Globals.swapTitleAndWorkspaces
            }
            // Barvisualizer directly after title/workspaces with no extra outer spacing
            Blocks.Barvisualizer {
              id: barvisualizer
              Layout.alignment: Qt.AlignVCenter
              // No negative margins needed; group spacing controls gap
              visible: Globals.showBarvisualizer
            }
          }
        }

        // Center: Workspaces (default) or WindowTitle (when swapped)
        // Centered Workspaces when not swapped
        Blocks.Workspaces {
          id: workspacesCenter
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          visible: Globals.showWorkspaces && !Globals.swapTitleAndWorkspaces
        }
        // Centered WindowTitle when swapped
        Blocks.WindowTitle {
          id: windowTitleCenter
          maxWidth: Math.max(200, barRect.width * 0.35)
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          visible: Globals.showWindowTitle && Globals.swapTitleAndWorkspaces
        }

        // Right side: container + layout (allows DnD overlay without layout constraints)
        Item {
          id: rightArea
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 12
          }
          // Size right area based on active mode to avoid empty space after exiting reorder
          width: Globals.reorderMode ? dynamicRight.implicitWidth : staticRight.implicitWidth
          height: Globals.reorderMode ? dynamicRight.implicitHeight : staticRight.implicitHeight

          // Layout holding the modules
          RowLayout {
            id: rightBlocks
            anchors.fill: parent
            spacing: 8

          // Static (normal mode) — but still follow saved order, just no controls
          RowLayout {
            id: staticRight
            visible: !Globals.reorderMode
            spacing: 3

            // Components for each block (reuse same mapping)
            Component { id: sSystemTray; Blocks.SystemTray { visible: Globals.showSystemTray } }
            Component { id: sUpdates; Blocks.Updates { visible: Globals.showUpdates } }
            Component { id: sNetwork; Blocks.Network { visible: Globals.showNetwork; onToggleNmAppletRequested: if (staticRight.systemTrayRef) staticRight.systemTrayRef.toggleNetworkApplet() } }
            Component { id: sBluetooth; Blocks.Bluetooth { visible: Globals.showBluetooth } }
            Component { id: sCPU; Blocks.CPU { visible: Globals.showCPU } }
            Component { id: sGPU; Blocks.GPU { visible: Globals.showGPU } }
            Component { id: sMemory; Blocks.Memory { visible: Globals.showMemory } }
            Component { id: sPowerProfiles; Blocks.PowerProfiles { visible: Globals.showPowerProfiles } }
            Component { id: sClipboard; Blocks.Clipboard { visible: Globals.showClipboard } }
            Component { id: sKeybinds; Blocks.InfoKeybinds { visible: Globals.showKeybinds } }
            Component { id: sNotifications; Blocks.Notifications { visible: Globals.showNotifications } }
            Component { id: sWindowSelector; Blocks.WindowSelector { visible: Globals.showWindowSelector } }
            Component { id: sSound; Blocks.Sound { visible: Globals.showSound } }
            Component { id: sWeather; Blocks.Weather { visible: Globals.showWeather } }
            Component { id: sBattery; Blocks.Battery { visible: Globals.showBattery } }
            Component { id: sDate; Blocks.Date { visible: Globals.showDate } }
            Component { id: sTime; Blocks.Time { visible: Globals.showTime } }
            Component { id: sPower; Blocks.Power { visible: Globals.showPower } }

            Repeater {
              model: Globals.rightModulesOrder
              delegate: Loader {
                id: staticLoader
                // resolve if this module should be shown in static mode
                property bool shown: staticRight.isShown(modelData)
                visible: shown
                active: shown
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: shown && item ? (
                  (item.Layout && item.Layout.preferredWidth && item.Layout.preferredWidth > 0) ? item.Layout.preferredWidth :
                  (item.implicitWidth && item.implicitWidth > 0) ? item.implicitWidth : (item.width || 24)
                ) : 0
                Layout.preferredHeight: shown && item ? (
                  (item.Layout && item.Layout.preferredHeight && item.Layout.preferredHeight > 0) ? item.Layout.preferredHeight :
                  (item.implicitHeight && item.implicitHeight > 0) ? item.implicitHeight : (item.height || 24)
                ) : 0
                sourceComponent: (
                  modelData === "SystemTray" ? sSystemTray :
                  modelData === "Updates" ? sUpdates :
                  modelData === "Network" ? sNetwork :
                  modelData === "Bluetooth" ? sBluetooth :
                  modelData === "CPU" ? sCPU :
                  modelData === "GPU" ? sGPU :
                  modelData === "Memory" ? sMemory :
                  modelData === "PowerProfiles" ? sPowerProfiles :
                  modelData === "Clipboard" ? sClipboard :
                  modelData === "Keybinds" ? sKeybinds :
                  modelData === "Notifications" ? sNotifications :
                  modelData === "WindowSelector" ? sWindowSelector :
                  modelData === "Sound" ? sSound :
                  modelData === "Weather" ? sWeather :
                  modelData === "Battery" ? sBattery :
                  modelData === "Date" ? sDate :
                  modelData === "Time" ? sTime :
                  modelData === "Power" ? sPower : null)
                onLoaded: {
                  if (modelData === "SystemTray") staticRight.systemTrayRef = item
                }
              }
            }

            property var systemTrayRef: null
            // map module name to its visibility toggle
            function isShown(name) {
              switch (name) {
                case "SystemTray": return Globals.showSystemTray
                case "Updates": return Globals.showUpdates
                case "Network": return Globals.showNetwork
                case "Bluetooth": return Globals.showBluetooth
                case "CPU": return Globals.showCPU
                case "GPU": return Globals.showGPU
                case "Memory": return Globals.showMemory
                case "PowerProfiles": return Globals.showPowerProfiles
                case "Clipboard": return Globals.showClipboard
                case "Keybinds": return Globals.showKeybinds
                case "Notifications": return Globals.showNotifications
                case "WindowSelector": return Globals.showWindowSelector
                case "Sound": return Globals.showSound
                case "Weather": return Globals.showWeather
                case "Battery": return Globals.showBattery
                case "Date": return Globals.showDate
                case "Time": return Globals.showTime
                case "Power": return Globals.showPower
                default: return true
              }
            }
          }

          // Dynamic (reorder mode) — modules via rightModulesOrder with move handles
          RowLayout {
            id: dynamicRight
            visible: Globals.reorderMode
            spacing: 3

            // live drag state (overlay-free DnD)
            property int dragFrom: -1
            property int dragTo: -1
            property string dragName: ""
            readonly property bool dragging: dragFrom !== -1 && dragTo !== -1

            // Compute x position (within rightBlocks) for insert marker before index dragTo
            function insertX() {
              const to = Math.max(0, Math.min(Globals.rightModulesOrder.length, dragTo))
              let acc = 0
              for (let i = 0; i < to; i++) {
                const it = rightRepeater.itemAt(i)
                if (!it) continue
                const w = it.width || it.implicitWidth || 24
                acc += w
                if (i < to - 1) acc += dynamicRight.spacing
              }
              return acc
            }

            // Components for each block
            Component { id: cSystemTray; Blocks.SystemTray { visible: Globals.showSystemTray } }
            Component { id: cUpdates; Blocks.Updates { visible: Globals.showUpdates } }
            Component { id: cNetwork; Blocks.Network { visible: Globals.showNetwork; onToggleNmAppletRequested: if (dynamicRight.systemTrayRef) dynamicRight.systemTrayRef.toggleNetworkApplet() } }
            Component { id: cBluetooth; Blocks.Bluetooth { visible: Globals.showBluetooth } }
            Component { id: cCPU; Blocks.CPU { visible: Globals.showCPU } }
            Component { id: cGPU; Blocks.GPU { visible: Globals.showGPU } }
            Component { id: cMemory; Blocks.Memory { visible: Globals.showMemory } }
            Component { id: cPowerProfiles; Blocks.PowerProfiles { visible: Globals.showPowerProfiles } }
            Component { id: cClipboard; Blocks.Clipboard { visible: Globals.showClipboard } }
            Component { id: cKeybinds; Blocks.InfoKeybinds { visible: Globals.showKeybinds } }
            Component { id: cNotifications; Blocks.Notifications { visible: Globals.showNotifications } }
            Component { id: cWindowSelector; Blocks.WindowSelector { visible: Globals.showWindowSelector } }
            Component { id: cSound; Blocks.Sound { visible: Globals.showSound } }
            Component { id: cBattery; Blocks.Battery { visible: Globals.showBattery } }
            Component { id: cDate; Blocks.Date { visible: Globals.showDate } }
            Component { id: cTime; Blocks.Time { visible: Globals.showTime } }
            Component { id: cPower; Blocks.Power { visible: Globals.showPower } }
            Component { id: cWeather; Blocks.Weather { visible: Globals.showWeather } }

            // map module name to its visibility toggle (for reorder placeholders)
            function isShown(name) {
              switch (name) {
                case "SystemTray": return Globals.showSystemTray
                case "Updates": return Globals.showUpdates
                case "Network": return Globals.showNetwork
                case "Bluetooth": return Globals.showBluetooth
                case "CPU": return Globals.showCPU
                case "GPU": return Globals.showGPU
                case "Memory": return Globals.showMemory
                case "PowerProfiles": return Globals.showPowerProfiles
                case "Clipboard": return Globals.showClipboard
                case "Keybinds": return Globals.showKeybinds
                case "Notifications": return Globals.showNotifications
                case "Sound": return Globals.showSound
                case "Battery": return Globals.showBattery
                case "Date": return Globals.showDate
                case "Time": return Globals.showTime
                case "Power": return Globals.showPower
                case "Weather": return Globals.showWeather
                default: return true
              }
            }

            function move(arr, from, to) {
              if (from === to || from < 0 || to < 0 || from >= arr.length || to >= arr.length) return arr
              const a = Array.prototype.slice.call(arr)
              const [it] = a.splice(from, 1)
              a.splice(to, 0, it)
              return a
            }

            Repeater {
              id: rightRepeater
              model: Globals.rightModulesOrder
              delegate: RowLayout {
                id: modWrap
                property string modName: modelData
                property int myIndex: index
                // Access the dynamicRight container via the repeater's parent to avoid id-scope issues
                property var host: rightRepeater ? rightRepeater.parent : null
                // whether this module is currently shown (based on toggles)
                property bool shown: host ? host.isShown(modName) : true
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                // Accept drops to compute new order
                DropArea {
                  // Avoid anchors inside RowLayout-managed item; use explicit size overlay
                  x: 0; y: 0
                  width: modWrap.width
                  height: modWrap.height
                  z: 100
                  keys: [] // accept all drags
                  onEntered: function(event) {
                    if (event) event.acceptProposedAction()
                    console.log('[reorder][dnd] enter over', modWrap.modName)
                  }
                  onExited: function(event) {
                    console.log('[reorder][dnd] exit over', modWrap.modName)
                  }
                  onPositionChanged: function(event) {
                    if (event) event.acceptProposedAction()
                  }
                  onDropped: function(event) {
                    if (event) event.acceptProposedAction()
                    const src = event.source
                    const fromName = (src && src.parent) ? src.parent.modName : null
                    if (!fromName) return
                    const from = Globals.rightModulesOrder.indexOf(fromName)
                    if (from < 0) return
                    // Decide insert position: before or after this cell based on drop x
                    const after = event.x > (width / 2)
                    let to = modWrap.myIndex + (after ? 1 : 0)
                    // Adjust target if removing from before the insertion point
                    if (from < to) to = to - 1
                    if (from === to) return
                    const a = Array.prototype.slice.call(Globals.rightModulesOrder)
                    const [it] = a.splice(from, 1)
                    a.splice(Math.max(0, Math.min(a.length, to)), 0, it)
                    Globals.rightModulesOrder = a
                    console.log('[reorder][dnd] moved', fromName, 'from', from, 'to', to)
                  }
                }

                // Left move control (hidden to avoid widening layout; DnD is primary)
                Rectangle {
                  visible: false
                  z: 10
                  Layout.preferredWidth: 18
                  Layout.preferredHeight: (loader.item && (loader.item.implicitHeight || loader.item.height)) ? (loader.item.implicitHeight || loader.item.height) : 24
                  width: 18; height: Layout.preferredHeight
                  color: Qt.rgba(0,0,0,0)
                  Text { anchors.centerIn: parent; text: "‹"; color: Globals.moduleIconColor }
                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      console.log('[reorder] left click on', modWrap.modName, 'idx', modWrap.myIndex)
                      if (modWrap.myIndex > 0) {
                        const next = modWrap.host.move(Globals.rightModulesOrder, modWrap.myIndex, modWrap.myIndex - 1)
                        Globals.rightModulesOrder = next
                        console.log('[reorder] new order', JSON.stringify(next))
                      }
                    }
                  }
                }
                // Loaded module (acts as drag handle area)
                Loader {
                  id: loader
                  z: 1
                  visible: modWrap.shown
                  active: true
                  Layout.alignment: Qt.AlignVCenter
                  Layout.preferredWidth: item ? (
                    (item.Layout && item.Layout.preferredWidth && item.Layout.preferredWidth > 0) ? item.Layout.preferredWidth :
                    (item.implicitWidth && item.implicitWidth > 0) ? item.implicitWidth : (item.width || 24)
                  ) : 24
                  Layout.preferredHeight: item ? (
                    (item.Layout && item.Layout.preferredHeight && item.Layout.preferredHeight > 0) ? item.Layout.preferredHeight :
                    (item.implicitHeight && item.implicitHeight > 0) ? item.implicitHeight : (item.height || 24)
                  ) : 24
                  // Attach Drag to the Loader (Item) so Drag works; RowLayout is not an Item
                  Drag.keys: ["right-mod"]
                  Drag.mimeData: ({ "text/plain": modWrap.modName })
                  Drag.supportedActions: Qt.MoveAction
                  Drag.active: dhandler.active
                  Drag.hotSpot.x: loader.width / 2
                  Drag.hotSpot.y: loader.height / 2
                  sourceComponent: (
                    modWrap.modName === "SystemTray" ? cSystemTray :
                    modWrap.modName === "Updates" ? cUpdates :
                    modWrap.modName === "Network" ? cNetwork :
                    modWrap.modName === "Bluetooth" ? cBluetooth :
                    modWrap.modName === "CPU" ? cCPU :
                    modWrap.modName === "GPU" ? cGPU :
                    modWrap.modName === "Memory" ? cMemory :
                    modWrap.modName === "PowerProfiles" ? cPowerProfiles :
                    modWrap.modName === "Clipboard" ? cClipboard :
                    modWrap.modName === "Keybinds" ? cKeybinds :
                    modWrap.modName === "Notifications" ? cNotifications :
                    modWrap.modName === "WindowSelector" ? cWindowSelector :
                    modWrap.modName === "Sound" ? cSound :
                    modWrap.modName === "Battery" ? cBattery :
                    modWrap.modName === "Date" ? cDate :
                    modWrap.modName === "Time" ? cTime :
                    modWrap.modName === "Power" ? cPower :
                    modWrap.modName === "Weather" ? cWeather : null)
                  onLoaded: {
                    if (modWrap.modName === "SystemTray" && modWrap.host) modWrap.host.systemTrayRef = item
                  }

                  // Use DragHandler for reliable drag start/stop without moving item
                  DragHandler {
                    id: dhandler
                    target: null
                    acceptedButtons: Qt.LeftButton
                    grabPermissions: PointerHandler.CanTakeOverFromAnything
                    dragThreshold: 2
                    onActiveChanged: {
                      console.log('[reorder][dnd] drag', active ? 'start' : 'stop', 'on', modWrap.modName)
                      if (active) {
                        if (modWrap.host) {
                          modWrap.host.dragFrom = modWrap.myIndex
                          modWrap.host.dragName = modWrap.modName
                          modWrap.host.dragTo = modWrap.myIndex
                        }
                      } else {
                        // finalize reorder if target changed
                        const from = modWrap.host ? modWrap.host.dragFrom : -1
                        let to = modWrap.host ? modWrap.host.dragTo : -1
                        if (from !== -1 && to !== -1) {
                          if (from < to) to = to - 1
                          if (from !== to) {
                            const a = Array.prototype.slice.call(Globals.rightModulesOrder)
                            const [it] = a.splice(from, 1)
                            a.splice(Math.max(0, Math.min(a.length, to)), 0, it)
                            Globals.rightModulesOrder = a
                            console.log('[reorder][dnd][final] moved', modWrap.host ? modWrap.host.dragName : modWrap.modName, 'from', from, 'to', to)
                          }
                        }
                        if (modWrap.host) {
                          modWrap.host.dragFrom = -1
                          modWrap.host.dragTo = -1
                          modWrap.host.dragName = ""
                        }
                      }
                    }
                    onCentroidChanged: {
                      if (active && modWrap.host) {
                        // compute index under drag position
                        const p = mapToItem(rightBlocks, centroid.position.x, centroid.position.y)
                        let acc = 0
                        for (let i = 0; i < rightRepeater.count; i++) {
                          const it = rightRepeater.itemAt(i)
                          if (!it) continue
                          const w = it.width || it.implicitWidth || 24
                          if (p.x < acc + w / 2) { modWrap.host.dragTo = i; return }
                          acc += w + dynamicRight.spacing
                        }
                        modWrap.host.dragTo = rightRepeater.count
                      }
                    }
                  }
                }

                // Placeholder when module is hidden — still draggable
                Rectangle {
                  id: placeholder
                  visible: !modWrap.shown
                  Layout.preferredWidth: 24
                  Layout.preferredHeight: 24
                  width: 24; height: 24
                  radius: 6
                  color: Qt.rgba(0.8, 0.8, 0.8, 0.18)
                  border.color: barRect.border.color
                  border.width: 1
                  Drag.keys: ["right-mod"]
                  Drag.mimeData: ({ "text/plain": modWrap.modName })
                  Drag.supportedActions: Qt.MoveAction
                  Drag.active: pdhandler.active
                  Drag.hotSpot.x: width / 2
                  Drag.hotSpot.y: height / 2
                  DragHandler {
                    id: pdhandler
                    target: null
                    acceptedButtons: Qt.LeftButton
                    grabPermissions: PointerHandler.CanTakeOverFromAnything
                    dragThreshold: 2
                    onActiveChanged: {
                      if (active) {
                        if (modWrap.host) {
                          modWrap.host.dragFrom = modWrap.myIndex
                          modWrap.host.dragName = modWrap.modName
                          modWrap.host.dragTo = modWrap.myIndex
                        }
                      } else {
                        const from = modWrap.host ? modWrap.host.dragFrom : -1
                        let to = modWrap.host ? modWrap.host.dragTo : -1
                        if (from !== -1 && to !== -1) {
                          if (from < to) to = to - 1
                          if (from !== to) {
                            const a = Array.prototype.slice.call(Globals.rightModulesOrder)
                            const [it] = a.splice(from, 1)
                            a.splice(Math.max(0, Math.min(a.length, to)), 0, it)
                            Globals.rightModulesOrder = a
                            console.log('[reorder][dnd][final] moved (ph)', modWrap.host ? modWrap.host.dragName : modWrap.modName, 'from', from, 'to', to)
                          }
                        }
                        if (modWrap.host) {
                          modWrap.host.dragFrom = -1
                          modWrap.host.dragTo = -1
                          modWrap.host.dragName = ""
                        }
                      }
                    }
                    onCentroidChanged: {
                      if (active && modWrap.host) {
                        const p = mapToItem(rightBlocks, centroid.position.x, centroid.position.y)
                        let acc = 0
                        for (let i = 0; i < rightRepeater.count; i++) {
                          const it = rightRepeater.itemAt(i)
                          if (!it) continue
                          const w = it.width || it.implicitWidth || 24
                          if (p.x < acc + w / 2) { modWrap.host.dragTo = i; return }
                          acc += w + dynamicRight.spacing
                        }
                        modWrap.host.dragTo = rightRepeater.count
                      }
                    }
                  }
                }

                // Left move control (hidden to avoid widening layout; DnD is primary)
                Rectangle {
                  visible: false
                  z: 10
                  Layout.preferredWidth: 18
                  Layout.preferredHeight: (loader.item && (loader.item.implicitHeight || loader.item.height)) ? (loader.item.implicitHeight || loader.item.height) : 24
                  width: 18; height: Layout.preferredHeight
                  color: Qt.rgba(0,0,0,0)
                  Text { anchors.centerIn: parent; text: "‹"; color: Globals.moduleIconColor }
                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      console.log('[reorder] left click on', modWrap.modName, 'idx', modWrap.myIndex)
                      if (modWrap.myIndex > 0) {
                        const next = modWrap.host.move(Globals.rightModulesOrder, modWrap.myIndex, modWrap.myIndex - 1)
                        Globals.rightModulesOrder = next
                        console.log('[reorder] new order', JSON.stringify(next))
                      }
                    }
                  }
                }

                // Right move control (hidden to avoid widening layout; DnD is primary)
                Rectangle {
                  visible: false
                  z: 10
                  Layout.preferredWidth: 18
                  Layout.preferredHeight: (loader.item && (loader.item.implicitHeight || loader.item.height)) ? (loader.item.implicitHeight || loader.item.height) : 24
                  width: 18; height: Layout.preferredHeight
                  color: Qt.rgba(0,0,0,0)
                  Text { anchors.centerIn: parent; text: "›"; color: Globals.moduleIconColor }
                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      console.log('[reorder] right click on', modWrap.modName, 'idx', modWrap.myIndex)
                      if (modWrap.myIndex < Globals.rightModulesOrder.length - 1) {
                        const next = modWrap.host.move(Globals.rightModulesOrder, modWrap.myIndex, modWrap.myIndex + 1)
                        Globals.rightModulesOrder = next
                        console.log('[reorder] new order', JSON.stringify(next))
                      }
                    }
                  }
                }
              }
            }
            // Keep a reference to SystemTray for Network hook
            property var systemTrayRef: null
          }

          // Overlay DropArea across the entire right area (active only in reorder mode)
          DropArea {
            id: rightOverlay
            visible: Globals.reorderMode
            // Avoid anchors inside any layout-managed context; use explicit geometry over rightBlocks
            x: rightBlocks.x
            y: rightBlocks.y
            width: rightBlocks.width
            height: rightBlocks.height
            z: 999
            keys: [] // accept all drags
            onEntered: function(event) {
              if (event) event.acceptProposedAction();
              console.log('[reorder][dnd][overlay] enter', 'keys=', event.keys, 'src=', event.source)
            }
            onPositionChanged: function(event) { if (event) event.acceptProposedAction() }
            onDropped: function(event) {
              if (event) event.acceptProposedAction()
              const src = event.source
              const fromName = (src && src.parent) ? src.parent.modName : null
              if (!fromName) return
              const from = Globals.rightModulesOrder.indexOf(fromName)
              if (from < 0) return
              // Compute global target index by x across all delegates
              const N = Globals.rightModulesOrder.length
              let dropX = event.x
              let acc = 0
              let to = 0
              for (let i = 0; i < N; i++) {
                const it = rightRepeater.itemAt(i)
                if (!it) continue
                const w = it.width || it.implicitWidth || 24
                if (dropX < acc + w / 2) { to = i; break }
                acc += w + rightBlocks.spacing
                to = i + 1
              }
              if (from < to) to = to - 1
              if (to < 0) to = 0
              if (to > N - 1) to = N - 1
              if (from === to) return
              const a = Array.prototype.slice.call(Globals.rightModulesOrder)
              const [itname] = a.splice(from, 1)
              a.splice(to, 0, itname)
              Globals.rightModulesOrder = a
              console.log('[reorder][dnd][overlay] moved', fromName, 'from', from, 'to', to)
            }
          }
        }
      }
    }
    // Mini gear-only window when bar is hidden (game mode)
    PanelWindow {
      id: miniGear
      screen: bar.screen
      visible: Globals.barHidden
      color: "transparent"
      implicitHeight: (Globals.baseBarHeight !== undefined ? Globals.baseBarHeight : 38)
                      + (Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0)
      implicitWidth: 44
      anchors {
        top: Globals.barPosition === "top"
        bottom: Globals.barPosition === "bottom"
        left: true
        right: false
      }

      Item {
        id: miniRect
        anchors.fill: parent
        anchors.leftMargin: (Globals.barSideMargin !== undefined ? Globals.barSideMargin : 0) + 2
        anchors.rightMargin: 2
        anchors.topMargin: (Globals.barPosition === "top" ? ((Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0) + 2) : 2)
        anchors.bottomMargin: (Globals.barPosition === "bottom" ? ((Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0) + 2) : 2)

        RowLayout {
          anchors.fill: parent
          anchors.margins: 0
          spacing: 0
          Blocks.Setup { id: miniSetup; Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter }
        }
      }
    }
  }
  // (removed) Custom toast overlay; using swaync for notifications now
}


}
