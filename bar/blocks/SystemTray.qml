import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Qt5Compat.GraphicalEffects
import "root:/"
import "root:/bar"

RowLayout {
  id: root
  spacing: 5

  // Toggle to hide NetworkManager applet from tray (default hidden on startup)
  property bool hideNmApplet: true
  // Generic list of tray item IDs to hide
  property var hiddenIds: []

  // Heuristic: find Network-related tray items (nm-applet, plasma-nm, etc.)
  function candidateNetworkIds() {
    const items = [...SystemTray.items.values]
    const ids = []
    for (let i = 0; i < items.length; i++) {
      const it = items[i]
      const id = it.id || ""
      const tip = (it.tooltipTitle || "")
      const idL = id.toLowerCase()
      const tipL = tip.toLowerCase()
      const looksLikeNm = idL.includes("nm-applet") || idL.includes("plasma-nm") || idL.includes("network") || idL === "nm" || idL.startsWith("nm-") || idL.includes("networkmanager")
      const looksLikeNetwork = tipL === "nm-applet" || tipL.includes("nm-applet") || tipL.includes("network") || tipL.includes("netzwerk") || tipL.includes("wifi") || tipL.includes("wlan") || tipL.includes("ethernet") || tipL.includes("wired") || tipL.includes("kabelgebunden") || tipL.includes("verbunden") || tipL.includes("verbindung") || tipL.includes("networkmanager")
      if (looksLikeNm || looksLikeNetwork) ids.push(id)
    }
    return ids
  }

  // Toggle network applet visibility using heuristic candidates.
  function toggleNetworkApplet() {
    const candidates = candidateNetworkIds()
    if (candidates.length === 0) {
      console.log("[SystemTray] No network tray candidates found to toggle. Dumping tray items for debugging:")
      const items = [...SystemTray.items.values]
      for (let i = 0; i < items.length; i++) {
        const it = items[i]
        console.log("[SystemTray] item:", JSON.stringify({ id: it.id || "", tooltipTitle: it.tooltipTitle || "", icon: (it.icon ? String(it.icon).slice(0,64) : "") }))
      }
      return
    }
    const allHidden = candidates.every(id => hiddenIds.indexOf(id) !== -1)
    if (allHidden) {
      // Unhide: remove candidates from hiddenIds
      root.hiddenIds = hiddenIds.filter(id => candidates.indexOf(id) === -1)
      root.hideNmApplet = false
      console.log("[SystemTray] Unhid network tray ids:", JSON.stringify(candidates))
    } else {
      // Hide: add all candidates to hiddenIds
      const set = new Set(hiddenIds)
      candidates.forEach(id => set.add(id))
      root.hiddenIds = Array.from(set)
      root.hideNmApplet = true
      console.log("[SystemTray] Hid network tray ids:", JSON.stringify(candidates))
    }
  }

  Repeater {
    model: ScriptModel {
      values: {[...SystemTray.items.values]
        .filter((item) => {
          const hideNm = root.hideNmApplet && (item.id === "nm-applet" || item.id.indexOf("nm") === 0)
          const hiddenByList = Array.isArray(root.hiddenIds) && root.hiddenIds.indexOf(item.id) !== -1
          return (!hideNm && !hiddenByList
               && item.id != "spotify-client"
               && item.id != "chrome_status_icon_1")
        })
      }
    }

    MouseArea {
      id: delegate
      required property SystemTrayItem modelData
      property alias item: delegate.modelData

      // Match BarBlock height for visual consistency with Time/Date blocks
      Layout.preferredHeight: 24
      implicitWidth: icon.width + 5

      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      hoverEnabled: true

      onClicked: event => {
        if (event.button == Qt.LeftButton) {
          item.activate();
        } else if (event.button == Qt.MiddleButton) {
          item.secondaryActivate();
        } else if (event.button == Qt.RightButton) {
          menuAnchor.open();
        }
      }

      onWheel: event => {
        event.accepted = true;
        const points = event.angleDelta.y / 120
        item.scroll(points, false);
      }

      function sanitizeIcon(src) {
        // Some tray icons (e.g., Steam) include a query string like
        // "steam_tray_mono?path=/home/..." which triggers a warning.
        // Strip the query part so the theme icon name is used.
        if (!src) return src;
        const qIndex = src.indexOf("?");
        return qIndex >= 0 ? src.slice(0, qIndex) : src;
      }

      // Systray icon sized to match text symbol visual size (~18px on 24px bar)
      IconImage {
        id: icon
        anchors.centerIn: parent
        property int iconSize: Math.round(delegate.height * 0.75) // ~18px for 24px height
        source: sanitizeIcon(item.icon)
        width: iconSize
        height: iconSize
        smooth: true
      }

      // Optional color tint for tray icons
      ColorOverlay {
        anchors.fill: icon
        source: icon
        color: Globals.trayIconColor !== "" ? Globals.trayIconColor : "transparent"
        visible: Globals.trayIconColor !== ""
        antialiasing: true
      }

      QsMenuAnchor {
        id: menuAnchor
        menu: item.menu

        anchor.window: delegate.QsWindow.window
        anchor.adjustment: PopupAdjustment.Flip

        anchor.onAnchoring: {
          const window = delegate.QsWindow.window;
          const widgetRect = window.contentItem.mapFromItem(delegate, 0, delegate.height, delegate.width, delegate.height);

          menuAnchor.anchor.rect = widgetRect;
        }
      }

      Tooltip {
        relativeItem: delegate.containsMouse ? delegate : null

        Label {
          text: delegate.item.tooltipTitle || delegate.item.id
        }
      }
    }
  }
}
