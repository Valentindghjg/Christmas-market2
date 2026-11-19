# P0 implementation audit

Date: 2026-11-19  
Scope: existing Rojo scaffold and shared Luau modules prior to feature expansion.

## Resolved findings

1. **Critical — caller-controlled wholesale cost.** `BusinessState.buyStock` accepted a unit cost argument. Any future RemoteEvent that forwarded client data could have let a player buy stock for zero. The function now derives its price from `GameConfig.wholesaleFor`; callers provide only species, size and quantity.
2. **High — invalid numeric values could enter economy helpers.** `NaN`, infinities and fractional currency were not consistently rejected. Economy, inventory and business-state validation now require finite integers for persisted money and stock quantities.
3. **Medium — configuration was incomplete for a server-owned quote.** Wholesale prices are now defined per species and size. Medium values are screenshot-observed; Small and Large values are explicitly provisional balance values.
4. **Medium — no automated test structure.** Added a framework-free Studio unit-test runner and contract tests for Economy, Inventory and BusinessState. The runner lives under `ServerStorage.UnitTest` when synchronized through Rojo.

## Verified evidence

- `rojo build default.project.json --output build.rbxlx`: PASS.
- Roblox Studio Play Server: PASS, 11 direct contract checks covering tier prices, invalid money, inventory mutation, server-derived costs and atomic insufficient-funds rejection.
- Rojo server: PASS at `http://localhost:34872` (HTTP 200).

## Tooling follow-up

The running Rojo Studio plugin synchronized changes to existing source instances, but did not add the newly mapped `ServerStorage.UnitTest` root during this session. `rojo sourcemap` and `rojo build` both include the test tree correctly. Reconnect the Rojo plugin or reopen the place before treating the runner's automatic discovery as Studio-verified. Direct Play Server checks were used for this audit and are the only test result claimed above.

## Open blockers and next work

- There is no versioned company schema/migration, session lock, DataStore persistence, remote action protocol or authoritative command queue yet (CM2-06 through CM2-09).
- `buyStock` currently places stock directly into the aggregate stock map; the required pending/delivered/stored/displayed/reserved lifecycle has not been implemented.
- Studio output emitted repeated `rbxassetid://203785492` asset-type warnings. This is not introduced by project source and should be investigated before visual QA.
- No map, UI, delivery simulation, NPCs, published content or paid products were created.
