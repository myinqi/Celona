import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/"

// New rectangle-based Dock using Globals.* config-only
PanelWindow {
  id: root
  color: "transparent"
  // Reorder state (custom, no Qt DnD)
  property int dragFromIndex: -1
  property int dragToIndex: -1
  // Theme-aware marker color contrast based on icon background
  property color __dockBg: Globals.dockIconBGColor
  property bool __bgIsLight: (0.2126*__dockBg.r + 0.7152*__dockBg.g + 0.0722*__dockBg.b) > 0.5
  property color __markerColor: __bgIsLight ? Qt.rgba(0,0,0,0.65) : Qt.rgba(1,1,1,0.65)

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
                if (!Globals.allowDockIconMovement || !delegateRoot.didDrag)
                  runCmd(modelData && modelData.cmd ? String(modelData.cmd) : "")
              }
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              id: dragArea
              // Always accept LeftButton so clicks work even when movement is disabled
              acceptedButtons: Qt.LeftButton
              onPressed: (mouse) => {
                delegateRoot.didDrag = false
                delegateRoot.pressX = mouse.x
                delegateRoot.pressY = mouse.y
                if (Globals.allowDockIconMovement) {
                  root.dragFromIndex = delegateRoot.myIndex
                  root.dragToIndex = delegateRoot.myIndex
                  insertMarker.height = 4
                  // position marker at current slot
                  let acc = 0
                  for (let i = 0; i < reps.count && i < delegateRoot.myIndex; i++) {
                    const it = reps.itemAt(i)
                    acc += (it ? it.height : Globals.dockIconSizePx) + col.spacing
                  }
                  insertMarker.y = col.y + Math.max(0, acc - col.spacing/2) - 2
                }
              }
              onPressAndHold: {
                if (Globals.allowDockIconMovement) delegateRoot.didDrag = true
              }
              onPositionChanged: (mouse) => {
                if (!Globals.allowDockIconMovement) return
                const dx = mouse.x - delegateRoot.pressX
                const dy = mouse.y - delegateRoot.pressY
                const dist = Math.sqrt(dx*dx + dy*dy)
                const thresh = Qt.styleHints.startDragDistance
                if (dist >= thresh) {
                  delegateRoot.didDrag = true
                  // compute target index relative to column
                  const relY = col.mapFromItem(dragArea, Qt.point(mouse.x, mouse.y)).y
                  const N = reps.count
                  let acc = 0
                  let to = 0
                  for (let i = 0; i < N; i++) {
                    const it = reps.itemAt(i)
                    const h = (it ? it.height : Globals.dockIconSizePx)
                    if (relY < acc + h/2) { to = i; break }
                    acc += h + col.spacing
                    to = i + 1
                  }
                  root.dragToIndex = to
                  insertMarker.y = col.y + Math.max(0, acc - col.spacing/2) - 2
                }
              }
              onReleased: (mouse) => {
                if (!Globals.allowDockIconMovement) return
                if (delegateRoot.didDrag && root.dragFromIndex >= 0) {
                  const from = root.dragFromIndex
                  let to = root.dragToIndex
                  const N = reps.count
                  if (from >= 0 && from < N) {
                    if (to < 0) to = 0
                    if (to > N) to = N
                    // adjust when moving downwards (array shrinks before insert)
                    if (to > from) to -= 1
                    if (to !== from) {
                      const a = Array.prototype.slice.call(Globals.dockItems)
                      const [item] = a.splice(from, 1)
                      a.splice(to, 0, item)
                      Globals.dockItems = a
                      Globals.saveTheme()
                    }
                  }
                }
                // reset marker/state
                root.dragFromIndex = -1
                root.dragToIndex = -1
                delegateRoot.didDrag = false
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

    // Visual insert marker during custom DnD (not inside Column)
    Rectangle {
      id: insertMarker
      visible: Globals.allowDockIconMovement && root.dragFromIndex >= 0
      x: Math.floor(flick.width / 2) - 1
      width: 2
      height: 4 // may be updated during drag
      y: col.y
      z: 10
      color: root.__markerColor
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
