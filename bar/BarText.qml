import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "root:/"

Text {
  // Determine if bar background is visually light to tune shadow strength
  readonly property color __barBg: Globals.barBgColor
  readonly property bool __barIsLight: (0.2126*__barBg.r + 0.7152*__barBg.g + 0.0722*__barBg.b) > 0.5
  // Default to global main font, fallback to JetBrains Mono Nerd Font if Globals not yet loaded
  property string mainFont: (typeof Globals !== 'undefined' && Globals && Globals.mainFontFamily && Globals.mainFontFamily.length)
                            ? Globals.mainFontFamily : "JetBrains Mono Nerd Font"
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
    horizontalOffset: __barIsLight ? 0 : 1
    verticalOffset: __barIsLight ? 0 : 1
    // In light mode, make shadow very subtle to avoid halo; in dark keep stronger
    radius: __barIsLight ? 2 : 8
    samples: __barIsLight ? 7 : 17
    color: __barIsLight ? "#22000000" : "#66000000"
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

