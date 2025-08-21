import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../"
import "root:/"

BarBlock {
    id: root
    // Parsed model shaped like: { children: [ { children: [ { name, keybinds: [ {mods:[], key:"", comment:""} ] } ] } ] }
    property var keybinds: ({ children: [ { children: [] } ] })
    property real spacing: 20
    property real titleSpacing: 7

    // Inline bar UI: keyboard icon
    content: BarText {
        id: label
        mainFont: "JetBrains Mono Nerd Font"
        symbolFont: "Symbols Nerd Font Mono"
        symbolText: "" // keyboard icon
        symbolSpacing: 0
    }

    property var keyBlacklist: ["Super_L"]
    property var keySubstitutions: ({
        "Super": "󰖳",
        "mouse_up": "Scroll ↓",    
        "mouse_down": "Scroll ↑",  
        "mouse:272": "LMB",
        "mouse:273": "RMB",
        "mouse:275": "MouseBack",
        "Slash": "/",
        "Hash": "#",
        "Return": "Enter",
        // "Shift": "",
    })

    // --- Read and parse Hyprland keybinds file ---
    property string bindsPath: "~/.config/hypr/conf/keybindings/khrom.conf"

    function parseHyprBinds(text) {
        // Heuristic parser for Hyprland bind lines.
        // Group by preceding comment lines starting with '# '
        const lines = String(text || "").split(/\n/)
        const sections = []
        let current = { name: "General", keybinds: [] }
        const pushSection = () => { if (current.keybinds.length) sections.push(current) }
        for (let raw of lines) {
            const line = raw.trim()
            if (!line) continue
            if (line.startsWith("#")) {
                const body = line.replace(/^#+\s*/, "").trim()
                // Skip commented-out bind lines like: "#bind = ..." or "# bind = ..."
                if (/^bind[\w]*\s*=/.test(body)) continue
                const name = body
                if (name.length) {
                    // start new section
                    pushSection()
                    current = { name: name, keybinds: [] }
                }
                continue
            }
            // match bind*, unbind not included
            // Examples: bind=SUPERSHIFT, R, exec rofi # Launch Rofi
            const m = line.match(/^bind[a-zA-Z0-9_]*\s*=\s*([^,]+),\s*([^,]+),\s*(.*)$/)
            if (!m) continue
            const modsRaw = m[1].trim()
            const key = m[2].trim()
            let cmdAndCmt = m[3].trim()
            let comment = ""
            // Allow trailing comment after # or //
            const hashIdx = cmdAndCmt.indexOf("#")
            const slIdx = cmdAndCmt.indexOf("//")
            let cut = -1
            if (hashIdx >= 0 && slIdx >= 0) cut = Math.min(hashIdx, slIdx)
            else cut = (hashIdx >= 0 ? hashIdx : slIdx)
            if (cut >= 0) {
                comment = cmdAndCmt.slice(cut + (cmdAndCmt[cut] === '#' ? 1 : 2)).trim()
                cmdAndCmt = cmdAndCmt.slice(0, cut).trim()
            }
            if (!comment) comment = cmdAndCmt
            // split mods by + or space or |
            const mods = modsRaw.split(/[+\s|]+/).filter(s => !!s)
            current.keybinds.push({ mods: mods, key: key, comment: comment })
        }
        pushSection()
        return { children: [ { children: sections } ] }
    }

    // Process to read file
    property string bindsBuf: ""
    // Track last known modification time to auto-refresh on change
    property int bindsMtime: -1
    
    // Reconfigure commands when path changes
    function _updateCommands() {
        const p = String(Globals.keybindsPath || "").trim()
        if (p.length === 0) return
        const esc = p.replace(/\\/g, "\\\\").replace(/"/g, '\\"')
        const buildCat = "p=\"" + esc + "\"; p=${p/#~/$HOME}; if [[ \"$p\" != /* ]]; then p=\"$HOME/$p\"; fi; cat \"$p\""
        const buildStat = "p=\"" + esc + "\"; p=${p/#~/$HOME}; if [[ \"$p\" != /* ]]; then p=\"$HOME/$p\"; fi; stat -c %Y \"$p\" 2>/dev/null || echo 0"
        bindsProc.command = ["bash", "-lc", buildCat]
        mtimeProc.command = ["bash", "-lc", buildStat]
    }
    function _reconfigure() {
        const p = String(Globals.keybindsPath || "").trim()
        if (p.length === 0) {
            // Stop watchers and clear data
            if (bindsProc.running) bindsProc.running = false
            if (mtimeProc.running) mtimeProc.running = false
            bindsBuf = ""
            keybinds = { children: [ { children: [] } ] }
            return
        }
        _updateCommands()
        bindsBuf = ""
        if (bindsProc.running) bindsProc.running = false
        Qt.callLater(() => bindsProc.running = true)
        bindsMtime = -1
    }

    // Extract just the filename part for display
    function _baseName(p) {
        if (!p) return ""
        let s = String(p).trim()
        if (!s.length) return ""
        // Remove trailing slashes
        while (s.length > 1 && s.endsWith("/")) s = s.slice(0, -1)
        const parts = s.split("/")
        return parts.length ? parts[parts.length - 1] : s
    }
    Process {
        id: bindsProc
        command: ["bash", "-lc", "true"] // set dynamically from keybindsPath
        running: true
        stdout: SplitParser {
            onRead: data => { root.bindsBuf += String(data) + "\n" }
        }
        onRunningChanged: {
            if (!running) {
                try {
                    root.keybinds = parseHyprBinds(String(root.bindsBuf))
                } catch (e) { console.log("InfoKeybinds parse error:", e) }
                root.bindsBuf = ""
            }
        }
    }

    // Poll file modification time periodically and refresh when it changes
    Process {
        id: mtimeProc
        running: false
        command: ["bash", "-lc", "echo 0"] // set dynamically from keybindsPath
        property int _latest: -1
        stdout: SplitParser {
            onRead: data => {
                const s = String(data).trim()
                const n = parseInt(s)
                if (!isNaN(n)) mtimeProc._latest = n
            }
        }
        onRunningChanged: {
            if (!running) {
                if (mtimeProc._latest >= 0 && mtimeProc._latest !== root.bindsMtime) {
                    root.bindsMtime = mtimeProc._latest
                    // Trigger a re-read
                    if (bindsProc.running) bindsProc.running = false
                    Qt.callLater(() => bindsProc.running = true)
                }
            }
        }
    }

    Timer {
        id: watchTimer
        interval: 4000
        repeat: true
        running: true
        onTriggered: { if (!mtimeProc.running) mtimeProc.running = true }
    }

    // React to path changes and on startup
    Connections {
        target: Globals
        function onKeybindsPathChanged() { _reconfigure() }
    }
    Component.onCompleted: _reconfigure()

    // Simple local keycap component to avoid external dependencies
    Component {
        id: keyCapComponent
        Rectangle {
            property string label: ""
            color: "transparent"
            radius: 6
            border.width: 1
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : (palette.active.light || "#666")
            implicitWidth: keyText.implicitWidth + 8
            implicitHeight: keyText.implicitHeight + 4
            Text {
                id: keyText
                anchors.centerIn: parent
                text: parent.label
                color: Globals.popupText !== "" ? Globals.popupText : "#ddd"
                font.pixelSize: 12
            }
        }
    }

    // Hover tooltip under/over the bar
    PopupWindow {
        id: tipWindow
        visible: false
        implicitWidth: tipLabel.implicitWidth + 20
        implicitHeight: tipLabel.implicitHeight + 20
        color: "transparent"

        anchor {
            window: root.QsWindow?.window
            edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
            gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
            onAnchoring: {
                const win = root.QsWindow?.window
                if (win) {
                    const gap = 3
                    tipWindow.anchor.rect.y = (Globals.barPosition === "top")
                        ? (tipWindow.anchor.window.height + gap)
                        : (-gap)
                    tipWindow.anchor.rect.x = win.contentItem.mapFromItem(root, root.width / 2, 0).x
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
            border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
            border.width: 1
            radius: 8

            Text {
                id: tipLabel
                anchors.fill: parent
                anchors.margins: 10
                text: "Keybinds"
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.NoWrap
            }
        }
    }

    // Popup window to show the cheatsheet
    PopupWindow {
        id: sheetWindow
        visible: false
        color: "transparent"
        implicitWidth: Math.min(800, sheetContent.implicitWidth + 20)
        implicitHeight: Math.min(600, sheetContent.implicitHeight + 20)
        onVisibleChanged: if (visible) {
            // If data not ready yet, read again
            const hasData = keybinds && keybinds.children && keybinds.children.length > 0 && keybinds.children[0].children && keybinds.children[0].children.length > 0
            if (!hasData && !bindsProc.running) {
                bindsBuf = ""
                bindsProc.running = true
            }
        }

        anchor {
            window: root.QsWindow?.window
            edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
            gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
            onAnchoring: {
                const win = root.QsWindow?.window
                if (win) {
                    const gap = 5
                    const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(sheetWindow.implicitHeight + gap))
                    const x = -(sheetWindow.implicitWidth - root.width) / 2
                    const rect = win.contentItem.mapFromItem(root, x, y, sheetWindow.implicitWidth, sheetWindow.implicitHeight)
                    sheetWindow.anchor.rect = rect
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Globals.popupBg !== "" ? Globals.popupBg : (palette.active.toolTipBase || "#222")
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : (palette.active.light || "#666")
            border.width: 1
            radius: 8

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 10
                contentWidth: sheetContent.implicitWidth
                contentHeight: sheetContent.implicitHeight
                clip: true

                // Vertical scrollbar like Clipboard left-click popup
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }

                ColumnLayout {
                    id: sheetContent
                    spacing: 10

                    // Header: show which file is parsed
                    Item {
                        visible: String(Globals.keybindsPath || "").trim().length > 0
                        implicitWidth: headerText.implicitWidth
                        implicitHeight: headerText.implicitHeight
                        Text {
                            id: headerText
                            text: "Keybinds parsed from " + _baseName(Globals.keybindsPath)
                            color: Globals.popupText !== "" ? Globals.popupText : "#ddd"
                            font.pixelSize: 12
                        }
                    }

                    // No path configured placeholder
                    Item {
                        visible: String(Globals.keybindsPath || "").trim().length === 0
                        implicitWidth: noPathText.implicitWidth
                        implicitHeight: noPathText.implicitHeight
                        Text { id: noPathText; text: "No keybinds file configured. Set 'keybindsPath' in theme.json to display the cheatsheet."; color: Globals.popupText !== "" ? Globals.popupText : "#bbb"; wrapMode: Text.WrapAtWordBoundaryOrAnywhere; width: sheetContent.width }
                    }
                    // Loading placeholder when path set but no data yet
                    Item {
                        visible: String(Globals.keybindsPath || "").trim().length > 0 && !(keybinds && keybinds.children && keybinds.children[0] && keybinds.children[0].children && keybinds.children[0].children.length > 0)
                        implicitWidth: loadingText.implicitWidth
                        implicitHeight: loadingText.implicitHeight
                        Text { id: loadingText; text: "Loading keybinds..."; color: Globals.popupText !== "" ? Globals.popupText : "#bbb" }
                    }

                    RowLayout { // Keybind columns
                        id: rowLayout
                        spacing: root.spacing
                        Repeater {
                            model: keybinds.children
                            delegate: ColumnLayout { // Keybind sections
                                spacing: root.spacing
                                required property var modelData
                                Layout.alignment: Qt.AlignTop
                                Repeater {
                                    model: modelData.children
                                    delegate: Item { // Section with real keybinds
                                        required property var modelData
                                        implicitWidth: sectionColumnLayout.implicitWidth
                                        implicitHeight: sectionColumnLayout.implicitHeight
                                        ColumnLayout {
                                            id: sectionColumnLayout
                                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                                            spacing: root.titleSpacing
                                             Text {
                                                 id: sectionTitle
                                                 Layout.alignment: Qt.AlignLeft
                                                 font.bold: true
                                                 font.italic: true
                                                 color: Globals.popupText !== "" ? Globals.popupText : "#ddd"
                                                 text: modelData.name
                                             }
                                            GridLayout {
                                                id: keybindGrid
                                                columns: 2
                                                columnSpacing: 8
                                                rowSpacing: 4
                                                Repeater {
                                                    model: {
                                                        var result = [];
                                                        for (var i = 0; i < modelData.keybinds.length; i++) {
                                                            result.push({ type: "keys", mods: modelData.keybinds[i].mods, key: modelData.keybinds[i].key });
                                                            result.push({ type: "comment", comment: modelData.keybinds[i].comment });
                                                        }
                                                        return result;
                                                    }
                                                    delegate: Item {
                                                        required property var modelData
                                                        implicitWidth: keybindLoader.implicitWidth
                                                        implicitHeight: keybindLoader.implicitHeight
                                                        Loader {
                                                            id: keybindLoader
                                                            sourceComponent: (modelData.type === "keys") ? keysComponent : commentComponent
                                                        }
                                                        Component {
                                                            id: keysComponent
                                                            RowLayout {
                                                                spacing: 4
                                                                Repeater {
                                                                    model: modelData.mods
                                                                    delegate: Loader {
                                                                        required property var modelData
                                                                        sourceComponent: keyCapComponent
                                                                        onLoaded: { item.label = keySubstitutions[modelData] || modelData }
                                                                    }
                                                                }
                                                                Text {
                                                                    id: keybindPlus
                                                                    visible: !keyBlacklist.includes(modelData.key) && modelData.mods.length > 0
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    text: "+"
                                                                    color: Globals.popupText !== "" ? Globals.popupText : "#ddd"
                                                                }
                                                                Loader {
                                                                    id: keybindKey
                                                                    visible: !keyBlacklist.includes(modelData.key)
                                                                    sourceComponent: keyCapComponent
                                                                    onLoaded: { item.label = keySubstitutions[modelData.key] || modelData.key }
                                                                }
                                                            }
                                                        }
                                                        Component {
                                                            id: commentComponent
                                                            Item {
                                                                id: commentItem
                                                                implicitWidth: commentText.implicitWidth + 8 * 2
                                                                implicitHeight: commentText.implicitHeight
                                                                Text {
                                                                    id: commentText
                                                                    anchors.centerIn: parent
                                                                    font.pixelSize: 12
                                                                    text: modelData.comment
                                                                    color: Globals.popupText !== "" ? Globals.popupText : "#bbb"
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Click + tooltip behavior
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onEntered: tipWindow.visible = true
        onExited: tipWindow.visible = false
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                tipWindow.visible = false
                sheetWindow.visible = !sheetWindow.visible
            }
        }
    }

    // Close popup/tooltip when bar position flips
    Connections {
        target: Globals
        function onBarPositionChanged() {
            if (sheetWindow.visible) sheetWindow.visible = false
            if (tipWindow.visible) tipWindow.visible = false
        }
    }
}