-- Run with a Lua 5.1 interpreter from the FossieGearScore directory:
-- lua tests/test_scoring.lua
local NS = {}
assert(loadfile("Weights.lua"))("FossieGearScore", NS)
assert(loadfile("Scoring.lua"))("FossieGearScore", NS)
local count = 0
local function close(actual, expected, text)
    assert(math.abs(actual - expected) < 0.00001,
        (text or "score") .. ": expected " .. expected .. ", got " .. actual)
end
local function test(name, api, lines, expected, context, expectedStats)
    local stats, warnings = NS.ExtractStats(api, lines, context or {})
    local score = NS.CalculateScore(stats)
    close(score, expected, name)
    for stat, value in pairs(expectedStats or {}) do close(stats[stat] or 0, value, name .. " / " .. stat) end
    count = count + 1
    return stats, warnings
end

-- Brandon's example: 7 Intellect and 3 Spirit = 7*2 + 3*1.
test("basic attributes", {ITEM_MOD_INTELLECT_SHORT=7, ITEM_MOD_SPIRIT_SHORT=3}, {"+7 Intellect", "+3 Spirit"}, 17)
test("different primary stats are additive", {}, {"+8 Strength", "+6 Agility", "+11 Stamina", "+9 Intellect", "+4 Spirit"}, 72)
test("flat health and mana, no derived health from stamina", {ITEM_MOD_STAMINA_SHORT=5, ITEM_MOD_HEALTH_SHORT=20, ITEM_MOD_MANA_SHORT=100}, {"+5 Stamina", "+20 Health", "+100 Mana"}, 17)
test("signed penalties retained", {ITEM_MOD_AGILITY_SHORT=-10, ITEM_MOD_STRENGTH_SHORT=10}, {"-10 Agility", "+10 Strength"}, 0)
test("separate spell damage", {ITEM_MOD_SPELL_DAMAGE_DONE=7}, {"Equip: Increases damage done by magical spells and effects by up to 7."}, 7)
local combinedStats = test("combined damage and healing", {ITEM_MOD_SPELL_POWER=7}, {"Equip: Increases damage and healing done by magical spells and effects by up to 7."}, 7, {}, {["Spell Damage"]=7, Healing=7, _sharedSpellPower=7})
test("spell power aliases do not stack", {ITEM_MOD_SPELL_POWER=7, ITEM_MOD_SPELL_DAMAGE_DONE=7, ITEM_MOD_SPELL_HEALING_DONE=7, ITEM_MOD_SPELL_HEALING_DONE_SHORT=7}, {}, 7)
test("unequal amounts on a healing effect", {}, {"Equip: Increases healing done by up to 31 and damage done by up to 10 for all magical spells and effects."}, 20.15,
    {}, {["Healing (with damage)"]=31,["Spell Damage"]=0,Healing=0,_sharedSpellPower=0})
test("healing-only bonus retains its weight", {ITEM_MOD_SPELL_HEALING_DONE=7}, {"Equip: Increases healing done by spells and effects by up to 7."}, 2.8)
test("combined bonus plus separate healing", {ITEM_MOD_SPELL_POWER=7,ITEM_MOD_SPELL_DAMAGE_DONE=7,ITEM_MOD_SPELL_HEALING_DONE=17}, {"Equip: Increases damage and healing done by magical spells and effects by up to 7.", "Equip: Increases healing done by spells and effects by up to 10."}, 11)
test("combined bonus plus both separate categories", {}, {"+7 Spell Power", "+2 Spell Damage", "+10 Healing"}, 13)
test("API shared bonus with additional healing", {ITEM_MOD_SPELL_POWER=7,ITEM_MOD_SPELL_DAMAGE_DONE=7,ITEM_MOD_SPELL_HEALING_DONE=17}, {}, 11)
test("short spell power alias", {ITEM_MOD_SPELL_POWER_SHORT=7}, {}, 7)
test("separate API totals do not imply a shared effect", {ITEM_MOD_SPELL_DAMAGE_DONE=7,ITEM_MOD_SPELL_HEALING_DONE=7}, {}, 9.8)
test("separate tooltip damage and healing are additive", {}, {"+7 Spell Damage", "+7 Healing"}, 9.8)
test("school bonus remains separate from shared spell power", {}, {"+7 Spell Damage and Healing", "+7 Fire Damage"}, 14)
test("multiple combined effects sum once each", {}, {"+7 Spell Power", "+3 Spell Power"}, 10)
test("tooltip provenance replaces API provenance", {ITEM_MOD_SPELL_POWER=7}, {"+8 Spell Power"}, 8)
test("separate tooltip bonuses override generic API provenance", {ITEM_MOD_SPELL_POWER=7}, {"+7 Spell Damage", "+7 Healing"}, 9.8)
test("paired healing with damage first", {}, {"Equip: Increases damage done by up to 10 and healing done by up to 31 for all magical spells and effects."}, 20.15)
test("equal separate amounts still use healing scoring", {}, {"Equip: Increases healing done by up to 10 and damage done by up to 10."}, 6.5)
test("API totals cannot restore ignored paired damage", {ITEM_MOD_SPELL_POWER=8,ITEM_MOD_SPELL_DAMAGE_DONE=8,ITEM_MOD_SPELL_HEALING_DONE=22},
    {"Equip: Increases healing done by up to 22 and damage done by up to 8 for all magical spells and effects."}, 14.3)
