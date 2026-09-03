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

The main scene is `scenes/main.tscn` (configured via `run/main_scene` in `project.godot`), and it is the **only** scene. The start menu is a `CanvasLayer` overlay inside it, not a separate scene — deliberately, so that running the project (F5) and running the current scene (F6, which ignores `run/main_scene`) both show the menu first. Don't move the menu back into its own scene. There are no lint/test/build commands in this repo — verify changes by running the scene in-editor and playing through the flow described below.

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
  - `money_ui.gd` (`MoneyLabel`) — extends `SoulAmount`; polls `board_view.economy.money` every frame via `%GridContainer` and self-positions in the top-right corner.
- **`scripts/soul_amount.gd`** (`class_name SoulAmount`, extends `Control`) — the single way money is displayed: it draws `assets/ui/soul.png` and writes the amount inside the droplet. Two measured constants make it legible, so don't "simplify" them away: `UiTheme.SOUL_EMBLEM_REGION` crops the texture's large transparent glow padding (the emblem is only the middle ~57% of the 512px square, and the droplet itself only ~27%, so drawing the texture whole leaves the number spilling outside the droplet), and `DROPLET_CENTER` puts the number on the droplet's widest band rather than the texture's geometric centre. The number is drawn in three passes — white halo, dark thickening outline, then the glyph — since the default font has no bold face. Every place that shows an amount uses it — draft card prices, the refresh cost, the top-right counter, the log rows — so don't render a bare number or a coin emoji anywhere. Note that the draft panel's icon sizes are capped: raising `PRICE_SOUL_RATIO`/`TITLE_SOUL_SIZE` pushes the panel past `UiTheme.ACTION_PANEL_HEIGHT`, which the three action panels share.
- `scripts/main.gd` — root node script of `scenes/main.tscn`. Adds the runtime-only overlays (`ForestAtmosphere`, `CreatureRefPanel`, `TutorialManager`) and hands the tutorial its node references, because `%UniqueName` lookups only resolve from nodes that belong to the scene — a node created at runtime cannot use them.
- `scripts/menu_overlay.gd` (`MenuOverlay`) — the start menu, a `CanvasLayer` over the game scene (title, `Oyna` / `Nasıl Oynanır` / `Çıkış`). `Nasıl Oynanır` does not open a text page: it emits `tutorial_requested`, and `main.gd` starts the hands-on tutorial. `MenuOverlay.skip_next` (static, survives `reload_current_scene()`) lets the end-game `Yeniden Başla` button reload straight into the game while `Ana Menü` reloads into the menu.
- `scripts/creature_ref_ui.gd` (`CreatureRefPanel`) — openable creature reference, on its own `CanvasLayer` above the tutorial's so it stays reachable while the tutorial locks the screen. Its texts come from `LegendPanel.CREATURE_NAMES` / `CREATURE_DESCRIPTIONS` — don't copy those strings anywhere.

### Tutorial (`scripts/tutorial_manager.gd`)

A hands-on, step-gated tutorial rather than a text page. It **observes** the game and never drives it: `board_view.gd` emits `cell_selected` / `tile_purchased` / `tile_rotated` / `tile_placed` / `creature_placed`, and each step advances only on its own event, so the player has to actually make the move.

