import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
    id: root
    visible: Globals.showBarvisualizer
    leftPadding: 0
    rightPadding: 0

    property int bars: 24
    property var values: new Array(bars).fill(0)
    property bool cavaAvailable: true
    property string errorText: ""
    property string nowPlaying: ""

    content: Item {
        // Ensure content aligns to the very start of the BarBlock
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: iconWrap.width + 4 + vizArea.width
        implicitHeight: 26
        
        // Music note icon (BarText centers itself; wrap it so we can left-align)
        Item {
            id: iconWrap
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: noteIcon.implicitWidth
            height: parent.height
            BarText {
                id: noteIcon
                anchors.centerIn: parent
                mainFont: Globals.mainFontFamily
                symbolFont: "Symbols Nerd Font Mono"
                symbolText: "♪"
            }
        }
        
        // Compact visualizer area (60px)
        Rectangle {
            id: vizArea
            anchors.left: iconWrap.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 225
            height: 28
            color: "transparent"
            
            // Error/missing cava message
            Text {
                anchors.centerIn: parent
                visible: !root.cavaAvailable || root.errorText !== ""
                text: root.errorText !== "" ? "cava error" : "no cava"
                color: Globals.moduleValueColor !== "" ? Globals.moduleValueColor : "#FFFFFF"
                font.pixelSize: 10
            }
            
            // Visualizer bars
            Row {
                id: barsRow
                anchors.fill: parent
                anchors.margins: 2
                spacing: 1
                visible: root.cavaAvailable && root.errorText === ""
                
                Repeater {
                    model: root.values.length
                    Rectangle {
                        width: Math.max(1, (barsRow.width - (barsRow.spacing * (root.values.length - 1))) / root.values.length)
                        height: Math.max(2, (root.values[index] / 100) * barsRow.height)
                        anchors.bottom: parent.bottom
                        radius: 1
                        color: (Globals.visualizerBarColorEffective && Globals.visualizerBarColorEffective !== "")
                                 ? Globals.visualizerBarColorEffective
                                 : (Globals.visualizerBarColor !== "" ? Globals.visualizerBarColor : "#00bee7")
                    }
                }
            }
        }
    }

    // Hover tooltip showing now playing
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        // Do not consume clicks so inner controls remain clickable
        acceptedButtons: Qt.NoButton
        onEntered: tipWindow.visible = true
        onExited: tipWindow.visible = false
    }

    PopupWindow {
        id: tipWindow
        visible: false
        // Narrow tooltip and horizontally scroll title if it overflows
        // Width: ~35% of window, clamped to [220, 360]
        implicitWidth: Math.max(220, Math.min(360, Math.floor((root.QsWindow?.window?.width || 1200) * 0.35)))
        // Height follows content text
        implicitHeight: marqueeText.implicitHeight + 20
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

            // Marquee viewport
            Item {
                id: marqueeViewport
                anchors.fill: parent
                anchors.margins: 10
                clip: true

                // Scrolling text
                Text {
                    id: marqueeText
                    text: root.nowPlaying
                    color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
                    font.family: Globals.mainFontFamily
                    font.pixelSize: Globals.mainFontSize
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.NoWrap
                    y: (marqueeViewport.height - height) / 2
                    onTextChanged: {
                        x = 0
                        marqueeAnim.restart()
                    }
                }

                // Animate only when needed and while visible (ping-pong without jump)
                SequentialAnimation {
                    id: marqueeAnim
                    running: (marqueeText.implicitWidth > marqueeViewport.width) && tipWindow.visible
                    loops: Animation.Infinite
                    // configurable durations
                    property int travel: Math.abs(marqueeViewport.width - marqueeText.implicitWidth)
                    property int slideDuration: Math.max(1800, 25 * travel)
                    PauseAnimation { duration: 600 }
                    // forward to left (revealing tail)
                    NumberAnimation {
                        target: marqueeText
                        property: "x"
                        from: 0
                        to: Math.min(0, marqueeViewport.width - marqueeText.implicitWidth)
                        duration: marqueeAnim.slideDuration
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 500 }
                    // backward to start (no jump)
                    NumberAnimation {
                        target: marqueeText
                        property: "x"
                        to: 0
                        duration: marqueeAnim.slideDuration
                        easing.type: Easing.Linear
                    }
                    onStopped: marqueeText.x = 0
                }
            }
        }
    }

    // Robust restart routine for the embedded cava process
    function restartVisualizer() {
        try {
            // Stop then start next tick to ensure the process is fully torn down
            vizProc.running = false
            Qt.callLater(() => { if (root.visible) vizProc.running = true })
        } catch (e) { /* ignore */ }
    }

    onVisibleChanged: {
        // Ensure a clean start when the module becomes visible again
        if (visible) restartVisualizer()
    }

    // Cava process for audio data
    Process {
        id: vizProc
        running: root.visible
        command: ["sh", "-c",
            // Use a custom process name (cava_bar) so global `pkill -USR1 -x cava` doesn't hit this instance
            `if command -v cava >/dev/null 2>&1; then \\
               printf '[general]\\nframerate=60\\nbars=${root.bars}\\nsleep_timer=3\\n[output]\\nchannels=mono\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=100' | exec -a cava_bar cava -p /dev/stdin; \\
             else \\
               echo '__CAVA_MISSING__'; \\
             fi`
        ]
        stdout: SplitParser {
            onRead: data => {
                const line = String(data).trim()
                if (line === "__CAVA_MISSING__") {
                    root.cavaAvailable = false
                    root.errorText = "cava not installed"
                    vizProc.running = false
                    return
                }
                const parts = line.split(";").filter(s => s.length > 0)
                if (parts.length > 0) {
                    const nums = parts.map(v => Math.max(0, Math.min(100, parseInt(v, 10) || 0)))
                    if (nums.length !== root.bars) {
                        const trimmed = nums.slice(0, root.bars)
                        while (trimmed.length < root.bars) trimmed.push(0)
                        root.values = trimmed
                    } else {
                        root.values = nums
                    }
                }
            }
        }
        stderr: SplitParser { onRead: data => console.log(`[Barvisualizer] cava stderr: ${String(data)}`) }
        onRunningChanged: {
            if (running) {
                root.errorText = ""
                root.cavaAvailable = true
                root.values = new Array(root.bars).fill(0)
            }
        }
    }

    // Now playing info process
    Process {
        id: nowProc
        running: root.visible
        command: ["sh", "-c", 
            "if command -v playerctl >/dev/null 2>&1; then " +
            "while true; do playerctl metadata --format '{{ title }}' 2>/dev/null || echo ''; sleep 2; done; " +
            "else echo '__PLAYERCTL_MISSING__'; fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                const line = String(data).trim()
                if (line === '__PLAYERCTL_MISSING__') { 
                    root.nowPlaying = ''
                    nowProc.running = false
                    return 
                }
                root.nowPlaying = line
            }
        }
        stderr: SplitParser { onRead: data => console.log(`[Barvisualizer] now stderr: ${String(data)}`) }
    }

    // Close tooltip on bar position change
    Connections {
        target: Globals
        function onBarPositionChanged() {
            if (tipWindow.visible) tipWindow.visible = false
        }
        // When theme changes (Matugen apply) we also update visualizerBarColor in Globals.
        // Use that change as a signal to force-restart the embedded cava process to avoid freezes.
        function onVisualizerBarColorChanged() {
            restartVisualizer()
        }
        // Also listen to a generic theme epoch bump so we restart even if color values didn't change
        function onThemeEpochChanged() {
            restartVisualizer()
        }
    }
}
