# FossieGearScore 0.1.22

Gear scores for **WoW Forever**. Normal **GS** rates the item; **DGS** adjusts it
for the wearer's class and talents. Scores appear on items, player hovers, and
both character and inspect panels.

## Install

1. Put the `FossieGearScore` folder in your client's `Interface/AddOns` folder.
2. Enable it in the AddOns menu.
3. Restart the client after installing the icon files; use `/reload` for code updates.

## Using the addon

- Hover gear to see item, set and permanent enchantment points. Bag items also
  show a colored difference against equipped gear.
- Hover a player to see their total and talent spread. Other players require a
  successful inspection; the addon requests one in the background when possible.
- Character and inspect totals sit above the weapon slots, in gold with a black shadow.
- The talent dropdown previews another role without changing actual talents.
- Click the shield minimap button to open settings. Drag it to move; its position is saved.

## Settings and commands

`/fgs settings` opens display options. Choose **Both**, **Normal**, **Dynamic**, or
**None** independently for panels, player hovers, and item tooltips. Equal GS/DGS
rows collapse in Both mode. The minimap icon can be hidden in settings or toggled
with `/fgs minimap`.

For troubleshooting: `/fgs debug` explains the last hovered item and enchant ID;
`/fgs talents` shows detected talents; `/fgs raw` shows source stats; `/fgs ui`
shows panel and hover status.

## How scores work

Normal scores combine weighted stats, item level, rarity and intrinsic effects.
Dynamic scores filter stats for the detected class and role. The top talent
trees within five points count as a hybrid. Players below level 10 or with no
spent talents have no DGS. Base armor keeps full value for everyone; only bonus armor
is reduced for non-tanks. Feral cat and bear share one profile.

Set bonuses are separate. Permanent enhancements add these **flat** points,
without rarity, role or set multipliers:

| Enchant tier | Points |
|---|---:|
| 1 | 1 |
| 2 | 2 |
| 3 | 4 |
| 4 | 8 |
| 5 | 16 |

Totals show the parts separately, for example **GS: 365 + 8**. The final item
row is **Enchantment Score**. Temporary oils, stones and poisons are excluded.

## Limits and development

English tooltips provide the fullest stat coverage. Missing data is marked
partial or unknown. Some shared two-handed enchant IDs use the lower applicable
tier; unverified attachments and extra stacked installs still need client testing.

Weights are in `Weights.lua` and `DynamicWeights.lua`; enchant tiers and IDs are
in `EnchantmentData.lua`. Run `python tests/run_tests.py` with Python's `lupa`
installed to check the Lua 5.1 fixtures.

Reuse an active development branch without changing its version. Increment the
version only when starting a new branch for changes. Create ZIPs/releases only
when requested.

## Changelog

### 0.1.22

- Shorten the README overview while preserving existing changelogs.
- Change enchantment tiers to 1, 2, 4, 8 and 16 flat points.
- Add the 128x128 shield AddOns icon and a draggable, optional minimap button.
- Make character and inspect GS/DGS totals gold with a black shadow.
- Start `dev/0.1.22`; keep this version for later changes on the same branch.
  No release packaged.

### 0.1.21

- Correct four basic armor-kit mappings that previously used only legacy
  simulator IDs. Add verified current application IDs while retaining aliases;
  tiers and flat point values remain unchanged.
- Add the reported Stamina +2 / Armor +16 leggings regression, current kits on
  every eligible slot, and separate equipment totals.
- `/fgs debug` now prints the applied ID, recognition source, tier and unknown
  reason for permanent enhancements. No release packaged.

### 0.1.20

- Keep full base Armor for non-tanks; halve only bonus armor.
- Show actual GUID-bound talent points on player hovers, preserving previews.
- Add all 249 assigned permanent enhancement entries with flat 5 points per
  tier, one final tooltip row, and separate known/unknown total additions.
- Collapse equal normal/dynamic rows in Both mode while retaining Dynamic-only.
- Move both override dropdowns above the weapon row and center totals above them.
- Cache parsed intrinsic/dynamic scores and effective preview profiles. Refresh
  on changed raw/tooltip/metadata, affected item loads, converter changes and
  level updates; reuse unchanged dropdown menus. Extend regression coverage.
  No release packaged.

