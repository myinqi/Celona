import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/"

// New rectangle-based Dock using Globals.* config-only
PanelWindow {
  id: root
  color: "transparent"
  // Resolve icon path: absolute/file URLs pass-through; relative -> root:/ prefix
  // Also percent-encode spaces to avoid QML URL loading issues
  function resolveIconPath(p) {
    const s = String(p || "").trim()
    if (!s.length) return ""
    const enc = (x) => x.replace(/ /g, "%20")
    const rootPrefix = "~/.config/quickshell/Celona/"
    if (s.startsWith(rootPrefix)) {
      // Map to project-root-relative
      return enc("root:/" + s.substring(rootPrefix.length))
    }
    if (s.startsWith("/") || s.startsWith("file:") || s.startsWith("root:/")) return enc(s)
    return enc("root:/" + s)
  }
  // Reorder state (custom, no Qt DnD)
  property int dragFromIndex: -1
  property int dragToIndex: -1
  // Theme-aware marker color contrast based on icon background
  property color __dockBg: Globals.dockIconBGColor
  property bool __bgIsLight: (0.2126*__dockBg.r + 0.7152*__dockBg.g + 0.0722*__dockBg.b) > 0.5
  property color __markerColor: __bgIsLight ? Qt.rgba(0,0,0,0.65) : Qt.rgba(1,1,1,0.65)

  // Autohide mode
  property bool __autoHide: Globals.dockLayerPosition === "autohide"
  property bool __expanded: false
  // While collapsing, keep content visible for fade/size animation
  property bool __collapsing: false
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
  // When autohide is active and not expanded, keep a 1px invisible trigger strip via implicitWidth
  implicitWidth: (__autoHide && !__expanded)
                  ? 1
                  : Math.max(Globals.dockIconSizePx + 16, 56)
  implicitHeight: col.implicitHeight + 16

  // Expand on enter, collapse after short delay on leave
  Timer {
    id: hideTimer
    interval: 400
    repeat: false
    onTriggered: if (root.__autoHide) {
      // start collapse sequence
      root.__collapsing = true
      root.__expanded = false
      collapseDone.restart()
    }
  }

  // Timer to end collapsing state after out-duration so visibility doesn't cut the fade
  Timer {
    id: collapseDone
    interval: Globals.dockAutoHideOutDurationMs
    repeat: false
    onTriggered: root.__collapsing = false
  }

  Flickable {
    id: flick
    anchors.fill: parent
    clip: true
    // Keep visible while collapsing so animations can play
    visible: !root.__autoHide || root.__expanded || root.__collapsing
    opacity: (!root.__autoHide || root.__expanded) ? 1 : 0
    Behavior on opacity {
      NumberAnimation {
        duration: root.__expanded ? Globals.dockAutoHideInDurationMs : Globals.dockAutoHideOutDurationMs
        easing.type: Easing.OutQuad
      }
    }
    contentWidth: width
    contentHeight: col.implicitHeight
    interactive: false

    Column {
      id: col
      x: 0
      width: flick.width
      spacing: Globals.dockIconSpacing
      anchors.margins: (root.__autoHide && !root.__expanded) ? 0 : 8
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
            id: iconRect
            anchors.fill: parent
            radius: Globals.dockIconRadius
            color: Globals.dockIconBGColor
            border.width: Math.max(0, Globals.dockIconBorderPx)
            border.color: Globals.dockIconBorderColor
            anchors.horizontalCenter: parent.horizontalCenter

            // Optional centered PNG icon
            Image {
              anchors.centerIn: parent
              anchors.verticalCenterOffset: (modelData && modelData.iconOffsetYPx !== undefined)
                                              ? Number(modelData.iconOffsetYPx)
                                              : -Math.floor(parent.height * 0.12)
              visible: !!(modelData && modelData.icon)
              source: root.resolveIconPath(modelData && modelData.icon ? modelData.icon : "")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              smooth: true
              readonly property real __ratio: (modelData && modelData.iconSizeRatio !== undefined)
                                               ? Math.max(0.1, Math.min(1.0, Number(modelData.iconSizeRatio)))
                                               : 0.55
              width: Math.floor(parent.width * __ratio)
              height: Math.floor(parent.height * __ratio)
            }

            MouseArea {
              anchors.fill: parent
              enabled: !root.__autoHide || root.__expanded
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
                if (root.__autoHide && !root.__expanded) return
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
                if (root.__autoHide && !root.__expanded) return
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
                if (root.__autoHide && !root.__expanded) return
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

    // Hover watcher for autohide: collapse when mouse leaves the dock
    MouseArea {
      anchors.fill: parent
      visible: root.__autoHide && root.__expanded
      enabled: visible
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      onEntered: { hideTimer.stop(); collapseDone.stop(); root.__collapsing = false }
      onExited: hideTimer.restart()
    }
  }

  // Trigger area when collapsed: expand on hover
  MouseArea {
    anchors.fill: parent
    visible: root.__autoHide && !root.__expanded
    enabled: visible
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: { root.__expanded = true; hideTimer.stop(); collapseDone.stop(); root.__collapsing = false }
  }

  // Subtle animation for expand/collapse using implicitWidth
  Behavior on implicitWidth {
    NumberAnimation {
      duration: root.__expanded ? Globals.dockAutoHideInDurationMs : Globals.dockAutoHideOutDurationMs
      easing.type: Easing.OutQuad
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
