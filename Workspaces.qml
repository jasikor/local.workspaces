import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Ten fixed workspace slots, labelled 0..9 in keyboard order.
// "0" maps to the tenth workspace of the monitor's block (what SUPER + 0
// already targets).
//
// Every monitor owns a block of ten workspaces, which Hyprland numbers 1-10,
// 11-20, and so on (see default/hypr/monitor-workspaces.lua). Each bar shows
// its own monitor's block, so the same digits address the workspaces of
// whichever screen the bar belongs to.
//
// States use the font's own circled digits rather than drawn shapes:
//   unused    -> plain dim digit
//   occupied  -> outline circled digit (①)
//   focused   -> filled circled digit (❶)
BarWidget {
  id: root
  moduleName: "local.workspaces"

  // ---------------------------------------------------------------- settings
  // Font defaults match the clock in the bar centre: the bar body size and
  // normal weight. `fontSize` 0 (the default) follows Style.font.body, so the
  // digits track the theme's font scale.
  readonly property int fontSize: {
    var value = Number(root.setting("fontSize", 0))
    return isFinite(value) && value > 0 ? Math.round(value) : Style.font.body
  }
  readonly property string weightName: String(root.setting("weight", "normal"))
  readonly property int fontWeight: root.weightName === "light" ? Font.Light
    : (root.weightName === "demibold" ? Font.DemiBold
      : (root.weightName === "bold" ? Font.Bold
        : (root.weightName === "black" ? Font.Black : Font.Normal)))
  readonly property string colorSetting: String(root.setting("color", ""))
  readonly property color fg: root.colorSetting !== "" ? root.colorSetting : (bar ? bar.barForeground : Color.foreground)
  readonly property real dimOpacity: {
    var value = Number(root.setting("dim", 0.4))
    return isFinite(value) ? value : 0.4
  }
  // The filled (focused) glyph is a solid blob of bar foreground, which reads
  // as a glare at full strength; soften it by default.
  readonly property real focusOpacity: {
    var value = Number(root.setting("focusOpacity", 0.65))
    return isFinite(value) ? value : 0.65
  }
  readonly property real slotWidth: Style.spaceReal(Number(root.setting("slotWidth", 22)))
  readonly property real slotGap: Style.spaceReal(Number(root.setting("gap", 2)))
  readonly property real nudge: Number(root.setting("nudge", 0))
  // Circled glyphs are drawn inside the em box, so they need a bigger pixel
  // size than a bare digit to end up the same visual size.
  readonly property real circleScale: {
    var value = Number(root.setting("circleScale", 1.6))
    return isFinite(value) && value > 0 ? value : 1.6
  }

  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ------------------------------------------------------------- workspaces
  readonly property int slots: 10

  // Display order, so the digits read 0..9: the tenth slot comes first.
  readonly property var slotsInOrder: [10, 1, 2, 3, 4, 5, 6, 7, 8, 9]

  // The monitor whose bar this is. Slots address that monitor's block, not
  // whichever one happens to have focus.
  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  // Connector -> block, from the file Hyprland keeps them in.
  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  // Until Hyprland has written the file, the workspace a monitor shows is in
  // its own block.
  readonly property int block: {
    var block = root.blocks[root.monitorName]
    if (block !== undefined) return block
    var active = root.focusedId()
    return active > 0 ? Math.floor((active - 1) / root.slots) : 0
  }

  // Slot (1..10) -> real workspace id on this monitor.
  function idFor(slot) { return root.block * root.slots + slot }
  function labelFor(slot) { return slot === root.slots ? "0" : String(slot) }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function focusedId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  // Ask Omarchy for the workspace, so its block bookkeeping runs and the
  // workspace is reclaimed from another monitor if it wandered there.
  function focusWorkspace(slot) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote(
      "o.workspaces.focus(" + slot + ", \"" + root.monitorName + "\")"))
  }

  // Circled digits straight from the bar font (Iosevka Nerd Font Mono):
  //   ⓪ U+24EA  ①..⑨ U+2460..U+2468   (outline circle)
  //   ⓿ U+24FF  ❶..❿ U+2776..U+277F   (filled circle, digit knocked out)
  // Falling back to drawn circles would be pointless when the font ships them.
  function circledDigit(digit, filled) {
    if (digit === 0) return filled ? "\u24FF" : "\u24EA"
    return String.fromCharCode((filled ? 0x2775 : 0x245F) + digit)
  }

  // Quickshell credits every workspace switch to the focused monitor, and
  // misses the workspace a monitor falls back to when its own is moved away,
  // so a bar on another screen could keep highlighting the wrong slot. Ask
  // Hyprland for the truth whenever the layout of workspaces changes.
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.slotsInOrder.length
    columnSpacing: root.vertical ? 0 : root.slotGap
    rowSpacing: root.vertical ? root.slotGap : 0

    Repeater {
      model: root.slotsInOrder

      WidgetButton {
        id: slot
        required property int modelData

        readonly property int workspaceId: root.idFor(modelData)
        readonly property var workspace: root.workspaceById(workspaceId)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: root.focusedId() === workspaceId
        // 0 for the tenth slot, so the glyph matches the digit shown.
        readonly property int digit: modelData % root.slots
        readonly property string plainLabel: root.labelFor(modelData)
        readonly property bool circled: occupied || focused
        readonly property int pixelSize: circled ? Math.round(root.fontSize * root.circleScale) : root.fontSize
        readonly property string label: focused
          ? root.circledDigit(digit, true)
          : (occupied ? root.circledDigit(digit, false) : plainLabel)

        bar: root.bar
        // Keeps WidgetButton's hasVisualContent true (so the slot is drawn and
        // clickable) while the built-in label stays hidden.
        text: label
        labelVisible: false
        opacity: 1
        horizontalMargin: 0
        verticalPadding: 0
        fixedWidth: root.slotWidth
        fixedHeight: root.barSize
        tooltipText: "Workspace " + (modelData === root.slots ? String(root.slots) : modelData)
        onPressed: root.focusWorkspace(modelData)

        // Enclosed glyphs are not optically centred in their advance box, so a
        // circled slot would otherwise jump a few pixels to the right when it
        // becomes used. Measure the ink and pull it back onto the slot centre.
        TextMetrics {
          id: glyphMetrics
          font.family: root.fontFamily
          font.pixelSize: slot.pixelSize
          font.weight: root.fontWeight
          text: slot.label
        }

        readonly property real inkOffset: {
          var ink = glyphMetrics.boundingRect
          return Math.round(glyphMetrics.advanceWidth / 2 - (ink.x + ink.width / 2))
        }

        Text {
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: slot.inkOffset
          anchors.verticalCenterOffset: root.nudge
          text: slot.label
          color: root.fg
          opacity: slot.focused ? root.focusOpacity
            : (slot.occupied ? 1 : root.dimOpacity)
          font.family: root.fontFamily
          font.pixelSize: slot.pixelSize
          font.weight: root.fontWeight
          renderType: Text.NativeRendering
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter

          Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}
