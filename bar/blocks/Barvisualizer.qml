import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
    id: root
    // Only show when enabled and audio is active (fallback: MPRIS active)
    visible: Globals.showBarvisualizer && (Globals.hasAudioActivity || Globals.hasActivePlayer)
    leftPadding: 0
    rightPadding: 0

    property int bars: 24
    property var values: new Array(bars).fill(0)
    property bool cavaAvailable: true
    property string errorText: ""
    property string nowPlaying: ""
    // Track last successful values update for watchdog restarts
    property double _lastUpdateMs: 0
    // Convenience alias for readability
    readonly property bool active: (Globals.showBarvisualizer && (Globals.hasAudioActivity || Globals.hasActivePlayer))
    // local presence flag removed; rely on Globals.hasActivePlayer for consistency with MediaControls

    content: Item {
        // Ensure content aligns to the very start of the BarBlock
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // Collapse content completely when inactive
        implicitWidth: root.active ? (iconWrap.width + 4 + vizArea.width) : 0
        implicitHeight: root.active ? 26 : 0
        visible: root.active
        
        // Music note icon (BarText centers itself; wrap it so we can left-align)
        Item {
            id: iconWrap
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: noteIcon.implicitWidth
            height: parent.height
            visible: root.active
            BarText {
                id: noteIcon
                anchors.centerIn: parent
                mainFont: Globals.mainFontFamily
                symbolFont: "Symbols Nerd Font Mono"
                symbolText: ""
            }

            // Visibility controlled by Globals.hasAudioActivity (debounced). Optional debug:
            onVisibleChanged: {
                console.log(`[Barvisualizer] visible=${visible} active=${root.active} audio=${Globals.hasAudioActivity}`)
                if (visible) restartVisualizer()
                else vizProc.running = false
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
            visible: root.active
            clip: true
            
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
            
            // Scrolling track title overlay
            Item {
                id: scrollContainer
                anchors.fill: parent
                visible: root.nowPlaying !== "" && root.cavaAvailable
                clip: true
                
                Text {
                    id: trackTitle
                    y: 1
                    text: root.nowPlaying
                    color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
                    font.family: Globals.mainFontFamily
                    font.pixelSize: Globals.mainFontSize
                    font.bold: false
                    
                    // Calculate if scrolling is needed
                    property bool needsScroll: implicitWidth > scrollContainer.width
                    
                    // Scroll animation (runs once, then stays at start)
                    SequentialAnimation {
                        id: scrollAnim
                        running: trackTitle.needsScroll && root.active
                        loops: Animation.Infinite
                        
                        // Wait at start
                        PauseAnimation { duration: 2000 }
                        
                        // Scroll to left
                        NumberAnimation {
                            target: trackTitle
                            property: "x"
                            from: 0
                            to: -(trackTitle.implicitWidth - scrollContainer.width + 20)
                            duration: trackTitle.implicitWidth * 30
                            easing.type: Easing.Linear
                        }
                        
                        // Wait at end
                        PauseAnimation { duration: 3000 }
                        
                        // Smooth scroll back to start
                        NumberAnimation {
                            target: trackTitle
                            property: "x"
                            to: 0
                            duration: 1000
                            easing.type: Easing.InOutQuad
                        }
                    }
                    
                    // Static position when no scroll needed or after animation completed
                    x: trackTitle.needsScroll && scrollAnim.running ? trackTitle.x : (trackTitle.needsScroll ? 0 : (scrollContainer.width - implicitWidth) / 2)
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
        onEntered: tipWindow.visible = root.active
        onExited: tipWindow.visible = false
    }

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

            // Simple centered text
            Text {
                id: tipLabel
                anchors.centerIn: parent
                text: "Barvisualizer"
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
                font.family: Globals.mainFontFamily
                font.pixelSize: Globals.mainFontSize
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
               printf '[general]\\nframerate=60\\nbars=${root.bars}\\nsleep_timer=2\\n[output]\\nchannels=mono\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=100' | exec -a cava_bar cava -p /dev/stdin; \\
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
                console.log('[Barvisualizer] cava started')
            } else {
                console.log('[Barvisualizer] cava stopped')
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
        // Restart viz on audio activity change to ensure fresh capture
        function onHasAudioActivityChanged() {
            if (Globals.hasAudioActivity && root.visible) restartVisualizer()
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
