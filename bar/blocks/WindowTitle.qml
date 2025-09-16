import QtQuick
import "../utils" as Utils
import "root:/"

Item {
  id: root
  implicitWidth: title.implicitWidth
  implicitHeight: title.implicitHeight

  property color color: Globals.windowTitleColor
  property bool bold: true
  property int pixelSize: Globals.mainFontSize
  property string family: String(Globals.mainFontFamily || "JetBrains Mono Nerd Font, sans-serif")
  // Dynamische maximale Breite: standardmäßig 35% der Elternbreite, Fallback 600px
  property real maxWidthRatio: 0.35
  property int maxWidth: parent ? Math.floor(parent.width * maxWidthRatio) : 600

  Text {
    id: title
    text: Utils.CompositorUtils.activeTitle
    color: root.color
    font.bold: root.bold
    font.pixelSize: root.pixelSize
    font.family: root.family
    width: Math.min(implicitWidth, root.maxWidth)
    elide: Text.ElideRight
  }
}