- `scripts/tutorial_overlay.gd` (`TutorialOverlay`) does the locking and highlighting in one node: it covers the screen, and `_has_point()` returns `false` inside the current step's target rects so clicks fall through to just those elements while every other click is silently swallowed. Everything outside the holes is dimmed, and the holes get a pulsing gold border. `_dim_rects()`/`_subtract()` exist because Godot cannot draw a rectangle with holes — the screen is split into the pieces that remain.
- Target rects are recomputed **every frame** (`_target_rects()`), not cached: `_render_board()` destroys and recreates every `TileCell`, so node references from a previous frame go stale. `board_view.cell_nodes` holds the current `"row,col" -> TileCell` mapping for this.
- Only the current step is shown — a `Adım 3 / 7 · <short name>` heading plus that step's instruction. Its width is derived at runtime from the board's own width (`BOX_WIDTH_MARGIN` wider, read from the `GridContainer`'s rect so the grid separations are included), and it is centred on the board rather than on the viewport — the side columns are not always equal, so viewport-centring would make the overhang lopsided. The box sits **top-centre**, over the board's top rows — fine while those rows are empty and dimmed, but the last step highlights exactly that area (the key cells and the top-centre win cell), so the box moves to the **top-right** for it. For that position the box must stay narrower than `UiTheme.COLUMN_WIDTH`: that keeps it inside the right panel column, and the board can never slide under it because `SidePanels` reserves at least that width.
- The rotate/confirm steps are skipped automatically when only one rotation fits (the game auto-places, `tile_placed` arrives while the tutorial is still on the rotate step).
- First run starts it automatically; `scripts/game_settings.gd` (`GameSettings`) persists `tutorial_completed` in `user://settings.cfg`. Both exits — `Bitir` on the last step and `Atla` at any point — mark it complete and reload the scene back to the menu, since the tutorial leaves a half-played board behind. The `game_over` path is the exception: it calls `_finish()` without reloading, so the end-game panel stays on screen.

### Relic system (kalıntılar)

Collecting a key grants one relic chosen from 3 random options; a run has 4 keys → 4 relics. The relic pool and **all** relic effect logic live in one place: **`scripts/data/relic_manager.gd`**, registered as the `RelicManager` autoload (alongside `MusicManager`). It is a `Node` — the one data-layer file that isn't a scene-free `RefCounted` — because relic state must be global and single-instance. Every other system (`economy.gd`/`board.gd`/`creature_scorer.gd`/`tile_generator.gd`/`board_view.gd` and several `*_ui.gd`) only *asks* it (`has_relic`, `adjust_tile_price`, `keys_needed`, `salamander_pair_bonus`, …); never re-implement a relic condition outside this file.

- `scripts/data/relic.gd` (`class_name RelicDef`, `Resource`) — one relic: `id`, `display_name`, `description`, `category`, `one_shot`, `choice_kind` (`""`/`"creature"`/`"element"` — relics that pick a contract target on acquire).
- Autoloads survive `reload_current_scene()`, so `board_view._ready()` calls `RelicManager.reset()` each new game. The one turn-scoped counter (`Tüccar Yüzüğü`'s free refresh) resets via `RelicManager.begin_turn()` at the top of `_on_cell_pressed`.
- `scripts/relic_ui.gd` (`class_name RelicPanel`, `CanvasLayer`, created by `main.gd`, ref handed to `board_view`) is **one node, three jobs**: the modal 3-card chooser (full-screen backdrop locks the game until a pick), the contract/`Kılık Taşı` sub-picker (same modal), and the always-on owned-relics list bottom-left. The bar is added before the modal so the backdrop covers it.
- One-shots come in two flavours. **Bar-activated** (`Eter Şardı`, `Ayna Tahta`, `Kılık Taşı`, `Çift Ruh` — the `RelicManager._BAR_ACTIVATED` list, `is_bar_activatable()`) render as clickable buttons in the owned list, are routed by `board_view._on_relic_activated`, and `mark_spent` on click; `board_view` holds the transient flags (`mirror_armed`, `twin_armed`) that the next placement consumes. **Contextual** — `Ruh Pazarı` only — fires from the creature panel's "Yak" button, calls `mark_spent` itself, and shows as plain faded text once spent.
- `Karanlık Tohum`'s "next draft has a Dagon" flag is **non-consuming** in `generate_draft()` (loss-check drafts must not eat it); `board_view` clears it with `clear_dagon_guarantee()` only after showing the real draft.

### Turn flow (as implemented in `board_view.gd`)

1. Player clicks an expandable empty cell (`_on_cell_pressed`) → locks that cell and collects any key there. **If a key was collected, the draft is deferred**: key flight → `_advance_lock` → (4th/`Kestirme` key: lock-open linger first) → `_on_key_collected` opens the relic chooser → after the pick, `_on_relic_chosen` → `_show_draft_for_pending()`. No key → `_show_draft_for_pending()` immediately. The draft must be generated *after* the relic so draft-affecting relics apply that turn.
2. Player buys a tile from the draft (`_on_pair_selected`) → price is `pair["price"] + pending_surcharge` (`+2` only for cells reachable solely via `Çapraz Adım`; `Boşluk Deldirme` is free) or `0` (Kadim Anahtar on a key cell); with `Sabit Yön` only rotation 0 is valid and there's no rotate panel; otherwise if exactly one rotation fits it places immediately, else shows the rotate/confirm panel.
3. On placement (`_finalize_tile_placement`) → `Ayna Tahta` mirror copy, then win check (reaching `WIN_ROW`/`WIN_COL`), then creature-placement mode.
4. Player clicks a valid empty-slot cell to place the creature (`_on_creature_target_pressed`) → scores via `CreatureScorer`, pays via `Economy`; if `twin_armed` (`Çift Ruh` was activated) it re-enters creature mode once with the same type; `Ruh Pazarı` (one-shot) adds a "Yak" button (`_on_creature_burn`, +3 souls instead of placing).

Node lookups between scripts go through Godot's unique-name (`%NodeName`) system (`unique_name_in_owner` on scene nodes) rather than exported node paths — check `scenes/main.tscn` when adding new cross-node references.
