import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    symbolText: root.iconGlyph
  }

  // Data
  property var entries: [] // [{id: string, text: string}]
  property var filtered: []
  // Internal buffer to coalesce streaming output without resetting scroll/focus repeatedly
  property var _buf: []

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
      if (!running) console.log(`[Clipboard] Copy finished`)
    }
  }

  // Popup UI as a separate window (like Sound), anchored unter dem Block
  MouseArea {
    id: clickArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    onClicked: {
      if (root.QsWindow?.window?.contentItem) {
        // Anchor to the area directly below this bar block
        menuWindow.anchor.rect = root.QsWindow.window.contentItem.mapFromItem(root, 0, root.height, root.width, root.height)
        menuWindow.visible = !menuWindow.visible
        if (menuWindow.visible) {
          // Refresh once on open. Disable periodic refresh to avoid stealing focus and resetting scroll.
          refreshList()
        } else {
          if (listProc.running) listProc.running = false
        }
      }
    }
  }
  PopupWindow {
    id: menuWindow
    implicitWidth: 300
    implicitHeight: 220
    visible: false
    color: "transparent"
    // No auto focus needed since we removed the search field
    onVisibleChanged: undefined

    anchor {
      window: root.QsWindow?.window
      edges: Edges.Top
      gravity: Edges.Bottom
      onAnchoring: {
        const win = root.QsWindow?.window
        if (win) {
          const rect = win.contentItem.mapFromItem(root, 0, root.height, root.width, root.height)
          menuWindow.anchor.rect = rect
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: palette.active.toolTipBase
      border.color: palette.active.light
      border.width: 1
      radius: 8
      // Keep the popup open; ESC closes. This avoids any hover/timer interference with typing.

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
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
            MouseArea {
              anchors.fill: parent
              onClicked: { if (modelData && modelData.id) root.copyEntry(modelData.id); menuWindow.visible = false }
            }
            RowLayout {
              anchors.fill: parent
              spacing: 8
                Label {
                  text: modelData && modelData.text ? modelData.text : ""
                  color: "#ffffff"
                  elide: Text.ElideRight
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
              color: "#cccccc"
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }
          }

          // Note: periodic auto-refresh disabled to preserve typing and scroll position.
        }
      }
    }
  }

  // Note: buffered application handled in listProc.onRunningChanged to avoid frequent UI resets
 
