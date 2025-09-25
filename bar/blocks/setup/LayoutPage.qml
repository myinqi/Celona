import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "root:/"

Item {
  id: page
  // Size provided by parent SwipeView; avoid setting anchors to prevent conflicts
  width: parent ? parent.width : 0
  height: parent ? parent.height : 0

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 10

    Label {
      text: "Layout"
      color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"
      font.bold: true
      font.family: Globals.mainFontFamily
      font.pixelSize: Globals.mainFontSize
    }

    // Controls (framed)
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: 6
      color: Globals.popupBg !== "" ? Globals.popupBg : palette.active.toolTipBase
      border.color: Globals.popupBorder !== "" ? Globals.popupBorder : palette.active.light
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

    // Swap Title & Workspaces
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Label { text: "Title & Workspaces order:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
      Item { Layout.fillWidth: true }
      Text { text: swapSwitch.checked ? "Title center, WS left" : "Title left, WS center"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
      Switch { id: swapSwitch; checked: Globals.swapTitleAndWorkspaces; onToggled: { Globals.swapTitleAndWorkspaces = checked; Globals.saveTheme() } }
    }

    // Bar position (top/bottom)
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Label { text: "Bar Position (top/bottom):"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
      Item { Layout.fillWidth: true }
      Text { text: posSwitch.checked ? "Bottom" : "Top"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
      Switch {
        id: posSwitch
        checked: Globals.barPosition === "bottom"
        onToggled: { Globals.barPosition = checked ? "bottom" : "top"; Globals.saveTheme() }
        ToolTip {
          id: posTip
          visible: posSwitch.hovered
          text: posSwitch.checked ? "Bottom" : "Top"
          contentItem: Text { text: posTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          background: Rectangle { color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase; border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light; border.width: 1; radius: 6 }
        }
      }
    }

    // Bar height
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Label { text: "Bar Height:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
      Item { Layout.fillWidth: true }
      Text { id: barHeightValue; text: String(Globals.baseBarHeight !== undefined ? Globals.baseBarHeight : 38) + " px"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
      Slider {
        id: barHeightSlider
        from: 30; to: 40; stepSize: 1; wheelEnabled: true
        Layout.preferredWidth: 180
        value: Globals.baseBarHeight !== undefined ? Globals.baseBarHeight : 38
        onMoved: {
          const v = Math.round(value)
          if (Globals.baseBarHeight !== v) { Globals.baseBarHeight = v; Globals.saveTheme() }
        }
        onValueChanged: barHeightValue.text = String(Math.round(value)) + " px"
        ToolTip {
          id: heightTip
          visible: parent.hovered
          text: "Visual bar height"
          contentItem: Text { text: heightTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          background: Rectangle {
            color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
            border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
            border.width: 1
            radius: 6
          }
        }
      }
    }

    // Edge margin (top/bottom)
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Label { text: "Bar Margin (" + (Globals.barPosition === "top" ? "top" : "bottom") + "):"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
      Item { Layout.fillWidth: true }
      Text { id: marginValue; text: String(Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0) + " px"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
      Slider {
        id: marginSlider
        from: 0; to: 12; stepSize: 1; wheelEnabled: true
        Layout.preferredWidth: 180
        value: Globals.barEdgeMargin !== undefined ? Globals.barEdgeMargin : 0
        onMoved: {
          const v = Math.round(value)
          if (Globals.barEdgeMargin !== v) { Globals.barEdgeMargin = v; Globals.saveTheme() }
        }
        onValueChanged: marginValue.text = String(Math.round(value)) + " px"
        ToolTip {
          id: edgeTip
          visible: parent.hovered
          text: (Globals.barPosition === "top" ? "Margin from top" : "Margin from bottom")
          contentItem: Text { text: edgeTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          background: Rectangle {
            color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
            border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
            border.width: 1
            radius: 6
          }
        }
      }
    }

    // Side margins (left/right)
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Label { text: "Bar Margin (left/right):"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
      Item { Layout.fillWidth: true }
      Text { id: sideMarginValue; text: String(Globals.barSideMargin !== undefined ? Globals.barSideMargin : 0) + " px"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
      Slider {
        id: sideMarginSlider
        from: 0; to: 400; stepSize: 1; wheelEnabled: true
        Layout.preferredWidth: 180
        value: Globals.barSideMargin !== undefined ? Globals.barSideMargin : 0
        onMoved: {
          const v = Math.round(value)
          if (Globals.barSideMargin !== v) { Globals.barSideMargin = v; Globals.saveTheme() }
        }
        onValueChanged: sideMarginValue.text = String(Math.round(value)) + " px"
        ToolTip {
          id: sideTip
          visible: parent.hovered
          text: "Margin from left/right"
          contentItem: Text { text: sideTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          background: Rectangle {
            color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
            border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
            border.width: 1
            radius: 6
          }
        }
      }
    }

    // Bar corner radius
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Label { text: "Bar Radius:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
      Item { Layout.fillWidth: true }
      Text { id: barRadiusValue; text: String(Globals.barRadius !== undefined ? Globals.barRadius : 11) + " px"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
      Slider {
        id: barRadiusSlider
        from: 0; to: 20; stepSize: 1; wheelEnabled: true
        Layout.preferredWidth: 180
        value: Globals.barRadius !== undefined ? Globals.barRadius : 11
        onMoved: {
          const v = Math.round(value)
          if (Globals.barRadius !== v) { Globals.barRadius = v; Globals.saveTheme() }
        }
        onValueChanged: barRadiusValue.text = String(Math.round(value)) + " px"
        ToolTip {
          id: radiusTip
          visible: parent.hovered
          text: "Corner radius of the bar"
          contentItem: Text { text: radiusTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          background: Rectangle {
            color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
            border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
            border.width: 1
            radius: 6
          }
        }
      }
    }

    // Bar border width
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Label { text: "Bar Border Width:"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
      Item { Layout.fillWidth: true }
      Text { id: barBorderWidthValue; text: String(Globals.barBorderWidth !== undefined ? Globals.barBorderWidth : 2) + " px"; color: Globals.popupText !== "" ? Globals.popupText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
      Slider {
        id: barBorderWidthSlider
        from: 0; to: 4; stepSize: 1; wheelEnabled: true
        Layout.preferredWidth: 180
        value: Globals.barBorderWidth !== undefined ? Globals.barBorderWidth : 2
        onMoved: {
          const v = Math.round(value)
          if (Globals.barBorderWidth !== v) { Globals.barBorderWidth = v; Globals.saveTheme() }
        }
        onValueChanged: barBorderWidthValue.text = String(Math.round(value)) + " px"
        ToolTip {
          id: borderWidthTip
          visible: parent.hovered
          text: "Width of the bar border"
          contentItem: Text { text: borderWidthTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          background: Rectangle {
            color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
            border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
            border.width: 1
            radius: 6
          }
        }
      }
    }

    // Hide bar (game mode)
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Item { Layout.fillWidth: true }
      CheckBox {
        id: hideBarChk
        text: "Hide Bar (Game mode)"
        checked: Globals.barHidden
        onToggled: { 
          Globals.barHidden = checked; 
          Globals.saveTheme() 
        }
        spacing: 6
        Component.onCompleted: {
          const c = (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF")
          if (hideBarChk.contentItem && hideBarChk.contentItem.color !== undefined) hideBarChk.contentItem.color = c
          if (hideBarChk.contentItem && hideBarChk.contentItem.font) { 
            hideBarChk.contentItem.font.family = Globals.mainFontFamily; 
            hideBarChk.contentItem.font.pixelSize = Globals.mainFontSize 
          }
        }
        Connections {
          target: Globals
          function onPopupTextChanged() {
            const c = (Globals.popupText !== "" ? Globals.popupText : "#FFFFFF")
            if (hideBarChk.contentItem && hideBarChk.contentItem.color !== undefined) hideBarChk.contentItem.color = c
          }
          function onMainFontFamilyChanged() {
            if (hideBarChk.contentItem && hideBarChk.contentItem.font) {
              hideBarChk.contentItem.font.family = Globals.mainFontFamily
            }
          }
          function onMainFontSizeChanged() {
            if (hideBarChk.contentItem && hideBarChk.contentItem.font) {
              hideBarChk.contentItem.font.pixelSize = Globals.mainFontSize
            }
          }
        }
        ToolTip {
          id: hideTip
          visible: hideBarChk.hovered
          text: hideBarChk.checked
                ? "Game mode: Bar hidden (only gear icon). Modules are unloaded to save CPU and memory."
                : "Bar visible"
          contentItem: Text { text: hideTip.text; color: Globals.tooltipText !== "" ? Globals.tooltipText : "#FFFFFF"; font.family: Globals.mainFontFamily; font.pixelSize: Globals.mainFontSize }
          background: Rectangle {
            color: Globals.tooltipBg !== "" ? Globals.tooltipBg : palette.active.toolTipBase
            border.color: Globals.tooltipBorder !== "" ? Globals.tooltipBorder : palette.active.light
            border.width: 1
            radius: 6
          }
        }
      }
      Item { Layout.fillWidth: true }
    }
      }
    }
  }
}
