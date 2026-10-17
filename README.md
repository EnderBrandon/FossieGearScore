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
  enhancement coverage.
  Use **Refresh** to retry unavailable data.

Open settings with `/fgs settings` or the minimap button. Choose normal,
dynamic, both or no scores separately for panels, player hovers and items.
Enchantment points are combined into totals by default. Choose separate points
independently for panels and player hovers.
Drag the minimap button to move it; hide it in settings or with `/fgs minimap`.

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

## Changelog

### 1.1.0

- Add a movable GearScore inspection window to your own and target portrait menus.
- Show player details, talents, GS/DGS, weapons and the highest-scoring armor item.
- Show eligible-piece enchantment coverage; hover for tiers and separate missing
  and unknown counts.
- Keep the selected player's data visible when changing targets.

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
