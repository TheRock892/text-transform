import QtQuick
import qs.Ui

// Bar icon that opens the text-transform picker; the click does exactly what
// the `omarchy-shell shell toggle text-transform` keybinding does (see
// README.md), so both routes stay in sync automatically.
BarWidget {
  id: root
  moduleName: "text-transform"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "Aa"
    tooltipText: "Transform text\nHighlight text, then click to pick UPPERCASE, lowercase, or Capitalize"
    onPressed: function(mouseButton) {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle text-transform")
    }
  }
}
