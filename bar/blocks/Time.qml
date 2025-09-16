import QtQuick
import "../"

BarBlock {
  id: text
  content: BarText {
    mainFont: Globals.mainFontFamily
    symbolFont: "Symbols Nerd Font Mono"
    symbolSpacing: 2
    symbolText: ` ${Datetime.time}`
  }
}
