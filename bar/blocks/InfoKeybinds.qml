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
    // Debug: which parser was used last (Hyprland or Niri)
    property string _parserName: ""
    // Debug: last resolved file path actually read
    property string _resolvedPath: ""
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

    // --- Read and parse keybinds (Hyprland .conf and Niri .kdl) ---
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

    function parseNiriKdlBinds(text) {
        // Robust KDL parser for common Niri binding styles.
        // Supports:
        //   bindings { binding { modifiers ["Super"] key "Return" action "spawn" command "alacritty" } }
        //   binding { ... } on a single line
        //   Optional brace-less forms: bind modifiers [..] key ".." action ".." command ".."
        const src = String(text || "")
        const sections = []
        let current = { name: "General", keybinds: [] }
        const pushSection = () => { if (current.keybinds.length) sections.push(current) }

        const unquote = (s) => {
            if (!s) return ""
            s = String(s).trim()
            if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) return s.slice(1, -1)
            return s
        }
        const parseArray = (s) => {
            const m = s.match(/\[(.*)\]/)
            if (!m) return []
            const inside = m[1]
            const quoted = inside.match(/(["'])(?:\\.|(?!\1).)*\1/g) || []
            const unquoted = inside
                .replace(/(["'])(?:\\.|(?!\1).)*\1/g, ' ') // blank out quoted to avoid double counting
                .match(/[A-Za-z0-9:_+\-]+/g) || []
            return [...quoted.map(unquote), ...unquoted]
        }
        const addBindFromChunk = (chunk) => {
            if (!chunk) return
            const mods = (() => {
                let m
                if ((m = chunk.match(/\bmodifiers\s*\[[^\]]*\]/))) return parseArray(m[0])
                if ((m = chunk.match(/\bmods?\s*\[[^\]]*\]/))) return parseArray(m[0])
                if ((m = chunk.match(/\bmodifiers\s+(["'][^"']+["'])/))) return [unquote(m[1])]
                if ((m = chunk.match(/\bmods?\s+(["'][^"']+["'])/))) return [unquote(m[1])]
                return []
            })()
            const key = (() => {
                let m
                if ((m = chunk.match(/\bkey\s+(["'][^"']+["'])/))) return unquote(m[1])
                if ((m = chunk.match(/\bkey\s+([^\s\}]+)/))) return m[1]
                return ""
            })()
            const action = (() => {
                let m
                if ((m = chunk.match(/\baction\s+(["'][^"']+["'])/))) return unquote(m[1])
                if ((m = chunk.match(/\baction\s+([^\s\}]+)/))) return m[1]
                return ""
            })()
            const command = (() => {
                let m
                if ((m = chunk.match(/\b(command|exec|spawn)\s+(["'][^"']+["'])/))) return unquote(m[2])
                if ((m = chunk.match(/\b(command|exec|spawn)\s+([^\s\}]+)/))) return m[2]
                return ""
            })()
            const comment = (() => {
                const m = chunk.match(/\bcomment\s+(["'][^"']+["'])/)
                return m ? unquote(m[1]) : (command || action)
            })()
            current.keybinds.push({ mods, key, comment })
        }

        // 1) Group by preceding line comments for sectioning
        const lines = src.split(/\r?\n/)
        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i]
            const line = raw.trim()
            if (!line) continue
            if (line.startsWith("//") || line.startsWith("#")) {
                const body = line.replace(/^\/{2,}|#+\s*/, "").trim()
                if (body.length) {
                    pushSection()
                    current = { name: body, keybinds: [] }
                }
            }
        }

        // 2) Extract brace-delimited binding blocks (multi- or single-line)
        const reBlock = /\b(bind|binding)\b[^\{]*\{([\s\S]*?)\}/g
        let m
        while ((m = reBlock.exec(src)) !== null) {
            addBindFromChunk(m[2])
        }

        // 2b) Extract and parse `binds { ... }` blocks with bare entries
        const reBindsBlock = /\bbinds\b[^\{]*\{([\s\S]*?)\}/g
        let bm
        while ((bm = reBindsBlock.exec(src)) !== null) {
            const body = bm[1]
            // First, capture any nested binding { ... } blocks if present
            let nm
            const nested = /\b(bind|binding)\b[^\{]*\{([\s\S]*?)\}/g
            while ((nm = nested.exec(body)) !== null) addBindFromChunk(nm[2])
            // Then, parse chord-style entries: Chord [props...] { inner; }
            // Example: Mod+Return hotkey-overlay-title="..." { spawn "ghostty"; }
            let em
            // Capture: chord, props (before '{'), and inner block
            const entryRe = /(^|\n)\s*([A-Za-z0-9+_:.-]+)([^\{]*)\{([^}]*)\}/g
            while ((em = entryRe.exec(body)) !== null) {
                const chord = em[2]
                const props = em[3] || ""
                const inner = em[4]
                const parts = chord.split('+')
                const key = parts.pop()
                const mods = parts
                // Prefer curated Niri overlay titles; if absent, skip to keep list tidy
                let titleMatch = props.match(/hotkey-overlay-title\s*=\s*(\"[^\"]+\"|'[^']+'|[^\s\{]+)/)
                if (!titleMatch) continue
                const comment = unquote(titleMatch[1])
                current.keybinds.push({ mods, key, comment })
            }
        }

        // 3) Fallback: inline, brace-less forms per line
        if (current.keybinds.length === 0) {
            const reInline = /\b(bind|binding)\b[^\n\{]*/g
            let mm
            while ((mm = reInline.exec(src)) !== null) {
                addBindFromChunk(mm[0])
            }
        }

        if (current.keybinds.length) sections.push(current)
        return { children: [ { children: sections } ] }
    }

    function parseKeybindsAuto(text, pathHint) {
        const t = String(text || "")
        // Only Hyprland parsing is supported for the popup
        return parseHyprBinds(t)
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
        const buildResolve = "p=\"" + esc + "\"; p=${p/#~/$HOME}; if [[ \"$p\" != /* ]]; then p=\"$HOME/$p\"; fi;"
        const buildCat = buildResolve + " cat \"$p\""
        const buildStat = buildResolve + " stat -c %Y \"$p\" 2>/dev/null || echo 0"
        bindsProc.command = ["bash", "-lc", buildCat]
        mtimeProc.command = ["bash", "-lc", buildStat]
        // Also compute resolved path once
        try {
            const out = Qs.runSync(["bash","-lc", buildResolve + " printf '%s' \"$p\""])
            if (out && out.stdout) root._resolvedPath = String(out.stdout).trim()
        } catch (e) { root._resolvedPath = p }
        console.log("InfoKeybinds: using path=", root._resolvedPath)
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
        // Under Niri (.kdl), do not read or parse; we show native overlay only
        if (p.toLowerCase().endsWith('.kdl')) {
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
        // Start modification watcher immediately
        if (!mtimeProc.running) mtimeProc.running = true
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
        running: false
        command: ["bash","-lc","cat /dev/null"] // updated dynamically
        onRunningChanged: if (!running) {
            if (root.bindsBuf.length > 0) {
                try {
                    const text = String(root.bindsBuf)
                    if (text.trim().length === 0) {
                        // Ignore transient empty reads
                        root.bindsBuf = ""
                        return
                    }
                    // Popup supports Hyprland only
                    root._parserName = "Hyprland"
                    root.keybinds = parseKeybindsAuto(text, Globals.keybindsPath)
                    // Debug counts
                    try {
                        const secs = (root.keybinds.children?.[0]?.children || [])
                        let total = 0
                        for (let s of secs) total += (s.keybinds?.length || 0)
                        console.log(`InfoKeybinds: parser=${root._parserName}, sections=${secs.length}, binds=${total}`)
                        console.log("InfoKeybinds: file head=", text.slice(0, 160).replace(/\n/g, ' ⏎ '))
                    } catch (e2) {}
                } catch (e) { console.log("InfoKeybinds parse error:", e) }
                root.bindsBuf = ""
            }
        }
        stdout: SplitParser {
            onRead: data => { root.bindsBuf += String(data) + "\n" }
        }
    }

    // Niri: trigger built-in hotkey overlay
    Process {
        id: niriOverlayProc
        running: false
        command: ["bash","-lc","niri msg action show-hotkey-overlay"]
        onRunningChanged: if (!running) {
            // auto-reset so it can be clicked again
            niriOverlayProc.running = false
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
                if (isNaN(n) || n === 0) return // ignore invalid or missing mtime
                if (n !== mtimeProc._latest) {
                    mtimeProc._latest = n
                    // Re-read file
                    root.bindsBuf = ""
                    bindsProc.running = true
                }
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
                    RowLayout {
                        visible: String(Globals.keybindsPath || "").trim().length > 0
                        spacing: 10
                        Text {
                            id: headerText
                            text: "Keybinds parsed from " + _baseName(root._resolvedPath || Globals.keybindsPath) + (root._parserName ? ("  (" + root._parserName + ")") : "")
                            color: Globals.popupText !== "" ? Globals.popupText : "#ddd"
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignVCenter
                        }
                        // Niri helper: open built-in hotkey overlay
                        Rectangle {
                            visible: root._parserName === "Niri"
                            color: "transparent"
                            border.color: Globals.popupText !== "" ? Globals.popupText : "#aaa"
                            radius: 4
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: 18
                            implicitWidth: overlayText.implicitWidth + 10
                            Text {
                                id: overlayText
                                anchors.centerIn: parent
                                text: "Open Niri overlay"
                                font.pixelSize: 11
                                color: Globals.popupText !== "" ? Globals.popupText : "#ddd"
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (!niriOverlayProc.running) niriOverlayProc.running = true
                                }
                            }
                        }
                    }

                    // No path configured placeholder
                    Item {
                        visible: String(Globals.keybindsPath || "").trim().length === 0
                        implicitWidth: noPathText.implicitWidth
                        implicitHeight: noPathText.implicitHeight
                        Text { id: noPathText; text: "No keybinds file configured. Set 'keybindsPath' in config.json to display the cheatsheet."; color: Globals.popupText !== "" ? Globals.popupText : "#bbb"; wrapMode: Text.WrapAtWordBoundaryOrAnywhere; width: sheetContent.width }
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
        onEntered: { tipWindow.visible = true }
        onExited: tipWindow.visible = false
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                const isNiri = String(Globals.keybindsPath || "").toLowerCase().endsWith(".kdl")
                tipWindow.visible = false
                if (isNiri) {
                    if (!niriOverlayProc.running) niriOverlayProc.running = true
                    if (sheetWindow.visible) sheetWindow.visible = false
                    return
                }
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