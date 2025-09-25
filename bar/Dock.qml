import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/"
import "./utils" as Utils

// New rectangle-based Dock using Globals.* config-only
PanelWindow {
  id: root
  color: "transparent"
  // Ensure the window follows implicit size immediately when content changes
  width: implicitWidth
  height: implicitHeight
  // Ensure a proper layout pass right after creation
  Component.onCompleted: {
    root.__updateCachedContentHeight()
    root.__layoutEpoch++
    Qt.callLater(function() { root.__layoutEpoch++ })
    // Also schedule a slightly later nudge in case globals load async
    Qt.callLater(function() { __layoutBurstA.restart(); __layoutBurstB.restart() })
  }
  Process {
    id: electronScanProc
    running: false
    stdout: SplitParser { onRead: (data) => { try { root.__electronHasWindsurf = (String(data||"").indexOf('YES') >= 0) } catch (e) { root.__electronHasWindsurf = false } } }
  }

  // ps-based detection across all configured Dock items (centralized)
  // Maintains a set of tokens found running via `ps -C <token>`
  property var __runningCmdSet: ({})
  // Global flag: any electron process points to windsurf app
  property bool __electronHasWindsurf: false
  function __cmdSetClear() { __runningCmdSet = ({}) }
  function __cmdSetPut(tok, isRun) {
    try {
      const k = String(tok||"").toLowerCase(); if (!k) return
      if (isRun) __runningCmdSet[k] = true; else delete __runningCmdSet[k]
    } catch (e) {}
  }
  function __cmdAnyRunning(tokOrArr) {
    try {
      const arr = Array.isArray(tokOrArr) ? tokOrArr : [String(tokOrArr||"").toLowerCase()]
      for (let j=0;j<arr.length;j++) {
        const t = arr[j]; if (!t) continue
        if (__runningCmdSet[t]) return true
      }
      const keys = Object.keys(__runningCmdSet)
      for (let i=0;i<keys.length;i++) {
        const k = keys[i]
        for (let j=0;j<arr.length;j++) {
          const t = arr[j]
          if (k.indexOf(t) >= 0 || t.indexOf(k) >= 0) return true
        }
      }
      return false
    } catch (e) { return false }
  }
  Timer {
    id: cmdScanTimer
    interval: 800
    repeat: true
    running: (Globals.showDock && Globals.showDockRunningIndicator)
    onTriggered: {
      try {
        const items = (Array.isArray(Globals.dockItems) ? Globals.dockItems : [])
        const seen = {}
        const toks = []
        for (let i=0;i<items.length;i++) {
          const it = items[i] || {}
          const arr = root.__tokensFromCmd(it.cmd)
          for (let k=0;k<arr.length;k++) {
            const tok = arr[k]
            if (tok && !seen[tok]) { seen[tok] = true; toks.push(tok) }
          }
        }
        if (toks.length === 0) { root.__cmdSetClear(); return }
        const joined = toks.map(t => t.replace(/'/g, "'\"'\"'"))
        const list = joined.join(' ')
        cmdScanProc.command = [
          "bash","-lc",
          "TOKENS=\"" + list + "\"; " +
          "for t in $TOKENS; do if ps -o pid= -C \"$t\" >/dev/null 2>&1; then echo RUN:$t; else echo OFF:$t; fi; done"
        ]
        root.__cmdSetClear()
        cmdScanProc.running = true
        // Also scan electron variants globally for windsurf
        electronScanProc.command = [
          "bash","-lc",
          "(ps -o args= -C electron -C electron34 -C electron32 2>/dev/null | grep -qi 'windsurf/resources/app' && echo YES) || echo NO"
        ]
        electronScanProc.running = true
      } catch (e) { root.__cmdSetClear() }
    }
    Component.onCompleted: { if (running) Qt.callLater(() => onTriggered()) }
  }
  Process {
    id: cmdScanProc
    running: false
    stdout: SplitParser {
      onRead: (data) => {
        try {
          const txt = String(data || "")
          const lines = txt.split(/\r?\n/)
          for (let i=0;i<lines.length;i++) {
            const s = lines[i].trim(); if (!s) continue
            const m = s.match(/^(RUN|OFF):(.*)$/)
            if (!m) continue
            const isRun = (m[1] === 'RUN')
            const tok = (m[2] || '').trim()
            root.__cmdSetPut(tok, isRun)
          }
        } catch (e) {}
      }
    }
  }
  // When the window becomes visible or dimensions become valid, bump layout once more
  onVisibleChanged: if (visible) { __layoutEpoch++; Qt.callLater(function(){ __layoutEpoch++ }) }
  onWidthChanged:  if (width  > 0) { __layoutEpoch++ }
  onHeightChanged: if (height > 0) { __layoutEpoch++ }
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

  // Compositor-based running detection (prefer this over process scanning)
  readonly property bool isHyprland: Utils.CompositorUtils.isHyprland
  readonly property bool isNiri: !isHyprland
  // Lowercased set of running app identifiers (class/name/title substrings)
  property var __runningAppSet: ({})
  function __setAdd(v) { try { if (!v) return; const s = String(v).toLowerCase(); if (!__runningAppSet[s]) __runningAppSet[s] = true } catch (e) {} }
  function __clearSet() { __runningAppSet = ({}) }
  function __anyRunningMatch(token) {
    try {
      const t = String(token||"").toLowerCase(); if (!t) return false
      // Fast exact hit
      if (__runningAppSet[t]) return true
      // Fallback: substring match across keys
      const keys = Object.keys(__runningAppSet)
      for (let i=0;i<keys.length;i++) { if (keys[i].indexOf(t) >= 0 || t.indexOf(keys[i]) >= 0) return true }
      return false
    } catch (e) { return false }
  }
  function __tokensFromCmd(cmd) {
    try {
      const out = []
      const s = String(cmd||"").trim(); if (!s) return out
      const parts = s.split(/\s+/)
      let tok = ""
      for (let i=0;i<parts.length;i++) {
        const p = parts[i]
        if (!p) continue
        if (p.indexOf("=") >= 0 && p.indexOf("/") < 0) continue
        if (p.startsWith("-")) continue
        tok = p; break
      }
      if (!tok) tok = parts[0] || ""
      const base = (tok.lastIndexOf('/') >= 0) ? tok.substring(tok.lastIndexOf('/')+1) : tok
      const b = base.toLowerCase()
      if (b) out.push(b)
      // alternates: strip hyphens, strip common suffixes
      const noDash = b.replace(/-/g, "")
      if (noDash && out.indexOf(noDash) < 0) out.push(noDash)
      if (b.endsWith("-browser")) {
        const alt = b.replace(/-browser$/, "")
        if (out.indexOf(alt) < 0) out.push(alt)
        // Known packaging: zen-browser binary is zen-bin
        if (b === "zen-browser" && out.indexOf("zen-bin") < 0) out.push("zen-bin")
      }
      // Known app: windsurf runs under electron
      if (b === "windsurf") { if (out.indexOf("windsurf") < 0) out.push("windsurf") }
      return out
    } catch (e) { return [] }
  }

  // Periodically refresh running windows list via compositor
  Timer {
    id: runningRefresh
    interval: 1000
    repeat: true
    running: Globals.showDockRunningIndicator
    onTriggered: {
      if (root.isHyprland) {
        hyprWinProc.command = ["bash","-lc","hyprctl clients -j 2>/dev/null || true"]
        hyprWinProc.running = true
      } else {
        niriWinProc.command = ["bash","-lc","niri msg -j windows 2>/dev/null || true"]
        niriWinProc.running = true
      }
    }
    Component.onCompleted: { if (running) Qt.callLater(() => onTriggered()) }
  }
  Process {
    id: hyprWinProc
    running: false
    stdout: SplitParser { onRead: (data) => { hyprBuf += String(data) } }
    property string hyprBuf: ""
    onRunningChanged: if (!running) {
      try {
        const txt = String(hyprBuf||"").trim(); hyprBuf = ""; root.__clearSet()
        if (txt) {
          const arr = JSON.parse(txt)
          for (let i=0;i<arr.length;i++) {
            const c = arr[i] || {}
            root.__setAdd(c.class||c.app||"")
            root.__setAdd(c.title||"")
          }
        }
      } catch (e) { root.__clearSet() }
    }
  }
  Process {
    id: niriWinProc
    running: false
    stdout: SplitParser { onRead: (data) => { niriBuf += String(data) } }
    property string niriBuf: ""
    onRunningChanged: if (!running) {
      try {
        const txt = String(niriBuf||"").trim(); niriBuf = ""; root.__clearSet()
        if (txt && txt[0] === '[') {
          const arr = JSON.parse(txt)
          for (let i=0;i<arr.length;i++) {
            const w = arr[i] || {}
            root.__setAdd(w.app_id || w.class || "")
            root.__setAdd(w.title || w.name || "")
          }
        }
      } catch (e) { root.__clearSet() }
    }
  }

  // Force layout recalculation when dock items change (prevents temporary distortion
  // until the next hover/expand). We bump an epoch counter and reference it in
  // geometry bindings to ensure re-evaluation on add/remove.
  property int __layoutEpoch: 0
  // Normalize vertical position: treat 'center' as 'top' (option removed)
  property string __vPos: (Globals.dockPositionVertical === "center" ? "top" : Globals.dockPositionVertical)
  // Short burst timers to re-bump layout after rapid sequences of changes
  Timer { id: __layoutBurstA; interval: 30; repeat: false; onTriggered: root.__layoutEpoch++ }
  Timer { id: __layoutBurstB; interval: 180; repeat: false; onTriggered: root.__layoutEpoch++ }
  Timer { id: __layoutBurstC; interval: 350; repeat: false; onTriggered: root.__layoutEpoch++ }
  // Timer to re-anchor to bottom after item deletions settle (bottom mode only)
  Timer { id: __bottomAnchorFix; interval: 100; repeat: false; onTriggered: { 
    if (root.__vPos === "bottom") {
      root.__updateCachedContentHeight();
      root.__layoutEpoch++;
      // Force immediate re-evaluation of contentY binding
      Qt.callLater(function() { root.__layoutEpoch++ });
    }
  } }
  // Additional timer for visual stability after item changes
  Timer { id: __visualStabilizer; interval: 150; repeat: false; onTriggered: { root.__updateCachedContentHeight(); root.__layoutEpoch++ } }
  // Force immediate geometry update on mouse enter to fix visual glitches
  function forceLayoutRefresh() {
    root.__updateCachedContentHeight()
    root.__layoutEpoch++
    Qt.callLater(function() { root.__layoutEpoch++ })
  }
  Connections {
    target: Globals
    function onDockItemsChanged() {
      // Update cached height first, then bump layout
      root.__updateCachedContentHeight()
      __layoutEpoch++
      Qt.callLater(function() { __layoutEpoch++ })
      // If there is a rapid burst of changes, re-bump shortly after to ensure final geometry
      __layoutBurstA.restart(); __layoutBurstB.restart(); __layoutBurstC.restart()
    }
    function onShowDockChanged() { __layoutEpoch++; Qt.callLater(function(){ __layoutEpoch++ }) }
    function onDockIconSizePxChanged() { 
      root.__updateCachedContentHeight()
      __layoutEpoch++; 
      Qt.callLater(function(){ __layoutEpoch++ }) 
    }
    function onDockIconSpacingChanged() { 
      root.__updateCachedContentHeight()
      __layoutEpoch++ 
    }
    function onDockPositionVerticalChanged() {
      __layoutEpoch++
      root.__vPos = (Globals.dockPositionVertical === "center" ? "top" : Globals.dockPositionVertical)
      // Force complete reset when switching to bottom mode
      root.__updateCachedContentHeight()
      Qt.callLater(function() { 
        root.__updateCachedContentHeight();
        root.__layoutEpoch++;
        if (root.__vPos === "bottom") {
          // Multiple correction cycles for bottom mode
          __bottomAnchorFix.restart();
          Qt.callLater(function() { __bottomAnchorFix.restart(); });
        }
      });
    }
    function onDockPositionHorizontalChanged() { __layoutEpoch++ }
  }

  // Autohide mode
  property bool __autoHide: Globals.dockLayerPosition === "autohide"
  property bool __expanded: false
  // While collapsing, keep content visible for fade/size animation
  property bool __collapsing: false
  // Expected height from model count to avoid initial squashing before delegates settle
  function __dockCount() { return (Array.isArray(Globals.dockItems) ? Globals.dockItems.length : 0) }
  // Cache the expected content height to avoid excessive recalculations
  property int __cachedContentHeight: 0
  function __updateCachedContentHeight() {
    const n = __dockCount()
    const h = Math.max(0, n) * Math.max(1, Globals.dockIconSizePx)
    const gaps = Math.max(0, n - 1) * Math.max(0, Globals.dockIconSpacing)
    __cachedContentHeight = h + gaps
    console.log("[Dock] updateCachedContentHeight: items=" + n + " iconSize=" + Globals.dockIconSizePx + " spacing=" + Globals.dockIconSpacing + " total=" + __cachedContentHeight)
    console.log("[Dock] window height=" + root.height + " implicitHeight=" + root.implicitHeight + " flick.height=" + flick.height + " vPos=" + root.__vPos)
  }
  function __expectedContentHeight() {
    return __cachedContentHeight
  }
  // Visibility
  visible: Globals.showDock && Array.isArray(Globals.dockItems)

  // Geometry/Anchors per config (screen is set by instantiator)
  anchors {
    top: root.__vPos === "top"
    bottom: root.__vPos === "bottom"
    left: Globals.dockPositionHorizontal === "left"
    right: Globals.dockPositionHorizontal === "right"
  }
  // Size follows content to avoid clipping when anchored only to top/bottom
  // When autohide is active and not expanded, keep a 1px invisible trigger strip via implicitWidth
  implicitWidth: (__autoHide && !__expanded)
                  ? 1
                  : (Math.max(Globals.dockIconSizePx + 16, 56) + 0*root.__layoutEpoch)
  // Use expected content height for stable sizing during transitions
  // Add extra safety margin for bottom mode to prevent complete disappearance
  implicitHeight: Math.max(__expectedContentHeight() + 16, 32) + 0*root.__layoutEpoch

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

  // Timer to end collapsing state after in-duration (collapse) so visibility doesn't cut the fade
  Timer {
    id: collapseDone
    interval: Globals.dockAutoHideInDurationMs
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
        // Use Out-duration when expanding (show), In-duration when collapsing (hide)
        duration: root.__expanded ? Globals.dockAutoHideOutDurationMs : Globals.dockAutoHideInDurationMs
        easing.type: Easing.OutQuad
      }
    }
    contentWidth: width
    // Use expected content height for stable scrolling with safety minimum
    contentHeight: Math.max(root.__expectedContentHeight(), 32) + 0*root.__layoutEpoch
    // Keep viewport aligned to show all content properly
    contentY: (root.__vPos === "bottom")
                ? Math.max(0, flick.contentHeight - flick.height + 0*root.__layoutEpoch)
                : 0
    interactive: false

    // Content frame to precisely scope hover detection to the visible dock area
    Item {
      id: contentFrame
      anchors.left: parent.left
      anchors.right: parent.right
      // Position content frame at the correct location within the scrollable area
      y: (root.__vPos === "bottom") 
          ? Math.max(0, flick.contentHeight - Math.max(root.__expectedContentHeight(), 32))
          : 0
      anchors.margins: 0
      // Fixed width to match column width
      width: Math.max(Globals.dockIconSizePx + 16, 56)
      // Use expected content height for stable sizing during item changes with safety minimum
      height: Math.max(root.__expectedContentHeight(), 32) + 0*root.__layoutEpoch

      Column {
        id: col
        x: 0
        // Fixed width to prevent layout races
        width: Math.max(Globals.dockIconSizePx + 16, 56)
        spacing: Globals.dockIconSpacing
        anchors.margins: (root.__autoHide && !root.__expanded) ? 0 : 8
        Component.onCompleted: { root.__layoutEpoch++; __layoutBurstA.restart(); __layoutBurstB.restart(); __layoutBurstC.restart() }

        Repeater {
        id: reps
        // Use a sliced copy so the model instance changes on each mutation,
        // forcing a full delegate rebuild and avoiding transient distortion
        model: (Array.isArray(Globals.dockItems) ? Globals.dockItems.slice(0) : [])
        onCountChanged: { root.__layoutEpoch++; __layoutBurstA.restart(); __layoutBurstB.restart(); __layoutBurstC.restart() }
        onItemAdded: (item, index) => { 
          // Update cache immediately when items change
          root.__updateCachedContentHeight();
          root.__layoutEpoch++; 
          __layoutBurstA.restart(); 
          __layoutBurstB.restart(); 
          __layoutBurstC.restart();
          // Extra stabilization for visual consistency
          __visualStabilizer.restart();
          // Force immediate refresh to prevent visual glitches
          Qt.callLater(root.forceLayoutRefresh);
        }
        onItemRemoved: (index, item) => { 
          // Update cache immediately when items change
          root.__updateCachedContentHeight();
          root.__layoutEpoch++; 
          __layoutBurstA.restart(); 
          __layoutBurstB.restart(); 
          __layoutBurstC.restart();
          // Re-anchor to bottom after removal settles (critical for bottom mode)
          __bottomAnchorFix.restart();
          // Extra stabilization for visual consistency
          __visualStabilizer.restart();
          // Force immediate refresh to prevent visual glitches
          Qt.callLater(root.forceLayoutRefresh);
          // Additional bottom anchor fix for problematic deletions
          if (root.__vPos === "bottom") {
            Qt.callLater(function() { __bottomAnchorFix.restart(); });
          }
        }
        delegate: Item {
          id: delegateRoot
          // Fixed sizes to prevent layout races and visual glitches
          width: Math.max(Globals.dockIconSizePx + 16, 56)
          height: Globals.dockIconSizePx
          property int myIndex: index
          // drag state helpers
          property real pressX: 0
          property real pressY: 0
          property bool didDrag: false
          // Fallback hover tracker at delegate level (helps in autohide right after expand)
          HoverHandler { id: hoverDelegate }

          Rectangle {
            id: iconRect
            anchors.fill: parent
            radius: Globals.dockIconRadius
            color: Globals.dockIconBGColor
            border.width: Math.max(0, Globals.dockIconBorderPx)
            border.color: Globals.dockIconBorderColor
            anchors.horizontalCenter: parent.horizontalCenter
            // Track hover independent of MouseArea enabled state (helps in autohide)
            HoverHandler { id: hoverHandler }

            // Small running indicator (bottom-right) when item's command has a running process
            // Toggle visibility globally via Globals.showDockRunningIndicator
            Rectangle {
              id: runningDot
              width: 10; height: 10
              radius: 5
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.leftMargin: 5
              anchors.topMargin: 5
              color: (Globals.barBorderColor && Globals.barBorderColor.length) ? Globals.barBorderColor : Globals.dockIconBorderColor
              // Show only when enabled and a matching process is detected
              visible: Globals.showDockRunningIndicator && (__runningState === "RUN")
              border.width: 1
              border.color: Globals.dockIconBGColor
              z: 10
              property string __runningState: "OFF"
              // Build a robust match pattern from cmd when processPattern is not provided
              function __derivePattern(cmd) {
                try {
                  const s = String(cmd||"").trim()
                  if (!s.length) return ""
                  const parts = s.split(/\s+/)
                  // pick first token that is not VAR= and not a dash-flag
                  let tok = ""
                  for (let i=0;i<parts.length;i++) {
                    const p = parts[i]
                    if (!p) continue
                    if (p.indexOf("=") >= 0 && p.indexOf("/") < 0) continue
                    if (p.startsWith("-")) continue
                    tok = p; break
                  }
                  if (!tok.length) tok = parts[0] || ""
                  const base = tok.lastIndexOf('/') >= 0 ? tok.substring(tok.lastIndexOf('/')+1) : tok
                  // Escape regex special chars and wrap in word boundaries
                  const esc = base.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
                  return esc.length ? "\\b" + esc + "\\b" : ""
                } catch (e) { return "" }
              }
              // Debounce to avoid flicker: keep RUN for a grace window after last detection
              property double __lastRunMs: 0
              property int __graceMs: 1000
              // Additional hysteresis: require several consecutive misses before turning OFF
              property int __missCount: 0
              property int __missThreshold: 1
              function checkNow() {
                try {
                  const toks = root.__tokensFromCmd(modelData && modelData.cmd)
                  const byCompositor = (toks.length && root.__anyRunningMatch(toks[0]))
                  const byPs = (toks.length && root.__cmdAnyRunning(toks))
                  const byElectron = (toks.indexOf("windsurf") >= 0) && root.__electronHasWindsurf
                  if (byCompositor || byPs || byElectron) {
                    runningDot.__lastRunMs = Date.now()
                    runningDot.__missCount = 0
                    runningDot.__runningState = "RUN"
                  } else {
                    const age = Date.now() - runningDot.__lastRunMs
                    if (age < runningDot.__graceMs) {
                      runningDot.__runningState = "RUN"
                    } else {
                      runningDot.__missCount++
                      runningDot.__runningState = (runningDot.__missCount >= runningDot.__missThreshold) ? "OFF" : "RUN"
                    }
                  }
                } catch (e) { runningDot.__runningState = "OFF" }
              }
              // Poll occasionally; cheap and isolated per delegate
              Timer {
                id: runPoll
                interval: 900
                repeat: true
                running: Globals.showDockRunningIndicator
                onTriggered: {
                  runningDot.checkNow()
                }
                Component.onCompleted: {
                  if (Globals.showDockRunningIndicator) {
                    running = true
                    // Fire an immediate check so the dot appears without waiting for the first interval
                    runningDot.checkNow()
                  }
                }
              }
              // Removed per-delegate ps/pgrep polling to avoid flicker—use global scanners instead
              Connections {
                target: Globals
                function onShowDockRunningIndicatorChanged() {
                  runPoll.running = Globals.showDockRunningIndicator
                  cmdScanTimer.running = (Globals.showDock && Globals.showDockRunningIndicator)
                  if (runPoll.running) runningDot.checkNow()
                }
              }
              // No per-delegate processes needed; compositor tracker updates run globally
            }

            // Optional centered PNG icon
            Image {
              anchors.centerIn: parent
              anchors.verticalCenterOffset: (!Globals.dockIconLabel)
                                              ? 0
                                              : ((modelData && modelData.iconOffsetYPx !== undefined)
                                                  ? Number(modelData.iconOffsetYPx)
                                                  : -Math.floor(parent.height * 0.12))
              visible: !!(modelData && modelData.icon)
              source: root.resolveIconPath(modelData && modelData.icon ? modelData.icon : "")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              smooth: true
              readonly property real __ratio: (!Globals.dockIconLabel)
                                               ? 0.55
                                               : ((modelData && modelData.iconSizeRatio !== undefined)
                                                   ? Math.max(0.1, Math.min(1.0, Number(modelData.iconSizeRatio)))
                                                   : 0.55)
              width: Math.floor(parent.width * __ratio)
              height: Math.floor(parent.height * __ratio)
            }

            // Hover highlight overlay
            Rectangle {
              anchors.fill: parent
              radius: iconRect.radius
              color: (Globals.barBorderColor && Globals.barBorderColor.length) ? Globals.barBorderColor : Globals.dockIconBorderColor
              opacity: (((!root.__autoHide) || root.__expanded) && (hoverHandler.hovered || hoverDelegate.hovered || dragArea.containsMouse)) ? 0.20 : 0.0
              visible: opacity > 0
              z: 5
              border.width: 0
              Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
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
              style: Text.Normal
              styleColor: "#A0000000"
            }
          }
        }
        }

        }

      // Hover watcher for autohide using HoverHandler (does not block child hover)
      HoverHandler {
        id: expandedHover
        enabled: root.__autoHide && root.__expanded
        onHoveredChanged: {
          if (hovered) {
            hideTimer.stop();
            collapseDone.stop();
            root.__collapsing = false;
            // Force layout refresh on hover to fix visual glitches
            root.forceLayoutRefresh();
          } else {
            hideTimer.restart();
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

    // (expanded hover watcher moved into contentFrame to avoid full-window capture in center mode)
  }

  // Trigger area when collapsed: expand on hover
  MouseArea {
    anchors.fill: parent
    visible: root.__autoHide && !root.__expanded
    enabled: visible
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: { 
      root.__expanded = true; 
      hideTimer.stop(); 
      collapseDone.stop(); 
      root.__collapsing = false;
      // Force layout refresh on expand to fix visual glitches
      root.forceLayoutRefresh();
    }
  }

  // Subtle animation for expand/collapse using implicitWidth
  Behavior on implicitWidth {
    NumberAnimation {
      // Use Out-duration when expanding (show), In-duration when collapsing (hide)
      duration: root.__expanded ? Globals.dockAutoHideOutDurationMs : Globals.dockAutoHideInDurationMs
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