for _,reverse in ipairs({false,true}) do
    local lines={"Equip: Increases healing done by up to 22 and damage done by up to 8 for all magical spells and effects.",
        "Equip: Increases damage and healing done by magical spells and effects by up to 7.",
        "Equip: Increases healing done by spells and effects by up to 10.",
        "Equip: Increases damage done by magical spells and effects by up to 2."}
    if reverse then lines[1],lines[4]=lines[4],lines[1]; lines[2],lines[3]=lines[3],lines[2] end
    test("mixed spell effects in either order", {ITEM_MOD_SPELL_POWER=15,ITEM_MOD_SPELL_DAMAGE_DONE=17,ITEM_MOD_SPELL_HEALING_DONE=39},
        lines, 27.3, {}, {["Healing (with damage)"]=22,["Spell Damage"]=9,Healing=17,_sharedSpellPower=7})
end
test("multiple paired healing effects sum once", {}, {
    "Equip: Increases healing done by up to 22 and damage done by up to 8.",
    "Equip: Increases damage done by up to 3 and healing done by up to 10."}, 20.8)
test("paired healing retains negative penalties", {}, {
    "Equip: Increases healing done by up to -20 and damage done by up to -7."}, -13)
test("paired enchant and conditional lines do not score", {}, {
    {type=15,leftText="Equip: Increases healing done by up to 22 and damage done by up to 8."},
    "Use: Increases healing done by up to 22 and damage done by up to 8.",
    "Equip: Increases healing done by up to 22 and damage done by up to 8 while outdoors."},
    0, {excludedTypes={[15]=true}})
test("paired bonus cannot consume unrelated suffix text", {}, {
    "Equip: Increases healing done by up to 22 and damage done by up to 8 percent."}, 0)
