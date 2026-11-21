# <ID> — <title>

Written by: Opus (planner). Implemented by: `implementer` agent (Sonnet). Playtested by: `playtester` agent (Sonnet).
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
One or two sentences: what the player can do afterwards.

## Source of truth
Spec sections, reference observations (`docs/REFERENCE_GAME_LIVE_TEST.md` §…) and owner decisions this plan implements.

## Skills to load
For example: roblox-data, roblox-networking, roblox-security, roblox-gui.

## Files
| File | New/Change | Purpose |
|---|---|---|

## Data and config
Exact config keys with values and evidence tags (OBSERVED/PROVISIONAL), schema fields, migration steps.

## Steps
1. Exact change, with function names and signatures, error codes and strings (English).
2. …

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|

## Playtest (Studio, via playtester)
1. Setup.
2. Action → expected result (values to read back, objects that must exist).

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (expected count), `rojo build`.
- Behaviour criteria from the backlog ticket.

## Out of scope
What this plan deliberately does not do.
