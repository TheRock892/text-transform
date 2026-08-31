import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// On-screen picker for transforming the highlighted text. Summoned with
// `omarchy-shell shell toggle capitalize-text` and bound to a key in
// ~/.config/hypr/bindings.lua. Picking a mode types the transformed text over
// the current selection; the heavy lifting lives in bin/capitalize-text.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string sourceDir: root.manifest ? String(root.manifest.__sourceDir || "") : ""
  readonly property string scriptPath: root.sourceDir ? root.sourceDir + "/bin/capitalize-text" : ""

  property bool opened: false
  property bool cursorActive: false
  property int selectedIndex: 0
  property string selection: ""

  // Shares the [menu] surface tokens, exactly like the emojis and clipboard
  // pickers, so themes that style the menu also style this overlay.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int cardWidth: Math.min(Style.space(440), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(300), panel.height - Style.gapsOut * 2)
  property int rowHeight: Math.max(Style.space(52), Style.font.body + Style.font.caption + Style.spacing.controlPaddingY * 2)

  property var modes: [
    { mode: "upcase", title: "Uppercase", hint: "U", sample: "EVERYTHING UPPER" },
    { mode: "downcase", title: "Lowercase", hint: "L", sample: "everything lower" },
    { mode: "capitalize", title: "Capitalize", hint: "C", sample: "Every Word In Title" }
  ]

  readonly property bool hasSelection: root.selection.length > 0

  function previewText() {
    var oneLine = root.selection.replace(/\s+/g, " ")
    return oneLine.length > 48 ? oneLine.slice(0, 48) + "…" : oneLine
  }

  function open(payloadJson) {
    root.opened = true
    root.selection = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.refreshSelection()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "capitalize-text")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function refreshSelection() {
    if (!root.scriptPath) return
    selectionProcess.command = [root.scriptPath, "--get-selection"]
    selectionProcess.running = true
  }

  function step(delta) {
    var length = root.modes.length
    root.selectedIndex = (root.selectedIndex + delta + length) % length
    root.cursorActive = true
  }

  function applyModeAt(index) {
    if (index < 0 || index >= root.modes.length) return
    var mode = root.modes[index].mode
    root.dismiss()
    Quickshell.execDetached([root.scriptPath, mode])
  }

  Process {
    id: selectionProcess
    stdout: StdioCollector {
      id: selectionStdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.selection = selectionStdout.text || ""
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-capitalize-text"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.step(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.step(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.applyModeAt(root.selectedIndex)
            event.accepted = true
          } else if (event.key === Qt.Key_U) {
            root.applyModeAt(0)
            event.accepted = true
          } else if (event.key === Qt.Key_L) {
            root.applyModeAt(1)
            event.accepted = true
          } else if (event.key === Qt.Key_C) {
            root.applyModeAt(2)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        // Header: title + live preview of the highlighted text.
        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"

          Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Transform selected text"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.hasSelection ? "Selected: “" + root.previewText() + "”"
                                     : "No text selected — highlight some text first"
              color: root.selectedText
              opacity: root.hasSelection ? 0.9 : 0.75
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }

        // One row per mode; Up/Down navigate, Return applies the highlighted row.
        Repeater {
          model: root.modes

          delegate: Rectangle {
            required property int index
            required property var modelData

            readonly property bool isSelected: root.cursorActive && index === root.selectedIndex

            width: parent.width
            height: root.rowHeight
            radius: root.cornerRadius
            color: isSelected ? root.selectedBackground : "transparent"

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.spacing.md
              anchors.rightMargin: Style.spacing.md
              spacing: Style.spacing.md

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.sample
                color: root.foreground
                opacity: 0.5
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width * 0.45
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.title
                color: isSelected ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                width: parent.width * 0.4
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.hint
                color: isSelected ? root.selectedText : root.foreground
                opacity: isSelected ? 0.9 : 0.4
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) {
                root.cursorActive = true
                root.selectedIndex = index
              }
              onClicked: {
                root.cursorActive = true
                root.selectedIndex = index
                root.applyModeAt(index)
              }
            }
          }
        }
      }
    }
  }
}