### 0.1.19

- Read equipped set context from existing character/inspect records instead of
  rescanning inventory during each set comparison tooltip rebuild.
- Cache available talent profiles; invalidate on talent/config/level changes.
  Throttle unavailable-data reads to twice a second, preserving inspection retries.
- Match native tooltip update IDs to equipment records and batch affected/pending
  updates over 0.25 seconds. Ignore unrelated completed tooltip data and stale
  pending inspections. Refresh visible set tooltips only when their data changes.
- Keep real equipment, inspection and item-loading refreshes. Add performance
  regressions alongside the existing delayed-item and native talent fixtures.
  No release packaged.

### 0.1.18

- Add a native purchased-node fallback for valid configs with unavailable group
  currency totals, matching the reported `currency-data-pending` diagnostic.
- Match ranks to ordered talent group IDs, deduplicate nodes, exclude increased
  ranks, and keep partial/ambiguous data hidden. Preserve inspect config isolation.
- Extend native API and display regressions for empty/missing/zero currencies,
  purchased versus free ranks, partial nodes and all dynamic display modes.
  No release packaged.

### 0.1.17

- Read Forever talent points from native trait configs and ordered group currency
  data, prioritizing the active dual spec and separate inspect config. Legacy
  tab APIs no longer silently hide native profiles. Refresh on native trait events.
- Anchor override dropdowns below level/class text rather than the pane corner;
  account for visible inspect title/guild text.
- Add independent inspect-player preview dropdowns, GUID-bound session choices,
  owner-specific cached rescoring and protection against stale open menus.
- Add `/fgs talents` diagnostics and native API regressions for zero legacy
  points, late trait data, active dual spec, all display modes and remote overrides.
  No release packaged.

### 0.1.16

- Restore Survival Hunter Strength and supported melee weapon skills, including
  hybrids with Survival. Keep caster weapon damage/DPS, base scoring and hybrid
  union behavior unchanged.
- Remove Warrior/Rogue Mana and MP5; filter supported skills by class and role;
  remove Druid parry and all block stats. Preserve normal scoring weights.
- Add five-second hover-driven retries for zero/missing inspected talents.
- Add native per-character talent override dropdown: Default and class tree names.
  Refresh own scores/comparisons immediately; leave remote talent profiles intact.
- Extend integration fixtures for cooldown/rehover/manual inspection, dropdown
  placement/selection, saved overrides, character isolation and profile eligibility.
  No release packaged.

### 0.1.15

- Classify talent trees and hybrids (top two within five points), using Forever's
  modern pointsSpent API plus legacy compatibility signatures.
- Apply class, role and damage-school weights independently from normal GS.
- Hide dynamic scores without spent talents, below ten, or with unknown data.
- Cache inspected talent profiles with gear snapshots; refresh after own talent changes.
- Extend Lua fixtures for all nine classes, roles, API signatures, reset hiding,
  hybrid boundaries, and remote/offline profile isolation. No release packaged.

### 0.1.14

- Add independent dynamic weights and empty per-class overrides for later balancing.
- Display dynamic item/set scores, bag differences, and character/inspect/hover totals.
- Retain the inspected wearer's class when rescoring cached equipment.
- Add three native display dropdowns with saved preferences and immediate refresh.
- Keep all initial dynamic weights equal to normal weights; no release packaged.

### 0.1.13

- Reduce the extra Equip/Chance on hit base factor to 1.05 for uncommon through legendary items.
- Increase both regular and bonus armor weights from 0.01 to 0.02.
- Reduce the healing weight from 0.5 to 0.4, retaining shared spell-power deduplication.
- Update score fixtures, diagnostics examples and the CSV to the new weights.

### 0.1.12