test("non-English API spell power scores once", {ITEM_MOD_SPELL_POWER=7}, {}, 7, {english=false})
test("shared negative bonus is deducted once", {ITEM_MOD_SPELL_POWER=-7}, {}, -7)
test("conditional combined effects remain excluded", {}, {"Use: +100 Spell Power", "Equip: +100 Spell Power against Beasts", "+7 Spell Power"}, 7)
NS.WEIGHTS.Healing = 9
test("higher healing weight wins for shared amount", {}, {"+7 Spell Power", "+2 Spell Damage", "+10 Healing"}, 155)
NS.WEIGHTS.Healing = 1
test("equal weights count shared amount once", {}, {"+7 Spell Power", "+10 Healing"}, 17)
NS.WEIGHTS.Healing = 0.4
local repeatedScore, combinedBreakdown = NS.CalculateScore(combinedStats)
close(repeatedScore, 7, "scoring is repeatable")
assert(combinedStats.Healing == 7 and combinedStats["Spell Damage"] == 7, "scoring preserves extracted totals")
assert(#combinedBreakdown == 1 and combinedBreakdown.sharedSpellStat == "Spell Damage", "debug breakdown has no duplicated healing contribution")
close(combinedBreakdown[1].points, 7, "breakdown matches score")
test("school damage", {}, {"Equip: Increases damage done by Fire spells and effects by up to 7."}, 7)
test("all six spell schools", {}, {"+2 Arcane Damage", "+3 Fire Damage", "+4 Nature Damage", "+5 Frost Damage", "+6 Shadow Damage", "+7 Holy Damage"}, 27)
test("regeneration", {ITEM_MOD_MANA_REGENERATION=4, ITEM_MOD_HEALTH_REGEN_SHORT=5}, {"Equip: Restores 4 mana per 5 sec.", "Equip: Restores 5 health per 5 sec."}, 5)
test("all resistance schools", {RESISTANCE2_NAME=2, RESISTANCE3_NAME=3, RESISTANCE4_NAME=4, RESISTANCE5_NAME=5, RESISTANCE6_NAME=6}, {}, 10)
test("all resistance shortcut", {}, {"+5 All Resistances"}, 12.5)
test("all resistance native wording", {}, {"+2 to All Resistances"}, 5, {}, {
    ["Arcane Resistance"]=2, ["Fire Resistance"]=2, ["Nature Resistance"]=2,
    ["Frost Resistance"]=2, ["Shadow Resistance"]=2})
test("all resistance native wording with format codes", {}, {"|cff00ff00+2 to All Resistances.|r"}, 5)
test("signed all resistance penalty", {}, {"-2 to All Resistances"}, -5)
test("all stats shortcut", {}, {"+2 All Stats"}, 18)
test("all stats wording with to", {}, {"+2 to All Stats"}, 18)
test("AP aliases counted once", {ITEM_MOD_ATTACK_POWER_SHORT=12, ITEM_MOD_ATTACK_POWER=12}, {"Equip: +12 Attack Power."}, 9.6)
test("separate AP types", {}, {"+10 Attack Power", "+20 Ranged Attack Power", "Equip: +30 Attack Power in Cat, Bear, and Dire Bear forms only."}, 48)
test("Concealed Hand Crossbow", {ITEM_MOD_RANGED_ATTACK_POWER_SHORT=12, ITEM_MOD_DAMAGE_PER_SECOND_SHORT=15.25}, {"(15.25 damage per second)", "+12 Ranged Attack Power"}, 30.95, {ranged=true})
test("weapon DPS preserves unrounded API value", {ITEM_MOD_DAMAGE_PER_SECOND_SHORT=15.217391014099}, {"(15.22 damage per second)"}, 21.3043474197386)
test("weapon tooltip fallback", {}, {"(10.5 damage per second)"}, 14.7)
test("ammunition DPS", {}, {"Adds 7.5 damage per second."}, 10.5, {ranged=true})
test("Might of Cenarius", {ITEM_MOD_STAMINA_SHORT=8, ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT=4}, {"+8 Stamina", "Equip: Improves your chance to hit by 1.0%.", "Equip: +4 Weapon Damage."}, 49)
test("Clobrok's Block Rock", {ITEM_MOD_STRENGTH_SHORT=7, BLOCK_VALUE=10}, {"+7 Strength", "+10 Block Value"}, 19)
test("shield block value and chances are separate", {RESISTANCE0_NAME=100}, {"100 Armor", "20 Block", "Block Chance 5%", "Equip: Increases your chance to block attacks with a shield by 1.0%."}, 30)
test("armor total not doubled with bonus armor", {RESISTANCE0_NAME=150, ITEM_MOD_EXTRA_ARMOR_SHORT=50}, {"150 Armor", "Equip: Increases armor by 50."}, 3, {}, {Armor=100, ["Armor (Bonus)"]=50})
test("tooltip-only bonus armor", {}, {"Equip: Increases armor by 50."}, 1)
test("defense is skill points", {}, {"Equip: Increased Defense +7."}, 14)
test("dodge and parry percentages", {}, {"Equip: Increases your chance to dodge an attack by 1.0%.", "Equip: Increases your chance to Parry an attack by 2.0%."}, 36)
test("crit and hit bonuses", {}, {"Equip: Improves your chance to hit by 2.0%.", "Equip: Improves your chance to get a critical strike by 1.0%."}, 38)
test("attack speed maps to Haste", {}, {"Equip: Increases ranged attack speed by 10%."}, 150)
test("expertise percentage", {}, {"+1% Expertise"}, 8)
local _, expertiseWarning = test("unknown expertise units skipped", {EXPERTISE=4}, {}, 0)
assert(expertiseWarning.Expertise)
test("tooltip expertise rescues unknown units", {EXPERTISE=4}, {"+1% Expertise"}, 8)
test("plural regeneration wording", {}, {"Equip: Restores 5 mana every 5 seconds."}, 5)
test("multiple additive rating lines", {}, {"Equip: Increases your dodge rating by 12.", "Equip: Increases your dodge rating by 6."}, 18)
test("raw chance ratings use Forever fallback conversions", {ITEM_MOD_HIT_RATING_SHORT=10, ITEM_MOD_CRIT_RATING_SHORT=14, ITEM_MOD_DODGE_RATING_SHORT=12, ITEM_MOD_PARRY_RATING_SHORT=15, ITEM_MOD_BLOCK_RATING_SHORT=5}, {}, 52)
test("rating aliases do not multiply score", {ITEM_MOD_CRIT_RATING_SHORT=14, ITEM_MOD_CRIT_MELEE_RATING_SHORT=14, ITEM_MOD_CRIT_RANGED_RATING_SHORT=14, ITEM_MOD_CRIT_SPELL_RATING_SHORT=14}, {}, 12)
test("native rating conversion", {ITEM_MOD_HASTE_RATING_SHORT=10, ITEM_MOD_EXPERTISE_RATING_SHORT=10, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT=3}, {}, 27, {convertRating=function(index,value) if index==2 then return value/1.5 end; return value/10 end})
test("tooltip percentage supersedes API rating", {ITEM_MOD_CRIT_RATING_SHORT=14}, {"Equip: Improves your critical strike rating by 14 (1.00%)."}, 12)
test("tooltip-only rating conversion", {}, {"Equip: Increases your dodge rating by 12."}, 12)
local _, warnings = test("missing conversion is explicit", {ITEM_MOD_HASTE_RATING_SHORT=10}, {}, 0)
assert(warnings.Haste, "missing conversion must mark a partial score")
test("known tooltip rescues missing converter", {ITEM_MOD_HASTE_RATING_SHORT=10}, {"+1% Haste"}, 15)
test("all weapon and feral skills", {}, {
    "Equip: Increased Two-Handed Swords +1.", "Equip: Increased Two-Handed Axes +1.", "Equip: Increased Two-Handed Maces +1.",
    "Equip: Increased Swords +1.", "Equip: Increased Maces +1.", "Equip: Increased Axes +1.", "Equip: Increased Guns +1.",
    "Equip: Increased Daggers +1.", "Equip: Increased Crossbows +1.", "Equip: Increased Polearms +1.",
    "Equip: Increased Fist Weapons +1.", "Equip: Increases Feral Combat +1.",
}, 168)
test("flat Spell Piercing alias", {}, {"+2 Spell Piercing"}, 2)
test("penetration equip effect", {}, {"Equip: Decreases the magical resistances of your spell targets by 10."}, 10)
test("excluded conditional AP and school damage", {ITEM_MOD_ATTACK_POWER_VS_HUMANOID_SHORT=15, ITEM_MOD_SPELL_DAMAGE_VS_BEAST_SHORT=4}, {"Equip: +15 Attack Power against Humanoids.", "Equip: Increases damage done to Beasts by magical spells and effects by up to 4."}, 0)
test("exclude proc, use, set and temporary effects", {}, {"Use: +100 Strength", "Chance on hit: +100 Attack Power", "(2) Set: +10 Strength", "Equip: Increases your attack power by 100 for 10 sec.", "Equip: Increases your chance to get a critical strike by 5% while in Cat Form."}, 0)
test("exclude enchant and proc typed lines", {}, {{type=15,leftText="+7 Strength"}, {type=46,leftText="+100 Attack Power"}, {leftText="+3 Spirit"}}, 3, {excludedTypes={[15]=true,[46]=true}})
test("critical-hit avoidance is not hit chance", {}, {"Equip: Reduces your chance to be critically hit by 1%."}, 0)
test("percentage AP is not a flat stat", {}, {"Equip: Increases your attack power by 10%."}, 0)
test("format codes removed", {}, {"|cff00ff00+7 Intellect|r", "|cff00ff00Equip: Increases your chance to Parry an attack by 1.0%.|r"}, 26)
test("unrelated tooltip numbers do not score", {}, {"Sword of 1000 Strength", "Requires Level 60", "Durability 50 / 50", "Sell Price: 20 Gold", "Item Level 80"}, 0)
test("non-English mode retains API stats", {ITEM_MOD_STRENGTH_SHORT=7}, {"+100 Strength"}, 14, {english=false})
test("no stats gives zero", {}, {}, 0)
local bad = setmetatable({}, {})
issecretvalue = function(v) return v == bad end
test("secret stat skipped safely", {ITEM_MOD_STRENGTH_SHORT=bad, ITEM_MOD_SPIRIT_SHORT=3}, {{leftText=bad}, "+3 Spirit"}, 3)
issecretvalue = nil

print("PASS: " .. count .. " scoring/extraction scenarios (Lua " .. _VERSION .. ")")
