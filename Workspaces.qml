import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Ten fixed workspace slots, labelled 0..9 in keyboard order.
// "0" maps to Hyprland workspace 10 (what SUPER + 0 already targets).
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

  // Real workspace ids, in display order.
  readonly property var workspaceIds: [10, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  function labelFor(id) { return id === 10 ? "0" : String(id) }

  // Circled digits straight from the bar font (Iosevka Nerd Font Mono):
  //   ⓪ U+24EA  ①..⑨ U+2460..U+2468   (outline circle)
  //   ⓿ U+24FF  ❶..❿ U+2776..U+277F   (filled circle, digit knocked out)
  // Falling back to drawn circles would be pointless when the font ships them.
  function circledDigit(digit, filled) {
    if (digit === 0) return filled ? "\u24FF" : "\u24EA"
    return String.fromCharCode((filled ? 0x2775 : 0x245F) + digit)
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds.length
    columnSpacing: root.vertical ? 0 : root.slotGap
    rowSpacing: root.vertical ? root.slotGap : 0

    Repeater {
      model: root.workspaceIds

      WidgetButton {
        id: slot
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property string plainLabel: root.labelFor(modelData)
        readonly property bool circled: occupied || focused
        readonly property int pixelSize: circled ? Math.round(root.fontSize * root.circleScale) : root.fontSize
        readonly property string label: focused
          ? root.circledDigit(modelData === 10 ? 0 : modelData, true)
          : (occupied ? root.circledDigit(modelData === 10 ? 0 : modelData, false) : plainLabel)

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
        tooltipText: "Workspace " + (modelData === 10 ? "10" : modelData)
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
