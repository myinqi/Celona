pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../utils" as Utils

// Compositor-agnostic workspace provider for Hyprland and Niri.
// Exposes a uniform API:
//  - property var workspaces: Array of { id: int, active: bool }
//  - function switchWorkspace(id: int)
//
// Hyprland backend: delegates to Utils.HyprlandUtils
// Niri backend: uses `niri msg` CLI (workspaces, focused-output, action focus-workspace)
//
// Detection: Hyprland if HYPRLAND_INSTANCE_SIGNATURE is set; otherwise treat as Niri.
Singleton {
  id: comp

  // Public API
  property var workspaces: []
  property string activeTitle: "Desktop"

  function switchWorkspace(w) {
    if (comp.isHyprland) {
      Utils.HyprlandUtils.switchWorkspace(w)
    } else {
      // Niri: focus by index on the current output
      niriActionProc.command = ["bash", "-lc", `niri msg action focus-workspace ${w}`]
      niriActionProc.running = true
      // Short refresh after switching
      niriRefreshTimer.restart()
    }
  }

  // --- Backend detection ---
  readonly property bool isHyprland: _hyprSig && _hyprSig.length > 0
  readonly property bool isNiri: !isHyprland
  property string _hyprSig: ""

  // One-shot: read HYPRLAND_INSTANCE_SIGNATURE from environment
  Process {
    id: detectHyprProc
    command: ["bash", "-lc", "printf %s \"$HYPRLAND_INSTANCE_SIGNATURE\""]
    running: true
    stdout: SplitParser {
      onRead: (data) => { comp._hyprSig += String(data) }
    }
  }

  // Keep Hyprland workspaces synced when on Hyprland
  Connections {
    target: Utils.HyprlandUtils
    enabled: comp.isHyprland
    function onWorkspacesChanged() {
      comp.workspaces = (Utils.HyprlandUtils.workspaces || []).map(ws => ({ id: ws.id, active: ws.active }))
    }
    function onActiveTitleChanged() {
      comp.activeTitle = Utils.HyprlandUtils.activeTitle || "Desktop"
    }
  }

  // Initialize Hyprland state
  Timer {
    interval: 250
    running: comp.isHyprland
    repeat: false
    onTriggered: {
      comp.workspaces = (Utils.HyprlandUtils.workspaces || []).map(ws => ({ id: ws.id, active: ws.active }))
      comp.activeTitle = Utils.HyprlandUtils.activeTitle || "Desktop"
    }
  }

  // --- Niri backend (CLI polling) ---
  // Focused output name (e.g., DP-3)
  property string _niriFocusedOutput: ""
  property string _niriWorkspacesRaw: ""
  property string _niriFocusedWindowJson: ""
  // Event-stream availability
  property bool _niriEventsActive: false

  // Poll timer
  Timer {
    id: niriPoll
    interval: 800
    repeat: true
    running: comp.isNiri && !comp._niriEventsActive
    onTriggered: {
      // Fetch focused output and workspace list
      niriFocusedOutProc.command = ["bash", "-lc", "niri msg focused-output"]
      _niriFocusedOutput = ""
      niriFocusedOutProc.running = true

      niriWorkspacesProc.command = ["bash", "-lc", "niri msg workspaces"]
      _niriWorkspacesRaw = ""
      niriWorkspacesProc.running = true

      // Focused window as JSON for title
      niriFocusedWinProc.command = ["bash", "-lc", "niri msg -j focused-window"]
      _niriFocusedWindowJson = ""
      niriFocusedWinProc.running = true
    }
  }

  // Short refresh after actions
  Timer {
    id: niriRefreshTimer
    interval: 150
    repeat: false
    onTriggered: {
      // Actively re-run the same queries as in the poll timer
      niriFocusedOutProc.command = ["bash", "-lc", "niri msg focused-output"]
      _niriFocusedOutput = ""
      niriFocusedOutProc.running = true

      niriWorkspacesProc.command = ["bash", "-lc", "niri msg workspaces"]
      _niriWorkspacesRaw = ""
      niriWorkspacesProc.running = true
    }
  }

  Process {
    id: niriFocusedOutProc
    running: false
    stdout: SplitParser {
      onRead: (data) => { comp._niriFocusedOutput += String(data) }
    }
    onRunningChanged: if (!running) {
      // Parse output name from text like: Output "DP-3": ...
      try {
        const m = comp._niriFocusedOutput.match(/Output\s+\"([^\"]+)\"/)
        comp._niriFocusedOutput = m ? m[1] : comp._niriFocusedOutput.trim()
      } catch (e) { /* noop */ }
      comp._rebuildNiriWorkspaces()
    }
  }

  Process {
    id: niriWorkspacesProc
    running: false
    stdout: SplitParser { onRead: (data) => { comp._niriWorkspacesRaw += String(data) } }
    onRunningChanged: if (!running) comp._rebuildNiriWorkspaces()
  }

  Process { id: niriActionProc; running: false }

  Process {
    id: niriFocusedWinProc
    running: false
    stdout: SplitParser { onRead: (data) => { comp._niriFocusedWindowJson += String(data) } }
    onRunningChanged: if (!running) {
      try {
        const txt = comp._niriFocusedWindowJson && comp._niriFocusedWindowJson.trim()
        if (txt && txt[0] === '{') {
          const obj = JSON.parse(txt)
          const title = obj && (obj.title || obj.name)
          if (title && typeof title === 'string') comp.activeTitle = title
          else comp.activeTitle = "Desktop"
        } else {
          // If not JSON (older versions), fallback to plain parsing: first line
          const first = (comp._niriFocusedWindowJson || "").split(/\r?\n/)[0]
          comp.activeTitle = first && first.length ? first : "Desktop"
        }
      } catch (e) {
        comp.activeTitle = "Desktop"
      }
    }
  }

  // --- Niri event stream (debounced refresh) ---
  // Start the event stream shortly after load if on Niri
  Timer {
    id: niriStartEvents
    interval: 300
    repeat: false
    running: comp.isNiri
    onTriggered: {
      niriEventsProc.command = ["bash", "-lc", "niri msg -j event-stream"]
      niriEventsProc.running = true
    }
  }

  // Debounce timer to coalesce many events into one refresh
  Timer {
    id: niriEventDebounce
    interval: 120
    repeat: false
    onTriggered: {
      // Same queries as polling
      niriFocusedOutProc.command = ["bash", "-lc", "niri msg focused-output"]
      _niriFocusedOutput = ""
      niriFocusedOutProc.running = true

      niriWorkspacesProc.command = ["bash", "-lc", "niri msg workspaces"]
      _niriWorkspacesRaw = ""
      niriWorkspacesProc.running = true

      niriFocusedWinProc.command = ["bash", "-lc", "niri msg -j focused-window"]
      _niriFocusedWindowJson = ""
      niriFocusedWinProc.running = true
    }
  }

  // Long-running event stream process
  Process {
    id: niriEventsProc
    running: false
    stdout: SplitParser {
      // We don't rely on event schema; any event triggers a debounced refresh
      onRead: (data) => {
        // If any data arrives, consider events active and debounce a refresh
        comp._niriEventsActive = true
        if (!niriEventDebounce.running) niriEventDebounce.start()
      }
    }
    onRunningChanged: {
      if (running) {
        comp._niriEventsActive = true
      } else {
        // Event stream ended; fall back to polling and attempt restart
        comp._niriEventsActive = false
        if (!niriPoll.running) niriPoll.start()
        // Try to restart after a short delay
        niriStartEvents.restart()
      }
    }
  }

  function _rebuildNiriWorkspaces() {
    if (!comp.isNiri) return
    if (!_niriWorkspacesRaw || !_niriWorkspacesRaw.length) return

    const text = String(_niriWorkspacesRaw)
    const selectedOut = _niriFocusedOutput || ""
    let list = []

    // Try to extract the block of the focused output (works with or without newlines)
    // Regex captures from 'Output "NAME":' up to the next 'Output "' or end
    let block = ""
    if (selectedOut) {
      const re = new RegExp("Output\\s+\\\"" + selectedOut.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&') + "\\\":\\s*([\\s\\S]*?)(?=^Output\\s+\\\"|$)", "m")
      const m = text.match(re)
      if (m && m[1] !== undefined) block = m[1]
    }
    // If not found, fall back to the first output's block
    if (!block) {
      const m2 = text.match(/Output\s+\"([^\"]+)\":\s*([\s\S]*?)(?=^Output\s+\"|$)/m)
      if (m2 && m2[2] !== undefined) block = m2[2]
    }

    // Extract entries of the form '* 1' or '2' possibly separated by spaces or newlines
    if (block) {
      const entryRe = /(\*)?\s*(\d+)/g
      let em
      while ((em = entryRe.exec(block)) !== null) {
        const isActive = !!em[1]
        const id = parseInt(em[2], 10)
        if (!isNaN(id)) list.push({ id, active: isActive })
      }
    }

    comp.workspaces = list
  }
}
