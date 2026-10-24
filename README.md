# game-mods

Mods and helper tools for games I play.

## Layout

```
<game>/                 one folder per game, lowercase-kebab-case
  <mod_id>/             one folder per mod, named after the game's mod id
  tools/                optional helpers for that game (web pages, scripts)
```

Each mod folder keeps the exact structure the game expects, so it can be copied straight into the game's mod directory.

## Games

| Game | Mod / tool | What it does |
|---|---|---|
| Transport Fever 3 | [`saige_line_namer`](transport-fever-3/saige_line_namer) | Fills in line numbers and sets cargo-coded line colors from a name prefix such as `N-FB`. |
| Transport Fever 3 | [`tools/line-namer.html`](transport-fever-3/tools/line-namer.html) | Browser tool for planning line names and colors with the same scheme. |
