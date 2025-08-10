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
        onEntered: tipWindow.visible = true
        onExited: tipWindow.visible = false
        onClicked: { tipWindow.visible = false; toggleMenu() }
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
                text: "Volume controls"
                color: "#ffffff"
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
                      : (-(menuWindow.implicitHeight + gap))
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
              : (-(menuWindow.implicitHeight + gap))
            menuWindow.anchor.rect = root.QsWindow.window.contentItem.mapFromItem(root, 0, y, root.width, root.height)
            menuWindow.visible = !menuWindow.visible
        }
    }
}