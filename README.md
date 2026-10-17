# FossieGearScore 1.1.0

Gear scoring for **WoW Forever**. **GS** rates gear by its stats and effects;
**DGS** adjusts the score for the player's class and talents.

## Install

Place the `FossieGearScore` folder in `Interface/AddOns`, then enable it in the
AddOns menu.

## Use

- Hover items to see scores, set bonuses and enchantment points. Bag items and
  quest rewards show a comparison with equipped gear.
- See equipped totals on the character and inspect panels, plus the inspected
  player's spec. Hover players to see their total and talent points once
  inspection data is available.
- Use the talent dropdown on either panel to preview gear for another spec.
- Right-click your own portrait or a player's target portrait and choose
  **GearScore** for an inspection window with weapon highlights and permanent
  enhancement coverage, level-based GS/DGS ratings and a spec-fit assessment, plus
  dungeon ratings for the player's level.
  Use **Refresh** to retry unavailable data.

Open settings with `/fgs settings` or the minimap button. Choose normal,
dynamic, both or no scores separately for panels, player hovers and items.
Enchantment points are combined into totals by default. Choose separate points
independently for panels and player hovers.
Adjust **GearScore menu background opacity** in settings (0–100); text and icons
remain fully visible. Zero is transparent and 100 is fully opaque; existing
opacity preferences are preserved; new/unset preferences default to 90%.
The compact menu keeps enhancement counts
and tiers on hover and shows only pink **Enchanted** on equipped item highlights.
The enchantment bar uses the player's highest confirmed equipped tier as blue,
one tier lower as green, two lower as yellow and all lower tiers as red. Missing
enchants are grey; unknown/uncertain tiers are neutral white. The bar fills from
left to right, grouping confirmed tiers from highest to lowest, then other
installed enchants, unknown coverage and finally missing enchants. For example, if the
highest worn tier is 2, tier 2 is blue and tier 1 is green.
The portrait menu entry is blue. Matching GS/DGS item scores appear once.
Drag the minimap button to move it; hide it in settings or with `/fgs minimap`.

Player hover tooltips show a normal-GS level rating above their score rows:
Overgeared, Well Geared, Averagely Geared, Badly Geared or Very Badly Geared.
The menu's Geared and Well geared bands both appear as Well Geared on hover.
Partial or unavailable gear and missing level references receive no hover rating.
The rating reads the captured GS without evaluating alternate specs.

A small update popup appears at login until **Okay!** acknowledges its notice.
Edit the text in `UpdateMessage.lua`; change its `id` to a new value when you
want everyone to see it again. Text edits and ordinary addon updates with the
same ID do not repeat acknowledged notices. Set `enabled=false` to disable it.
Acknowledgement is saved account-wide in the addon's existing saved variables.

## Scoring

DGS requires level 10 or higher and spent talent points. Builds with the two
leading talent trees within five points count as hybrids. Scores are estimates,
not a best-in-slot ranking. DGS never exceeds the normal GS of an item.
English tooltips have the fullest coverage; incomplete data is marked partial
or unknown.

Items assigned to another role receive half DGS. Unassigned items also receive
half DGS if none of their stats benefit your spec and they have no Equip, Use
or chance-on-hit effect. Hybrid builds accept their combined roles.

Permanent enchants and armor kits add points by tier:

| Tier | Points |
|---|---:|
| 1 | 1 |
| 2 | 2 |
| 3 | 4 |
| 4 | 8 |
| 5 | 16 |

`LevelBenchmarks.lua` retains the supplied provisional GS reference for each
level from 1 to 60. `byLevel[level]` contains the original number;
`splitsByLevel[level][80]` (and 90, 110, 120, 140) contains its exact percentage
cutoff. The menu rates ordinary GS and available DGS separately against the
player's current level using the same six labels as the dungeon table. The DGS
column includes its percentage of the level reference, independently of the
spec-fit caption: gear can be optimal for a spec yet weak for the player's level.
A missing or zero reference has no level rating.
These references exclude permanent enchantment points, regardless of the chosen
display mode.

The spec-fit caption compares unenchanted DGS with unenchanted GS. Equal positive
scores or a loss strictly below 5% show **Gear optimal for [spec]** under the
addon's weights. Below 80% shows **Gear suboptimal for [spec]**; 80% through 95%
shows the fit percentage. Exactly 5% loss is outside the optimal band. Unknown talents, incomplete gear data and nonpositive GS cannot
produce a spec-fit judgement. Percentages displayed in this caption round down;
the comparisons use exact values.

For suboptimal gear, the addon scores the same captured items for the class's
other talent trees. It suggests the best alternative only if it retains at least
80% of GS and improves on the current DGS; tied best specs appear together.
This uses the same stat weights, effects, role penalties, item caps and captured
wearer set bonuses as normal DGS. Recommendations cache per gear snapshot and
never change talents, preview selections or equipped scores. Manual DGS previews
are assessed for their labelled override spec. Feral remains one combined profile.

Dungeon ratings compare DGS plus permanent enchantment points with the supplied
reference in `DungeonBenchmarks.lua`. If DGS is unavailable, the table uses normal
GS and labels its columns accordingly. The numeric comparison stays the same in
combined and separate display modes. Partial scans and unknown enchantment
scores show an unavailable rating. Benchmarks are manual estimates,
not entry requirements; a rating does not measure player skill.

