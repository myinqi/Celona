pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: hyprland

    // Detect Hyprland availability once
    property string _hyprSig: ""
    readonly property bool isAvailable: _hyprSig && _hyprSig.length > 0

    Process {
        id: detectHypr
        command: ["bash", "-lc", "printf %s \"$HYPRLAND_INSTANCE_SIGNATURE\""]
        running: true
        stdout: SplitParser { onRead: (data) => { hyprland._hyprSig += String(data) } }
    }

    // Expose sorted workspaces only when Hyprland is available
    property var workspaces: isAvailable ? sortWorkspaces(Hyprland.workspaces.values) : []
    property int maxWorkspace: findMaxId()
    // Active window title (defaults to "Desktop")
    property string activeTitle: (isAvailable && Hyprland.activeToplevel) ? (Hyprland.activeToplevel.title || "Desktop") : "Desktop"
    // Active workspace id (updates via Hyprland.activeWorkspace and raw events)
    property int activeWorkspaceId: 1
    // Buffer for hyprctl JSON
    property string _activeWsJson: ""

    function _updateActiveWorkspace() {
        try {
            if (isAvailable && Hyprland.activeWorkspace && typeof Hyprland.activeWorkspace.id === 'number') {
                activeWorkspaceId = Hyprland.activeWorkspace.id
                return
            }
        } catch (e) { /* noop */ }
        // Fallback: if list exists, pick the one marked active or default to 1
        try {
            const ws = (hyprland.workspaces || [])
            const found = ws.find(w => w && w.active)
            if (found && typeof found.id === 'number') {
                activeWorkspaceId = found.id
                return
            }
        } catch (e2) { activeWorkspaceId = 1 }
        // As a final resort, ask hyprctl for the active workspace (Hyprland must be present)
        if (hyprland.isAvailable) {
            hyprland._queryActiveWorkspace()
        }
    }

    function _queryActiveWorkspace() {
        try {
            hyprland._activeWsJson = ""
            hyprActiveWsProc.command = ["bash","-lc","command -v hyprctl >/dev/null 2>&1 && hyprctl -j activeworkspace || true"]
            hyprActiveWsProc.running = true
        } catch (e) { /* noop */ }
    }

    function sortWorkspaces(ws) {
        return [...ws].sort((a, b) => a?.id - b?.id)
    }

    function switchWorkspace(w: int): void {
        if (isAvailable) Hyprland.dispatch(`workspace ${w}`)
    }

    function findMaxId(): int {
        if (!isAvailable || hyprland.workspaces.length === 0) return 1
        let num = hyprland.workspaces.length
        let maxId = hyprland.workspaces[num - 1]?.id || 1
        return maxId
    }

    Connections {
        target: Hyprland
        enabled: hyprland.isAvailable
        function onRawEvent(event) {
            let eventName = event.name
            switch (eventName) {
            case "createworkspacev2":
                {
                    hyprland.workspaces = hyprland.sortWorkspaces(Hyprland.workspaces.values)
                    hyprland.maxWorkspace = findMaxId()
                }
            case "destroyworkspacev2":
                {
                    hyprland.workspaces = hyprland.sortWorkspaces(Hyprland.workspaces.values)
                    hyprland.maxWorkspace = findMaxId()
                }
            }
            // Keep active workspace id in sync for all events
            hyprland._updateActiveWorkspace()
        }
        function onActiveWorkspaceChanged() { hyprland._updateActiveWorkspace() }
    }

    // Initialize active workspace shortly after start
    Timer {
        interval: 200
        running: hyprland.isAvailable
        repeat: false
        onTriggered: hyprland._updateActiveWorkspace()
    }

    // Process to query hyprctl -j activeworkspace as a fallback
    Process {
        id: hyprActiveWsProc
        running: false
        stdout: SplitParser { onRead: (data) => { hyprland._activeWsJson += String(data) } }
        onRunningChanged: if (!running) {
            try {
                const t = (hyprland._activeWsJson || '').trim()
                if (t && t[0] === '{') {
                    const obj = JSON.parse(t)
                    if (obj && typeof obj.id === 'number') {
                        hyprland.activeWorkspaceId = obj.id
                    }
                }
            } catch (e) { /* noop */ }
        }
    }
}
