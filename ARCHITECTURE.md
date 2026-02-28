# Orbit Idle Architecture

This refactor keeps gameplay behavior while moving progression/economy/simulation into explicit systems.

## System Layout

- `main.lua`
  - Owns rendering, input routing, and Love2D lifecycle hooks.
  - Initializes runtime services in `initGameSystems()`.
  - Delegates simulation (`update`) and purchases to services.

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
  - Owns orbiter creation, impulse boosts, and orbit simulation.
  - Emits orbit rewards and FX callbacks.
  - Applies speed multipliers from modifier keys:
    - `speed_global`
    - `speed_<kind>` (`speed_satellite`, `speed_moon`, etc.)

- `game/systems/upgrades.lua`
  - Owns speed wave / speed click / black hole upgrade behavior.
  - Owns stability mechanics and ripple/text timers.

## Runtime Wiring

`main.lua` creates a single runtime container:

- `runtime.modifiers`
- `runtime.economy`
- `runtime.progression`
- `runtime.upgrades`
- `runtime.orbiters`

Update order each frame:

1. `runtime.upgrades:update(dt)`
2. `runtime.orbiters:update(dt)`
3. `runtime.progression:update()`

This keeps visual/UI code stable while gameplay logic lives in systems.

## Adding Future Skill Trees / Perks

- Add skill nodes in `DEFAULT_SKILL_TREE` (`game/systems/progression.lua`).
- Add auto-unlock perks in `DEFAULT_PERKS` with thresholds/conditions.
- Define modifier payloads per node/perk using `{ add = x, mul = y }`.
- Existing systems consume those modifiers automatically if keys match supported stats.

Examples:

- Click specialization:
  - `planet_click_impulse_boost`
- Satellite specialization:
  - `speed_satellite`
  - `speed_moon_satellite`
- Moon perks:
  - `speed_moon`
  - `cost_moonSatellite`

## Behavior Preservation Notes

- Existing orbit generation, UI interactions, and rendering are preserved.
- Current perks are scaffolded and disabled by default in progression definitions.