`DungeonLevels.lua` stores inclusive level bands reported in-game by the addon
author on 17 October 2026. Gnomeregan retains its earlier 29–38 range from
[Wowhead's Forever dungeon range chart](https://www.wowhead.com/forever/guide/dungeons-overview-locations-details)
because it was not included in the in-game report.
Ranges are separate from shared benchmarks, so paired dungeons can appear at
different levels. Only the fourteen instances with supplied benchmarks are rated.
Instances currently in range with the same reference share one row, with names
and individual level ranges stacked vertically beside one reference and rating.

| Comparison score / reference | Rating |
|---|---|
| Below 80% | Far below |
| 80% to below 90% | Below average |
| 90% to below 110% | Average |
| 110% to below 120% | Geared |
| 120% to below 140% | Well geared |
| 140% or higher | Overgeared |

Cutoffs use exact percentages, not the benchmark export's rounded point values.

## Changelog

### 1.1.0

- Add a movable GearScore inspection window to your own and target portrait menus.
- Show player details, divided GS/DGS totals and compact equipment highlight cards.
- Add a background opacity setting for the GearScore menu, defaulting to 90%.
- Add a hover gear rating, relative enchantment tier colours and a configurable
  update popup with saved acknowledgement.
- Add level GS benchmarks with exact rating cutoffs and a cached spec-fit summary
  that can suggest better-fitting talent trees for suboptimal gear.
- Show an enchantment coverage bar; hover for eligible counts, tiers and separate
  missing and unknown counts.
- Keep the selected player's data visible when changing targets.
- Show level-filtered dungeon ratings using DGS, with normal GS as a fallback.

### 1.0.1

- Show GS and DGS comparisons on quest rewards.
- Add combined or separate enchantment totals for panels and player hovers.
- Hide inactive set bonuses and preview set bonuses on bag items.
- Rebalance healing gear scores, with reduced healing value for DPS and tanks.
- Reduce DGS for stat-only items with no useful stats for your spec.
- Fix negative-stat scoring and prevent DGS from exceeding GS.
- Improve performance when hovering items and inspecting players.

### 1.0.0

- Improve performance when comparing gear and loading item data.
- Release under the MIT license.

### 0.1.22

- Change enchantment points to 1, 2, 4, 8 and 16 for tiers 1–5.
- Add a minimap button for settings.
- Improve readability of equipped totals.
- Show the inspected player's current spec.

### 0.1.21

- Fix recognition of basic armor kits.

### 0.1.20

- Keep full base armor value in DGS for non-tanks; reduce only bonus armor.
- Show talent points when hovering players.
- Add permanent enchantment and armor-kit scoring to items and totals.
- Hide duplicate GS/DGS values when both scores are enabled.
- Reduce frame-rate drops when hovering items.

### 0.1.19

- Reduce frame-rate drops when hovering inspected players' gear.

### 0.1.18

- Fix missing DGS when talent totals are unavailable but selected talents can
  still be read.

### 0.1.17

- Fix talent detection and DGS for the active spec.
- Add talent overrides for inspected players.

### 0.1.16

- Count melee stats for Survival Hunters in DGS.
- Exclude mana and MP5 for Warriors and Rogues, unsupported weapon skills,
  and parry/block for Druids from DGS.
- Recheck players whose talents were previously missing or unspent.
- Add a talent override to preview another spec's gear scores.

### 0.1.15

- Adjust DGS for class, spec and spell damage type, including hybrid builds.
- Hide DGS below level 10 or when no talents are selected.

### 0.1.14

- Add DGS to item tooltips, gear comparisons and equipped totals.
- Add separate display settings for items, player hovers and panels.

### 0.1.13

- Increase armor scoring and reduce healing and passive-effect scoring.

### 0.1.12

- Fix missing or incomplete player totals while inspected items load.
- Keep set bonuses accurate after inspection data loads.

### 0.1.11

- Inspect hovered players in the background when possible, outside combat.
- Hide item scores on shirts and tabards without stats or effects.

### 0.1.10

- Adjust active-set bonus scoring.

### 0.1.9

- Improve scoring of items with on-use effects.
- Add colored comparisons against equipped gear, including paired ring and
  trinket slots and weapon replacements.

### 0.1.8

- Score items whose only benefit is an effect.
- Recognize more set-bonus formats and all-resistance bonuses.

### 0.1.7

- Add active set-bonus scores to item tooltips and equipped totals.

### 0.1.6

- Reduce overall score values.
- Fix missing totals on character, inspect and player tooltips.

### 0.1.5

- Add equipped totals to character, inspect and player tooltips.
- Give items without scored stats or effects a score of zero.

### 0.1.4

- Rename the addon to FossieGearScore, with `/fgs` and `/fossiegs` commands.

### 0.1.3

- Adjust spell damage scoring and round scores down to whole numbers.

### 0.1.2

- Include item level and rarity in scores; adjust spell damage and healing weights.
- Mark scores with missing item data as partial.

### 0.1.1

- Count combined spell damage/healing bonuses once while retaining separate
  additional bonuses.
