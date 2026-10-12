# FossieGearScore 0.1.21

An initial item-score addon for WoW Forever 1.60.1 (interface 16001). It adds
**Item Score** to equipment tooltips, including item links and comparison frames
that use the game's item tooltip pipeline. Character and inspect totals sit
above the talent override dropdown, just above the bottom weapon slots.
Player hover tooltips show cached totals and actual **Talents: A/B/C** points.
Permanent enhancements add a separate **Enchantment Score**. No dependencies are required.
Bag equipment also shows a colored Item Score difference against your current gear.
Hovering another player requests inspection in the background when possible.

## Dynamic scoring and display settings

Dynamic scores use independent weights and the wearer's class/talent profile.
Normal scoring stays unchanged. The three trees are ranked by spent points;
when the top two nonempty trees are within **5 points**, the profile is marked
**Hybrid**. Every nonempty tree within 5 points of the leader contributes its
roles and useful schools. Thus 0/31/24 is Feral, 0/30/25 is Feral/Restoration
Hybrid, and 15/15/15 includes all three trees. Useful stats are preserved for
either role rather than averaging the two profiles.

No dynamic score is shown below level 10, with no spent talent points, or while
class/level/talent data is unavailable. Talent APIs are never called below 10.
Local talent changes refresh totals, item rows and bag comparisons. Inspected
talents are captured at a matching INSPECT_READY and cached by player GUID;
Forever's active trait config supplies the three ordered talent groups through
`C_Traits.GetGroupCurrencyInfo` and `currencyInfos[1].spent`. Own detection uses
the active dual-spec config; remote detection uses the dedicated inspect config.
If group currency data is missing (or zero while purchased ranks are present),
`C_Traits.GetTreeNodes` and `GetNodeInfo` provide a fallback. Purchased ranks
are summed once per node using its native groupIDs; increased/free ranks are
excluded. Incomplete or ambiguous node data stays unavailable, and a complete
zero-purchased profile still hides DGS. `/fgs talents` reports `trait-nodes` when
this fallback is used, plus fallback failure detail if data is still unavailable.
Legacy talent-tab APIs are used only when the native trait APIs are absent;
incomplete native data stays unavailable until it loads. Native trait update
events refresh scoring, including late inspection talent data;

offline gear loading retains that owner's profile. `/fgs debug` reports the
current item owner's specialization or why dynamic scoring is unavailable.

| Class | Tree order | Tank profile | Scored damage schools |
|---|---|---|---|
| Warrior | Arms, Fury, Protection | Protection | None |
| Paladin | Holy, Protection, Retribution | Protection | Holy |
| Hunter | Beast Mastery, Marksmanship, Survival | None | None: physical/ranged gear profile |
| Rogue | Assassination, Combat, Subtlety | None | None: physical gear profile |
| Priest | Discipline, Holy, Shadow | None | Discipline: Holy/Shadow; Holy: Holy; Shadow: Shadow; Night Elf racial: Arcane |
| Shaman | Elemental, Enhancement, Restoration | None | Nature/Fire/Frost |
| Mage | Arcane, Fire, Frost | None | Arcane/Fire/Frost |
| Warlock | Affliction, Demonology, Destruction | None | Shadow/Fire |
| Druid | Balance, Feral, Restoration | Feral (cat/bear combined) | Balance/Restoration: Arcane/Nature; Feral: none |

Having a damage school does not itself make a class a spell-power gear user:
Hunter magic shots and Rogue poisons are excluded from this initial physical
profile. Enhancement and Retribution retain their useful magical schools.
Feral is deliberately one tank/melee profile, including cats, as agreed.

- All profiles retain the full base Armor weight of 0.02. Non-tanks halve only
  bonus armor to 0.01; Defense becomes zero.
- Tanks retain 0.02 bonus armor and Defense; useful spell damage/schools halve.
- Unused damage schools score zero. Feral/Warrior/Hunter/Rogue generic spell
  damage scores zero. Shared damage/healing still counts once with the higher
  applicable weight, so Feral receives healing credit for a shared bonus.
- Casters/healers: Strength, all AP categories and weapon skills become zero;
  Agility halves. Hunters keep AP/ranged AP, Agility and ranged skills, but
  Strength and melee weapon skills score zero outside Survival. Survival and
  hybrids including Survival retain Strength and usable melee skills as well.
  Ranged-only AP is excluded for
  other classes, and feral-only AP is excluded outside melee Druids.
