local _, NS = ...

-- Independent baseline; normal scoring never reads these overrides.
NS.DYNAMIC_WEIGHTS = {}
for stat, weight in pairs(NS.WEIGHTS) do NS.DYNAMIC_WEIGHTS[stat] = weight end
NS.DYNAMIC_CLASS_WEIGHTS = {WARRIOR={}, PALADIN={}, HUNTER={}, ROGUE={}, PRIEST={},
    SHAMAN={}, MAGE={}, WARLOCK={}, DRUID={}}

local function spec(name, melee, tank, heal, schools)
    local role = tank and "Tank" or heal and "Healer" or melee and "Attack DPS" or "Spell DPS"
    return {name=name, melee=melee, tank=tank, heal=heal, schools=schools or {}, role=role, roles={[role]=true}}
end
-- Native classic tree order. Feral intentionally combines cat and bear.
NS.DYNAMIC_SPECS = {
    WARRIOR={spec("Arms",true),spec("Fury",true),spec("Protection",true,true)},
    PALADIN={spec("Holy",false,false,true,{"Holy"}),spec("Protection",true,true,false,{"Holy"}),spec("Retribution",true,false,false,{"Holy"})},
    HUNTER={spec("Beast Mastery",true),spec("Marksmanship",true),spec("Survival",true)},
    ROGUE={spec("Assassination",true),spec("Combat",true),spec("Subtlety",true)},
    PRIEST={spec("Discipline",false,false,true,{"Holy","Shadow"}),spec("Holy",false,false,true,{"Holy"}),spec("Shadow",false,false,false,{"Shadow"})},
    SHAMAN={spec("Elemental",false,false,false,{"Nature","Fire","Frost"}),spec("Enhancement",true,false,false,{"Nature","Fire","Frost"}),spec("Restoration",false,false,true,{"Nature","Fire","Frost"})},
    MAGE={spec("Arcane",false,false,false,{"Arcane","Fire","Frost"}),spec("Fire",false,false,false,{"Arcane","Fire","Frost"}),spec("Frost",false,false,false,{"Arcane","Fire","Frost"})},
    WARLOCK={spec("Affliction",false,false,false,{"Shadow","Fire"}),spec("Demonology",false,false,false,{"Shadow","Fire"}),spec("Destruction",false,false,false,{"Shadow","Fire"})},
    DRUID={spec("Balance",false,false,false,{"Arcane","Nature"}),spec("Feral",true,true),spec("Restoration",false,false,true,{"Arcane","Nature"})},
}
-- Cat and bear share one scoring profile and may use either role's items.
NS.DYNAMIC_SPECS.DRUID[2].roles["Attack DPS"] = true
local schools = {"Arcane","Fire","Nature","Frost","Shadow","Holy"}

local function canHeal(classToken)
    -- Derive class capabilities from the same data that defines its specs.
    -- Added healing trees therefore do not need a second class whitelist.
    for _, tree in ipairs(NS.DYNAMIC_SPECS[classToken] or {}) do
        if tree.heal == true then return true end
    end
    return false
end

function NS.GetClassToken(unit)
    if type(UnitClass) ~= "function" then return end
    local ok, _, token = pcall(UnitClass, unit or "player")
    if ok and NS.IsSafe(token) and type(token) == "string" and token ~= "" then return token end
end

