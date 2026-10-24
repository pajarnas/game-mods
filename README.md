# game-mods

Mods and helper tools for games I play. 我玩的游戏的 mod 和辅助工具。

## Mods

| Game | Mod / tool | Status | What it does |
|---|---|---|---|
| Transport Fever 3 | [`saige_line_namer`](transport-fever-3/saige_line_namer) | Draft, untested in game | Name a line `N-FB 铁矿→北港仓` and it becomes `N-FB03 铁矿→北港仓` with a cargo-coded color. |
| Transport Fever 3 | [`tools/line-namer.html`](transport-fever-3/tools/line-namer.html) | Working | Browser tool for planning line names and colors with the same scheme. |

Downloads are on the [Releases](https://github.com/pajarnas/game-mods/releases) page.

## Install

Each release has a zip per mod. Unzip it and copy the mod folder into the game's mod directory. Game-specific steps are in each game folder's README, for example [Transport Fever 3](transport-fever-3/README.md).

## Layout

```
<game>/                 one folder per game, lowercase-kebab-case
  README.md             install and test steps for that game
  <mod_id>/             one folder per mod, named after the game's mod id
  tools/                optional helpers for that game (web pages, scripts)
```

A mod folder keeps the exact structure the game expects, so it can be copied straight into the game.

## Releases and versions

Every mod is versioned on its own. Tags are `<game>-<mod>-v<major>.<minor>.<patch>`, for example `tf3-line-namer-v0.1.0`. Releases below `v1.0.0` are marked as pre-releases.

## Adding a mod for another game

1. Create `<game>/` with a README covering install and test steps.
2. Put the mod in `<game>/<mod_id>/` using the game's own structure.
3. Add a row to the table above.
4. Tag `<game>-<mod>-v0.1.0` and publish a release with the zipped mod folder.

## License

Code in this repository is under the [MIT License](LICENSE). Game names, assets and APIs belong to their owners. Mods published on a game's own platform (for example mod.io for Transport Fever 3) also follow that platform's terms.
