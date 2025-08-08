import QtQuick
import "../"

BarBlock {
  id: text
  content: BarText {
    mainFont: "JetBrains Mono Nerd Font"
    symbolFont: "Symbols Nerd Font Mono"
    symbolSpacing: 2
    symbolText: ` ${Datetime.time}`
  }
}

