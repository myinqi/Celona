import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "root:/"

BarBlock {
  id: root

  // Display: storage icon + free space percent of root partition
  content: BarText {
    mainFont: Globals.mainFontFamily
    symbolFont: "Symbols Nerd Font Mono"
    // Fixed-width percent (0-100) to prevent layout shifts: pad to 3 chars
    property string percent3: String(Math.floor(rootFreePercent)).padStart(3, " ")
    symbolText: "󰋊 " + percent3 + "%"
  }

  // Root partition data
  property real rootFreePercent: 0
  property real rootUsedGB: 0
  property real rootTotalGB: 0
  property real rootFreeGB: 0
  
  // All partitions/drives for tooltip (array of objects)
  property var drives: []
  property int drivesVersion: 0  // Increment to force repaint
  
  // Format size with appropriate unit (M, G, T)
  function formatSize(gb) {
    if (gb < 1) {
      return (gb * 1024).toFixed(1) + "M"
    } else if (gb < 1024) {
      return gb.toFixed(1) + "G"
    } else {
      return (gb / 1024).toFixed(1) + "T"
    }
  }

  // Get root partition free space percentage
  Process {
    id: rootProc
    command: [
      "sh", "-c",
      "df -BG / | awk 'NR==2 {used=$3; total=$2; free=$4; gsub(/G/, \"\", used); gsub(/G/, \"\", total); gsub(/G/, \"\", free); pct=(free/total)*100; printf(\"%.1f %.1f %.1f %.1f\\n\", pct, used, total, free)}'"
    ]
    running: true

    stdout: SplitParser {
      onRead: data => {
        const parts = String(data).trim().split(/\s+/)
        if (parts.length >= 4) {
          rootFreePercent = Number(parts[0])
          rootUsedGB = Number(parts[1])
          rootTotalGB = Number(parts[2])
          rootFreeGB = Number(parts[3])
        }
      }
    }
  }

  // Accumulator for drive data
  property var driveDataAccumulator: []
  
  // Get all mounted drives for tooltip
  Process {
    id: drivesProc
    command: [
      "sh", "-c",
      // Get all mounted filesystems with device name and filesystem type from df -T
      "df -BG -T -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs | awk 'NR>1 {device=$1; fstype=$2; total=$3; used=$4; free=$5; mount=$7; gsub(/G/, \"\", used); gsub(/G/, \"\", total); gsub(/G/, \"\", free); pct=(used/total)*100; printf(\"%s|%.1f|%.1f|%.1f|%.1f|%s|%s\\n\", mount, used, total, free, pct, device, fstype)}'"
    ]
    running: false

    stdout: SplitParser {
      onRead: data => {
        const line = String(data).trim()
        if (!line) return
        
        const parts = line.split('|')
        
        // Check if it's df data (7 parts: mount|used|total|free|pct|device|fstype)
        if (parts.length >= 7) {
          const device = parts[5].split('/').pop() || parts[5]
          // Filter duplicates (btrfs subvolumes)
          const existing = root.driveDataAccumulator.findIndex(d => d.device === device && d.mount === parts[0])
          if (existing === -1) {
            root.driveDataAccumulator.push({
              mount: parts[0],
              usedGB: Number(parts[1]),
              totalGB: Number(parts[2]),
              freeGB: Number(parts[3]),
              usedPercent: Number(parts[4]),
              device: device,
              fstype: parts[6] || "unknown"
            })
          }
        }
      }
    }
    
    onExited: {
      // Filter out btrfs subvolumes - keep only unique devices or main mounts
      const uniqueDrives = []
      const seenDevices = new Set()
      
      for (let drive of root.driveDataAccumulator) {
        // Skip boot partition
        if (drive.mount === "/boot/efi" || drive.mount.startsWith("/boot")) {
          continue
        }
        
        // For btrfs, only show the first (main) mount point for each device
        if (drive.fstype === "btrfs") {
          if (!seenDevices.has(drive.device)) {
            seenDevices.add(drive.device)
            uniqueDrives.push(drive)
          }
        } else {
          uniqueDrives.push(drive)
        }
      }
      
      root.drives = uniqueDrives
      root.driveDataAccumulator = []
      root.drivesVersion++
    }
  }

  // Tooltip with drive details
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
    implicitWidth: Math.max(400, contentCol.width + 20)
    implicitHeight: Math.max(60, contentCol.height + 20)
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
        x: 10
        y: 10
        spacing: 3
        width: childrenRect.width
        height: childrenRect.height

        // Title
        Text {
          text: "Storage (" + root.drives.length + " drives)"
          color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
          font.family: Globals.mainFontFamily
          font.pixelSize: Globals.mainFontSize
          font.bold: true
        }

        // Drives list
        Repeater {
          model: root.drives
          delegate: Item {
            width: driveRow.implicitWidth
            height: driveRow.implicitHeight
            
            RowLayout {
              id: driveRow
              spacing: 0
            
            // Progress bar with percentage
            Rectangle {
              width: 80
              height: 14
              radius: 4
              color: "#333333"
              opacity: 0.6
              
              property real usedFrac: Math.max(0, Math.min(1, modelData.usedPercent / 100))
              
              Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: parent.width * parent.usedFrac
                radius: 4
                // Color based on usage: green -> yellow -> red
                color: {
                  if (modelData.usedPercent < 70) {
                    return Globals.moduleIconColor !== "" ? Globals.moduleIconColor : "#89b4fa"
                  } else if (modelData.usedPercent < 90) {
                    return "#f9e2af" // yellow
                  } else {
                    return "#f38ba8" // red
                  }
                }
              }
            }
            
            // Percentage
            Text {
              text: String(Math.floor(modelData.usedPercent)).padStart(3, " ") + "%"
              color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              font.family: "monospace"
              font.pixelSize: Globals.mainFontSize - 1
              Layout.preferredWidth: 50
            }
            
            // Device name
            Text {
              text: modelData.device || "device"
              color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              font.family: "monospace"
              font.pixelSize: Globals.mainFontSize - 1
              elide: Text.ElideRight
              Layout.preferredWidth: 85
            }
            
            // Size info
            Text {
              text: root.formatSize(modelData.usedGB) + "/" + root.formatSize(modelData.totalGB)
              color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              font.family: "monospace"
              font.pixelSize: Globals.mainFontSize - 1
              Layout.preferredWidth: 120
            }
            
            // Filesystem type
            Text {
              text: "[" + (modelData.fstype || "?") + "]"
              color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              font.family: "monospace"
              font.pixelSize: Globals.mainFontSize - 1
              Layout.preferredWidth: 70
            }
            
            // Mount point
            Text {
              text: {
                let mount = modelData.mount
                // Remove /run/media/<user>/ prefix for cleaner display
                const mediaMatch = mount.match(/^\/run\/media\/[^\/]+\/(.+)$/)
                if (mediaMatch) {
                  return mediaMatch[1]
                }
                return mount
              }
              color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
              font.family: "monospace"
              font.pixelSize: Globals.mainFontSize - 1
              elide: Text.ElideMiddle
              Layout.fillWidth: true
            }
            }
          }
        }
      }
    }
  }

  // Refresh timer
  Timer {
    interval: 5000  // Update every 5 seconds
    running: true
    repeat: true
    onTriggered: {
      rootProc.running = true
      drivesProc.running = true
    }
  }
}
