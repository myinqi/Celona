import QtQuick
import Quickshell.Hyprland
import "root:/"

Item {
  id: root
  implicitWidth: title.implicitWidth
  implicitHeight: title.implicitHeight

  property color color: Globals.windowTitleColor
  property bool bold: true
  property int pixelSize: 14
  property string family: "JetBrains Mono Nerd Font, sans-serif"
  property int maxWidth: 600

  Text {
    id: title
    text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "Desktop"
    color: root.color
    font.bold: root.bold
    font.pixelSize: root.pixelSize
    font.family: root.family
    width: Math.min(implicitWidth, root.maxWidth)
    elide: Text.ElideRight
  }
}
