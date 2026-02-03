# fr0z3nUI ArtLayer

A lightweight WoW Retail addon for:
- Inspecting frames under the mouse (name/strata/level + region draw layers)
- Persisting frame strata/level overrides by global frame name
- Managing simple overlay “widgets” (textures/models) with basic conditions

## Install
1. Copy the folder `fr0z3nUI_ArtLayer` into:
   - `World of Warcraft/_retail_/Interface/AddOns/`
2. Launch WoW and enable the addon.

## Usage
- `/fal` opens the UI.

### Slash commands
- `/fal` or `/artlayer` — open the UI
- `/fal seen list|clear` — inspect/clear the "seen" list
- `/fal strata <strata>` — set override strata for a named frame
- `/fal level <number>` — set override level for a named frame
- `/fal wipe widgets|all` — wipe widgets (or everything)

### Widgets (CLI)
- `/fal widgets add texture <key> <file.tga>`
- `/fal widgets add model <key> <player|npc|display|file> [id]`
- `/fal widgets set <key> pos <point> <x> <y>`
- `/fal widgets set <key> size|pos|alpha|strata|layer ...`
- `/fal widgets cond <key> clear|add ...`

The addon stores settings in:
- `fr0z3nUI_ArtLayerDB`

## Notes
- Overrides can only be persisted for frames that have a global name.
- Widget texture paths may be given as bare filenames and will resolve to:
  - `Interface\\AddOns\\fr0z3nUI_ArtLayer\\media\\<file>`
