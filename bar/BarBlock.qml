import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/"

Rectangle {
  id: root
  // Exclude hidden blocks from layout entirely
  Layout.preferredWidth: root.visible ? (contentContainer.implicitWidth + leftPadding + rightPadding) : 0
  Layout.preferredHeight: root.visible ? 26 : 0

  property Item content
  property Item mouseArea: mouseArea

  property string text
  property bool dim: false
  property bool underline
  property var onClicked: function() {}
  property int leftPadding: 5
  property int rightPadding: 5
  // When true, the internal MouseArea will not accept any buttons (clicks pass through to children)
  property bool passClicks: false

  property string hoveredBgColor: Globals.hoverHighlightColor
  // Track hover state passively (does not consume events) so child MouseAreas
  // (tooltips in CPU/GPU/Memory) still receive hover events.
  property bool hovered: hoverHandler.hovered

  // Background color
  color: hovered ? hoveredBgColor : "transparent"

  states: [
    State {
      when: mouseArea.containsMouse
      PropertyChanges {
        target: root
      }
    }
  ]

  Behavior on color {
    ColorAnimation {
      duration: 200
    }
  }

  Item {
    // Contents of the bar block
    id: contentContainer
    implicitWidth:  content.implicitWidth
    implicitHeight: content.implicitHeight
    anchors.left: parent.left
    anchors.leftMargin: leftPadding
    anchors.verticalCenter: parent.verticalCenter
    children: content
  }

  MouseArea {
    id: mouseArea
    anchors.fill: root
    hoverEnabled: true
    acceptedButtons: root.passClicks ? Qt.NoButton : Qt.LeftButton
    onClicked: root.onClicked()
  }

  // Passive hover tracker; does not grab events, so child hover tooltips work
  HoverHandler {
    id: hoverHandler
  }

  // While line underneath workspace
  Rectangle {
    id: wsLine
    width: parent.width
    height: 2

    color: {
      if (parent.underline)
        return "white";
      return "transparent";
    }
    anchors.bottom: parent.bottom
  }
}

