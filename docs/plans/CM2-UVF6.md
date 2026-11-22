# CM2-UVF6 — Team panel on a Solo save hides New code

Written by: `planner` (Opus 5.5, high). Implemented by: the tier's agent. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything is decided; if something is missing, the implementer stops and reports.

## Goal
The owner of a Solo save no longer sees a `NewCode` button that can only fail. After a resize to Duo or larger, `NewCode` comes back and `CodeLine` shows the server's code. A resize back to Solo hides it again.

## Source of truth
- Backlog launch order 5g; CM2-UV observations under 5b (uv-f9: the Solo owner view shows "Solo saves have no invite code." next to a visible `NewCode`).
- PRODUCT_SPEC "Saves and multiplayer": Solo saves have no invite code, and only the owner renews the code (CM2-S2).
- CM2-UVF4 (f61a3b8): Team footer 96 px (`UiTheme.Dialogs.Team.footerHeight`). `CodeLine` sits at y 58 and `CodeHint` at y 98. Neither changes here.

## Analysis
- The server already refuses the action, and nothing changes there. `SaveSlotService:_regenerateCode` returns `SoloHasNoCode` when `info.saveSize == "Solo"`, before it claims a code. `BusinessState.setInviteCode` refuses a code on a Solo state in the same way. `_setSize` gives a save that grew from Solo its first code (`_ensureInviteCode`) and calls `_teamChanged`.
- What is missing is a test through the service path. `BusinessState_Test` covers only the state function. This plan adds that test, so no server guard is in scope and the tier stays S.
- The client cause is in `TeamPanel.client.lua` `render`: `newCode.Visible = owner` ignores `solo`. After every own action, `act` sets `refetchPending`, so a `Size_*` click re-renders from `Save.Team`. Visibility therefore follows the server size with no new event.

## Implementer tier
Tier: S. Reason: a one-line visibility rule in one client script, plus one service-path test and doc lines. No change to the save schema, money, inventory, purchases or remote validation (the server guard already exists).

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-input, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-security (read only: confirm that the server guard stays the authority), roblox-tooling.

## Decisions (settled)
| # | Decision |
|---|---|
| D1 | `NewCode` is shown only when `owner and not solo`. `LeaveTeam` stays `not owner`, and `Size_*` stay `owner`. |
| D2 | The footer layout is unchanged. On a Solo owner view the left half of the bottom row stays empty, and `Close` keeps its place on the right half (same position in every view). No new string keys. `CodeLine` keeps `teamNoCode` on Solo, and `CodeHint` stays hidden on Solo. |
| D3 | No server change. The service-path test (Tests) pins the existing `SoloHasNoCode` refusal and the code a save gets when it grows to Duo. |
| D4 | Studio test per `cm2-task` step 3 batching. The queue "Studio-Test ausstehend" holds CM2-UVF5, so this task is position 2. BUILD stays `cm2-n1-fix2` and RunPlaytest is unchanged. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/client/TeamPanel.client.lua` | Change | D1 in `render` |
| `tests/studio/Cases/CoopSave_Test.lua` | Change | 1 test |
| `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md` | Change | entry, one sentence |

No other file changes.

## Data and config
None. No save fields, config keys, string keys or remote changes.

## Steps
1. **TeamPanel.client.lua** `render`: replace `newCode.Visible = owner` with `newCode.Visible = owner and not solo`. Put this comment on the line above it: `-- Solo saves have no invite code, so the owner gets no New code button (CM2-UVF6).` Nothing else in the file changes.
2. **CoopSave_Test.lua**: add the test below directly after "a new code invalidates the old one" (line 413 block). Use only the existing helpers `setup`, `coopSave`, `act`, `inviteOf`, `OWNER`, `BusinessState`.
3. **DECISION_LOG.md**: add an entry at the end, titled `## 2026-11-22 — CM2-UVF6 New code hidden on Solo (engineering)`, with these bullets:
   - the defect (uv-f9);
   - "The server already refuses `Save.RegenerateCode` on Solo with `SoloHasNoCode`; no server change, now pinned by a service-path test";
   - D1;
   - D2;
   - files;
   - headless total.
4. **TEST_PLAN.md** section 3, item J: append ` Team footer on Solo: \`CoopSave_Test\` Solo code case; Studio CM2-UVF6.`

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| CoopSave_Test | a Solo save refuses a new code until it grows | See the asserts below the table. |

The asserts, in order:
1. `local env = setup()`; `local save = coopSave(env, "Solo")`; `save.code == nil`.
2. `local refused = act(env.a, OWNER, "Save.RegenerateCode")`; `refused.ok == false`; `refused.errorCode == "SoloHasNoCode"`.
3. `env.a.companies:teamInfo(save.companyId).inviteCode == nil`.
4. `act(env.a, OWNER, "Save.SetSize", { size = "Duo" }).ok`.
5. `local team = act(env.a, OWNER, "Save.Team")`; `team.ok`; `team.data.size == "Duo"`; `BusinessState.isInviteCode(team.data.inviteCode)`; `inviteOf(env, team.data.inviteCode).saveId == save.saveId`.
6. `local renewed = act(env.a, OWNER, "Save.RegenerateCode")`; `renewed.ok`; `renewed.data.inviteCode ~= team.data.inviteCode`.