- Warriors/Rogues: Intellect, Mana and MP5 score zero. Druids keep base-form Intellect.
- Supported weapon skills are filtered by class and scoring role. Warriors keep
  supported melee skills; Rogues keep one-handed sword/mace/axe/dagger/fist skills
  (including Forever's new axes); melee Paladins keep sword/axe/mace and polearm
  skills; Enhancement keeps axe/mace/dagger/fist skills, including two-handed
  axes/maces. Hunters keep ranged skills and Survival also retains its usable
  melee skills. Feral uses Feral Combat Skill only. Casters/healers get no weapon
  skill points. Staff and Bow Skill have no baseline rows in this addon yet.
- Druids receive no Parry, Block Chance (base or bonus), or Block Value credit.
  Caster weapon DPS and flat weapon damage remain unchanged.
- Healing-capable DPS profiles halve Healing from 0.4 to 0.2; healer/hybrid
  healer profiles retain 0.4. Classes without healing spells score it at zero.

Unmentioned weights, item-level bases, effect factors, rarity adjustment,
division/rounding and the set formula are retained. Future adjustments can be
made in `DynamicWeights.lua`; explicit class overrides are applied last.

Item tooltips show **Dynamic Item Score** below the normal rows. Set items also
show **Dynamic Set Bonus Score**, calculated from the dynamic item score using
the same set formula and minimum-one rule. Equipped **DGS:** totals include
these dynamic set points. Bag items show a separate colored dynamic difference.
Bags and links use your talent profile; inspected equipment and cached player
totals use the wearer's profile, retained even when their unit token disappears.
In Both mode, an equal dynamic item, set or total score is omitted. Dynamic-only
mode still shows its selected dynamic rows. Enchantment points are identical for
both profiles and have one row.

Open **Settings → AddOns → FossieGearScore**, or type `/fgs settings`.
Three dropdowns control **Show GS on Character Panel**, **Show GS on Hover**,
and **Show GS on Items**. Each offers **Both Normal and Dynamic**, **Normal**,
**Dynamic**, and **None**. All default to Both and persist account-wide through
`FossieGearScoreDB`. Changes refresh visible displays immediately. The character
setting controls both your own and the inspect panel. Disabling hover scores
also stops new background inspection requests. Missing inspection data keeps
the existing “Inspect to see GS” fallback for normal GS; DGS is hidden until
a valid talent profile is available.

## Talent-tree overrides

Native dropdowns sit **above the weapon/off-hand/ranged row** in both the character
and inspect equipment panes. The totals are centered immediately above the
dropdown. Native off-hand buttons anchor the layout; skins without those buttons
use their weapon-slot array or an equipment-pane fallback. Each lists **Default**
and the three talent-tree names for the displayed player's class. Names come
from the native trait group headers when available.

Default uses detected talents; choosing a tree previews that role's dynamic
scoring for the displayed player's current gear. Own choices refresh the character
total, self-hover, item/set scores and bag comparisons. Inspect choices refresh
that player's inspect total, cached hover and inspected item scores, preserving
their detected talents and other players' choices. Choosing from a menu opened
for a previous player cannot apply the selection after the inspect target changes.

Own selections persist per character GUID. Other players' previews are stored
per GUID for the current session. Below-ten and confirmed no-spent-talents rules
still apply. A preview does not change anyone's actual talents.

Type `/fgs talents` to report own and currently inspected talent points, effective
profile, API source and trait config/loading status if a dynamic score is missing.

## Permanent enchantment points

`EnchantmentData.lua` retains all **249 tiered entries** from
**WowForeverEnchTiers2**: 179 Enchanting recipes, 32 crafted attachments and 38
quest/reputation enhancements. Availability is separate metadata; unconfirmed
entries receive their assigned tier when observed. Seven reported buckle and
embroidery families without verified tiers remain pending and unscored.

Each recognized permanent effect adds exactly **tier × 5** points: 5, 10, 15,
20 or 25. These flat points receive no stat, role, quality, item-level, effect,
set or rounding adjustment. The **Enchantment Score** row appears last, below
any set rows. Equipment and hover totals retain separate components, for example
**GS: 365 + 20**. Bag Item Score differences continue to compare intrinsic gear
points; enchantment and set changes have their own rows.

Recognition uses applied item-link IDs, with explicit native permanent-enchant
IDs or application-spell IDs as fallback. The base-stat query clears only the
permanent link field and preserves gems, suffixes, instance and bonus fields.
Permanent tooltip lines cannot inflate intrinsic stats or the item-level effect
factor. Temporary oils, stones, poisons and other timed applications are excluded.

The catalogue contains 219 distinct applied IDs, including legacy aliases for
four basic armor kits. Current Medium/Heavy/Thick/Rugged application IDs are
8481/8484/8487/8490; their original 16/17/18/1843 aliases remain recognized.
Slots distinguish shared IDs
where possible. On two-handed weapons, IDs 805, 1897 and 2563 can each describe
different-tier applicable recipes; the client exposes their shared effect rather
than the crafting recipe. They use the lowest applicable reference tier and
retain ambiguity metadata. No similar-name guessing is used.

Unknown native enhancements show **Enchantment Score: Unknown** and totals add
**+ ?** (or **+ 20 + ?** alongside known enhancements). The primary link exposes
one permanent enchant field. Duplicate native rows count once; conflicting rows
stay unknown until secondary attachment stacking is verified in the client.
Sources, application spell IDs and availability are retained in the catalogue.

## Zero-talent inspection retry

An inspected 0/0/0 result hides DGS and becomes eligible for another background
inspection after **5 seconds**. Rehovering the player then retries even when
normal GS is still fresh. The timer does not inspect by itself. Manual inspection
refreshes talents immediately regardless of the cooldown. Another zero result
restarts the cooldown; successful talents restore normal cache freshness. Missing
talent data also uses the same retry eligibility. Inspection range, combat,
request throttling and manual-inspection priority still apply.

## Install

1. Remove the old `ForeverGS` folder from `Interface/AddOns` when upgrading
   from the previous name, so both copies cannot load together. Extract the ZIP into your active Forever client folder's `Interface/AddOns`.
2. Confirm the file is at `Interface/AddOns/FossieGearScore/FossieGearScore.toc`.
   Avoid an extra nested `FossieGearScore/FossieGearScore` folder.
3. Restart the client, enable FossieGearScore in the character selection AddOns list,
   and enter the game. Use `/reload` after changing its files.
4. Hover an equipment item. The pink **Item Score** label shows a whole-number score.

## Calculation

`Stat Score = sum of (each item's stat amount × that stat's weight)`

`Item Score = floor(((Stat Score + Item Level × 1.2 × Effect Multiplier) × Rarity Multiplier) / 4)`

For example, 7 Intellect and 3 Spirit give 17 stat points. On an item-level 15
green item with no equip/proc effect, the final score is `floor(((17 + 15×1.2)×1.1)/4) = 9`.
The calculation retains fractional amounts through the rarity multiplication,
then divides by 4 and rounds down once at the very end.
Negative stat penalties subtract points. **An item with no recognized scored
stats and no intrinsic Equip/Use/Chance on hit effect has an Item Score of 0**,
regardless of item level or rarity; its base is omitted.
Armor and weapon DPS count as scored stats, along with the other configured
categories. An intrinsic equip, use or proc effect also qualifies for the base,
even when the effect does not supply any recognized flat stats.
Plain shirts and tabards with no stats or intrinsic effects omit the **Item Score**
line entirely. They still contribute zero to equipped totals. Shirts and tabards
with stats or effects retain their score, even when it rounds down to zero.
The base is retained for items that have scored stats, even when bonuses and
penalties cancel their stat subtotal to zero.

Item level comes from the full instance link via the detailed item-level API,
falling back to `GetItemInfo`'s item level. Required character level is not used.

| Rarity | Multiplier |
| --- | ---: |
| Gray / Poor | 0.8 |
| Common | 1.0 |
| Uncommon | 1.1 |
| Rare | 1.15 |
| Epic | 1.2 |
| Legendary | 1.3 |

### Equip and chance-on-hit effects

If the item has an intrinsic **Equip:** or **Chance on hit:** effect, its
item-level base gets one additional multiplier:

| Rarity | Effect multiplier on the base |
| --- | ---: |
| Gray / Common | 1.0 |
| Uncommon | 1.05 |
| Rare | 1.05 |
| Epic | 1.05 |
| Legendary | 1.05 |

This factor applies once, even with multiple qualifying effects. It multiplies
the item-level base, then the existing rarity multiplier still applies to the
complete stat-plus-base score. The effect factor does not multiply individual
stats. Native equip/proc tooltip line types are also recognized. Set effects
and enchantment/socket lines do not trigger this extra factor.
An effect-only item receives the item-level base and these rarity factors.
For example, an item-level 15 green with only an equip/proc effect scores
`floor((15 × 1.2 × 1.05 × 1.1) / 4) = 5`.

### On-use effects

An intrinsic **Use:** effect qualifies the item for its item-level base, even
if the item has no scored flat stats. Its effect multiplier on that base is
**1.5**, independent of rarity. The ordinary rarity multiplier still applies
to the stat-plus-base subtotal. Native on-use tooltip line types are recognized.

For an item-level 15 green with only a Use effect, the score is
`floor((15 × 1.2 × 1.5 × 1.1) / 4) = 7`.
Use takes priority over the Equip/Chance on hit effect factor. Multiple effects
do not stack extra base multipliers. Temporary stats inside the Use description
are not counted as permanent item stats; set, enchantment and socket effects
do not qualify the item for this intrinsic on-use factor.

### Set Bonus Score

Set items show a second pink label, **Set Bonus Score**, directly below
**Item Score**. The first line keeps the item's intrinsic whole-number score.
The second line shows only the additional points from the active set:

`Set Bonus Score = max(1, floor(Item Score × 1.05^(N + 1)) − Item Score)` when active

`Equipment contribution = Item Score + Set Bonus Score`

Here `N` is the number of equipped items from that same set. At least one set
bonus tier must be unlocked: if the first bonus requires two pieces, one piece
gets no extra points, two pieces use `1.05³`, three use `1.05⁴`, and four
use `1.05⁵`. The exponent is the equipped-piece count plus one for activation,
regardless of the number of active bonus tiers. Separate
sets maintain separate counts. Inactive sets show a Set Bonus Score of 0.
An active set grants at least 1 extra point to each equipped member, including
an item whose intrinsic Item Score is 0. An Item Score of 1 with two active
pieces therefore has a Set Bonus Score of 1 and contributes 2 points.

For an Item Score of 105 in an active four-piece set,
`floor(105 × 1.05⁵) = 134`: the tooltip shows **Item Score: 105** and
**Set Bonus Score: 29**, and that item contributes **134** to your GS.
The set bonus is applied after the item score's final division and rounding;
it is not divided by 4 again. Actual set-effect stats are not added separately.

Membership prefers the game's item-set ID and falls back to its tooltip set
name. English `(N) Set:`, `Set (N):` and `Set: (N)` bonus lines supply
numbered activation thresholds. Active `Set: ...` lines, which omit a piece
number, also confirm activation when the header matches that wearer's equipped
count. This works when all tiers are active and no numbered lines remain.
Gray tooltip text cannot veto a threshold reached by the equipped count.
Inspected totals use that player's equipped pieces and tooltip context.
If the tooltip's wearer count differs and no reached numbered threshold is
known, the addon does not transfer active state from your set to theirs.
Special profession/skill activation restrictions are not evaluated separately.

Equipment tooltips use the native inventory-owner argument; bags, merchant
items and links use your current worn-set context, without pretending the hovered
item has been equipped. These are current bonuses, not an upgrade simulation.
Known set membership still counts while an item's stat data loads; its unknown
individual score is omitted and the equipment total is marked partial.
Statless set members count toward activation; an active set gives them the
same minimum 1 Set Bonus Score while leaving their Item Score at 0.

## Bag Item Score difference

Hovering equipment through the native bag tooltip shows its Item Score and an
inline difference, for example **Item Score: 105 (+20)**. The difference is
green for an increase, red for a decrease, and white for zero. The label
remains pink and the original score remains gold.

The comparison uses the intrinsic **Item Score** of your eligible equipped
replacement, without adding Set Bonus Score or simulating changes to other
set pieces. Rings and trinkets compare both slots and display the larger gain;
an empty eligible slot has a baseline of 0. The native weapon comparison handles
both-hand replacements and any bag partner it proposes. If the native comparison
is unavailable, the slot fallback subtracts both main-hand and off-hand scores
when replacing them with a two-hander, and respects main/off-hand restrictions.

Character, inspect, merchant, chat-link and shopping comparison tooltips keep
their normal score lines. Bag equipment differences refresh when your equipped
items change. An unavailable or partial comparison is shown as white **(?)**,
so an unloaded item cannot silently become a zero-score replacement.
This compares score values and does not evaluate unique-equipped restrictions
or promise that the item is better for your class or role.

## Equipped totals and player hover

The total is the sum of each equipped item's **Item Score + Set Bonus Score**.
It includes equipment slots 1–19 (shirt/tabard and all three weapon slots),
and excludes bags and carried inventory. Empty slots contribute zero.
Gear changes and newly loaded item data refresh your own total automatically.

The character equipment panel shows **GS: TOTAL + ENCHANTMENTS** centered above
the talent override dropdown and weapon slots. The enchant addition is omitted
when it is zero.
The label sits on a dedicated frame above the model background and refreshes
when either the character window or its equipment tab opens.
The inspect equipment panel shows **GS: ...** until matching inspection data
arrives, then shows that player's total. If an equipped item's data is missing
or incomplete, the loaded sum is explicitly marked **(partial)**.

Player hover tooltips using the game's unit tooltip pipeline show **GS:** and
actual **Talents: A/B/C**, even while previewing another role. Confirmed unspent
talents and players below level 10 show 0/0/0; unknown inspection talent data
shows **Inspect to see talents**. Player GUID checks prevent another player's
points from being reused when a skin changes targets before clearing its rows.
Your own score is available directly. Hovering another player requests a
background inspection after a 0.3-second delay, without opening their inspect
window. Requests are at least 3 seconds apart, with only one pending at a time.
Background inspection pauses during combat and while manual inspection is
open or pending. Manual requests and requests from other addons take priority.
Ending combat or closing manual inspection retries the current hover.

When there is no known score, the tooltip shows **Inspect to see GS** while
waiting, and retains that text if the player cannot be inspected, is out of
range, or the request fails. A request times out after 5 seconds; failed players
have a 15-second retry backoff. Successful results replace the fallback in place.
An inspection response does not guarantee that all item data has loaded. The
addon retains every full equipped item link, requests missing item data, and
rescans every 0.5 seconds for up to 10 seconds after the response. Item and
tooltip loading events also refresh the snapshot. Saved item links can finish
loading even after the mouse moves away or another inspection starts.
An incomplete remote total shows **Inspect to see GS** instead of its subtotal.
Partial inspection records never count as a fresh 60-second cache entry.
Another player's known score is marked **(cached)**. Cached scores remain
visible while a refresh request is pending. Once the new response arrives,
the tooltip waits for its complete equipment data. An incomplete refresh keeps
the previous complete cache intact. A failed background inspection shows the
fallback even when an older score was cached; a successful background or manual
inspection restores the score. Background inspection can refresh cached totals
on a later hover once their inspection data is 60 seconds old. Item data that
loads later updates partial scores without requiring the inspect window.
NPCs get no score line.
Caches use player GUIDs, so switching targets cannot reuse somebody else's
score. The cache lasts only for the current UI session and resets on `/reload`.
Set counts and their contributions refresh when equipment changes, including
every remaining piece after one is removed. Visible set-item tooltips are asked
to rebuild through the native tooltip pipeline after those changes.
The addon also checks when the unit tooltip opens, so known totals can appear
on skins that do not run the native tooltip callback. It resolves the unit from
the tooltip's GUID and verifies matching player identity before reading the cache.

Missing item level or missing/unsupported rarity marks the score **(partial)**.
In that case, the missing base is omitted or the rarity multiplier defaults to 1.

The 53 weights are based on Brandon's **FOREVER GS ADDON** spreadsheet,
read on October 10, 2026:
https://docs.google.com/spreadsheets/d/1OBldVGx4rckYkCYUC8cdSS6xbGGYB1Okb1SqqHhaThs/edit

Weapon DPS and Ranged Weapon DPS were subsequently reduced from 14 to 1.4
at Brandon's request. General Spell Damage is now 1 and Healing is 0.4.
Regular and bonus armor both contribute 0.02 points per armor point.
All six school-specific damage categories are now 1 each as well.
Other stat weights retain their spreadsheet values.

`weights.csv` records the addon weights. `Weights.lua` is the actual configuration:
edit its `NS.WEIGHTS` values and `/reload` to change stat weights. The base weight
and rarity factors are `NS.ITEM_LEVEL_WEIGHT` and `NS.RARITY_MULTIPLIERS`; the
final divisor is `NS.SCORE_DIVISOR` in the same file. This version does
not connect to Google Sheets while the game is running.
The extra equip/proc effect factors are `NS.EFFECT_MULTIPLIERS`, and the on-use
factor is `NS.USE_EFFECT_MULTIPLIER`. The set factor is `NS.SET_PIECE_MULTIPLIER`,
raised to the equipped-piece count plus one when active.

### Units and interpretation

- Attributes, health, mana, spell bonuses, attack power, armor, resistances,
  block value and flat weapon damage use their printed flat amounts.
- `+2 to All Resistances` supplies 2 Arcane, Fire, Nature, Frost and Shadow
  resistance. At 0.5 per resistance point, this adds 5 stat points before
  the item-level base, rarity multiplier and final division by 4. Matching
  API resistance amounts are replaced, so they cannot be counted twice.
- Weapon DPS and ranged weapon DPS use damage per second. When available, the
  API's full precision takes priority over the rounded tooltip amount.
- Hit, crit, dodge, parry, block chance, haste and expertise use **percentage
  points**: a 1% bonus contributes one unit, not 0.01 units.
- Defense and weapon/feral skill use skill points.
- Mana per 5 and Health per 5 use the amount restored per five seconds.
- A combined spell damage-and-healing bonus scores its shared amount once,
  using the higher of those two weights. For example, +7 damage and healing
  contributes `7×1 = 7` stat points. A separate +10 healing adds `10×0.4 = 4`,
  giving 11 stat points before base and rarity. Damage-only and healing-only bonuses retain their full
  weights, as do separate damage and healing effects. A school-specific
  damage bonus uses its own row. For one combined effect with unequal amounts,
  the overlap scores once and the remaining amount scores normally.
- Separate AP categories and skill categories contribute independently. No
  extra derived stats are calculated from attributes: Intellect does not also
  generate mana points, for example.
- API aliases are counted once. Parsed tooltip amounts replace matching API
  categories rather than being added to them. Total armor is split into base
  and bonus armor when both are available.

## Initial scope and limitations

This is a general additive item score, independent of character class or role.
Intrinsic equip/use/proc effects receive the item-level proxy described above,
and active sets receive the per-piece multiplier. The addon does not evaluate
individual proc damage, proc rates or actual set-effect stat amounts. It does
not add temporary on-use stat amounts, creature-specific bonuses, temporary effects or
other conditional effects as flat stats. The spreadsheet's
explicit Feral Attack Power category is supported. Permanent enchantment and
socket effect tooltip lines are excluded; this is not an enhancement scoring
system. There is no settings UI yet.

English tooltips (`enUS`/`enGB`) are the supported first-release parsing format.
Other locales receive an API-only score marked **(partial)**. A known rating
without a reliable conversion is skipped and also marks the score partial.
Conversions prefer Forever's native rating API; verified Forever fallback
divisors are hit 10, crit 14, dodge 12, parry 15 and block 5 rating per 1%.
Unqualified expertise fields are skipped when their units cannot be verified.

Custom item wording that the parser does not recognize can still be missed
without a partial marker. Please verify representative items in the actual
client before treating this first build's scores as complete.

## Diagnostics

- `/fgs` shows the version and command help.
- `/fgs debug` shows the last scored item and each stat's contribution.
  Shared damage/healing appears under the winning stat, with an explanatory
  line; the other category shows only its additional, independently scored amount.
  It also shows the item-level base, rarity multiplication, final division and rounding down.
  The base includes the effect factor; set items also show worn-piece count,
  activation, the separate set score and the combined equipment contribution.
  Bag items also show their intrinsic score difference when known.
- `/fgs raw` shows its raw API stat fields and tooltip text.
- `/fgs ui` shows the version, divisor, tooltip hook status, panel visibility,
  frame levels, current panel text, and the hovered player's known score.

If an item looks wrong, hover it and run `/fgs debug` and `/fgs raw`. Send the
item link and screenshots of the tooltip and those outputs. For Lua errors,
enable the game's error window with `/console scriptErrors 1`, then `/reload`.
If a total is missing, open the character panel or hover an inspected player,
then run `/fgs ui` and send its output. Player-tooltip errors are reported once
in chat and included in that command's output.

## Validation

The implementation was checked against Forever's build 70338 UI/API source.
Automated Lua 5.1 fixtures cover scoring arithmetic, stat extraction,
deduplication, rating conversion, ignored effects, secret-value handling,
tooltip rebuilds, cache refreshes, instance links, error recovery, equipped
totals, inspection result matching and player-tooltip cache behavior. The unit
helper fixture uses Forever's actual `(name, unit, GUID)` return order. Panel
fixtures include native model/background frame levels, root-window opening,
equipment tab visibility and skin level changes.
New fixtures cover effect factors across all rarities, multiple-effect handling,
the corrected 105-point four-piece example, inactive and mixed sets, per-player
inspection contexts, tooltip line separation, set removal, known membership
with unloaded stats, statless set members and native set-ID fallback.
Build 0.1.8 regressions also cover effect-only bases, native active set text,
fully active sets with no numbered tiers, alternate set formats, gray tooltip
colors, minimum set points, the all-resistance wording and owner-specific
character/inspect/hover totals after equipment changes.
Build 0.1.9 fixtures cover on-use bases across rarities, mixed effect handling,
set factors, inline bag colors, empty and paired slots, native weapon
comparison structures, instance GUIDs, unavailable comparisons and equipment refreshes.
Build 0.1.10 updates the active set fixtures to the piece-count-plus-one exponent,
including separate tooltip points, character/inspect/hover totals and minimum points.
Build 0.1.11 fixtures cover hover delay, cooldown, inspection timeout and retry,
range and combat guards, manual preemption, changed unit tokens, GUID matching,
inspection cache expiry, deferred item data, cleared engine data, and cosmetic
shirt/tabard tooltip suppression while retaining scored items.
Build 0.1.12 fixtures reproduce a 215-point player whose initially loaded items
sum to only 69. They verify explicit item-data requests, full-link retention,
completion through item and tooltip events, timer retries, missing-slot recovery,
completion after inspection ownership changes, complete-cache preservation,
equipment replacement during loading, and the inspected player's set context
when the local player wears a different number of pieces.
Build 0.1.14 fixtures load the TOC in order and cover independent class profiles,
native settings registration, persisted preferences, live display modes, dynamic
sets, comparisons, inspection snapshots, and incomplete-score suppression.
Build 0.1.19 fixtures repeatedly rebuild inspected boots/belts with local set
comparisons and count inventory/talent reads. They cover native data-instance
event matching, batched updates, unchanged-data feedback prevention, late-data
changes, equipment invalidation and bounded retries for unavailable talents.
Build 0.1.20 fixtures cover tier/slot/ID mapping, unknown and secret data,
permanent-only detection, flat item/inspection/hover additions, actual talent
points during previews, equal-score collapse, weapon-row positioning, unchanged
menu reuse, rating conversion invalidation and bounded parsed-item caching.
Four hundred repeated item/comparison rebuilds perform no stat parses, scoring
calculations, inventory scans or talent scans after the cache is populated.
Build 0.1.21 covers current native Medium/Heavy/Thick/Rugged kit IDs across all
four eligible armor slots, legacy aliases, the reported stamina/armor leggings
tooltip, separate flat equipment additions and enchantment ID diagnostics.
The full suite contains 2,181 checks.
These are mocked tests; this package has not yet been tested in a running
WoW Forever client.

The reproducible tests are included in `tests/`. From this addon directory,
run `lua tests/test_scoring.lua`, `lua tests/test_bonuses.lua`,
`lua tests/test_comparison.lua`, `lua tests/test_tooltip.lua`,
`lua tests/test_gear_totals.lua`, `lua tests/test_regressions_018.lua`,
`lua tests/test_dynamic_profiles.lua`, `lua tests/test_forever_traits.lua` and
`lua tests/test_enchantments.lua` with Lua 5.1.
Alternatively, run `python3 tests/run_tests.py` after installing Python's `lupa`.

## Versioning

Increment the final version number with every addon update: 0.1.14, 0.1.15, etc.
Keep `Weights.lua`, `FossieGearScore.toc` and this document in sync.
Create a release or ZIP only when requested, named `FossieGS-BUILDNUMBER.zip`.

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
