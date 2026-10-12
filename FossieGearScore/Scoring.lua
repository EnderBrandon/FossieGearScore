local _, NS = ...

-- Pure extraction/scoring functions. No item database or external addon required.
local abs, max, min = math.abs, math.max, math.min
local function safe(value)
    return not (issecretvalue and issecretvalue(value))
end
NS.IsSafe = safe

local function number(value)
    if not safe(value) then return nil end
    if type(value) == "string" then value = tonumber((value:gsub(",", ""))) end
    if type(value) ~= "number" or value ~= value or abs(value) == math.huge then return nil end
    return value
end
NS.GetNumber = number

local function clean(value)
    if not safe(value) or type(value) ~= "string" then return "" end
    return (value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("\194\160", " ")
        :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
NS.CleanText = clean

local RAW = {
    ["Strength"] = {"ITEM_MOD_STRENGTH_SHORT"},
    ["Agility"] = {"ITEM_MOD_AGILITY_SHORT"},
    ["Stamina"] = {"ITEM_MOD_STAMINA_SHORT"},
    ["Intellect"] = {"ITEM_MOD_INTELLECT_SHORT"},
    ["Spirit"] = {"ITEM_MOD_SPIRIT_SHORT"},
    ["Mana"] = {"ITEM_MOD_MANA_SHORT"},
    ["Health"] = {"ITEM_MOD_HEALTH_SHORT", "HEALTH"},
    ["Health per 5"] = {"ITEM_MOD_HEALTH_REGEN_SHORT"},
    ["Mana per 5"] = {"ITEM_MOD_MANA_REGENERATION", "ITEM_MOD_POWER_REGEN0_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT"},
    ["Spell Damage"] = {"ITEM_MOD_SPELL_DAMAGE_DONE", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_SPELL_POWER", "ITEM_MOD_SPELL_POWER_SHORT"},
    ["Healing"] = {"ITEM_MOD_SPELL_HEALING_DONE", "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_SPELL_POWER", "ITEM_MOD_SPELL_POWER_SHORT"},
    ["Spell Penetration"] = {"ITEM_MOD_SPELL_PENETRATION", "ITEM_MOD_SPELL_PENETRATION_SHORT", "ITEM_MOD_SPELL_PIERCING_SHORT"},
    ["Attack Power"] = {"ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_ATTACK_POWER", "ITEM_MOD_MELEE_ATTACK_POWER_SHORT"},
    ["Ranged Attack Power"] = {"ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER"},
    ["Feral Attack Power"] = {"ITEM_MOD_FERAL_ATTACK_POWER_SHORT", "FERAL_ATTACK_POWER"},
    ["Flat Weapon Damage"] = {"ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT", "WEAPON_DAMAGE"},
    ["Armor"] = {"RESISTANCE0_NAME", "ITEM_MOD_ARMOR_SHORT"},
    ["Armor (Bonus)"] = {"ITEM_MOD_EXTRA_ARMOR_SHORT", "ITEM_MOD_BONUS_ARMOR_SHORT"},
    ["Defense"] = {"DEFENSE", "ITEM_MOD_DEFENSE_SKILL_SHORT"},
    ["Block Value"] = {"ITEM_MOD_BLOCK_VALUE_SHORT", "BLOCK_VALUE"},
    ["Arcane Resistance"] = {"RESISTANCE6_NAME", "ITEM_MOD_ARCANE_RESISTANCE_SHORT"},
    ["Fire Resistance"] = {"RESISTANCE2_NAME", "ITEM_MOD_FIRE_RESISTANCE_SHORT"},
    ["Nature Resistance"] = {"RESISTANCE3_NAME", "ITEM_MOD_NATURE_RESISTANCE_SHORT"},
    ["Frost Resistance"] = {"RESISTANCE4_NAME", "ITEM_MOD_FROST_RESISTANCE_SHORT"},
    ["Shadow Resistance"] = {"RESISTANCE5_NAME", "ITEM_MOD_SHADOW_RESISTANCE_SHORT"},
    ["Two-Handed Sword Skill"] = {"WEAPON_SKILL_2H_SWORD"},
    ["Two-Handed Axe Skill"] = {"WEAPON_SKILL_2H_AXE"},
    ["Two-Handed Mace Skill"] = {"WEAPON_SKILL_2H_MACE"},
    ["Sword Skill"] = {"WEAPON_SKILL_SWORD"},
    ["Mace Skill"] = {"WEAPON_SKILL_MACE"},
    ["Axe Skill"] = {"WEAPON_SKILL_AXE"},
    ["Gun Skill"] = {"WEAPON_SKILL_GUN"},
    ["Dagger Skill"] = {"WEAPON_SKILL_DAGGER"},
    ["Crossbow Skill"] = {"WEAPON_SKILL_CROSSBOW"},
    ["Polearm Skill"] = {"WEAPON_SKILL_POLEARM"},
    ["Fist Weapon Skill"] = {"WEAPON_SKILL_FIST", "WEAPON_SKILL_UNARMED"},
    ["Feral Combat Skill"] = {"FERAL_COMBAT_SKILL", "WEAPON_SKILL_FERAL"},
}
for _, school in ipairs({"Arcane", "Fire", "Nature", "Frost", "Shadow", "Holy"}) do
    RAW[school .. " Damage"] = {"ITEM_MOD_" .. school:upper() .. "_DAMAGE_SHORT", "ITEM_MOD_" .. school:upper() .. "_DAMAGE_DONE_SHORT"}
end

local PERCENT = {
    ["Hit Chance"] = {direct={"HIT_PCT", "SPELL_HIT_PCT"}, rating={"ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT", "ITEM_MOD_HIT_RANGED_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT"}, index=6, divisor="HIT"},
    ["Crit Chance"] = {direct={"CRIT_PCT", "SPELL_CRIT_PCT"}, rating={"ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT", "ITEM_MOD_CRIT_RANGED_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT"}, index=9, divisor="CRIT"},
    ["Haste"] = {direct={"MELEE_HASTE_PCT", "RANGED_HASTE_PCT", "SPELL_HASTE_PCT", "HASTE_PCT"}, rating={"ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_HASTE_MELEE_RATING_SHORT", "ITEM_MOD_HASTE_RANGED_RATING_SHORT", "ITEM_MOD_HASTE_SPELL_RATING_SHORT"}, index=18},
    ["Expertise"] = {direct={"EXPERTISE_PCT"}, rating={"ITEM_MOD_EXPERTISE_RATING_SHORT"}, index=24},
    ["Dodge Chance"] = {direct={"DODGE_PCT"}, rating={"ITEM_MOD_DODGE_RATING_SHORT"}, index=3, divisor="DODGE"},
    ["Parry Chance"] = {direct={"PARRY_PCT"}, rating={"ITEM_MOD_PARRY_RATING_SHORT"}, index=4, divisor="PARRY"},
    ["Block Chance (Bonus)"] = {direct={"BLOCK_PCT"}, rating={"ITEM_MOD_BLOCK_RATING_SHORT"}, index=5, divisor="BLOCK"},
}

-- Immutable lookup tables shared by cache misses, rather than rebuilt for
-- each item or tooltip line.
local sharedSpellPowerKeys = {"ITEM_MOD_SPELL_POWER", "ITEM_MOD_SPELL_POWER_SHORT"}
local weaponDPSKeys = {"ITEM_MOD_DAMAGE_PER_SECOND_SHORT"}
local defenseRatingKeys = {"ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"}
local allStats = {"Strength", "Agility", "Stamina", "Intellect", "Spirit"}
local resistanceSchools = {"Arcane", "Fire", "Nature", "Frost", "Shadow"}
local conditionalPhrases = {" against ", " versus ", " while ", " when ", " if ", " after ", " upon ", " in forests", " in grassland"}
local percentLabels = {
    ["hit chance"]="Hit Chance", ["hit"]="Hit Chance", ["critical strike"]="Crit Chance",
    ["critical strike chance"]="Crit Chance", ["crit chance"]="Crit Chance", ["haste"]="Haste",
    ["expertise"]="Expertise", ["dodge"]="Dodge Chance", ["dodge chance"]="Dodge Chance",
    ["parry"]="Parry Chance", ["parry chance"]="Parry Chance", ["block chance"]="Block Chance (Base)",
}
local ratingDescriptions = {
    {"hit", "Hit Chance", 6, "HIT"}, {"crit", "Crit Chance", 9, "CRIT"},
    {"haste", "Haste", 18}, {"expertise", "Expertise", 24},
    {"dodge", "Dodge Chance", 3, "DODGE"}, {"parry", "Parry Chance", 4, "PARRY"},
    {"block", "Block Chance (Bonus)", 5, "BLOCK"},
}

local function first(raw, keys)
    for _, key in ipairs(keys) do
        local value = number(raw[key])
        if value then return value end
    end
end
local function largest(raw, keys)
    local result
    for _, key in ipairs(keys) do
        local value = number(raw[key])
        if value and (not result or abs(value) > abs(result)) then result = value end
    end
    return result
end

-- All aliases in a group describe one stat, so they are never blindly summed.
function NS.ReadAPIStats(raw, context)
    local stats, warnings = {}, {}
    raw, context = raw or {}, context or {}
    for stat, keys in pairs(RAW) do stats[stat] = first(raw, keys) end
    -- Keep the provenance of generic spell power: it increases both totals,
    -- but its shared portion must receive only one weight during scoring.
    stats._sharedSpellPower = first(raw, sharedSpellPowerKeys) or 0
    local dps = first(raw, weaponDPSKeys)
    if dps then stats[context.ranged and "Ranged Weapon DPS" or "Weapon DPS"] = dps end
    local function convert(index, value, divisor, stat)
        if context.convertRating then
            local ok, result = pcall(context.convertRating, index, value)
            result = ok and number(result) or nil
            if result then return result end
        end
        if divisor and NS.RATING_DIVISORS[divisor] then return value / NS.RATING_DIVISORS[divisor] end
        warnings[stat] = "Rating conversion unavailable for " .. stat
    end
    for stat, def in pairs(PERCENT) do
        local value = largest(raw, def.direct)
        if value then stats[stat] = value
        else
            value = largest(raw, def.rating)
            if value then stats[stat] = convert(def.index, value, def.divisor, stat) end
        end
    end
    if not stats.Defense then
        local value = first(raw, defenseRatingKeys)
        if value then stats.Defense = convert(2, value, nil, "Defense") end
    end
    -- An unqualified EXPERTISE key has no verified units in Forever. Never
    -- silently treat legacy skill points as percentage points.
    if not stats.Expertise then
        local value = number(raw.EXPERTISE)
        if value then warnings.Expertise = "Unverified units for the EXPERTISE field; tooltip percentage required" end
    end
    return stats, warnings
end

local labels = {}
local function label(text, stat)
    text = clean(text):lower():gsub("%.$", "")
    if text ~= "" and not text:find("%", 1, true) then labels[text] = stat end
end
for stat, keys in pairs(RAW) do
    label(stat, stat)
    for _, key in ipairs(keys) do if _G[key] then label(_G[key], stat) end end
end
label("Spell Power", "Spell Power")
label("Spell Damage and Healing", "Spell Power")
label("Spell Piercing", "Spell Penetration")
label("Bonus Healing", "Healing")
label("Healing Spells", "Healing")
label("Weapon Damage", "Flat Weapon Damage")
label("Physical Damage", "Flat Weapon Damage")
label("Bonus Armor", "Armor (Bonus)")
label("Defense Skill", "Defense")
label("All Stats", "All Stats")
label("All Resistances", "All Resistances")

local skills = {
    ["two-handed swords"]="Two-Handed Sword Skill", ["two handed swords"]="Two-Handed Sword Skill",
    ["two-handed axes"]="Two-Handed Axe Skill", ["two handed axes"]="Two-Handed Axe Skill",
    ["two-handed maces"]="Two-Handed Mace Skill", ["two handed maces"]="Two-Handed Mace Skill",
    ["swords"]="Sword Skill", ["one-handed swords"]="Sword Skill",
    ["maces"]="Mace Skill", ["one-handed maces"]="Mace Skill",
    ["axes"]="Axe Skill", ["one-handed axes"]="Axe Skill",
    ["guns"]="Gun Skill", ["daggers"]="Dagger Skill", ["crossbows"]="Crossbow Skill",
    ["polearms"]="Polearm Skill", ["fist weapons"]="Fist Weapon Skill",
    ["unarmed"]="Fist Weapon Skill", ["feral combat"]="Feral Combat Skill",
}
for text, stat in pairs(skills) do label(text, stat); label(text .. " skill", stat) end

local function add(stats, stat, value)
    value = number(value)
    if not stat or not value then return end
    if stat == "Spell Power" then
        add(stats, "Spell Damage", value); add(stats, "Healing", value)
        stats._sharedSpellPower = (stats._sharedSpellPower or 0) + value
    elseif stat == "All Stats" then
        for _, key in ipairs(allStats) do add(stats, key, value) end
    elseif stat == "All Resistances" then
        for _, school in ipairs(resistanceSchools) do add(stats, school .. " Resistance", value) end
    else stats[stat] = (stats[stat] or 0) + value end
end

local function excluded(text, line, context)
    if safe(line.type) and line.type and context.excludedTypes and context.excludedTypes[line.type] then return true end
    if text:match("^use:") or text:match("^chance on hit:") or text:find("set%s*:")
        or text:match("^set%s*%(") or text:match("^%(%s*%d+%s*%)")
        or text:find("chance on", 1, true) then return true end
    for _, phrase in ipairs(conditionalPhrases) do
        if text:find(phrase, 1, true) then return true end
    end
    return text:match("for [%d%.]+ sec") or text:match("damage done to [%a]+ by")
end

-- Deliberately anchored patterns: flavor text and named procs are not stat bonuses.
local function parseLine(original, line, context, out, ratings)
    local text = clean(original):lower()
    if text == "" or excluded(text, line, context) then return end
    local equip = text:match("^equip:") ~= nil
    text = text:gsub("^equip:%s*", ""):gsub("%.$", "")
    text = text:gsub(" seconds$", " sec"):gsub(" secs$", " sec")

    local value, name = text:match("^([+-]?[%d%.%,]+)%s+(.+)$")
    if name then name = name:gsub("^to%s+", "") end
    if value and labels[name] then add(out, labels[name], value); return end
    -- The client's percent labels can also be direct stat lines.
    local pct, pctName = text:match("^([+-]?[%d%.]+)%%%s+(.+)$")
    if pct then
        local stat = percentLabels[pctName]
        if stat == "Block Chance (Base)" and equip then stat = "Block Chance (Bonus)" end
        if stat then add(out, stat, pct); return end
    end
    local dps = text:match("^%(([%d%.]+) damage per second%)$")
        or text:match("^adds ([%d%.]+) damage per second$")
        or text:match("^([%d%.]+) damage per second$")
    if dps then add(out, context.ranged and "Ranged Weapon DPS" or "Weapon DPS", dps); return end

    local skill, amount = text:match("^increased (.-) %+([%d%.]+)$")
    if not skill then skill, amount = text:match("^increases (.-) %+([%d%.]+)$") end
    if skill and skills[skill] then add(out, skills[skill], amount); return end
    amount, skill = text:match("^increases your skill in (.-) by ([%d%.]+)$")
    if amount and skills[amount] then add(out, skills[amount], skill); return end
    amount = text:match("^increased defense %+([%d%.]+)$") or text:match("^increases defense by ([%d%.]+)$")
    if amount then add(out, "Defense", amount); return end

    local regen, unit = text:match("^restores ([%d%.]+) (mana) per 5 sec$")
    if not regen then regen, unit = text:match("^restores ([%d%.]+) (health) per 5 sec$") end
    if not regen then regen, unit = text:match("^restores ([%d%.]+) (mana) every 5 sec$") end
    if not regen then regen, unit = text:match("^restores ([%d%.]+) (health) every 5 sec$") end
    if regen then add(out, unit == "mana" and "Mana per 5" or "Health per 5", regen); return end
    amount = text:match("^increases damage and healing done by magical spells and effects by up to ([%d%.]+)$")
        or text:match("^increases damage and healing done by up to ([%d%.]+)$")
    if amount then add(out, "Spell Power", amount); return end
    amount = text:match("^increases healing done by spells and effects by up to ([%d%.]+)$")
        or text:match("^increases healing done by up to ([%d%.]+)$")
    if amount then add(out, "Healing", amount); return end
    amount = text:match("^increases damage done by magical spells and effects by up to ([%d%.]+)$")
        or text:match("^increases spell damage by ([%d%.]+)$")
    if amount then add(out, "Spell Damage", amount); return end
    local school, schoolAmount = text:match("^increases damage done by (.-) spells and effects by up to ([%d%.]+)$")
    if school and schoolAmount then
        school = school:sub(1,1):upper() .. school:sub(2)
        if NS.WEIGHTS[school .. " Damage"] then add(out, school .. " Damage", schoolAmount); return end
    end
    amount = text:match("^increases healing done by up to ([%d%.]+) and damage done by up to")
    local damage = text:match("^increases healing done by up to [%d%.]+ and damage done by up to ([%d%.]+)")
    if amount and damage then
        add(out, "Healing", amount); add(out, "Spell Damage", damage)
        out._sharedSpellPower = (out._sharedSpellPower or 0) + min(number(amount), number(damage))
        return
    end
    amount = text:match("^increases damage done by up to ([%d%.]+) and healing done by up to")
    local healing = text:match("^increases damage done by up to [%d%.]+ and healing done by up to ([%d%.]+)")
    if amount and healing then
        add(out, "Spell Damage", amount); add(out, "Healing", healing)
        out._sharedSpellPower = (out._sharedSpellPower or 0) + min(number(amount), number(healing))
        return
    end
    amount = text:match("^increases your spell penetration by ([%d%.]+)$")
        or text:match("^increases your spell piercing by ([%d%.]+)$")
        or text:match("^decreases the magical resistances of your spell targets by ([%d%.]+)$")
        or text:match("^your spells pierce ([%d%.]+) magical resists$")
    if amount then add(out, "Spell Penetration", amount); return end
    amount = text:match("^%+([%d%.]+) attack power in cat, bear, and dire bear forms only$")
        or text:match("^increases attack power by ([%d%.]+) in cat, bear, and dire bear forms only$")
    if amount then add(out, "Feral Attack Power", amount); return end
    amount = text:match("^increases attack power by ([%d%.]+)$")
    if amount then add(out, "Attack Power", amount); return end
    amount = text:match("^increases ranged attack power by ([%d%.]+)$")
    if amount then add(out, "Ranged Attack Power", amount); return end
    amount = text:match("^increases the block value of your shield by ([%d%.]+)$")
        or text:match("^increases your shield block value by ([%d%.]+)$")
    if amount then add(out, "Block Value", amount); return end
    amount = text:match("^increases armor by ([%d%.]+)$")
    if amount then add(out, "Armor (Bonus)", amount); return end
    amount = text:match("^([%d%.]+) block$")
    if amount then add(out, "Block Value", amount); return end
    amount = text:match("^block chance ([%d%.]+)%%$")
    if amount then add(out, equip and "Block Chance (Bonus)" or "Block Chance (Base)", amount); return end

    amount = text:match("^reduces the chance your attacks will be dodged or parried by ([%d%.]+)%%$")
        or text:match("^reduces the chance for your attacks to be dodged or parried by ([%d%.]+)%%$")
    if amount then add(out, "Expertise", amount); return end

    -- Only stat-increase descriptions are accepted; a resistance to critical
    -- hits, a damage proc, or a percentage AP multiplier is not hit/crit chance.
    local isStatIncrease = text:match("^increases your ") or text:match("^improves your ")
        or text:match("^increases ranged attack speed") or text:match("^increases attack speed")
        or text:match("^increases spell haste") or text:match("^%+[%d%.]+ .-rating$")
    if not isStatIncrease then return end
    -- Percent values in parentheses next to a rating are authoritative.
    local shown = text:match("%(([%d%.]+)%%")
    for _, entry in ipairs(ratingDescriptions) do
        local matches = text:find(entry[1], 1, true)
        if entry[1] == "haste" and text:find("attack speed", 1, true) then matches = true end
        if entry[1] == "hit" and text:find("critical", 1, true) then matches = false end
        if matches then
            local percent = shown or text:match("by ([%d%.]+)%%")
            if percent then add(out, entry[2], percent); return end
            local rating = text:match("rating by ([%d%.]+)") or text:match("^%+([%d%.]+) .-rating$")
            if rating then
                ratings[#ratings+1] = {stat=entry[2], index=entry[3], divisor=entry[4], value=number(rating)}
                return
            end
        end
    end
end

function NS.ExtractStats(raw, lines, context)
    context = context or {}
    local stats, warnings = NS.ReadAPIStats(raw, context)
    local fromTooltip, ratingLines = {}, {}
    if context.english ~= false then
        for _, line in ipairs(lines or {}) do
            if type(line) == "string" then line = {leftText=line} end
            parseLine(line.leftText, line, context, fromTooltip, ratingLines)
        end
    end
    -- Tooltip percentages take priority; never add their underlying ratings again.
    local convertedRatings = {}
    for _, entry in ipairs(ratingLines) do
        if fromTooltip[entry.stat] == nil then
            local result
            if context.convertRating then
                local ok, converted = pcall(context.convertRating, entry.index, entry.value)
                result = ok and number(converted) or nil
            end
            if not result and entry.divisor then result = entry.value / NS.RATING_DIVISORS[entry.divisor] end
            if result then add(convertedRatings, entry.stat, result)
            else warnings[entry.stat] = "Rating conversion unavailable for " .. entry.stat end
        end
    end
    for stat, value in pairs(convertedRatings) do add(fromTooltip, stat, value) end
    local apiArmor = stats.Armor
    for stat, value in pairs(fromTooltip) do
        if stat ~= "Armor" or not apiArmor then stats[stat] = value end
        warnings[stat] = nil
    end
    -- A parsed set of spell bonuses replaces the API's spell totals and its
    -- provenance together. Separate damage/healing lines are still additive.
    if fromTooltip["Spell Damage"] ~= nil or fromTooltip.Healing ~= nil then
        stats._sharedSpellPower = fromTooltip._sharedSpellPower or 0
    end
    -- API weapon DPS has more precision than the printed, rounded tooltip DPS.
    local apiDPS = first(raw or {}, weaponDPSKeys)
    if apiDPS then stats[context.ranged and "Ranged Weapon DPS" or "Weapon DPS"] = apiDPS end
    -- API armor is the total; split bonus armor without counting it twice.
    if apiArmor and stats["Armor (Bonus)"] then stats.Armor = apiArmor - stats["Armor (Bonus)"] end
    return stats, warnings
end

function NS.CalculateScore(stats, weights)
    weights = weights or NS.WEIGHTS
    local score, breakdown = 0, {}
    local damage = number(stats["Spell Damage"]) or 0
    local healing = number(stats.Healing) or 0
    local shared = number(stats._sharedSpellPower) or 0
    -- Clamp to the amount actually present in both categories, including
    -- penalties. Never infer overlap just because separate totals are equal.
    if shared > 0 then shared = max(0, min(shared, damage, healing))
    elseif shared < 0 then shared = min(0, max(shared, damage, healing)) end
    local damageWeight = number(weights["Spell Damage"]) or 0
    local healingWeight = number(weights.Healing) or 0
    local lowerStat = damageWeight >= healingWeight and "Healing" or "Spell Damage"
    if shared ~= 0 then
        breakdown.sharedSpellPower = shared
        breakdown.sharedSpellStat = lowerStat == "Healing" and "Spell Damage" or "Healing"
    end
    for _, stat in ipairs(NS.STAT_ORDER) do
        local value = number(stats[stat])
        local weight = number(weights[stat])
        if value and stat == lowerStat then value = value - shared end
        if value and weight and value ~= 0 then
            local points = value * weight
            score = score + points
            breakdown[#breakdown+1] = {stat=stat, value=value, weight=weight, points=points}
        end
    end
    return score, breakdown
end

-- Apply the item's baseline before the final rarity adjustment. Keep the
-- stat subtotal separately so diagnostics explain every stage of the score.
function NS.CalculateItemScore(stats, itemLevel, quality, hasEffect, hasUse, weights)
    local statScore, breakdown = NS.CalculateScore(stats, weights)
    local warnings = {}
    local level = number(itemLevel)
    if not level or level < 0 then
        level = 0
        warnings.ItemLevel = "Item level unavailable; base score omitted"
    end
    quality = number(quality)
    local multiplier = quality and number(NS.RARITY_MULTIPLIERS[quality])
    if not multiplier then
        multiplier = 1
        warnings.Rarity = "Rarity unavailable or unsupported; neutral multiplier used"
    end
    local baseWeight = number(NS.ITEM_LEVEL_WEIGHT) or 0
    local effectMultiplier = hasEffect and quality and NS.EFFECT_MULTIPLIERS
        and number(NS.EFFECT_MULTIPLIERS[quality]) or 1
    -- Use effects qualify independently of recognized flat stats. Apply one
    -- effect factor on the base, even if Equip/Use/proc effects coexist.
    if hasUse == true then effectMultiplier = number(NS.USE_EFFECT_MULTIPLIER) or 1.5 end
    local hasStats = #breakdown > 0
    local hasBase = hasStats or hasEffect == true or hasUse == true
    local baseScore = hasBase and level * baseWeight * effectMultiplier or 0
    local rawScore = (statScore + baseScore) * multiplier
    local divisor = number(NS.SCORE_DIVISOR) or 4
    if divisor <= 0 then divisor = 4 end
    local score = math.floor(rawScore / divisor)
    return score, breakdown, {
        statScore=statScore, itemLevel=level, baseWeight=baseWeight,
        baseScore=baseScore, rarity=quality and NS.RARITY_NAMES[quality] or "Unknown",
        hasEffect=hasEffect == true, hasUse=hasUse == true, effectMultiplier=effectMultiplier,
        rarityMultiplier=multiplier,
        rawScore=rawScore, divisor=divisor,
        hasStats=hasStats, hasBase=hasBase,
    }, warnings
end
