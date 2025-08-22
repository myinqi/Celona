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
        }
    }
}
