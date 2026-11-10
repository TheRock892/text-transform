import QtQuick
import Quickshell
import Quickshell.Io

// Headless service that owns the plugin's global shortcut.
//
// Third-party plugins have no manifest-level way to register a persistent
// Hyprland keybinding (bar-widget "schema" settings only configure a
// widget's own behaviour, not system keybindings). This Omarchy install's
// Hyprland config is Lua-based (bindings.lua, `o.bind`), which rejects the
// legacy `hyprctl keyword bind`/`unbind` entirely ("can't work with
// non-legacy parsers"), and `hl.unbind(combo)` removes *every* bind on that
// combo, not just ours — unacceptable, since a shortcut can collide with an
// existing default binding. So this service calls Hyprland's own Lua API
// (`hl.bind`) through `hyprctl eval`, keeps the single bind object it creates
// in a Lua global, and swaps it out by disabling that exact object
// (`handle:set_enabled(false)`) before creating a new one — never touching
// any other binding that happens to share the same keys.
//
// The shortcut lives as an ordinary bar-widget setting (the "shortcut" key,
// editable with `omarchy bar set text-transform shortcut "SUPER + U"`, or by
// right-clicking the bar icon), read straight out of shell.json since
// services don't get a `settings` property injected the way bar widgets do.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string defaultShortcut: "SUPER + U"
  readonly property string pluginId: "text-transform"
  readonly property string execCommand: "omarchy-shell shell toggle text-transform"
  // Lua global the bind object is stashed in, so a later apply() (a setting
  // change, or the next shell start) can disable the previous one precisely
  // instead of unbinding by key combo. Hyprland's Lua state outlives the
  // shell process, so this survives a shell restart; only a Hyprland restart
  // resets it, which re-sources bindings.lua fresh anyway.
  readonly property string luaVar: "__omarchyTextTransformBind"
  readonly property string hyprctl: "/usr/bin/hyprctl"

  // What we last asked Hyprland to apply, so an unrelated shell.json rewrite
  // (any other plugin's setting change rewrites the whole file) doesn't
  // trigger a redundant hyprctl eval call.
  property string lastAppliedShortcut: ""

  readonly property var barSections: ["left", "centerBegin", "center", "centerEnd", "right", "tray"]

  function currentShortcutSetting() {
    var text = shellJsonFile.text()
    if (!text) return root.defaultShortcut
    var data
    try { data = JSON.parse(text) } catch (e) { return root.defaultShortcut }
    var layout = data && data.bar && data.bar.layout
    if (!layout) return root.defaultShortcut
    for (var i = 0; i < root.barSections.length; i++) {
      var list = layout[root.barSections[i]]
      if (!Array.isArray(list)) continue
      for (var j = 0; j < list.length; j++) {
        var entry = list[j]
        if (entry && typeof entry === "object" && entry.id === root.pluginId) {
          // Distinguish "never configured" (fall back to the default) from
          // an explicit empty string (the user asked for no shortcut).
          if (!("shortcut" in entry)) return root.defaultShortcut
          var value = entry.shortcut
          return value === null || value === undefined ? "" : String(value)
        }
      }
    }
    return root.defaultShortcut
  }

  // Lua double-quoted string literal.
  function luaQuote(value) {
    return "\"" + String(value || "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
  }

  function disableExpr() {
    return "if _G." + root.luaVar + " and _G." + root.luaVar + ".set_enabled then "
      + "_G." + root.luaVar + ":set_enabled(false) end\n"
      + "_G." + root.luaVar + " = nil\n"
  }

  function apply() {
    var shortcut = String(root.currentShortcutSetting() || "").trim()
    if (shortcut === root.lastAppliedShortcut) return

    var lua = root.disableExpr()
    if (shortcut !== "") {
      lua += "_G." + root.luaVar + " = hl.bind(" + root.luaQuote(shortcut) + ", "
        + "hl.dsp.exec_cmd(" + root.luaQuote(root.execCommand) + "), "
        + "{ description = " + root.luaQuote("Transform text") + " })\n"
    }
    Quickshell.execDetached([root.hyprctl, "eval", lua])
    root.lastAppliedShortcut = shortcut
  }

  FileView {
    id: shellJsonFile
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.apply()
    onLoadFailed: function(error) { root.apply() }
    onFileChanged: reload()
  }

  // No Component.onDestruction here on purpose: this plugin is keepLoaded,
  // so the host is expected to keep this instance alive across an ordinary
  // plugin hot-reload rather than destroy and recreate it — but disabling
  // the bind on destruction would race a freshly-created instance's apply()
  // if that guarantee ever slipped, silently leaving the shortcut dead (as
  // happened once). A dangling enabled bind from a genuinely removed plugin
  // is harmless noise; it only ever points at `omarchy-shell shell toggle
  // text-transform`, which just no-ops once the plugin is gone, and it
  // disappears on the next Hyprland restart/reload regardless.
}
