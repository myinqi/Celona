import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root
  signal toggleNmAppletRequested()

  // Display: network icon + percent for Wi‑Fi, cable icon only for Ethernet
  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: root.displayText
  }

  // Data
  property string ifname: "-"
  property string connType: "-"      // wifi | ethernet | none
  property string ssid: "-"
  property string ip4: "-"
  property int signal: -1             // 0-100 for wifi, -1 unknown

  // Icons (Symbols Nerd Font Mono)
  // Staged Wi‑Fi glyphs by strength
  property string wifi0: "󰤯"  // wifi_strength_1
  property string wifi1: "󰤟"  // wifi_strength_2
  property string wifi2: "󰤢"  // wifi_strength_3
  property string wifi3: "󰤥"  // wifi_strength_4
  property string wifiGlyph: "󰤨"      // fallback Wi‑Fi icon
  property string ethernetGlyph: "󰈀"  // nf-fa_plug (cable)
  property string offlineGlyph: "󰖪"   // nf-md_wifi_off

  // Computed label text
  property string displayText: (
    connType === "wifi" ? (wifiBarsGlyph + " " + (signal >= 0 ? (String(signal).padStart(3, " ") + "%") : "-")) :
    connType === "ethernet" ? ethernetGlyph : offlineGlyph
  )

  // Compute Wi‑Fi bars glyph from signal percent
  property string wifiBarsGlyph: (
    signal < 0 ? offlineGlyph :
    signal < 25 ? wifi0 :
    signal < 50 ? wifi1 :
    signal < 75 ? wifi2 : wifi3
  )

  // Poll via NetworkManager (nmcli) with fallbacks
  Process {
    id: netProc
    command: [
      "sh", "-c",
      // Try NetworkManager first (prefer Wi‑Fi when connected)
      "export LC_ALL=C; if command -v nmcli >/dev/null 2>&1; then " +
      "  wline=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"wifi\" && $3==\"connected\"{print $0; exit}'); " +
      "  if [ -n \"$wline\" ]; then devline=\"$wline\"; else devline=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$3==\"connected\"{print $0; exit}'); fi; " +
      "  IFS=: read -r dev type state name <<< \"$devline\"; " +
      "  if [ -n \"$dev\" ] && [ \"$state\" = connected ]; then " +
      "    ip=$(nmcli -t -f IP4.ADDRESS device show \"$dev\" 2>/dev/null | awk -F: 'NR==1{gsub(/\\/.*/, \"\", $2); print $2}'); " +
      "    if [ \"$type\" = wifi ]; then " +
      "      ssid=$(nmcli -t -f IN-USE,SSID device wifi list 2>/dev/null | awk -F: '$1==\"*\"{print $2; exit}'); " +
      "      sig=$(nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null | awk -F: '$1==\"*\"{print $2; exit}'); " +
      "      [ -n \"$ssid\" ] || ssid=\"$name\"; " +
      "      if [ -z \"$sig\" ] || [ \"$sig\" = \"-1\" ]; then sig=$(iw dev \"$dev\" link 2>/dev/null | awk '/signal:/ {gsub(/dBm/, \"\", $2); s=$2; if (s<-90) p=0; else if (s>-30) p=100; else p=int((s+90)*100/60); print p; exit}'); fi; " +
      "    else ssid='-'; sig='-1'; fi; " +
      "    printf '%s\t%s\t%s\t%s\t%s\n' \"$dev\" \"$type\" \"${ip:- -}\" \"${sig:- -1}\" \"$ssid\"; exit 0; " +
      "  fi; fi; " +
      // Fallback: use ip/iw
      "dev=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if ($i==\"dev\") {print $(i+1); exit}}'); " +
      "[ -n \"$dev\" ] || dev=$(ip route show default 2>/dev/null | awk '/default/{for(i=1;i<=NF;i++) if ($i==\"dev\") {print $(i+1); exit}}'); " +
      "ip=$(ip -4 -o addr show dev \"$dev\" 2>/dev/null | awk '{print $4}' | head -n1 | cut -d/ -f1); " +
      "if iw dev \"$dev\" info >/dev/null 2>&1; then type=wifi; ssid=$(iw dev \"$dev\" link 2>/dev/null | awk -F': ' '/SSID/{print $2; exit}'); sig=$(iw dev \"$dev\" link 2>/dev/null | awk '/signal:/ {gsub(/dBm/, \"\", $2); s=$2; if (s<-90) p=0; else if (s>-30) p=100; else p=int((s+90)*100/60); print p; exit}'); else type=ethernet; ssid='-'; sig=-1; fi; " +
      "printf '%s\t%s\t%s\t%s\t%s\n' \"${dev:- -}\" \"${type:- -}\" \"${ip:- -}\" \"${sig:- -1}\" \"$ssid\";"
    ]
    running: true

    stdout: SplitParser {
      onRead: data => {
        const s = String(data).trim()
        if (!s.length) return
        const lines = s.split(/\n/)
        const last = lines[lines.length - 1]
        // Expect a single-line, tab-separated packet: dev \t type \t ip \t signal \t ssid
        const parts = last.split("\t")
        if (parts.length >= 5) {
          root.ifname = parts[0] || "-"
          root.connType = parts[1] || "-"
          root.ip4 = parts[2] || "-"
          root.signal = parts[3].length ? Number(parts[3]) : -1
          root.ssid = parts.slice(4).join("\t") || "-" // SSID may contain spaces; preserved
        }
      }
    }
  }

  // Refresh timer
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: netProc.running = true
  }

  // Tooltip
  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
    onClicked: ev => {
      if (ev.button === Qt.RightButton) {
        root.toggleNmAppletRequested()
      }
    }
  }

  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: contentCol.implicitWidth + 20
    implicitHeight: contentCol.implicitHeight + 20
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

      Column {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2
        Text { text: "Interface: " + root.ifname; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { text: "Type: " + (root.connType !== "-" ? root.connType : "-"); color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { visible: root.connType === "wifi"; text: "SSID: " + root.ssid; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { visible: root.connType === "wifi"; text: "Signal: " + (root.signal >= 0 ? root.signal + "%" : "-"); color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { text: "IP: " + root.ip4; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
      }
    }
  }
}
