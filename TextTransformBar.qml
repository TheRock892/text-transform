import QtQuick
import qs.Ui

// Bar icon that opens the text-transform picker; the click does exactly what
// the `omarchy-shell shell toggle text-transform` keybinding does (see
// README.md), so both routes stay in sync automatically. Right-click prompts
// for a new global shortcut (see Service.qml, which applies it live).
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
    tooltipText: "Transform text\nClick to pick UPPERCASE, lowercase, or Capitalize\nRight-click to change the shortcut"
    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton) {
        var payload = JSON.stringify({ action: "set-shortcut" })
        root.bar.run("omarchy-shell shell summon text-transform '" + payload.replace(/'/g, "'\\''") + "'")
        return
      }
      root.bar.run("omarchy-shell shell toggle text-transform")
    }
  }
}
