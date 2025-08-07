import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "root:/bar"

RowLayout {
  spacing: 5

  Repeater {
    model: ScriptModel {
      values: {[...SystemTray.items.values]
        .filter((item) => {
          return (item.id != "spotify-client"
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
