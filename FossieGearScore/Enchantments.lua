local _, NS = ...

-- Permanent enhancement IDs are independent of item quality, stats, talents and
-- set multipliers. Build the small ID indexes once, never scan the catalogue on hover.
local byID, bySpell = {}, {}
local SLOT = {
    Bracer={INVTYPE_WRIST=true}, Chest={INVTYPE_CHEST=true, INVTYPE_ROBE=true},
    Cloak={INVTYPE_CLOAK=true}, Gloves={INVTYPE_HAND=true}, Boots={INVTYPE_FEET=true},
    Shield={INVTYPE_SHIELD=true}, Necklace={INVTYPE_NECK=true},
    ["Off-Hand"]={INVTYPE_HOLDABLE=true}, Belt={INVTYPE_WAIST=true},
    ["Head/legs"]={INVTYPE_HEAD=true, INVTYPE_LEGS=true}, Shoulders={INVTYPE_SHOULDER=true},
    ["Chest/legs/hands/feet"]={INVTYPE_CHEST=true, INVTYPE_ROBE=true, INVTYPE_LEGS=true, INVTYPE_HAND=true, INVTYPE_FEET=true},
    ["Ranged weapon"]={INVTYPE_RANGED=true, INVTYPE_RANGEDRIGHT=true},
    Weapon={INVTYPE_WEAPON=true, INVTYPE_WEAPONMAINHAND=true, INVTYPE_WEAPONOFFHAND=true, INVTYPE_2HWEAPON=true},
    ["2H Weapon"]={INVTYPE_2HWEAPON=true}, ["2H weapon"]={INVTYPE_2HWEAPON=true},
    ["Melee weapon"]={INVTYPE_WEAPON=true, INVTYPE_WEAPONMAINHAND=true, INVTYPE_WEAPONOFFHAND=true, INVTYPE_2HWEAPON=true},
}
local function index(map, id, entry)
    local group = map[id] or {}
    map[id], group[#group+1] = group, entry
end
for _, entry in ipairs(NS.ENCHANTMENT_CATALOG or {}) do
    for _, id in ipairs(entry.enchantIDs or {}) do index(byID, id, entry) end
    for _, id in ipairs(entry.spellIDs or {}) do index(bySpell, id, entry) end
end
NS.enchantmentsByID = byID

local function positive(value)
    value = NS.GetNumber(value)
    if value and value > 0 and value == math.floor(value) then return value end
end
local function linkID(link)
    if not NS.IsSafe(link) or type(link) ~= "string" then return end
    return positive(link:match("item:%d+:([^:|]*)"))
end

-- Only field two is the permanent enchant. Preserve gems, random suffix,
-- unique instance, level and bonus fields (and the display text) byte for byte.
function NS.GetUnenchantedItemLink(link)
    if not NS.IsSafe(link) or type(link) ~= "string" then return link end
    return (link:gsub("(item:%d+:)[^:|]*", function(prefix) return prefix .. "0" end, 1))
end

local function selectEntry(group, equipLoc)
    if not group then return end
    equipLoc = NS.IsSafe(equipLoc) and type(equipLoc) == "string" and equipLoc or nil
    local selected, lowest, highest, matches
    for _, entry in ipairs(group) do
        if not equipLoc or (SLOT[entry.slot] and SLOT[entry.slot][equipLoc]) then
            matches = (matches or 0)+1
            if not lowest or entry.tier < lowest then selected, lowest = entry, entry.tier end
            highest = math.max(highest or entry.tier, entry.tier)
        end
    end
    return selected, lowest ~= highest, matches
end
local function result(group, id, source, context)
    local entry, ambiguous = selectEntry(group, context.equipLoc)
    if not entry then
        return 0, {score=0, id=id, unknownID=id, unknown=true, source=source,
            reason=group and "unmatched-slot" or "unknown-id"}
    end
    local score = NS.ENCHANTMENT_REFERENCE.tierPoints[entry.tier]
    return score, {score=score, tier=entry.tier, id=id, entry=entry, source=source,
        ambiguous=ambiguous, policy=ambiguous and "lowest-applicable-tier" or nil}
end

function NS.ReadEnchantmentScore(link, lines, context)
    context = context or {}
    local id = linkID(link)
    -- An applied link ID is authoritative. Do not override an unknown ID with a
    -- similar tooltip name, or count other rows as extra stacked enhancements.
    if id then return result(byID[id], id, "item-link", context) end

    local permanent = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
    if not permanent then return 0 end
    local found, foundID, foundSource, foundAmbiguous, seenPermanent, unknownID
    for _, line in ipairs(lines or {}) do
        if type(line) == "table" and NS.IsSafe(line.type) and line.type == permanent then
            seenPermanent = true
            local enchantID = positive(line.enchantmentID) or positive(line.enchantID)
            local spellID = positive(line.spellID)
            local text = NS.IsSafe(line.leftText) and type(line.leftText) == "string" and line.leftText or ""
            spellID = spellID or positive(text:match("|Hspell:(%d+)"))
            local group = enchantID and byID[enchantID] or spellID and bySpell[spellID]
            local candidate, ambiguous = selectEntry(group, context.equipLoc)
            if candidate then
                -- One native permanent slot: duplicate rows are not extra points.
                -- Conflicting rows cannot establish that multiple installs stack.
                if found and candidate ~= found then
                    return 0, {score=0, unknown=true, source="tooltip", reason="conflicting-permanent-lines"}
                end
                found, foundID = candidate, enchantID or spellID
                foundSource = enchantID and "tooltip-enchant-id" or "tooltip-spell-id"
                foundAmbiguous = foundAmbiguous or ambiguous
            elseif enchantID or spellID then unknownID = enchantID or spellID
            end
        end
    end
    if found and not unknownID then
        local score = NS.ENCHANTMENT_REFERENCE.tierPoints[found.tier]
        return score, {score=score, tier=found.tier, id=foundID, entry=found, source=foundSource,
            ambiguous=foundAmbiguous, policy=foundAmbiguous and "lowest-applicable-tier" or nil}
    end
    if seenPermanent then return 0, {score=0, unknown=true, unknownID=unknownID, source="tooltip",
        reason=unknownID and "unknown-permanent-id" or "missing-permanent-id"} end
    return 0
end