Headless total: **400** (399 + 1). If the baseline on HEAD is not 399, the expected total is baseline + 1; report the baseline.

## Playtest (Studio, via playtester; batch run, position 2)
Helpers come from `docs/plans/CM2-UV.md` and its H4b amendment:
- D4 clicks: GUI space, `AbsolutePosition + AbsoluteSize/2`, without `GuiService:GetGuiInset()`.
- D5 timeouts, D7 test data, H, `sa`, R and H4b.

All UI names are under `PlayerGui.TeamUI.TeamPanel` (`Footer.*`, `CodeLine`, `CodeHint`, `MemberList.TeamStatus`).

0. **Sync check.** The Edit DM script `StarterPlayer.StarterPlayerScripts.Client.TeamPanel` Source contains `owner and not solo`, and RunPlaytest BUILD is `cm2-n1-fix2`. If either fails, all steps are BLOCKED "Studio not synced with Rojo". Record HEAD and the viewport.
1. **Setup.** Play is running, and the player is on "Playtest A" with `CompanyReady == true`.
   - Delete any leftover "UV Solo" save.
   - `sa(R, "Save.Create", {name = "UV Solo", size = "Solo"})`, then `sa(R, "Save.Play", {saveId})`.
   - Wait for `CompanyReady == true` and `ActiveSaveSize == "Solo"`.
2. **Solo owner view.** Click `TeamButton` → `TeamPanel.Visible`.
   - Wait until `CodeLine.Text` equals `teamNoCode` ("Solo saves have no invite code.").
   - PASS when:
     - `Footer.NewCode.Visible == false`;
     - all 4 `Footer.Size_*` have `Visible == true`;
     - `Footer.Close.Visible == true`;
     - `Footer.LeaveTeam.Visible == false`;
     - `CodeHint.Visible == false`;
     - H4b{TeamUI} is empty.
   - Capture `uvf6-1`.
3. **Grow to Duo.** Click `Footer.Size_Duo` (D4). Within 5 s, all of these hold:
   - `ActiveSaveSize == "Duo"`;
   - `Footer.NewCode.Visible == true`;
   - `CodeLine.Text` contains `sa(R, "Save.Team", {}).data.inviteCode` (5 digits);
   - `CodeHint.Visible == true`;
   - `TeamStatus.Text == ""`.

   Record the code. Capture `uvf6-2`.
4. **New code works.** Click `Footer.NewCode`. Within 5 s, `CodeLine.Text` contains the new `Save.Team` code, and that code differs from the one recorded in step 3.
5. **Back to Solo.** Click `Footer.Size_Solo`. Within 5 s:
   - `ActiveSaveSize == "Solo"`;
   - `Footer.NewCode.Visible == false`;
   - `CodeLine.Text` is the `teamNoCode` text;
   - H4b{TeamUI} is empty.

   Capture `uvf6-3`. Click `Footer.Close`.
6. **Cleanup.** `sa(R, "Save.Play", {saveId = <Playtest A>})`, wait for `CompanyReady`, then delete "UV Solo" (`Save.Delete {saveId, confirmName = "UV Solo"}`).
7. Run `runPlaytest {mode="full"}` → `mode=full steps=41 pass=41 fail=0`.

End: as in CM2-UV "End". No UV save is left, the player is on "Playtest A", and the place is never saved.

## Acceptance
- Checks, all on the same HEAD:
  - `stylua --check src tests`
  - `selene src tests`
  - `lune run tests/headless/run.luau`: 400 run, 0 failed
  - `rojo build default.project.json --output build.rbxlx`
  - `rojo build release.project.json`: 0 instances named UnitTest, RunPlaytest or StudioTestService
- Ticket (PC):
  - Solo owner: `NewCode.Visible == false`, and the `Size_*` buttons are shown.
  - After `Size_Duo`: `NewCode` is shown, and `CodeLine` equals the server code.
  - Captures `uvf6-1`..`uvf6-3` are in PROGRESS.
  - `runPlaytest {mode="full"}` is all PASS.
- Security: the server refusal `SoloHasNoCode` is pinned by the new test, and the UI change hides the button only; it grants nothing.
- Skills: touch targets unchanged (≥ 44 px), and no new strings. `git diff` touches only the files listed in "Files".

## Out of scope
- Any server or save change.
- A Solo hint such as "Choose a bigger size to invite friends" in the Team panel.
- Re-laying out the footer for the empty left half (CM2-UI).
- Phone and tablet sizes (CM2-UV2).
- The member view (it already hides `NewCode`).
