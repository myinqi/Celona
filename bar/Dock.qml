import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/"

// New rectangle-based Dock using Globals.* config-only
PanelWindow {
  id: dock
  color: "transparent"

  // Visibility
  visible: Globals.showDock && Array.isArray(Globals.dockItems)

  // Geometry/Anchors per config (screen is set by instantiator)
  anchors {
    top: Globals.dockPositionVertical !== "bottom"
    bottom: Globals.dockPositionVertical !== "top"
    left: Globals.dockPositionHorizontal === "left"
    right: Globals.dockPositionHorizontal === "right"
  }
  // Size follows content to avoid clipping when anchored only to top/bottom
  implicitWidth: Math.max(Globals.dockIconSizePx + 16, 56)
  implicitHeight: col.implicitHeight + 16

  Flickable {
    id: flick
    anchors.fill: parent
    contentWidth: width
    // include symmetric margins to match implicitHeight
    contentHeight: col.implicitHeight + 16
    clip: true

    Column {
      id: col
      x: 0
      width: flick.width
      spacing: Math.max(0, Globals.dockIconSpacing)
      // Position via y instead of anchors to avoid Column anchor warnings
      y: Globals.dockPositionVertical === "center"
         ? Math.max(8, Math.floor((flick.height - col.implicitHeight) / 2))
         : (Globals.dockPositionVertical === "bottom"
            ? Math.max(8, flick.height - col.implicitHeight - 8)
            : 8)

      Repeater {
        id: reps
        model: Globals.dockItems
        delegate: Item {
          id: delegateRoot
          width: col.width
          height: Globals.dockIconSizePx
          property int myIndex: index
          // drag state helpers
          property real pressX: 0
          property real pressY: 0
          property bool didDrag: false
          // internal flag to control Drag.active
          property bool dragging: false
          Drag.active: Globals.allowDockIconMovement && dragging
          Drag.hotSpot.x: box.width/2
          Drag.hotSpot.y: box.height/2
          Drag.keys: ["dockItem"]

          Rectangle {
            id: box
            width: Globals.dockIconSizePx
            height: Globals.dockIconSizePx
            radius: Globals.dockIconRadius
            color: Globals.dockIconBGColor
            border.width: Math.max(0, Globals.dockIconBorderPx)
            border.color: Globals.dockIconBorderColor
            anchors.horizontalCenter: parent.horizontalCenter

            MouseArea {
              anchors.fill: parent
              onClicked: {
                // Only treat as click when not initiating a drag
                if (!Globals.allowDockIconMovement || (!delegateRoot.Drag.active && !delegateRoot.didDrag))
                  runCmd(modelData && modelData.cmd ? String(modelData.cmd) : "")
              }
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              id: dragArea
              drag.target: null // we use Drag API, not visual move
              // Always accept LeftButton so clicks work even when movement is disabled
              acceptedButtons: Qt.LeftButton
              onPressed: (mouse) => {
                delegateRoot.didDrag = false
                delegateRoot.pressX = mouse.x
                delegateRoot.pressY = mouse.y
                if (Globals.allowDockIconMovement) {
                  dragArea.drag.accepted = true
                  delegateRoot.dragging = false
                }
              }
              onPressAndHold: {
                if (Globals.allowDockIconMovement) {
                  delegateRoot.didDrag = true
                  delegateRoot.dragging = true
                  delegateRoot.Drag.startDrag()
                }
              }
              onPositionChanged: (mouse) => {
                if (!Globals.allowDockIconMovement || delegateRoot.dragging) return
                const dx = mouse.x - delegateRoot.pressX
                const dy = mouse.y - delegateRoot.pressY
                const dist = Math.sqrt(dx*dx + dy*dy)
                const thresh = Qt.styleHints.startDragDistance
                if (dist >= thresh) {
                  delegateRoot.didDrag = true
                  delegateRoot.dragging = true
                  delegateRoot.Drag.startDrag()
                }
              }
              onReleased: (mouse) => {
                if (delegateRoot.dragging) {
                  // end of drag; let DropArea handle reorder; prevent click
                  delegateRoot.dragging = false
                }
              }
            }

            // Label inside the icon
            Text {
              visible: Globals.dockIconLabel && (modelData && modelData.label && modelData.label.length)
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.margins: 4
              text: modelData && modelData.label ? modelData.label : ""
              color: Globals.dockIconLabelColor
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              font.pixelSize: Math.max(9, Math.min(13, Math.floor(parent.width * 0.18)))
              style: Text.Outline
              styleColor: "#A0000000"
            }
          }
        }
      }
    }

    // Visual insert marker and overlay DropArea (not inside Column)
    Rectangle {
      id: insertMarker
      visible: Globals.allowDockIconMovement && dropArea.containsDrag
      x: (width - 2) / 2
      width: 2
      height: 0 // set dynamically
      y: col.y
      z: 10
      color: Qt.rgba(1,1,1,0.6)
    }

    DropArea {
      id: dropArea
      visible: Globals.allowDockIconMovement
      x: 0
      y: col.y
      width: flick.width
      height: col.implicitHeight
      z: 10
      keys: ["dockItem"]
      onEntered: function(event) { if (event) event.acceptProposedAction() }
      onPositionChanged: function(event) {
        if (!event) return
        event.acceptProposedAction()
        // compute insert index by y position relative to column
        const relY = event.y - col.y
        const N = reps.count
        let acc = 0
        let to = 0
        for (let i = 0; i < N; i++) {
          const it = reps.itemAt(i)
          if (!it) continue
          const h = it.height || Globals.dockIconSizePx
          if (relY < acc + h/2) { to = i; break }
          acc += h + col.spacing
          to = i + 1
        }
        // position insert marker
        insertMarker.height = 4
        insertMarker.y = col.y + Math.max(0, acc - col.spacing/2) - 2
      }
      onDropped: function(event) {
        if (!event) return
        event.acceptProposedAction()
        const src = event.source
        if (!src || src.myIndex === undefined) return
        let from = src.myIndex
        // compute target index similar to onPositionChanged
        const relY = event.y - col.y
        const N = reps.count
        let acc = 0
        let to = 0
        for (let i = 0; i < N; i++) {
          const it = reps.itemAt(i)
          if (!it) continue
          const h = it.height || Globals.dockIconSizePx
          if (relY < acc + h/2) { to = i; break }
          acc += h + col.spacing
          to = i + 1
        }
        if (from < 0 || from >= N) return
        if (to < 0) to = 0
        if (to > N) to = N
        if (from === to || from === to - 1) return
        const a = Array.prototype.slice.call(Globals.dockItems)
        const [item] = a.splice(from, 1)
        a.splice(to > from ? to - 1 : to, 0, item)
        Globals.dockItems = a
        Globals.saveTheme()
      }
    }
  }

  // Command runner
  Process { id: runProc; running: false }
  function runCmd(cmd) {
    const s = String(cmd || "").trim()
    if (!s.length) return
    const esc = s.replace(/'/g, "'\"'\"'")
    runProc.command = ["bash", "-lc", "(" + esc + ") >/dev/null 2>&1 & disown || true"]
    runProc.running = true
  }
}
