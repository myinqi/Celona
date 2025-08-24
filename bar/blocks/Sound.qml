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
        mainFont: "JetBrains Mono Nerd Font"
        symbolFont: "Symbols Nerd Font Mono"
        // Fixed-width percent (0-100) to prevent layout shifts: pad to 3 chars
        property string percent3: String(Math.round(sink?.audio?.volume * 100)).padStart(3, " ")
        symbolText: `${sink?.audio?.muted ? "󰖁" : "󰕾"} ${percent3}%`
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tipWindow.visible = true
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
                font.pixelSize: Globals.tooltipFontPixelSize
                font.family: Globals.tooltipFontFamily !== "" ? Globals.tooltipFontFamily : font.family
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
        implicitHeight: 250
        color: "transparent"

        property int bars: 48
        property var values: new Array(bars).fill(0)
        property bool cavaAvailable: true
        property string errorText: ""
        property string nowPlaying: ""

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
                    vizWindow.anchor.rect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
                }
            }
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
                spacing: 8

                Row {
                    spacing: 8
                    width: parent.width
                    Text {
                        text: "Cava Visualizer"
                        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                        font.pixelSize: 12
                    }
                    Text {
                        text: vizWindow.nowPlaying !== "" ? `• ${vizWindow.nowPlaying}` : ""
                        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        width: parent.width - 160
                    }
                }

                Rectangle {
                    id: graph
                    width: parent.width
                    height: parent.height - 28
                    color: "transparent"

                    // Missing cava message
                    Text {
                        anchors.centerIn: parent
                        visible: !vizWindow.cavaAvailable || vizWindow.errorText !== ""
                        text: vizWindow.errorText !== "" ? vizWindow.errorText : "please install cava pkg"
                        color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                        font.pixelSize: 12
                    }

                    Row {
                        id: barsRow
                        anchors.fill: parent
                        spacing: 2
                        visible: vizWindow.cavaAvailable && vizWindow.errorText === ""
                        Repeater {
                            model: vizWindow.values.length
                            Rectangle {
                                width: (barsRow.width - (barsRow.spacing * (vizWindow.values.length - 1))) / vizWindow.values.length
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

        // Start/stop cava when popup toggles
        onVisibleChanged: {
            if (visible) {
                vizWindow.errorText = ""
                vizWindow.cavaAvailable = true
                vizWindow.values = new Array(vizWindow.bars).fill(0)
                vizProc.running = true
                nowProc.running = true
            } else {
                vizProc.running = false
                nowProc.running = false
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
                                font.pixelSize: 12
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