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
    mainFont: Globals.mainFontFamily
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
        font.family: Globals.mainFontFamily
        font.pixelSize: Globals.mainFontSize
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
      }
    }
  }

  // Small management popup for right-click actions (e.g., clear history)
  PopupWindow {
    id: manageWindow
    implicitWidth: manageCol.implicitWidth + 20
    implicitHeight: manageCol.implicitHeight + 20
    visible: false
    color: "transparent"
    onVisibleChanged: {
      if (visible) {
        tipWindow.visible = false
        if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== manageWindow) {
          if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
        }
        if (Globals.popupContext) Globals.popupContext.popup = manageWindow
      } else {
        if (Globals.popupContext && Globals.popupContext.popup === manageWindow) Globals.popupContext.popup = null
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
        id: manageCol
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
  // Latest entry ID currently displayed in the popup list (for change detection while open)
  property int shownLastId: 0

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
        // Update the last shown ID to the newest available in the refreshed list
        if (root.entries && root.entries.length) {
          const newestId = parseInt(root.entries[0]?.id)
          if (!isNaN(newestId)) root.shownLastId = newestId
        }
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

  // While popup is open, periodically check for new entries and refresh if a newer one exists
  Timer {
    id: openRefreshTimer
    interval: 2000
    repeat: true
    running: menuWindow.visible
    onTriggered: {
      // Update entryLastId; the change handler below will decide whether to refresh
      refreshLastId()
      // Keep the header count in sync while open
      refreshCount()
    }
  }

  // Refresh the list if a newer entry appears while popup is open
  onEntryLastIdChanged: {
    if (menuWindow.visible && entryLastId > (shownLastId || 0)) {
      // Preserve scroll; handled in listProc.onRunningChanged
      refreshList()
    }
  }

  // Popup UI as a separate window (like Sound), anchored unter dem Block
  MouseArea {
    id: clickArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    onEntered: {
      if (!Globals.popupContext || !Globals.popupContext.popup) {
        tipWindow.visible = true
      }
    }
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
        if (!menuWindow.visible) {
          if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== menuWindow) {
            if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
          }
        }
        menuWindow.visible = !menuWindow.visible
        if (menuWindow.visible) {
          // Refresh once on open. Disable periodic refresh to avoid stealing focus and resetting scroll.
          refreshList()
        } else {
          if (listProc.running) listProc.running = false
        }
      } else if (mouse.button === Qt.RightButton) {
        // Toggle manage popup on right click
        const my = (Globals.barPosition === "top") ? (root.height + gap) : (-(manageWindow.implicitHeight + gap))
        const mx = -(manageWindow.implicitWidth - root.width) / 2
        if (manageWindow.visible) {
          manageWindow.visible = false
        } else {
          const mrect = root.QsWindow.window.contentItem.mapFromItem(root, mx, my, manageWindow.implicitWidth, manageWindow.implicitHeight)
          manageWindow.anchor.rect = mrect
          if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== manageWindow) {
            if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
          }
          manageWindow.visible = true
        }
      }
    }
  }

  PopupWindow {
    id: menuWindow
    implicitWidth: 400
    implicitHeight: 220
    visible: false
    color: "transparent"
    // Update indicators on open for accuracy and manage global popup exclusivity
    onVisibleChanged: {
      if (visible) {
        tipWindow.visible = false
        if (Globals.popupContext && Globals.popupContext.popup && Globals.popupContext.popup !== menuWindow) {
          if (Globals.popupContext.popup.visible !== undefined) Globals.popupContext.popup.visible = false
        }
        if (Globals.popupContext) Globals.popupContext.popup = menuWindow
        refreshCount(); refreshLastId()
      } else {
        if (Globals.popupContext && Globals.popupContext.popup === menuWindow) Globals.popupContext.popup = null
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

        // Header: make it obvious which popup this is
        RowLayout {
          id: headerRow
          spacing: 10
          Layout.fillWidth: true
          Text {
            id: headerText
            text: "Clipboard history"
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
            font.bold: true
            color: Globals.popupText !== "" ? Globals.popupText : "#ddd"
            Layout.alignment: Qt.AlignVCenter
          }
          Item { Layout.fillWidth: true }
          // Small live badge mirroring the bar count
          Text {
            id: headerCount
            text: `(${root.entryCount})`
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
            color: Globals.popupText !== "" ? Globals.popupText : "#bbb"
            opacity: 0.8
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
          }
        }

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
            // Extract color from entry text
            // Supports:
            //  - rgba(rrrrggbbAA) with hex digits (example: rgba(5f5791ff))
            //  - rgba(r, g, b, a) with decimal components (a in 0..1 or 0..255)
            //  - rgb(r, g, b) with decimal components (0..255)
            //  - #RGB, #RRGGBB, #AARRGGBB hex
            property string colorValue: {
              const t = (modelData && modelData.text) ? String(modelData.text).trim() : ""
              // 1) rgba(XXXXXXXX) where X are hex digits (RRGGBBAA)
              const mRgba = t.match(/rgba\(\s*([0-9a-fA-F]{8})\s*\)/i)
              if (mRgba) {
                const hex = mRgba[1]
                const r = hex.slice(0, 2)
                const g = hex.slice(2, 4)
                const b = hex.slice(4, 6)
                const a = hex.slice(6, 8)
                // Qt expects #AARRGGBB when alpha present
                return `#${a}${r}${g}${b}`
              }
              // 2) rgba(r, g, b, a) decimals, allow spaces
              // r,g,b: 0..255 integers; a: 0..1 float or 0..255
              const mRgbaDec = t.match(/rgba\(\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*,\s*([0-9]*\.?[0-9]+)\s*\)/i)
              if (mRgbaDec) {
                let r = Math.max(0, Math.min(255, parseInt(mRgbaDec[1])))
                let g = Math.max(0, Math.min(255, parseInt(mRgbaDec[2])))
                let b = Math.max(0, Math.min(255, parseInt(mRgbaDec[3])))
                let aRaw = parseFloat(mRgbaDec[4])
                // If alpha > 1, assume 0..255; else 0..1
                let a255 = aRaw > 1 ? Math.max(0, Math.min(255, aRaw)) : Math.round(Math.max(0, Math.min(1, aRaw)) * 255)
                const toHex = (n) => n.toString(16).padStart(2, '0')
                return `#${toHex(a255)}${toHex(r)}${toHex(g)}${toHex(b)}`
              }
              // 3) rgb(r, g, b) decimals
              const mRgbDec = t.match(/rgb\(\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*,\s*([0-9]{1,3})\s*\)/i)
              if (mRgbDec) {
                let r = Math.max(0, Math.min(255, parseInt(mRgbDec[1])))
                let g = Math.max(0, Math.min(255, parseInt(mRgbDec[2])))
                let b = Math.max(0, Math.min(255, parseInt(mRgbDec[3])))
                const toHex = (n) => n.toString(16).padStart(2, '0')
                return `#${toHex(r)}${toHex(g)}${toHex(b)}`
              }
              // 2) #RGB, #RRGGBB or #AARRGGBB
              const mHex = t.match(/(#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8}))(?![0-9a-fA-F])/)
              if (mHex) {
                const h = mHex[1]
                if (h.length === 4) { // #RGB -> #RRGGBB
                  const r = h[1], g = h[2], b = h[3]
                  return `#${r}${r}${g}${g}${b}${b}`
                }
                return h // #RRGGBB or #AARRGGBB
              }
              return ""
            }
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
                font.family: Globals.mainFontFamily
                font.pixelSize: Globals.mainFontSize
              }
              // Optional color swatch if entry contains a recognized color
              Rectangle {
                visible: colorValue !== ""
                width: 14
                height: 14
                radius: 2
                color: visible ? colorValue : "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
                Layout.leftMargin: 4
                Layout.rightMargin: 4
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
                font.family: Globals.mainFontFamily
                font.pixelSize: Globals.mainFontSize
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
            text: root.entries && root.entries.length === 0 ? "no entries" : "no matches"
            color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
            opacity: 0.7
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.family: Globals.mainFontFamily
            font.pixelSize: Globals.mainFontSize
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
    function onBarPositionChanged() {
      if (menuWindow && menuWindow.visible) menuWindow.visible = false
      if (manageWindow && manageWindow.visible) manageWindow.visible = false
      if (tipWindow && tipWindow.visible) tipWindow.visible = false
    }
  }
}
