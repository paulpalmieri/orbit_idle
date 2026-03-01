# Orbit Idle Architecture

This prototype is structured around a timing/stability core loop, with simulation and content separated from rendering.

## System Layout

- `main.lua`
  - Owns rendering, input routing, and Love2D lifecycle hooks.
  - Initializes runtime services in `initGameSystems()`.
  - Delegates simulation (`update`) and purchases to systems.
  - Applies always-on black-hole gravity well post-processing.

- `game/systems/modifiers.lua`
  - Central stat-modifier registry.
  - Multiple sources can contribute additive (`add`) and multiplicative (`mul`) effects per stat key.

- `game/systems/progression.lua`
  - Skill-tree and auto-perk scaffolding.
  - Tracks progression state (`skillPoints`, unlocked skills/perks, earned orbits).
  - Pushes progression-derived modifiers into `ModifierSystem`.

- `game/systems/economy.lua`
  - Owns all cost lookups and orbit spending checks.
  - Costs are stat-driven via modifier keys: `cost_<id>`.

- `game/systems/orbiters.lua`
  - Owns orbiter creation and orbit simulation.
  - Emits orbit rewards and FX callbacks.
  - Applies speed multipliers from modifier keys:
    - `speed_global`
    - `speed_<kind>` (`speed_moon`, etc.)

- `game/config/gameplay.lua`
  - Central gameplay and simulation constants (`WORLD`, `GAMEPLAY`, `SLICE`, economy, audio, visuals).
  - Reduces `main.lua` local-variable pressure by moving large static tables out of the root chunk.

- `game/content/progression_content.lua`
  - Owns skill-tree node definitions, objective definitions/order, and skill links.
  - Builds tooltip content from upgrade-effect values.

- `game/config/assets.lua`
  - Central asset path registry.
  - Keeps path changes isolated from gameplay logic.

## Assets

- Audio and font assets are organized under:
  - `assets/audio`
  - `assets/fonts`

## Runtime Wiring

`main.lua` creates a single runtime container:

- `runtime.modifiers`
- `runtime.economy`
- `runtime.progression`
- `runtime.orbiters`

Update order each frame:

1. `runtime.orbiters:update(dt)`
2. `runtime.progression:update()`

This keeps visual/UI code stable while gameplay logic lives in systems.

## Adding Future Skill Trees / Perks

- Add skill nodes in `DEFAULT_SKILL_TREE` (`game/systems/progression.lua`).
- Add auto-unlock perks in `DEFAULT_PERKS` with thresholds/conditions.
- Define modifier payloads per node/perk using `{ add = x, mul = y }`.
- Existing systems consume those modifiers automatically if keys match supported stats.

Examples:

- Moon perks:
  - `speed_moon`

## Behavior Preservation Notes

- Existing orbit generation and timing/stability gameplay are preserved.
- Legacy visible light-source selection was removed (lighting remains via an invisible fixed light anchor).
- Gravity well visual distortion is now permanent and no longer upgrade-gated.
