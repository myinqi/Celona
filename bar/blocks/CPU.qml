import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // Display
  content: BarText {
    // CPU icon (Font Awesome microchip) + usage percent
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    // Fixed-width percent (0-100) to prevent layout shifts: pad to 3 chars
    property string percent3: isNaN(cpuPercent) ? "  -" : String(Math.floor(cpuPercent)).padStart(3, " ")
    symbolText: " " + percent3 + "%"
  }

  // Data
  property real cpuPercent: 0
  property string loadavg1: "-"
  property string loadavg5: "-"
  property string loadavg15: "-"
  property string cpuFreqGHz: "-"       // average current frequency in GHz
  property int logicalCores: 0
  // removed top processes list for a cleaner tooltip
  property string cpuTempC: "-"        // CPU temperature in °C
  // Current scaling governor
  property string governor: "-"
  // CPU type info
  property string cpuModel: "-"
  property string cpuVendor: "-"
  property string cpuArch: "-"
  // CPU usage history buffer (last ~60 seconds at 2s interval ≈ 30 samples)
  property var cpuHistory: []   // array of percent values (0..100)
  property int cpuHistMax: 30

  // Compute CPU usage by sampling /proc/stat twice and calculating deltas
  Process {
    id: cpuProc
    command: [
      "sh", "-c",
      "l1=$(grep '^cpu ' /proc/stat); sleep 0.4; l2=$(grep '^cpu ' /proc/stat); " +
      "awk -v a=\"$l1\" -v b=\"$l2\" 'BEGIN{split(a,x); split(b,y); " +
      "t1=x[2]+x[3]+x[4]+x[5]+x[6]+x[7]+x[8]+x[9]; id1=x[5]+x[6]; " +
      "t2=y[2]+y[3]+y[4]+y[5]+y[6]+y[7]+y[8]+y[9]; id2=y[5]+y[6]; " +
      "p=(1- (id2-id1)/(t2-t1))*100; if (p<0) p=0; if (p>100) p=100; printf(\"%.0f\\n\", p)}'"
    ]
    running: true

    stdout: SplitParser {
      onRead: data => {
        var v = Number(String(data).trim())
        root.cpuPercent = v
        if (!isNaN(v)) {
          var vv = Math.max(0, Math.min(100, Math.floor(v)))
          root.cpuHistory.push(vv)
          // keep only last cpuHistMax samples
          while (root.cpuHistory.length > root.cpuHistMax) root.cpuHistory.shift()
        }
      }
    }
  }

  // Tooltip like Date/GPU using PopupWindow
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
        Text { text: "Usage: " + (isNaN(root.cpuPercent) ? "-" : (Math.floor(root.cpuPercent) + "%")) + "  |  Load: " + root.loadavg1 + ", " + root.loadavg5 + ", " + root.loadavg15; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        // 60s CPU usage histogram (time on X recent→rechts, usage on Y)
        Canvas {
          id: cpuHist
          width: parent.width; height: 48
          antialiasing: false
          onPaint: {
            const ctx = getContext("2d")
            const w = width, h = height
            // clear
            ctx.clearRect(0, 0, w, h)
            // background
            ctx.globalAlpha = 0.6
            ctx.fillStyle = "#333333"
            ctx.fillRect(0, 0, w, h)
            ctx.globalAlpha = 1.0
            // axes
            const axisColor = (Globals.tooltipText && Globals.tooltipText !== "") ? Globals.tooltipText : "#FFFFFF"
            ctx.strokeStyle = axisColor
            ctx.lineWidth = 1
            // baseline (0%) and 100% line (faint)
            ctx.beginPath(); ctx.moveTo(0, h-1); ctx.lineTo(w, h-1); ctx.stroke()
            ctx.globalAlpha = 0.2
            ctx.beginPath(); ctx.moveTo(0, 1); ctx.lineTo(w, 1); ctx.stroke()
            ctx.globalAlpha = 1.0
            // draw bars
            const barColor = (Globals.moduleIconColor && Globals.moduleIconColor !== "") ? Globals.moduleIconColor : "#89b4fa"
            ctx.fillStyle = barColor
            // map last N samples across width (right = most recent)
            var n = root.cpuHistory.length
            if (n > 0) {
              var maxBars = w  // 1px bars
              var step = Math.max(1, Math.floor(n / maxBars))
              var x = w - 1
              for (var i = n - 1; i >= 0 && x >= 0; i -= step, x--) {
                var val = Math.max(0, Math.min(100, root.cpuHistory[i]))
                var bh = Math.max(1, Math.round((val / 100) * (h - 2)))
                ctx.fillRect(x, h - 1 - bh, 1, bh)
              }
            }
          }
        }
        Text { text: "Temp: " + (root.cpuTempC !== "-" ? (root.cpuTempC + " °C") : "-"); color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { text: "Gov: " + root.governor; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { text: "CPU: " + root.cpuModel; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { text: "vCPUs: " + root.logicalCores; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
        Text { text: "Freq: " + root.cpuFreqGHz + " GHz (avg all cores)"; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF" }
      }
    }
  }

  // Read load averages for tooltip
  Process {
    id: loadProc
    command: ["sh", "-c", "awk '{printf(\"%s %s %s\\n\", $1,$2,$3)}' /proc/loadavg"]
    running: true

    stdout: SplitParser {
      onRead: data => {
        const parts = String(data).trim().split(/\s+/)
        if (parts.length >= 3) {
          root.loadavg1 = parts[0]
          root.loadavg5 = parts[1]
          root.loadavg15 = parts[2]
        }
      }
    }
  }

  // Read logical cores count
  Process {
    id: coresProc
    command: ["sh", "-c", "nproc"]
    running: true
    stdout: SplitParser { onRead: data => root.logicalCores = Number(String(data).trim()) }
  }

  // Read current average CPU frequency in GHz
  Process {
    id: freqProc
    command: [
      "sh", "-c",
      "files=/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; " +
      "if ls $files >/dev/null 2>&1; then awk '{sum+=$1} END {if(NR>0) printf(\"%.1f\\n\", sum/NR/1000000)}' $files; " +
      "else awk -F: '/cpu MHz/ {s+=$2; n++} END {if(n) printf(\"%.1f\\n\", s/n/1000)}' /proc/cpuinfo; fi"
    ]
    running: true
    stdout: SplitParser { onRead: data => root.cpuFreqGHz = String(data).trim() }
  }

  // Read CPU temperature (sysfs hwmon preferred, fallback to sensors)
  Process {
    id: tempProc
    command: [
      "sh", "-c",
      "# Prefer thermal_zone matching CPU-related types\n" +
      "for z in /sys/class/thermal/thermal_zone*; do " +
      "  [ -r \"$z/temp\" ] || continue; ty=$(cat \"$z/type\" 2>/dev/null); " +
      "  echo \"$ty\" | grep -Ei 'x86_pkg_temp|k10temp|cpu_thermal|tctl|tdie|cpu' >/dev/null && awk '{printf(\"%.1f\\n\", $1/1000)}' \"$z/temp\" && exit 0; " +
      "done; " +
      "# Fallback: highest hwmon temp*_input\n" +
      "mx=-1000000; for i in /sys/class/hwmon/hwmon*/temp*_input; do " +
      "  [ -r \"$i\" ] || continue; v=$(cat \"$i\" 2>/dev/null); [ \"$v\" -gt \"$mx\" ] 2>/dev/null && mx=\"$v\"; " +
      "done; " +
      "if [ \"$mx\" -ne -1000000 ] 2>/dev/null; then awk -v t=\"$mx\" 'BEGIN{printf(\"%.1f\\n\", t/1000)}'; exit 0; fi; " +
      "# Fallback: lm-sensors\n" +
      "if command -v sensors >/dev/null 2>&1; then sensors 2>/dev/null | awk '/Package id 0:|Tctl:|Tdie:|CPU:/{for(i=1;i<=NF;i++) if ($i ~ /[0-9]+(\\.[0-9]+)?/) {gsub(/[^0-9.]/, \"\", $i); print $i; exit}}'; fi"
    ]
    running: true
    stdout: SplitParser { onRead: data => { const v = String(data).trim(); root.cpuTempC = v.length ? v : "-" } }
  }

  // Current CPU scaling governor (first CPU as representative)
  Process {
    id: govProc
    command: [
      "sh", "-c",
      "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if [ -r \"$f\" ]; then cat \"$f\"; exit 0; fi; done; echo '-'"
    ]
    running: true
    stdout: SplitParser { onRead: data => root.governor = String(data).trim() }
  }

  // CPU model/vendor (from /proc/cpuinfo) and arch (uname -m)
  Process {
    id: cpuInfoProc
    command: [
      "sh", "-c",
      "model='-'; vendor='-'; if [ -r /proc/cpuinfo ]; then model=$(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo | sed 's/^ *//'); vendor=$(awk -F: '/vendor_id/{print $2; exit}' /proc/cpuinfo | sed 's/^ *//'); fi; arch=$(uname -m); printf '%s|%s|%s\n' \"$model\" \"$vendor\" \"$arch\""
    ]
    running: true
    stdout: SplitParser { onRead: data => { const s = String(data).trim().split('|'); root.cpuModel = s[0] || '-'; root.cpuVendor = s[1] || '-'; root.cpuArch = s[2] || '-' } }
  }

  // Top CPU processes (pid, command, %CPU)
  // (removed)

  // Refresh timers
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: { cpuProc.running = true; loadProc.running = true; freqProc.running = true; coresProc.running = true; tempProc.running = true; govProc.running = true; cpuInfoProc.running = true; if (cpuHist) cpuHist.requestPaint() }
  }

}
