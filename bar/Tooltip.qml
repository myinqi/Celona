import QtQuick
import Quickshell
import "root:/" // for Globals

LazyLoader {
  id: root

  // The item to display the tooltip at. If set to null the tooltip will be hidden.
  property Item relativeItem: null

  // Tracks the item after relativeItem is unset.
  property Item displayItem: null

  property PopupContext popupContext: Globals.popupContext

  property bool hoverable: false;
  readonly property bool hovered: item?.hovered ?? false

  // The content to show in the tooltip.
  required default property Component contentDelegate

  active: displayItem != null && popupContext.popup == this

  onRelativeItemChanged: {
    if (relativeItem == null) {
      if (item != null) item.hideTimer.start();
    } else {
      if (item != null) item.hideTimer.stop();
      displayItem = relativeItem;
      popupContext.popup = this;
    }
  }

  PopupWindow {
    anchor {
      window: root.displayItem && root.displayItem.QsWindow ? root.displayItem.QsWindow.window : null
      rect.y: anchor.window ? (anchor.window.height + 3) : 0
      rect.x: (anchor.window && root.displayItem) ? anchor.window.contentItem.mapFromItem(root.displayItem, root.displayItem.width / 2, 0).x : 0
      edges: Edges.Top
      gravity: Edges.Bottom
    }

    visible: true

    property alias hovered: body.containsMouse;

    property Timer hideTimer: Timer {
      interval: 250

      // unloads the popup by causing active to become false
      onTriggered: root.popupContext.popup = null;
    }

    color: "transparent"

    // don't accept mouse input if !hoverable
    Region { id: emptyRegion }
    mask: root.hoverable ? null : emptyRegion

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    MouseArea {
      id: body

      anchors.fill: parent
      implicitWidth: content.implicitWidth + 10
      implicitHeight: content.implicitHeight + 10

      hoverEnabled: root.hoverable

      Rectangle {
        anchors.fill: parent

        radius: 8
        border.width: 1
        color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
        border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light

        Loader {
          id: content
          anchors.centerIn: parent
          sourceComponent: contentDelegate
          active: true
          onLoaded: {
            // Apply tooltip text color and font settings to nested items
            const c = Globals.tooltipText
            const px = (Globals.mainFontSize !== undefined && Globals.mainFontSize > 0)
              ? Globals.mainFontSize
              : ((Globals.tooltipPixelSize !== undefined && Globals.tooltipPixelSize > 0)
                  ? Globals.tooltipPixelSize
                  : Globals.tooltipFontPixelSize)
            function applyStyle(it) {
              if (!it) return
              if ("color" in it && c && c !== "") { it.color = c }
              // Apply font settings when available
              if (it.font !== undefined) {
                if (px > 0 && it.font.pixelSize !== undefined) {
                  it.font.pixelSize = px
                }
                if (Globals.tooltipFontFamily !== "" && it.font.family !== undefined) {
                  it.font.family = Globals.tooltipFontFamily
                }
              }
              if (it.children) for (const ch of it.children) applyColor(ch)
            }
            function applyColor(ch) { applyStyle(ch) }
            applyStyle(content.item)
          }
        }
      }
    }
  }
}
