import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "root:/"

Text {
  property string mainFont: "FiraCode"
  property string symbolFont: "Symbols Nerd Font Mono"
  property int pointSize: 12
  property int symbolSize: pointSize * 1.4
  // Per-module adjustable spacing between icon glyph and following text (in px)
  property int symbolSpacing: 5
  property string symbolText
  property bool dim
  // Colors
  property color iconColor: Globals.moduleIconColor
  property color valueColor: Globals.moduleValueColor
  text: wrapSymbols(symbolText)
  anchors.centerIn: parent
  color: dim ? "#CCCCCC" : valueColor
  textFormat: Text.RichText
  font {
    family: mainFont
    pointSize: pointSize
  }

  Text {
    visible: false
    id: textcopy
    text: parent.text
    textFormat: parent.textFormat
    color: parent.color
    font: parent.font
  }

  DropShadow {
    anchors.fill: parent
    horizontalOffset: 1
    verticalOffset: 1
    color: "#000000"
    source: textcopy
  }

  function wrapSymbols(text) {
    if (!text)
      return ""

    const isSymbol = (codePoint) =>
        (codePoint >= 0xE000   && codePoint <= 0xF8FF) // Private Use Area
     || (codePoint >= 0xF0000  && codePoint <= 0xFFFFF) // Supplementary Private Use Area-A
     || (codePoint >= 0x100000 && codePoint <= 0x10FFFF); // Supplementary Private Use Area-B

    return text.replace(/./gu, (c) => {
      const cp = c.codePointAt(0)
      if (isSymbol(cp)) {
        return `<span style='font-family: ${symbolFont}; letter-spacing: ${symbolSpacing}px; font-size: ${symbolSize}px; color: ${iconColor}'>${c}</span>`
      }
      // wrap normal characters so we can color them independently
      return `<span style='color: ${valueColor}'>${c}</span>`
    });
  }
}

