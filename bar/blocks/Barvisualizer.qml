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
        implicitWidth: noteIcon.implicitWidth + 4 + vizArea.width
        implicitHeight: Globals.baseBarHeight
        
        // Music note icon
        BarText {
            id: noteIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            mainFont: "JetBrains Mono Nerd Font"
            symbolFont: "Symbols Nerd Font Mono"
            symbolText: "♪"
        }
        
        // Compact visualizer area (60px)
        Rectangle {
            id: vizArea
            anchors.left: noteIcon.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 190
            height: 26
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
                        color: Globals.visualizerBarColor !== "" ? Globals.visualizerBarColor : "#00bee7"
                    }
                }
            }
        }
    }

    // Hover tooltip showing now playing
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: tipWindow.visible = true
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

            Text {
                id: tipLabel
                anchors.fill: parent
                anchors.margins: 10
                text: root.nowPlaying !== "" ? `${root.nowPlaying}` : "Audio Visualizer"
                color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
                font.pixelSize: Globals.tooltipFontPixelSize
                font.family: Globals.tooltipFontFamily !== "" ? Globals.tooltipFontFamily : font.family
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }

    // Cava process for audio data
    Process {
        id: vizProc
        running: root.visible
        command: ["sh", "-c",
            `if command -v cava >/dev/null 2>&1; then \\
               printf '[general]\\nframerate=60\\nbars=${root.bars}\\nsleep_timer=3\\n[output]\\nchannels=mono\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=100' | cava -p /dev/stdin; \\
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
    }
}
