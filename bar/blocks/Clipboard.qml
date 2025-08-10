import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../"
import "root:/"

BarBlock {
  id: root

  // Appearance
  property string iconGlyph: "󰅌" // nf-md-clipboard-text-outline
  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    // Show icon and the current number of history entries
    // Fixed-width numeric area (0–999): pad to 3 chars to prevent layout shifts
    property string count3: String(root.entryCount).padStart(3, " ")
    symbolText: `${root.iconGlyph} ${count3}`
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
        text: "Left: Clipboard history\nRight: Delete history"
        color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }

  // Small management popup for right-click actions (e.g., clear history)
  PopupWindow {
    id: manageWindow
    implicitWidth: 260
    implicitHeight: 120
    visible: false
    color: "transparent"

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
            : (-(manageWindow.implicitHeight + gap))
          const x = -(manageWindow.implicitWidth - root.width) / 2
          const rect = win.contentItem.mapFromItem(root, x, y, manageWindow.implicitWidth, manageWindow.implicitHeight)
          manageWindow.anchor.rect = rect
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
      border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
      border.width: 1
      radius: 8

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Label {
          text: "Delete clipboard history?"
          color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: 8
          Button {
            text: "Cancel"
            onClicked: manageWindow.visible = false
          }
          Button {
            text: "Delete"
            onClicked: { manageWindow.visible = false; wipeProc.running = true }
          }
        }
      }
    }
  }

  // Periodically refresh the latest entry ID so the badge updates without opening the popup
  Timer {
    id: badgeTimer
    interval: 4000
    repeat: true
    running: true
    onTriggered: { refreshLastId(); refreshCount() }
  }

  // Data
  property var entries: [] // [{id: string, text: string}]
  property var filtered: []
  // Internal buffer to coalesce streaming output without resetting scroll/focus repeatedly
  property var _buf: []
  // Live count of cliphist entries (kept in sync independently of popup)
  property int entryCount: 0
  // Latest entry ID from cliphist
  property int entryLastId: 0

  function refreshCount() {
    if (countProc.running) countProc.running = false
    Qt.callLater(() => countProc.running = true)
  }
  function refreshLastId() {
    if (lastIdProc.running) lastIdProc.running = false
    Qt.callLater(() => lastIdProc.running = true)
  }

  function updateFiltered() {
    // No search for now; show all entries. ListView handles scroll/height.
    filtered = Array.isArray(entries) ? entries : []
  }

  // Poll cliphist list when popup opens and periodically while open
  Process {
    id: listProc
    // Load full history; we limit UI height and allow scrolling instead
    command: ["sh", "-c", "/usr/bin/cliphist list"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        try {
          const text = String(data)
          const lines = text.split(/\n/).filter(l => l.length)
          const out = []
          for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            // Accept both tab and spaces: "<id>\t<preview>" or "<id> <preview>"
            const m = line.match(/^\s*(\d+)\s+(.*)$/)
            if (m) out.push({ id: m[1], text: m[2] })
          }
          if (out.length) {
            // Accumulate in buffer; we apply once after the process completes to avoid UI resets
            root._buf = (Array.isArray(root._buf) ? root._buf : []).concat(out)
          }
          // console.log(`[Clipboard] Parsed ${out.length} items (buffer size now: ${root._buf?.length || 0})`)
        } catch (e) {
          console.log(`[Clipboard] Parse error: ${e}`)
        }
      }
    }
    onRunningChanged: {
      if (!running) {
        const prevY = listView.contentY
        root.entries = (Array.isArray(root._buf) ? root._buf : [])
        root._buf = []
        root.updateFiltered()
        // Restore scroll position (should be 0 on first load, but keeps user position if they scrolled while loading)
        Qt.callLater(() => listView.contentY = prevY)
      }
    }
    stderr: SplitParser { onRead: data => console.log(`[Clipboard] STDERR: ${String(data)}`) }
  }

  // Lightweight counter process for accurate icon badge
  Process {
    id: countProc
    running: false
    command: ["sh", "-c", "/usr/bin/cliphist list | wc -l"]
    stdout: SplitParser {
      onRead: data => {
        const s = String(data).trim()
        const n = parseInt(s)
        if (!isNaN(n)) root.entryCount = n
      }
    }
    stderr: SplitParser { onRead: data => console.log(`[Clipboard] COUNT ERR: ${String(data)}`) }
  }

  // Lightweight process to fetch the latest entry ID
  Process {
    id: lastIdProc
    running: false
    // Take the first line (newest) and extract the first field (ID)
    command: ["sh", "-c", "/usr/bin/cliphist list | head -n1 | awk '{print $1}'"]
    stdout: SplitParser {
      onRead: data => {
        const s = String(data).trim()
        const n = parseInt(s)
        if (!isNaN(n)) root.entryLastId = n
      }
    }
    stderr: SplitParser { onRead: data => console.log(`[Clipboard] LASTID ERR: ${String(data)}`) }
  }

  function refreshList() {
    // Reset entries before fresh read
    root.entries = []
    root._buf = []
    // Restart the process to ensure a new run
    if (listProc.running) listProc.running = false
    Qt.callLater(() => listProc.running = true)
  }

  // Copy selected entry to clipboard
  function copyEntry(id) {
    if (!id) return
    console.log(`[Clipboard] Copy requested for id=${id}`)
    // Use --trim-newline to avoid trailing newline issues for text
    copyProc.command = ["sh", "-c", `/usr/bin/cliphist decode ${id} | /usr/bin/wl-copy --trim-newline`]
    copyProc.running = true
  }

  Process {
    id: copyProc
    running: false
    stdout: SplitParser { onRead: data => console.log(`[Clipboard] COPY OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Clipboard] COPY ERR: ${String(data)}`) }
    onRunningChanged: {
      if (!running) {
        console.log(`[Clipboard] Copy finished`)
        // Update count after copying (new entry in history)
        refreshCount()
        refreshLastId()
      }
    }
  }

  // Wipe history process
  Process {
    id: wipeProc
    running: false
    command: ["sh", "-c", "/usr/bin/cliphist wipe && /usr/bin/wl-copy -c"]
    stdout: SplitParser { onRead: data => console.log(`[Clipboard] WIPE OUT: ${String(data)}`) }
    stderr: SplitParser { onRead: data => console.log(`[Clipboard] WIPE ERR: ${String(data)}`) }
    onRunningChanged: {
      if (!running) {
        console.log(`[Clipboard] Wipe finished`)
        root.entries = []
        root.filtered = []
        root.entryCount = 0
        root.entryLastId = 0
        refreshCount(); refreshLastId()
        if (menuWindow.visible) menuWindow.visible = false
        if (manageWindow.visible) manageWindow.visible = false
      }
    }
  }

  // Initialize indicators at startup
  Component.onCompleted: { refreshCount(); refreshLastId() }

  // Popup UI as a separate window (like Sound), anchored unter dem Block
  MouseArea {
    id: clickArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    onEntered: tipWindow.visible = true
    onExited: tipWindow.visible = false
    onClicked: (mouse) => {
      tipWindow.visible = false
      if (!root.QsWindow?.window?.contentItem) return
      // Compute anchor rect relative to the block, opening below (top bar) or above (bottom bar)
      const gap = 5
      const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(menuWindow.implicitHeight + gap))
      const x = -(menuWindow.implicitWidth - root.width) / 2
      const rect = root.QsWindow.window.contentItem.mapFromItem(root, x, y, menuWindow.implicitWidth, menuWindow.implicitHeight)
      if (mouse.button === Qt.LeftButton) {
        menuWindow.anchor.rect = rect
        menuWindow.visible = !menuWindow.visible
        if (menuWindow.visible) {
          // Refresh once on open. Disable periodic refresh to avoid stealing focus and resetting scroll.
          refreshList()
        } else {
          if (listProc.running) listProc.running = false
        }
      } else if (mouse.button === Qt.RightButton) {
        // Compute rect for manageWindow with its own size
        const my = (Globals.barPosition === "top") ? (root.height + gap) : (-(manageWindow.implicitHeight + gap))
        const mx = -(manageWindow.implicitWidth - root.width) / 2
        const mrect = root.QsWindow.window.contentItem.mapFromItem(root, mx, my, manageWindow.implicitWidth, manageWindow.implicitHeight)
        manageWindow.anchor.rect = mrect
        manageWindow.visible = true
      }
    }
  }

  PopupWindow {
    id: menuWindow
    implicitWidth: 400
    implicitHeight: 220
    visible: false
    color: "transparent"
    // Update indicators on open for accuracy
    onVisibleChanged: if (visible) { refreshCount(); refreshLastId() }

    anchor {
      window: root.QsWindow?.window
      edges: Globals.barPosition === "top" ? Edges.Top : Edges.Bottom
      gravity: Globals.barPosition === "top" ? Edges.Bottom : Edges.Top
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          const gap = 5
          const y = (Globals.barPosition === "top") ? (root.height + gap) : (-(menuWindow.implicitHeight + gap))
          const x = -(menuWindow.implicitWidth - root.width) / 2
          const rect = win.contentItem.mapFromItem(root, x, y, menuWindow.implicitWidth, menuWindow.implicitHeight)
          menuWindow.anchor.rect = rect
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1
      radius: 8
      // Keep the popup open; ESC closes. This avoids any hover/timer interference with typing.

      ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 6

        // Search field removed for now to avoid focus issues

        ListView {
          id: listView
          Layout.fillWidth: true
          // Show up to ~12 rows, scroll for more
          Layout.preferredHeight: Math.min((root.filtered?.length || 0) * 34, 408)
          clip: true
          spacing: 4
          // Bind directly to the JS array of objects so modelData is the element
          model: root.filtered
          delegate: Item {
            required property var modelData
            width: listView.width
            height: 34
            // Hover background
            property bool hovered: false
            Rectangle {
              anchors.fill: parent
              color: hovered ? Globals.hoverHighlightColor : "transparent"
              radius: 4
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: parent.hovered = true
              onExited: parent.hovered = false
              onClicked: { if (modelData && modelData.id) root.copyEntry(modelData.id); menuWindow.visible = false }
            }
            RowLayout {
              anchors.fill: parent
              spacing: 2
              // Show sequential row number (1-based) to avoid confusion after wipes
              Label {
                text: (typeof index !== 'undefined' ? (index + 1).toString() : "")
                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                opacity: 0.7
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 10
              }
              Label {
                text: modelData && modelData.text ? modelData.text : ""
                color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
                elide: Text.ElideRight
                padding: 0
                leftPadding: 0
                rightPadding: 0
                Layout.rightMargin: 0
                Layout.fillWidth: true
              }
            }
          }
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }
        }

        // Empty state
        Rectangle {
          visible: (root.filtered?.length || 0) === 0
          Layout.fillWidth: true
          height: 34
          color: "transparent"
          Text {
            anchors.fill: parent
            anchors.margins: 8
            text: root.entries && root.entries.length === 0 ? "Keine Einträge" : "Keine Treffer"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            opacity: 0.7
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }
        }

          // Note: periodic auto-refresh disabled to preserve typing and scroll position.
        }
      }
    }

  // Note: buffered application handled in listProc.onRunningChanged to avoid frequent UI resets
 
  // Close any open popups when bar position flips (top <-> bottom)
  Connections {
    target: Globals
    onBarPositionChanged: {
      if (menuWindow && menuWindow.visible) menuWindow.visible = false
      if (manageWindow && manageWindow.visible) manageWindow.visible = false
      if (tipWindow && tipWindow.visible) tipWindow.visible = false
    }
  }
}