- Request missing equipped-item data explicitly and retain every full item link.
- Complete saved snapshots through item/tooltip loading events and bounded delayed rescans.
- Finish item loading after the player moves away or another inspection takes ownership.
- Preserve the inspected player's set activation when later scoring saved item links.
- Keep incomplete remote subtotals out of player tooltips and out of the fresh-cache check.
- Preserve a complete cached score while a newer inspection's equipment data loads.

### 0.1.11

- Inspect hovered players in the background with a delay, cooldown, timeout and retry backoff.
- Pause during combat; prioritize manual inspection and inspection requests from other addons.
- Show **Inspect to see GS** for players without an available score; update the same line on success.
- Refresh older cached totals and newly loaded item data without opening the inspect window.
- Hide **Item Score** on shirts and tabards without stats or intrinsic effects.

### 0.1.10

- Replace the initial 1.25 set factor with one extra 1.05 factor: `1.05^(pieces + 1)`.
- Retain the minimum of 1 Set Bonus Score for active sets and zero for inactive sets.
- Update all tooltip, character, inspection and cached hover totals through the shared formula.

### 0.1.9

- Give intrinsic on-use items the item-level base with a single 1.5 effect factor.
- Apply the active set's initial 1.25 factor before the per-piece 1.05 factors.
- Show green/red/white Item Score differences on bag equipment tooltips.
- Compare both ring/trinket slots, handle weapon replacements, and mark unknown comparisons.
- Refresh visible bag comparisons after gear changes; preserve panel and hover totals.

### 0.1.8

- Give effect-only items the item-level base, including the existing effect/rarity factors.
- Recognize active `Set:` lines without a piece number and fully active set sections.
- Support alternate numbered set formats and remove the gray-color activation veto.
- Apply a minimum of 1 Set Bonus Score to each member of an active set.
- Parse `+2 to All Resistances`, including API deduplication and signed penalties.
- Keep item tooltips, character totals, inspection totals and cached hover scores consistent.
- Explain the minimum set point in `/fgs debug`.

### 0.1.7

- Apply the rarity-specific extra item-level factor for equip/chance-on-hit effects.
- Show active set additions on a separate Set Bonus Score line.
- Apply one 1.05 multiplier per worn set piece after the intrinsic item score.
- Include both score lines in character, inspect and cached hover totals.
- Count each player's sets independently and refresh bonuses after equipping/removing pieces.
- Keep known set membership while stat data loads; preserve zero for statless items.

### 0.1.6

- Change the final score divisor from 2 to 4; retain rounding down.
- Move panel totals above model backgrounds and refresh on root-window opening.
- Fix the native tooltip unit/GUID return order to display inspected player totals.
- Add tooltip-opening recovery, GUID-checked skin fallbacks and `/fgs ui` diagnostics.
- Correct regression fixtures to reflect the actual Forever UI and tooltip API.

### 0.1.5

- Add bottom-left equipped gear totals to character and inspect panels.
- Add GUID-keyed inspection snapshots to player hover tooltips.
- Items without recognized scored stats now score 0 and get no item-level base.
- Use the same item reader for individual item scores and equipment totals.
- Mark loading/incomplete equipment totals rather than inventing missing points.

### 0.1.4

- Renamed the addon, folder, TOC and diagnostic namespace to FossieGearScore.
- Downloads use the filename FossieGS-BUILDNUMBER.zip.
- `/fgs` remains the short command; the long command is now `/fossiegs`.

### 0.1.3

- Arcane, Fire, Nature, Frost, Shadow and Holy damage weights are 1 each.
- Divide the complete score by 2 and round down at the very end.
- Display the whole-number result beside a pink Item Score label.
- Debug output includes the final division and floor operation.

### 0.1.2

- General Spell Damage weight is 1; Healing weight is 0.5.
- Every scored equipment item gets an item-level base of `item level × 1.2`.
- Apply the configured rarity multiplier to stat plus base points.
- Debug output explains the base and rarity calculation.
- Missing metadata produces an explicitly partial score.

### 0.1.1

- Shared spell damage/healing bonuses count once using the higher weight.
- Separate additional damage or healing still contributes normally.
- `/fgs debug` explains the shared portion and its selected category.
- Both melee and ranged DPS retain the previously requested weight of 1.4.
