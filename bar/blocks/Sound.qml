import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import "../"
import "root:/" 

BarBlock {
    id: root
    property var sink: Pipewire.defaultAudioSink

    PwObjectTracker { 
        objects: [Pipewire.defaultAudioSink]
        onObjectsChanged: {
            sink = Pipewire.defaultAudioSink
            if (sink?.audio) {
                sink.audio.volumeChanged.connect(updateVolume)
            }
        }
    }

    function updateVolume() {
        if (sink?.audio) {
            const icon = sink.audio.muted ? "󰖁" : "󰕾"
            const p3 = String(Math.round(sink.audio.volume * 100)).padStart(3, " ")
            content.symbolText = `${icon} ${p3}%`
        }
    }

    content: BarText {
        mainFont: Globals.mainFontFamily
        symbolFont: "Symbols Nerd Font Mono"
        // Fixed-width percent (0-100) to prevent layout shifts: pad to 3 chars
        property string percent3: String(Math.round(sink?.audio?.volume * 100)).padStart(3, " ")
        symbolText: `${sink?.audio?.muted ? "󰖁" : "󰕾"} ${percent3}%`
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: {
            if (!Globals.popupContext || !Globals.popupContext.popup) {
                tipWindow.visible = true
            }
        }
        onExited: tipWindow.visible = false
        onClicked: (mouse) => {
            tipWindow.visible = false
            if (mouse.button === Qt.LeftButton) {
                toggleMenu()
            } else if (mouse.button === Qt.RightButton) {
                // Toggle embedded visualizer popup
                toggleVisualizer()
            }
        }
        onWheel: function(event) {
            if (sink?.audio) {
                sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (event.angleDelta.y / 120) * 0.05))
            }
        }
    }

    // Hover tooltip under the bar
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
                text: "Left: Volume menu\nRight: Visualizer"
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
                font.family: Globals.mainFontFamily
                font.pixelSize: Globals.mainFontSize
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.NoWrap
            }
        }
    }

    Process {
        id: pavucontrol
        command: ["pavucontrol"]
        running: false
    }

    // Embedded visualizer popup (cava -> ASCII -> bars)
    PopupWindow {
        id: vizWindow
        visible: false
        implicitWidth: 571
        implicitHeight: 100
        color: "transparent"

        property int bars: 48
        property var values: new Array(bars).fill(0)
        property bool cavaAvailable: true
        property string errorText: ""
        property string nowPlaying: ""
        // desired bar visuals
        property int _targetBarWidth: 6
        property int _targetSpacing: 2

        function _computeBars(totalWidth) {
            const spacing = _targetSpacing
            const bw = Math.max(2, _targetBarWidth)
            if (totalWidth <= 0) return 32
            const n = Math.floor((totalWidth + spacing) / (bw + spacing))
            return Math.max(16, Math.min(128, n))
        }

        anchor {
            window: root.QsWindow?.window
            edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
            gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
            onAnchoring: {
                const win = root.QsWindow?.window
                if (win) {
                    const gap = 5
                    const y = (Globals.barPosition === "top")
                      ? (root.height + gap)
                      : (-(root.height + gap))
                    const left = Math.max(0, Number(Globals.barSideMargin || 0))
                    // compensate 1px border on both sides (total 2px)
                    const borderComp = -2
                    const leftEff = Math.max(0, left - borderComp)
                    const w = Math.max(50, win.width - (leftEff * 2))
                    // Map root-relative rect into window coordinates to match other popups' vertical offset
                    const baseRect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
                    // Place full-width rect with side margins and explicitly size the window
                    vizWindow.anchor.rect = Qt.rect(leftEff, baseRect.y, w, baseRect.height)
                    vizWindow.width = w
                    vizWindow.implicitWidth = w
                    // Recompute bar count based on available width
                    const desired = vizWindow._computeBars(w - 20) // account for internal paddings
                    if (vizWindow.bars !== desired) vizWindow.bars = desired
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            // Use bar background color for the visualizer window background
            color: (Globals.barBgColor && Globals.barBgColor !== "")
                     ? Globals.barBgColor
                     : (Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase)
            border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
            border.width: 1
            radius: 8

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Header moved into graph as an overlay so bars can animate behind it

                Rectangle {
                    id: graph
                    width: parent.width
                    // Use full available height so bars anchor to the very bottom of the popup
                    height: parent.height
                    color: "transparent"

                    // Single-line overlay (title + now playing) centered, with bars behind
                    Text {
                        id: overlayTitle
                        anchors.top: parent.top
                        anchors.topMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 20
                        textFormat: Text.RichText
                        text: vizWindow.nowPlaying !== ""
                              ? ("<b>Cava Visualizer</b> • " + vizWindow.nowPlaying)
                              : "<b>Cava Visualizer</b>"
                        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Globals.mainFontFamily
                        font.pixelSize: Globals.mainFontSize
                        z: 2
                    }

                    // Missing cava message
                    Text {
                        anchors.centerIn: parent
                        visible: !vizWindow.cavaAvailable || vizWindow.errorText !== ""
                        text: vizWindow.errorText !== "" ? vizWindow.errorText : "please install cava pkg"
                        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                        font.family: Globals.mainFontFamily
                        font.pixelSize: Globals.mainFontSize
                    }

                    Row {
                        id: barsRow
                        anchors.fill: parent
                        spacing: vizWindow._targetSpacing
                        visible: vizWindow.cavaAvailable && vizWindow.errorText === ""
                        Repeater {
                            model: vizWindow.values.length
                            Rectangle {
                                width: (barsRow.width - (barsRow.spacing * (vizWindow.values.length - 1))) / Math.max(1, vizWindow.values.length)
                                height: Math.max(2, (vizWindow.values[index] / 100) * barsRow.height)
                                anchors.bottom: parent.bottom
                                radius: 2
                                color: Globals.visualizerBarColor !== "" ? Globals.visualizerBarColor : "#00bee7"
                            }
                        }
                    }
                }
            }
        }

        // Start/stop cava when popup toggles and manage global popup context
        onVisibleChanged: {
            if (visible) {
                // Enforce exclusivity
                if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== vizWindow) {
                    if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
                }
                if (Globals.popupContext) Globals.popupContext.popup = vizWindow

                vizWindow.errorText = ""
                vizWindow.cavaAvailable = true
                // Recompute bars for current window width and set values accordingly
                const win = root.QsWindow?.window
                const left = Math.max(0, Number(Globals.barSideMargin || 0))
                const w = win ? Math.max(50, win.width - (left * 2)) : vizWindow.implicitWidth
                const desired = vizWindow._computeBars(w - 20)
                if (vizWindow.bars !== desired) vizWindow.bars = desired
                vizWindow.values = new Array(vizWindow.bars).fill(0)
                vizProc.running = true
                nowProc.running = true
            } else {
                if (Globals.popupContext && Globals.popupContext.popup === vizWindow) Globals.popupContext.popup = null
                vizProc.running = false
                nowProc.running = false
            }
        }

        // If bar count changes while visible, restart cava with new bars
        onBarsChanged: {
            if (vizWindow.visible) {
                vizProc.running = false
                vizWindow.values = new Array(vizWindow.bars).fill(0)
                vizProc.running = true
            }
        }

        // React to window width and margin changes while visible to keep full-width layout
        Connections {
            target: root.QsWindow ? root.QsWindow.window : null
            function onWidthChanged() {
                if (!vizWindow.visible) return
                const win = root.QsWindow?.window
                if (!win) return
                const left = Math.max(0, Number(Globals.barSideMargin || 0))
                const borderComp = -2
                const leftEff = Math.max(0, left - borderComp)
                const w = Math.max(50, win.width - (leftEff * 2))
                const gap = 5
                const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(root.height + gap))
                const baseRect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
                vizWindow.anchor.rect = Qt.rect(leftEff, baseRect.y, w, baseRect.height)
                vizWindow.width = w
                vizWindow.implicitWidth = w
                const desired = vizWindow._computeBars(w - 20)
                if (vizWindow.bars !== desired) vizWindow.bars = desired
            }
        }
        Connections {
            target: Globals
            function onBarSideMarginChanged() {
                if (!vizWindow.visible) return
                const win = root.QsWindow?.window
                if (!win) return
                const left = Math.max(0, Number(Globals.barSideMargin || 0))
                const borderComp = -2
                const leftEff = Math.max(0, left - borderComp)
                const w = Math.max(50, win.width - (leftEff * 2))
                const gap = 5
                const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(root.height + gap))
                const baseRect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
                vizWindow.anchor.rect = Qt.rect(leftEff, baseRect.y, w, baseRect.height)
                vizWindow.width = w
                vizWindow.implicitWidth = w
                const desired = vizWindow._computeBars(w - 20)
                if (vizWindow.bars !== desired) vizWindow.bars = desired
            }
        }

        Process {
            id: vizProc
            running: false
            command: ["sh", "-c",
                `if command -v cava >/dev/null 2>&1; then \\
                   printf '[general]\\nframerate=60\\nbars=${vizWindow.bars}\\nsleep_timer=3\\n[output]\\nchannels=mono\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=100' | cava -p /dev/stdin; \\
                 else \\
                   echo '__CAVA_MISSING__'; \\
                 fi`
            ]
            stdout: SplitParser {
                onRead: data => {
                    const line = String(data).trim()
                    if (line === "__CAVA_MISSING__") {
                        vizWindow.cavaAvailable = false
                        vizWindow.errorText = "cava ist nicht installiert"
                        vizProc.running = false
                        return
                    }
                    const parts = line.split(";").filter(s => s.length > 0)
                    if (parts.length > 0) {
                        const nums = parts.map(v => Math.max(0, Math.min(100, parseInt(v, 10) || 0)))
                        if (nums.length !== vizWindow.bars) {
                            const trimmed = nums.slice(0, vizWindow.bars)
                            while (trimmed.length < vizWindow.bars) trimmed.push(0)
                            vizWindow.values = trimmed
                        } else {
                            vizWindow.values = nums
                        }
                    }
                }
            }
            stderr: SplitParser { onRead: data => console.log(`[Sound] viz stderr: ${String(data)}`) }
        }

        Process {
            id: nowProc
            running: false
            command: ["sh", "-c",
                `if command -v playerctl >/dev/null 2>&1; then \\
                   playerctl metadata --follow --format '{{title}} — {{artist}}'; \\
                 else \\
                   echo '__PLAYERCTL_MISSING__'; \\
                 fi`
            ]
            stdout: SplitParser {
                onRead: data => {
                    const line = String(data).trim()
                    if (line === '__PLAYERCTL_MISSING__') { vizWindow.nowPlaying = ''; nowProc.running = false; return }
                    // playerctl prints empty lines on state changes; ignore to keep last value or clear
                    vizWindow.nowPlaying = line
                }
            }
            stderr: SplitParser { onRead: data => console.log(`[Sound] now stderr: ${String(data)}`) }
        }
    }

    PopupWindow {
        id: menuWindow
        implicitWidth: 200
        implicitHeight: 150
        visible: false
        // Ensure the window background is transparent so rounded corners show correctly
        color: "transparent"
        onVisibleChanged: {
            if (visible) {
                // Enforce exclusivity
                if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== menuWindow) {
                    if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
                }
                if (Globals.popupContext) Globals.popupContext.popup = menuWindow
            } else {
                if (Globals.popupContext && Globals.popupContext.popup === menuWindow) Globals.popupContext.popup = null
            }
        }

        anchor {
            // Align and behave like Tooltip: pop downward from the bar block
            window: root.QsWindow?.window
            edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
            gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
            onAnchoring: {
                const win = root.QsWindow?.window;
                if (win) {
                    const gap = 5
                    // Anchor rectangle relative to the bar block area
                    const y = (Globals.barPosition === "top")
                      ? (root.height + gap)
                      : (-(root.height + gap))
                    const rect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
                    menuWindow.anchor.rect = rect
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onExited: {
                if (!containsMouse) {
                    closeTimer.start()
                }
            }
            onEntered: closeTimer.stop()

            Timer {
                id: closeTimer
                interval: 500
                onTriggered: menuWindow.visible = false
            }

            Rectangle {
                anchors.fill: parent
                color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
                border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
                border.width: 1
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // Volume Slider
                    Rectangle {
                        width: parent.width
                        height: 35
                        color: "transparent"

                        Slider {
                            id: volumeSlider
                            anchors.fill: parent
                            from: 0
                            to: 1
                            value: sink?.audio?.volume || 0
                            onValueChanged: {
                                if (sink?.audio) {
                                    sink.audio.volume = value
                                }
                            }

                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: volumeSlider.availableWidth
                                height: 4
                                radius: 2
                                color: "#3c3c3c"

                                Rectangle {
                                    width: volumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#4a9eff"
                                    radius: 2
                                }
                            }

                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: 16
                                height: 16
                                radius: 8
                                color: volumeSlider.pressed ? "#4a9eff" : "#ffffff"
                                border.color: "#3c3c3c"
                            }
                        }
                    }

                    Repeater {
                        model: [
                            { text: sink?.audio?.muted ? "Unmute" : "Mute", action: () => sink?.audio && (sink.audio.muted = !sink.audio.muted) },
                            { text: "Pavucontrol", action: () => { pavucontrol.running = true; menuWindow.visible = false } }
                        ]

                        Rectangle {
                            width: parent.width
                            height: 35
                            color: mouseArea.containsMouse ? Globals.hoverHighlightColor : "transparent"
                            radius: 6

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                text: modelData.text
                                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                                font.family: Globals.mainFontFamily
                                font.pixelSize: Globals.mainFontSize
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    modelData.action()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function toggleMenu() {
        if (root.QsWindow?.window?.contentItem) {
            const gap = 5
            const y = (Globals.barPosition === "top")
              ? (root.height + gap)
              : (-(root.height + gap))
            menuWindow.anchor.rect = root.QsWindow.window.contentItem.mapFromItem(root, 0, y, root.width, root.height)
            if (!menuWindow.visible) {
                // Close any other global popup first
                if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== menuWindow) {
                    if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
                }
            }
            if (vizWindow.visible) vizWindow.visible = false
            menuWindow.visible = !menuWindow.visible
        }
    }

    function toggleVisualizer() {
        if (root.QsWindow?.window?.contentItem) {
            const gap = 5
            const y = (Globals.barPosition === "top")
              ? (root.height + gap)
              : (-(root.height + gap))
            vizWindow.anchor.rect = root.QsWindow.window.contentItem.mapFromItem(root, 0, y, root.width, root.height)
            if (!vizWindow.visible) {
                // Close any other global popup first
                if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== vizWindow) {
                    if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
                }
            }
            if (menuWindow.visible) menuWindow.visible = false
            vizWindow.visible = !vizWindow.visible
        }
    }

    // Close any open popups when bar position flips (top <-> bottom)
    Connections {
        target: Globals
        function onBarPositionChanged() {
            if (menuWindow.visible) menuWindow.visible = false
            if (tipWindow.visible) tipWindow.visible = false
            if (vizWindow.visible) vizWindow.visible = false
        }
    }
}