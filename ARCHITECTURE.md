# Orbit Idle Architecture

This refactor reduces `main.lua` local-variable pressure by moving static data and card-run gameplay logic into dedicated modules while keeping behavior stable.

## Current Module Layout

- `main.lua`
  - Love2D entry point and orchestration layer.
  - Owns rendering, input routing, audio runtime, and callback wiring.
  - Delegates simulation and card-run logic to systems.

- `game/config/game_config.lua`
  - Single source of truth for static configuration:
    - world/camera/render constants
    - card definitions and deck lists
    - audio constants
    - palette/swatch data
    - orbiter/body config tables

- `game/systems/orbiters.lua`
  - Orbiter creation and per-frame orbital simulation.
  - Handles boost stacks, speed multipliers, and orbit advancement.

- `game/systems/card_run.lua`
  - Owns run lifecycle (`startCardRun`, epoch transitions, collapse/completion).
  - Owns deck/hand/discard flow and card effects.
  - Pulls the active run deck from deck-builder state at run start.
  - Owns body OPE aggregation, epoch simulation payouts, and point tracking.
  - Awards end-of-run currency rewards once per run.

- `game/systems/deck_builder.lua`
  - Owns persistent deck/inventory/currency state.
  - Enforces deck size bounds (min/max cards).
  - Handles deck edit actions:
    - remove card from deck -> inventory
    - add card from inventory -> deck
  - Handles shop purchases and affordability checks.

- `game/systems/modifiers.lua`
  - Shared additive/multiplicative stat aggregation service.

## Runtime Wiring

`main.lua` initializes:

- `runtime.deckBuilder`
- `runtime.modifiers`
- `runtime.orbiters`
- `runtime.cardRun`

Core flow:

1. `runtime.cardRun:update(dt)` advances calm planning motion and epoch simulation motion.
2. `runtime.cardRun` is called from UI/input actions:
   - `playCard`
   - `endEpoch`
   - `startCardRun`
3. `runtime.deckBuilder` is called from deck menu UI actions.
4. Rendering/UI reads from shared `state` only.

## Practical Extension Rules

- Add new constants/cards/orbit tuning in `game/config/game_config.lua`.
- Add new run mechanics in `game/systems/card_run.lua`.
- Add deck/currency/shop behavior in `game/systems/deck_builder.lua`.
- Keep `main.lua` focused on:
  - translating input events to system calls
  - frame update/draw orchestration
  - pure presentation code

## Why This Helps

- Avoids repeatedly hitting Lua’s local-variable limits in `main.lua`.
- Keeps gameplay logic testable and isolated from render code.
- Makes future system splits incremental (audio/UI/render can be extracted next without touching card rules).
