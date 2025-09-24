import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"
import "../utils" as Utils

BarBlock {
  id: root

  // Appearance
  // Using the same Nerd Font icon you use in Waybar: ""
  // If you prefer another glyph (e.g. nf-md-power), let me know.
  property string iconGlyph: ""
  // Toggle for Hyprlock process logs (stdout/stderr). Default: off to reduce noise.
  property bool logHyprlock: false

  content: BarText {
    mainFont: Globals.mainFontFamily
    symbolFont: "Symbols Nerd Font Mono"
    // No value text follows the glyph; avoid extra gap from letter-spacing
    symbolSpacing: 0
    symbolText: root.iconGlyph
  }

  // Click handling: left -> power menu, right -> hyprlock
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true

    // Show tooltip below the bar (like CPU/Sound) to avoid covering the icon
    onEntered: {
      if (!Globals.popupContext || !Globals.popupContext.popup) {
        tipWindow.visible = true
      }
    }
    onExited: tipWindow.visible = false

    onClicked: (mouse) => {
      tipWindow.visible = false
      if (mouse.button === Qt.LeftButton) {
        // Unified: always show internal power popup on left click
        toggleMenu()
      } else if (mouse.button === Qt.RightButton) {
        lockProc.running = true
      }
    }
  }

  // Tooltip style and positioning (under the bar)
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
          // Dynamic spacing and centering: 3px below (top bar) or 3px above (bottom bar)
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
        text: "Left: Power menu\nRight: Lock screen"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
        wrapMode: Text.NoWrap
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  // Power menu popup (left-click)
  PopupWindow {
    id: menuWindow
    visible: false
    // Auto-size to content like Sound.qml tooltip
    implicitWidth: contentCol.implicitWidth + 20
    implicitHeight: contentCol.implicitHeight + 20
    color: "transparent"
    onVisibleChanged: {
      if (visible) {
        // Enforce exclusivity with other module popups
        if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== menuWindow) {
          if (Globals.popupContext.popup.visible !== undefined)
            Globals.popupContext.popup.visible = false
        }
        if (Globals.popupContext) Globals.popupContext.popup = menuWindow
      } else {
        if (Globals.popupContext && Globals.popupContext.popup === menuWindow)
          Globals.popupContext.popup = null
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
          const y = (Globals.barPosition === "top")
            ? (root.height + gap)
            : (-(root.height + gap))
          menuWindow.anchor.rect = win.contentItem.mapFromItem(root, 0, y, root.width, root.height)
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      // Keep popup open until user toggles or another popup opens
      hoverEnabled: false

      Rectangle {
        anchors.fill: parent
        color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
        border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
        border.width: 1
        radius: 8

        Column {
          id: contentCol
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.margins: 10
          spacing: 10

          Repeater {
            model: [
              { icon: "󰤄", text: "Suspend", action: () => suspendProc.running = true },
              { icon: "󰜉", text: "Reboot", action: () => rebootProc.running = true },
              { icon: "󰐥", text: "Poweroff", action: () => poweroffProc.running = true },
              { icon: "󰍃", text: "Logout", action: () => logoutProc.running = true }
            ]

            Rectangle {
              implicitWidth: contentRow.implicitWidth + 20
              implicitHeight: 35
              color: mouseArea.containsMouse ? Globals.hoverHighlightColor : "transparent"
              radius: 6

              Row {
                id: contentRow
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                  text: modelData.icon
                  color: Globals.hoverHighlightColor !== "" ? Globals.hoverHighlightColor : "#6c7086"
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
                  verticalAlignment: Text.AlignVCenter
                }
                Text {
                  text: modelData.text
                  color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                  font.family: Globals.mainFontFamily
                  font.pixelSize: Globals.mainFontSize
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: { modelData.action(); menuWindow.visible = false }
              }
            }
          }
        }
      }
    }
  }

  Process {
    id: lockProc
    running: false
    command: ["sh", "-c", "hyprlock"]
    stdout: SplitParser {
      onRead: data => { if (root.logHyprlock) console.log(`[Power] LOCK OUT: ${String(data)}`) }
    }
    stderr: SplitParser {
      onRead: data => { if (root.logHyprlock) console.log(`[Power] LOCK ERR: ${String(data)}`) }
    }
  }

  // Hyprland: open external wlogout menu directly (bypass our popup)
  Process {
    id: hyprWlogoutProc
    running: false
    command: ["bash", "-lc", "~/.config/ml4w/scripts/wlogout.sh"]
    stdout: SplitParser { onRead: data => console.log(`[Power] HYPR WLOGOUT OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Power] HYPR WLOGOUT ERR: ${String(data)}`) }
  }

  // Cross-DE/system power actions using loginctl if available, else systemctl
  Process {
    id: suspendProc
    running: false
    command: ["sh","-c","(command -v loginctl >/dev/null 2>&1 && loginctl suspend) || systemctl suspend"]
    stdout: SplitParser { onRead: data => console.log(`[Power] SUSPEND OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Power] SUSPEND ERR: ${String(data)}`) }
  }
  Process {
    id: rebootProc
    running: false
    command: ["sh","-c","(command -v loginctl >/dev/null 2>&1 && loginctl reboot) || systemctl reboot"]
    stdout: SplitParser { onRead: data => console.log(`[Power] REBOOT OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Power] REBOOT ERR: ${String(data)}`) }
  }
  Process {
    id: poweroffProc
    running: false
    command: ["sh","-c","(command -v loginctl >/dev/null 2>&1 && loginctl poweroff) || systemctl poweroff"]
    stdout: SplitParser { onRead: data => console.log(`[Power] POWEROFF OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Power] POWEROFF ERR: ${String(data)}`) }
  }

  // Niri: quit compositor without confirmation and return to SDDM
  Process {
    id: logoutProc
    running: false
    command: [
      "bash","-lc",
      // Hyprland: use hyprctl; else try Niri; else no-op
      "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ] && command -v hyprctl >/dev/null 2>&1; then " +
      "  hyprctl dispatch exit; " +
      "elif command -v niri >/dev/null 2>&1; then " +
      "  niri msg action quit --skip-confirmation; " +
      "else " +
      "  true; " +
      "fi"
    ]
    stdout: SplitParser { onRead: data => console.log(`[Power] LOGOUT OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Power] LOGOUT ERR: ${String(data)}`) }
  }

  function toggleMenu() {
    if (root.QsWindow?.window?.contentItem) {
      const gap = 5
      const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(root.height + gap))
      menuWindow.anchor.rect = root.QsWindow.window.contentItem.mapFromItem(root, 0, y, root.width, root.height)
      if (!menuWindow.visible) {
        // Close any other globally registered popup first
        if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== menuWindow) {
          if (Globals.popupContext.popup.visible !== undefined)
            Globals.popupContext.popup.visible = false
        }
      }
      menuWindow.visible = !menuWindow.visible
    }
  }
}
