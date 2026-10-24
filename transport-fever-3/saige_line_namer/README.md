# Line Namer (saige_line_namer)

English | [简体中文](README.zh-CN.md)

Script mod for Transport Fever 3. Type only a prefix when you name a line, and the mod fills in the number and sets the line color by cargo category.

## Usage

When you create or rename a line in game, name it like this:

```
N-FB Iron Mine→North Hub     →  N-FB03 Iron Mine→North Hub
NW-TB North Hub⇄West Hub     →  NW-TB01 North Hub⇄West Hub
NW-PR North→West             →  NW-PR01 North→West
```

About every 120 simulation steps the mod scans your lines:
- Prefix without a number: adds the next free two-digit number for that prefix.
- Any prefix: sets the matching color.
- No prefix (for example the game's default names): left alone.

Any text after the prefix is kept as you typed it, in any language.

| Part | Values |
|---|---|
| Region | Capital letters such as N, W, NW. Direct lines can use D |
| Role | T trunk (hub ⇄ hub), F feeder (to or from a hub), D direct (no warehouse) |
| Category | L liquid, B bulk, P flatbed, G goods, U universal |
| Passenger | `Region-P` + mode: R rail, B bus, T tram, A air, S ship, H helicopter |

Colors match what is carried: liquid (oil) is black-violet, bulk (coal, ore) is earth brown, flatbed (steel, timber) is rust red, goods are freight blue, universal is grey, and every passenger line is green with one shade per mode. Within a category, trunk is darkest, direct is medium and feeder is lightest. The web tool `tools/line-namer.html` uses the same palette.

## Languages

The Mod Hub name, summary and description come in English and Chinese through `localization` in `_metadata/modinfo.json`. The mod shows no other text in game.

## Testing locally

1. Copy the whole `saige_line_namer` folder to
   `C:\Program Files (x86)\Steam\userdata\<Steam ID>\3493540\local\staging_area\`
   (or open it from the main menu: Settings > Advanced > Open User Data Folder).
2. Start a new game and enable "Line Namer" in the mod list. Mods are enabled per save.
3. Create a line named `N-FB test`. After a few seconds it should become `N-FB01 test` with a light orange color.
4. In Mod Hub > My Mods, run the validator and export the report.

## Check in game

These calls follow the official docs, but the docs do not show them in full. Watch them on the first test:

1. **Script path**: `line_namer.gs.lua` uses `saige_line_namer::/line_namer/line_namer.script@update`, following the hook format of the official mods. If the script does not load, check this first.
2. **Color value**: built with `api.type.Vec3f.new(r, g, b)` on a 0 to 1 scale. The docs confirm the `api.type.X.new()` pattern but do not list Vec3f.
3. **Reading color**: assumes the `COLOR` component's `color` field has `.x .y .z`. If reading fails, the mod sets the color again on every scan. The result is the same, it just sends extra commands.
4. **Chinese language code**: `modinfo.json` uses `zh` for the Chinese text. If Mod Hub still shows English with the game set to Chinese, the game may expect another code.

On an error the mod stops and logs `[saige_line_namer] disabled after error: ...` once instead of flooding the log.

## Publishing

In Mod Hub > My Mods, select the mod and click Upload at the bottom left. It uploads to mod.io. Bump `revision` in `mod.json` before each update.
