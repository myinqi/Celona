import QtQuick
import Quickshell.Io
import "../"

BarBlock {
  property string battery: ""
  property bool hasBattery: false
  // Show when we have any display string (also for no-battery placeholder)
  visible: battery.length > 0
  
  content: BarText {
    // Ensure consistent fonts and icon coloring
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolText: battery
  }

  Process {
    id: batteryCheck
    command: ["sh", "-c", "test -d /sys/class/power_supply/BAT*"]
    running: true
    onExited: function(exitCode) {
      hasBattery = exitCode === 0
      // If no battery present, show mains power plug as placeholder (PUA glyph so BarText colors it with iconColor)
      if (!hasBattery) {
        battery = "" // Font Awesome plug (PUA), rendered from Nerd Font, gets iconColor
      }
    }
  }

  Process {
    id: batteryProc
    // Modify command to get both capacity and status in one call
    command: ["sh", "-c", "echo $(cat /sys/class/power_supply/BAT*/capacity),$(cat /sys/class/power_supply/BAT*/status)"]
    running: hasBattery

    stdout: SplitParser {
      onRead: function(data) {
        const [capacityStr, status] = data.trim().split(',')
        const capacity = parseInt(capacityStr)
        let batteryIcon = "󰂂"
        if (capacity <= 20) batteryIcon = "󰁺"
        else if (capacity <= 40) batteryIcon = "󰁽"
        else if (capacity <= 60) batteryIcon = "󰁿"
        else if (capacity <= 80) batteryIcon = "󰂁"
        else batteryIcon = "󰂂"
        
        // Use PUA plug so BarText applies iconColor; avoids emoji fallback coloring
        const symbol = status === "Charging" ? "" : batteryIcon
        battery = `${symbol} ${capacity}%`
      }
    }
  }

  Timer {
    interval: 1000
    running: hasBattery
    repeat: true
    onTriggered: batteryProc.running = true
  }
}
