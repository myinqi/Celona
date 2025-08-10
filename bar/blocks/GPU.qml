import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // Display: GPU icon + usage percent
  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    // GPU-Icon (Nerd Font). Bei fehlender Glyph zeigt die Schriftart ein Ersatzsymbol.
    // Icon kann bei Bedarf vom Nutzer überschrieben werden.
    // Fixed-width percent (0-100) to prevent layout shifts
    property string percent3: isNaN(gpuPercent) ? "  -" : String(Math.floor(gpuPercent)).padStart(3, " ")
    symbolText: root.iconGlyph + " " + percent3 + "%"
  }

  // Data
  // Anpassbares Icon-Glyph (Symbols Nerd Font Mono). Standard: nf-md-gpu
  property string iconGlyph: "󰢮"
  property real gpuPercent: NaN
  property string gpuModel: "-"
  property string gpuDriver: "-"
  property string usedGB: "-"
  property string totalGB: "-"
  property string tempC: "-"
  property string cardPath: ""   // e.g. /sys/class/drm/card0
  property string backend: "auto" // "nvidia" | "amdgpu" | "other"

  // Detect GPU model, driver, and pick a card path
  Process {
    id: gpuInfoProc
    command: [
      "sh", "-c",
      // Wähle bevorzugt NVIDIA-Karte, sonst erste
      "card=''; for c in /sys/class/drm/card*; do [ -e \"$c\" ] || continue; v=$(cat \"$c/device/vendor\" 2>/dev/null); if [ \"$v\" = 0x10de ]; then card=$c; break; fi; done; " +
      "[ -n \"$card\" ] || card=$(ls -1d /sys/class/drm/card* 2>/dev/null | head -n1); [ -n \"$card\" ] || card=/sys/class/drm/card0; " +
      // Treibername
      "drv=$(basename \"$(readlink -f $card/device/driver 2>/dev/null)\" 2>/dev/null); [ -n \"$drv\" ] || drv='-'; " +
      // nvidia-smi Pfad suchen
      "nv=''; for p in nvidia-smi /usr/bin/nvidia-smi /bin/nvidia-smi /usr/local/bin/nvidia-smi /run/current-system/sw/bin/nvidia-smi; do command -v $p >/dev/null 2>&1 && { nv=$(command -v $p); break; }; [ -x \"$p\" ] && { nv=$p; break; }; done; " +
      // Backend bestimmen (nvidia auch für 'nvidia-open')
      "case \"$drv\" in nvidia*) drv_is_nv=1;; *) drv_is_nv=0;; esac; " +
      "if [ -n \"$nv\" ] || [ \"$drv_is_nv\" = 1 ]; then be=nvidia; elif [ \"$drv\" = amdgpu ]; then be=amdgpu; else be=other; fi; " +
      // Modell/Treiber-Version
      "if [ \"$be\" = nvidia ] && [ -n \"$nv\" ]; then model=$($nv --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1); drvver=$($nv --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1); [ -n \"$drvver\" ] && drv=\"nvidia $drvver\"; fi; " +
      "[ -n \"$model\" ] || model=$(lspci -nn | grep -E 'VGA|3D' | head -n1 | cut -d: -f3- | sed 's/^ //'); [ -n \"$model\" ] || model='-'; " +
      "printf '%s\t%s\t%s\t%s\n' \"$card\" \"$drv\" \"$model\" \"$be\";"
    ]
    running: true
    stdout: SplitParser {
      onRead: data => {
        const txt = String(data).trim()
        const last = txt.split(/\n/).pop()
        const parts = last.split(/\t/)
        if (parts.length >= 4) {
          root.cardPath = parts[0]
          root.gpuDriver = parts[1]
          root.gpuModel = parts[2]
          root.backend = parts[3]
          // Trigger first poll immediately after detection
          if (root.backend === "nvidia") {
            memProc.command = [
              "sh", "-c",
              "nv=''; for p in nvidia-smi /usr/bin/nvidia-smi /bin/nvidia-smi /usr/local/bin/nvidia-smi /run/current-system/sw/bin/nvidia-smi; do command -v $p >/dev/null 2>&1 && { nv=$(command -v $p); break; }; [ -x \"$p\" ] && { nv=$p; break; }; done; " +
              "[ -n \"$nv\" ] || exit 0; out=$($nv --query-gpu=memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1); " +
              "used=$(echo \"$out\" | cut -d, -f1 | tr -d ' '); total=$(echo \"$out\" | cut -d, -f2 | tr -d ' '); temp=$(echo \"$out\" | cut -d, -f3 | tr -d ' '); " +
              "if [ -n \"$used\" ] && [ -n \"$total\" ]; then perc=$((100*used/total)); usedgb=$(awk -v u=$used 'BEGIN{printf(\"%.1f\", u/1024)}'); totalgb=$(awk -v t=$total 'BEGIN{printf(\"%.1f\", t/1024)}'); printf '%s %s %s %s\n' \"$perc\" \"$usedgb\" \"$totalgb\" \"$temp\"; fi"
            ]
            memProc.running = true
          } else if (root.backend === "amdgpu") {
            const card = (root.cardPath && root.cardPath.length) ? root.cardPath : ""
            const cmd =
              "card=\"" + card + "\"; [ -d \"$card\" ] || card=$(ls -1d /sys/class/drm/card* 2>/dev/null | head -n1); " +
              "dev=$card/device; usedf=$dev/mem_info_vram_used; totalf=$dev/mem_info_vram_total; " +
              "tempf=$(ls -1 $dev/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1); " +
              "if [ -r \"$usedf\" ] && [ -r \"$totalf\" ]; then used=$(cat \"$usedf\"); total=$(cat \"$totalf\"); " +
              "  perc=$(awk -v u=$used -v t=$total 'BEGIN{if(t>0) printf(\"%d\", (u*100)/t); else print 0}'); " +
              "  usedgb=$(awk -v u=$used 'BEGIN{printf(\"%.1f\", u/1073741824)}'); totalgb=$(awk -v t=$total 'BEGIN{printf(\"%.1f\", t/1073741824)}'); " +
              "  if [ -r \"$tempf\" ]; then temp=$(awk '{printf(\"%.0f\", $1/1000)}' \"$tempf\"); else temp='-'; fi; " +
              "  printf '%s %s %s %s\\n' \"$perc\" \"$usedgb\" \"$totalgb\" \"$temp\"; fi"
            memProcAmd.command = ["sh", "-c", cmd]
            memProcAmd.running = true
          } else {
            tempFallback.running = true
          }
        }
      }
    }
  }

  // Poll memory usage (percent, used/total GB)
  Process {
    id: memProc
    command: [
      "sh", "-c",
      // NVIDIA via nvidia-smi
      "if command -v nvidia-smi >/dev/null 2>&1; then " +
      "  out=$(nvidia-smi --query-gpu=memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1); " +
      "  used=$(echo \"$out\" | awk -F, '{gsub(/ /,\"\"); print $1}'); total=$(echo \"$out\" | awk -F, '{gsub(/ /,\"\"); print $2}'); temp=$(echo \"$out\" | awk -F, '{gsub(/ /,\"\"); print $3}'); " +
      "  if [ -n \"$used\" ] && [ -n \"$total\" ]; then perc=$((100*used/total)); printf '%s %s %s %s\\n' $perc $(awk 'BEGIN{printf(\"%.1f\", ' +
      // used GB
      '0)}') ; fi; fi"
    ]
    running: false
    stdout: SplitParser {
      onRead: data => {
        const txt = String(data).trim()
        const last = txt.split(/\n/).pop()
        const parts = last.split(/\s+/)
        if (parts.length >= 4) {
          root.gpuPercent = Number(parts[0])
          root.usedGB = parts[1]
          root.totalGB = parts[2]
          root.tempC = parts[3]
        } else {
          root.gpuPercent = NaN
          root.usedGB = "-"
          root.totalGB = "-"
          root.tempC = "-"
        }
      }
    }
  }

  // AMD path (amdgpu via sysfs)
  Process {
    id: memProcAmd
    running: false
    command: []
    stdout: SplitParser {
      onRead: data => {
        const txt = String(data).trim()
        const last = txt.split(/\n/).pop()
        const parts = last.split(/\s+/)
        if (parts.length >= 4) {
          root.gpuPercent = Number(parts[0])
          root.usedGB = parts[1]
          root.totalGB = parts[2]
          root.tempC = parts[3]
        } else {
          root.gpuPercent = NaN
          root.usedGB = "-"
          root.totalGB = "-"
          root.tempC = "-"
        }
      }
    }
  }

  // Temperature fallback via thermal zones if needed
  Process {
    id: tempFallback
    command: [
      "sh", "-c",
      "for z in /sys/class/thermal/thermal_zone*; do [ -r \"$z/type\" ] || continue; ty=$(cat \"$z/type\"); echo \"$ty\" | grep -Ei 'gpu|amdgpu|nvidia' >/dev/null || continue; if [ -r \"$z/temp\" ]; then awk '{printf(\"%.0f\\n\", $1/1000)}' \"$z/temp\"; exit; fi; done"
    ]
    running: false
    stdout: SplitParser { onRead: data => { const v = String(data).trim(); if (v.length) root.tempC = v } }
  }

  // Refresh timer
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      if (root.backend === "nvidia") {
        // Build the command with proper arithmetic and printing for used/total in GB
        memProc.command = [
          "sh", "-c",
          "nv=''; for p in nvidia-smi /usr/bin/nvidia-smi /bin/nvidia-smi /usr/local/bin/nvidia-smi /run/current-system/sw/bin/nvidia-smi; do command -v $p >/dev/null 2>&1 && { nv=$(command -v $p); break; }; [ -x \"$p\" ] && { nv=$p; break; }; done; " +
          "[ -n \"$nv\" ] || exit 0; out=$($nv --query-gpu=memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1); " +
          "used=$(echo \"$out\" | cut -d, -f1 | tr -d ' '); total=$(echo \"$out\" | cut -d, -f2 | tr -d ' '); temp=$(echo \"$out\" | cut -d, -f3 | tr -d ' '); " +
          "if [ -n \"$used\" ] && [ -n \"$total\" ]; then perc=$((100*used/total)); usedgb=$(awk -v u=$used 'BEGIN{printf(\"%.1f\", u/1024)}'); totalgb=$(awk -v t=$total 'BEGIN{printf(\"%.1f\", t/1024)}'); printf '%s %s %s %s\\n' \"$perc\" \"$usedgb\" \"$totalgb\" \"$temp\"; fi"
        ]
        memProc.running = true
      } else if (root.backend === "amdgpu") {
        // Build AMD sysfs command with the current cardPath
        const card = (root.cardPath && root.cardPath.length) ? root.cardPath : ""
        const cmd =
          "card=\"" + card + "\"; [ -d \"$card\" ] || card=$(ls -1d /sys/class/drm/card* 2>/dev/null | head -n1); " +
          "dev=$card/device; usedf=$dev/mem_info_vram_used; totalf=$dev/mem_info_vram_total; " +
          "tempf=$(ls -1 $dev/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1); " +
          "if [ -r \"$usedf\" ] && [ -r \"$totalf\" ]; then used=$(cat \"$usedf\"); total=$(cat \"$totalf\"); " +
          "  perc=$(awk -v u=$used -v t=$total 'BEGIN{if(t>0) printf(\\\"%d\\\", (u*100)/t); else print 0}'); " +
          "  usedgb=$(awk -v u=$used 'BEGIN{printf(\\\"%.1f\\\", u/1073741824)}'); totalgb=$(awk -v t=$total 'BEGIN{printf(\\\"%.1f\\\", t/1073741824)}'); " +
          "  if [ -r \"$tempf\" ]; then temp=$(awk '{printf(\\\"%.0f\\\", $1/1000)}' \"$tempf\"); else temp='-'; fi; " +
          "  printf '%s\\n%s\\n%s\\n%s\\n' \"$perc\" \"$usedgb\" \"$totalgb\" \"$temp\"; fi"
        memProcAmd.command = ["sh", "-c", cmd]
        memProcAmd.running = true
      } else {
        // Unknown backend: at least try to get temperature
        tempFallback.running = true
      }
    }
  }

  // Tooltip like Date module using PopupWindow
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
        Text { text: "Model: " + root.gpuModel; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { text: "Driver: " + root.gpuDriver; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { text: "VRAM: " + (root.usedGB !== "-" ? (root.usedGB + " / " + root.totalGB + " GB") : "-"); color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { text: "Temp: " + (root.tempC !== "-" ? (root.tempC + " °C") : "-"); color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
      }
    }
  }
}
