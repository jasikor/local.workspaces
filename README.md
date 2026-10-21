# local.workspaces

A ten-slot workspace widget for the [Omarchy](https://omarchy.org/) bar.

The bar shows `0 1 2 3 4 5 6 7 8 9` in keyboard order, always in the same
place: `0` is workspace 10 (what `SUPER + 0` targets), `1`–`9` are workspaces
1–9. Slots never appear, disappear or shift around.

State is shown with the font's own circled digits instead of drawn shapes:

| state | rendering |
|-------|-----------|
| unused | plain digit, dimmed |
| occupied | outlined circled digit (`⓪ ① ② …`) |
| focused | filled circled digit (`⓿ ❶ ❷ …`), softened with `focusOpacity` |

The digits use the bar's default font (the same size and weight as the clock),
and are optically centred per glyph via `TextMetrics`, so a slot does not jump
when it switches between plain, circled and filled forms.

Left click focuses the workspace; hovering shows a `Workspace N` tooltip.

## Install

```bash
git clone https://github.com/jasikor/local.workspaces.git \
  ~/.config/omarchy/plugins/local.workspaces

omarchy plugin enable local.workspaces
omarchy restart shell
```

The manifest carries `omarchy.clonedFrom: omarchy.workspaces`, so enabling it
replaces the stock workspaces widget in its current bar slot rather than
adding a second one. If it is not on the bar at all:

```bash
omarchy bar put local.workspaces left --after local.hostname
```

## Settings

Every value is optional and read from the widget's entry in
`~/.config/omarchy/shell.json`, for example:

```bash
omarchy bar set local.workspaces focusOpacity 0.55
```

| key | default | meaning |
|-----|---------|---------|
| `fontSize` | theme body size | digit size in px; circled glyphs scale from it |
| `weight` | `normal` | `light`, `normal`, `demibold`, `bold`, `black` |
| `color` | bar foreground | digit/ring colour |
| `dim` | `0.4` | opacity of unused slots |
| `focusOpacity` | `0.65` | opacity of the filled (focused) glyph |
| `slotWidth` | `22` | width of one slot |
| `gap` | `2` | spacing between slots |
| `circleScale` | `1.6` | size multiplier for circled glyphs (they live inside the em box) |
| `nudge` | `0` | vertical optical offset in px |

## Licence

MIT — see [LICENSE](LICENSE).