function NS.ClassifyTalents(classToken, points, level, race)
    local profile = {classToken=classToken, points=points, level=level, race=race, available=false}
    local trees = NS.DYNAMIC_SPECS[classToken]
    if not trees then profile.reason="unknown-class"; return profile end
    if not level then profile.reason="level-unavailable"; return profile end
    if level < NS.TALENT_RULES.minLevel then profile.reason="below-level-10"; return profile end
    local order, total = {1,2,3}, 0
    for i=1,3 do
        local value = points and NS.GetNumber(points[i])
        if not value or value < 0 or value > NS.TALENT_RULES.maxPoints or value ~= math.floor(value) then
            profile.reason="talents-unavailable"; return profile
        end
        total = total + value
    end
    if total == 0 then profile.reason="no-talents"; return profile end
    if total > NS.TALENT_RULES.maxPoints then profile.reason="talents-unavailable"; return profile end
    table.sort(order,function(a,b) if points[a]==points[b] then return a<b end; return points[a]>points[b] end)
    local top = points[order[1]]
    profile.hybrid = points[order[2]] > 0 and top - points[order[2]] <= NS.TALENT_RULES.hybridGap
    profile.trees, profile.schools, profile.roles = {}, {}, {}
    profile.melee, profile.tank, profile.heal = false, false, false
    local names = {}
    for _, i in ipairs(order) do
        if i == order[1] or (profile.hybrid and points[i] > 0 and top - points[i] <= NS.TALENT_RULES.hybridGap) then
            local tree = trees[i]
            for role in pairs(tree.roles or {}) do profile.roles[role]=true end
            profile.trees[#profile.trees+1] = i; names[#names+1] = tree.name
            profile.melee = profile.melee or tree.melee == true
            profile.tank = profile.tank or tree.tank == true
            profile.heal = profile.heal or tree.heal == true
            for _, school in ipairs(tree.schools) do profile.schools[school]=true end
        end
    end
    -- Starshards is a Night Elf priest racial; don't credit Arcane to all priests.
    if classToken=="PRIEST" and race=="NightElf" then profile.schools.Arcane=true end
    profile.name = (profile.hybrid and "Hybrid: " or "") .. table.concat(names," / ")
    profile.available=true
    return profile
end

-- Supported skill rows only: role filtering is separate from proficiency.
local skillSets = {
    WARRIOR={"Two-Handed Sword Skill","Two-Handed Axe Skill","Two-Handed Mace Skill","Sword Skill","Mace Skill","Axe Skill","Dagger Skill","Polearm Skill","Fist Weapon Skill"},
    PALADIN={"Two-Handed Sword Skill","Two-Handed Axe Skill","Two-Handed Mace Skill","Sword Skill","Mace Skill","Axe Skill","Polearm Skill"},
    HUNTER={"Two-Handed Sword Skill","Two-Handed Axe Skill","Sword Skill","Axe Skill","Dagger Skill","Polearm Skill","Fist Weapon Skill","Gun Skill","Crossbow Skill"},
    -- Forever adds one-handed axes; it does not add two-handed weapons to Rogues.
    ROGUE={"Sword Skill","Mace Skill","Axe Skill","Dagger Skill","Fist Weapon Skill"},
    SHAMAN={"Two-Handed Axe Skill","Two-Handed Mace Skill","Axe Skill","Mace Skill","Dagger Skill","Fist Weapon Skill"},
    DRUID={"Feral Combat Skill"},
}
NS.DYNAMIC_SKILLS = {}
for class, list in pairs(skillSets) do
    NS.DYNAMIC_SKILLS[class]={}
    for _, stat in ipairs(list) do NS.DYNAMIC_SKILLS[class][stat]=true end
end
local function hasTree(profile, index)
    for _, tree in ipairs(profile.trees or {}) do if tree==index then return true end end
    return false
end

function NS.GetDynamicWeights(classToken, profile)
    local weights = {}
    for stat, weight in pairs(NS.DYNAMIC_WEIGHTS) do weights[stat]=weight end
    if profile and profile.available then
        local function scale(stat, factor) weights[stat]=(weights[stat] or 0)*factor end
        -- Every armor piece carries base armor; only extra armor is role-specific.
        if not profile.tank then scale("Armor (Bonus)",0.5); weights.Defense=0 end
        local spellUser = next(profile.schools) ~= nil
        for _, school in ipairs(schools) do
            scale(school .. " Damage", profile.schools[school] and (profile.tank and 0.5 or 1) or 0)
        end
        scale("Spell Damage",spellUser and (profile.tank and 0.5 or 1) or 0)
        if not profile.melee then
            weights.Strength=0; weights["Attack Power"]=0; weights["Ranged Attack Power"]=0; weights["Feral Attack Power"]=0
            scale("Agility",0.5)
        end
        local survival = classToken=="HUNTER" and hasTree(profile,3)
        if classToken=="HUNTER" and not survival then weights.Strength=0 end
        local allowed=NS.DYNAMIC_SKILLS[classToken] or {}
        for stat in pairs(weights) do
            if stat:match(" Skill$") then
                local useful=profile.melee and allowed[stat]
                if classToken=="HUNTER" and not survival then useful=stat=="Gun Skill" or stat=="Crossbow Skill" end
                if not useful then weights[stat]=0 end
            end
        end
        if classToken~="HUNTER" then weights["Ranged Attack Power"]=0 end
        if classToken~="DRUID" or not profile.melee then weights["Feral Attack Power"]=0 end
        if classToken=="WARRIOR" or classToken=="ROGUE" then
            weights.Intellect=0; weights.Mana=0; weights["Mana per 5"]=0
        end
        if classToken=="DRUID" then
            weights["Parry Chance"]=0; weights["Block Chance (Base)"]=0
            weights["Block Chance (Bonus)"]=0; weights["Block Value"]=0
        end
        if not canHeal(classToken) then
            weights.Healing=0; weights["Healing (with damage)"]=0
        elseif not profile.heal then
            weights.Healing=0.1; weights["Healing (with damage)"]=0.1
        end
    end
    for stat, weight in pairs(NS.DYNAMIC_CLASS_WEIGHTS[classToken] or {}) do weights[stat]=weight end
    return weights
end
