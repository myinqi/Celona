import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: text
  content: BarText {
    // Symbol für Arbeitsspeicher aus Symbols Nerd Font (nf-mdi-memory: )
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    // Fixed-width percent (0-100) to prevent layout shifts: pad to 3 chars
    property string percent3: String(Math.floor(percentUsed)).padStart(3, " ")
    symbolText: " " + percent3 + "%"
  }

  // Show used memory percent based on MemTotal and MemAvailable
  property real percentUsed: 0
  property int totalKB: 0
  property int availKB: 0
  // Extra details for tooltip
  property int freeKB: 0
  property int buffersKB: 0
  property int cachedKB: 0
  property int sreclaimKB: 0
  property int swapTotalKB: 0
  property int swapFreeKB: 0
  property int swapUsedKB: 0
  // ZRAM (aggregated) in KB
  property int zOrigKB: 0
  property int zCompKB: 0
  property int zMemKB: 0

  Process {
    id: memProc
    // Robust aus /proc/meminfo: Total, Available, Free, Buffers, Cached, SReclaimable, SwapTotal, SwapFree
    command: [
      "sh", "-c",
      "awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} /MemFree/ {f=$2} /^Buffers:/ {b=$2} /^Cached:/ {c=$2} /SReclaimable/ {sr=$2} /SwapTotal/ {st=$2} /SwapFree/ {sf=$2} END {printf(\"%d %d %d %d %d %d %d %d\\n\", t, a, f, b, c, sr, st, sf)}' /proc/meminfo"
    ]
    running: true

    stdout: SplitParser {
      onRead: data => {
        const parts = String(data).trim().split(/\s+/);
        if (parts.length >= 8) {
          totalKB = Number(parts[0]);
          availKB = Number(parts[1]);
          freeKB = Number(parts[2]);
          buffersKB = Number(parts[3]);
          cachedKB = Number(parts[4]);
          sreclaimKB = Number(parts[5]);
          swapTotalKB = Number(parts[6]);
          swapFreeKB = Number(parts[7]);
          swapUsedKB = Math.max(0, swapTotalKB - swapFreeKB);
          if (totalKB > 0 && !isNaN(availKB)) {
            percentUsed = Math.round(((totalKB - availKB) / totalKB) * 100);
          }
        }
      }
    }
  }

  // Aggregate ZRAM metrics (bytes -> KB) across all /sys/block/zram*/mm_stat if present
  Process {
    id: zramProc
    running: false
    command: [
      "sh", "-c",
      "orig=0; comp=0; mem=0; for f in /sys/block/zram*/mm_stat; do [ -r \"$f\" ] || continue; read od cd mu _ < \"$f\"; orig=$((orig+od)); comp=$((comp+cd)); mem=$((mem+mu)); done; echo $orig $comp $mem"
    ]
    stdout: SplitParser {
      onRead: data => {
        const parts = String(data).trim().split(/\s+/)
        if (parts.length >= 3) {
          const o = Number(parts[0])
          const c = Number(parts[1])
          const m = Number(parts[2])
          zOrigKB = isNaN(o) ? 0 : Math.round(o / 1024)
          zCompKB = isNaN(c) ? 0 : Math.round(c / 1024)
          zMemKB  = isNaN(m) ? 0 : Math.round(m / 1024)
        }
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: { memProc.running = true; zramProc.running = true }
  }

  // Tooltip mit detaillierten Infos (verwendet/gesamt in GB, 1 Nachkommastelle)
  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
  }

  PopupWindow {
    id: tipWindow
    visible: false
    implicitWidth: contentCol.implicitWidth + 20
    implicitHeight: contentCol.implicitHeight + 20
    color: "transparent"

    anchor {
      window: text.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = text.QsWindow?.window
        if (win) {
          const gap = 3
          tipWindow.anchor.rect.y = (Globals.barPosition === "top")
            ? (tipWindow.anchor.window.height + gap)
            : (-gap)
          tipWindow.anchor.rect.x = win.contentItem.mapFromItem(text, text.width / 2, 0).x
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
        Text {
          // compute GB inline: KB -> GB (divide by 1024^2)
          text: ((Math.max(totalKB - availKB, 0)) / 1048576).toFixed(1)
                + " / " + (totalKB / 1048576).toFixed(1) + " GB ("
                + Math.floor(percentUsed) + "%)"
          color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        }
        // Mini bar: Used | Cache | Free (avail-cached)
        Rectangle {
          width: 180; height: 8; radius: 4
          color: "#333333"; opacity: 0.6
          property real usedFrac: totalKB > 0 ? Math.max(0, Math.min(1, (totalKB - availKB) / totalKB)) : 0
          property real cacheFrac: totalKB > 0 ? Math.max(0, Math.min(1, cachedKB / totalKB)) : 0
          property real freeFrac: totalKB > 0 ? Math.max(0, 1 - usedFrac - cacheFrac) : 0
          Rectangle { id: usedBar; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; height: parent.height; width: parent.width * parent.usedFrac; radius: 4; color: Globals.moduleIconColor }
          Rectangle { id: cacheBar; anchors.left: usedBar.right; anchors.verticalCenter: parent.verticalCenter; height: parent.height; width: parent.width * parent.cacheFrac; radius: 0; color: Globals.workspaceActiveBg }
          Rectangle { anchors.left: cacheBar.right; anchors.verticalCenter: parent.verticalCenter; height: parent.height; width: parent.width * parent.freeFrac; radius: 0; color: Globals.barBorderColor }
        }
        // Details grid
        GridLayout {
          columns: 2
          columnSpacing: 8
          rowSpacing: 2
          Label { text: "Used:"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label { text: ((Math.max(totalKB - availKB, 0)) / 1048576).toFixed(1) + " GB"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label { text: "Cache:"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label { text: (cachedKB / 1048576).toFixed(1) + " GB"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label { text: "Free:"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label { text: (Math.max(availKB - cachedKB, 0) / 1048576).toFixed(1) + " GB"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label { text: "Available:"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label { text: (availKB / 1048576).toFixed(1) + " GB"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label { text: "Total:"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label { text: (totalKB / 1048576).toFixed(1) + " GB"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        }
        // Swap status
        RowLayout {
          spacing: 6
          Label { text: "Swap:"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label {
            color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
            text: (swapUsedKB / 1048576).toFixed(1) + " / " + (swapTotalKB / 1048576).toFixed(1) + " GB ("
                  + (swapTotalKB > 0 ? Math.round(swapUsedKB * 100 / swapTotalKB) : 0) + "%)"
          }
        }
        // ZRAM status (if present)
        RowLayout {
          visible: (zOrigKB + zCompKB + zMemKB) > 0
          spacing: 6
          Label { text: "ZRAM:"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
          Label {
            color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
            text: (zCompKB / 1048576).toFixed(1) + " / " + (zOrigKB / 1048576).toFixed(1) + " GB (x"
                  + (zCompKB > 0 ? (zOrigKB / zCompKB).toFixed(2) : "0.00") + ")"
          }
        }
      }
    }
  }
}
