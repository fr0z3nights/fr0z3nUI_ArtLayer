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

The addon stores settings in:
- `fr0z3nUI_ArtLayerDB`

## Notes
- Overrides can only be persisted for frames that have a global name.
- Widget texture paths may be given as bare filenames and will resolve to:
  - `Interface\\AddOns\\fr0z3nUI_ArtLayer\\media\\<file>`
