# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A Godot 4.7 (Forward Plus) single-player tile-placement/economy game. There is no build step, no package manager, and no automated test suite — this is a GDScript project run and iterated on inside the Godot editor.

Code comments and in-game text are written in Turkish; keep new comments/UI text consistent with that unless the user says otherwise.

## Running the project

Open and run from the Godot 4.7 editor (`project.godot` at repo root), or from the command line if the `godot` executable is on PATH:

```
godot --path . 
```

The main scene is `scenes/main.tscn` (configured via `run/main_scene` in `project.godot`). There are no lint/test/build commands in this repo — verify changes by running the scene in-editor and playing through the flow described below.

## Architecture

The game splits cleanly into a data/logic layer (`scripts/data/`, no scene dependencies, `RefCounted`/`Resource` classes) and a UI/scene layer (`scripts/*_ui.gd`, `scenes/board_view.gd`, `TileCell`) that reads from and drives that layer. `scenes/board_view.gd` is the orchestrator that owns all game state and wires the UI panels together.

### Data/logic layer (`scripts/data/`)

- **`tile_data.gd`** (`class_name TileDef`, extends `Resource`) — a single tile: 4 edges (`Element` enum: `FIRE, WATER, EARTH, AIR, ETHER, VOID`), a `price`, and `placed_creature` (`Creature` enum: `SALAMANDER, ROC, GOLEM, ABZU, DAGON`, or `-1` if empty).
- **`board.gd`** (`class_name Board`) — owns the `ROWS x COLS` (8x5) grid of `TileDef` (or `null`). Key rules live here:
  - `edges_compatible(neighbor_edge, my_edge)` — the edge-matching rule is **directional/asymmetric**: `VOID` never matches anything except placing against an empty/off-board neighbor; `ETHER` matches anything; otherwise edges must match exactly.
  - `tile_fits(edges, row, col)` — checks all 4 neighbors for a candidate placement.
  - `_is_cell_accessible` / `get_expandable_cells` — a cell is placeable only if it has a filled neighbor with a non-`VOID` edge facing it.
  - The start tile (all `ETHER`) is placed at `grid[7][2]` (bottom-center) on init; the win cell is `grid[0][2]` (top-center, see `WIN_ROW`/`WIN_COL` in `board_view.gd`).
- **`tile_generator.gd`** (`class_name TileGenerator`) — weighted-random edge generation (`EDGE_WEIGHTS`) and price calculation (`compute_price`: base 3, + difficulty scaling by ether-edge count, − discount for void-edge count). `generate_draft()` produces the 3-option draft shown to the player.
- **`creature_scorer.gd`** (`class_name CreatureScorer`) — pure scoring logic for each creature's payment rule when placed (and, for Abzu, retroactively when neighbors are added later via `update_abzu_neighbors`). Each creature has a distinct spatial rule (symmetry, flood-fill group size, nearest-same-creature distance, 8-neighbor fill count, diagonal count) — see the `CREATURE_DESCRIPTIONS` in `legend_ui.gd` for the player-facing summary of each.
- **`economy.gd`** (`class_name Economy`) — player money (`START_MONEY = 15`), spend/gain, and the loss condition (`can_afford_anything` across the current draft + refresh cost).

### UI/scene layer

- **`scenes/board_view.gd`** (extends `GridContainer`, the `%GridContainer` node) — the central controller. Owns `Board`, `TileGenerator`, `CreatureScorer`, `Economy` instances and all turn-state flags (`is_drafting`, `is_pending_placement`, `placing_creature`, `pending_*`). Rebuilds the entire grid of `TileCell` nodes on every state change via `_render_board()` (no incremental diffing — the grid is fully torn down and recreated with `queue_free()`/`add_child()` each time). Connects to signals from the side panels rather than the panels reaching into board state directly.
- **`scripts/tile_cell.gd`** (`class_name TileCell`, extends `Control`) — a custom-drawn (`_draw()`) single grid cell, reused both for the actual 8x5 board and for small preview cards in the side panels (`cell_size` is configurable per instance). Visual states: empty/selectable (`+`), filled with edge-color strips + creature glyph, live placement preview (gold border), static/invalid preview (red border, used in draft cards).
- **`scripts/creature_icon.gd`** (`class_name CreatureIcon`) — small custom-drawn shape-per-creature icon, used in the legend.
- Side panels under `Root/Layout/SidePanels` in `scenes/main.tscn`, each a `PanelContainer` subclass communicating with `board_view.gd` purely via Godot signals (never called into directly by name for state changes):
  - `draft_ui.gd` (`DraftPanel`) — shows the 3-tile draft with per-option prices and fit validity; emits `pair_selected` / `refresh_selected`.
  - `placement_ui.gd` (`PlacementPanel`) — rotate/confirm UI for a tile pending placement; emits `rotate_requested` / `confirm_requested`.
  - `creature_ui.gd` (`CreaturePanel`) — prompts the player to place (or skip) the creature that came with the just-placed tile; emits `skip_requested`.
  - `end_game_ui.gd` (`EndGamePanel`) — win/lose screen with a restart button (`get_tree().reload_current_scene()`).
  - `legend_ui.gd` (`LegendPanel`) — static reference panel listing each creature's scoring rule.
  - `money_ui.gd` (`MoneyLabel`) — polls `board_view.economy.money` every frame via `%GridContainer` and self-positions in the top-right corner.
- `scripts/main.gd` — currently an empty root node script; scene logic lives in `board_view.gd` instead.

### Turn flow (as implemented in `board_view.gd`)

1. Player clicks an expandable empty cell (`_on_cell_pressed`) → locks that cell, generates a 3-tile draft, checks for a loss condition.
2. Player buys a tile from the draft (`_on_pair_selected`) → if exactly one rotation fits, places it immediately; otherwise shows the rotate/confirm panel.
3. On placement (`_finalize_tile_placement`) → checks win condition (reaching `WIN_ROW`/`WIN_COL`), then enters creature-placement mode for the creature bundled with that tile.
4. Player clicks a valid empty-slot cell on an already-placed tile to place the creature (`_on_creature_target_pressed`) → scores it via `CreatureScorer`, pays out via `Economy`, and (for Abzu) later placements can retroactively pay existing Abzu tiles.

Node lookups between scripts go through Godot's unique-name (`%NodeName`) system (`unique_name_in_owner` on scene nodes) rather than exported node paths — check `scenes/main.tscn` when adding new cross-node references.
