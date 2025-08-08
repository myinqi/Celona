import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/"

Rectangle {
  id: root
  Layout.preferredWidth: contentContainer.implicitWidth + leftPadding + rightPadding
  Layout.preferredHeight: 26

  property Item content
  property Item mouseArea: mouseArea

  property string text
  property bool dim: false
  property bool underline
  property var onClicked: function() {}
  property int leftPadding: 5
  property int rightPadding: 5

  property string hoveredBgColor: Globals.hoverHighlightColor

  // Background color
  color: {
    if (mouseArea.containsMouse)
      return hoveredBgColor;
    return "transparent";
  }

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
    acceptedButtons: Qt.LeftButton
    onClicked: root.onClicked()
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

