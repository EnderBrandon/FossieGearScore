local _, NS = ...
local setIDsByName = {}

-- GetItemInfo's sixteenth return value is the native item-set ID. Keep the
-- complete item link so random suffixes and instances retain their identity.
function NS.GetItemSetID(link)
    local getter = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(getter) ~= "function" then return end
    local ok, id = pcall(function() return select(16, getter(link)) end)
    id = ok and NS.GetNumber(id)
    if id and id > 0 then return id end
end

function NS.GetSetKey(set)
    if not set then return end
    local id = NS.GetNumber(set.id)
    if not id and set.name then id = setIDsByName[set.name:lower()] end
    if id then return "id:" .. tostring(id) end
    if set.name then return "name:" .. set.name:lower() end
end

local function setRequirement(text)
    return NS.GetNumber(text:match("^%(%s*(%d+)%s*%)%s*set%s*:")
        or text:match("^set%s*%(%s*(%d+)%s*%)%s*:")
        or text:match("^set%s*:%s*%(%s*(%d+)%s*%)"))
end

function NS.ReadItemBonuses(lines, setID)
    local metadata = {hasEffect=false, hasUse=false}
    local header, requirements, headerIndex, hasActiveBonus
    requirements = {}
    for index, source in ipairs(lines or {}) do
        local line = type(source) == "string" and {leftText=source} or source
        local text = NS.CleanText(line.leftText)
        local name, count, total = text:match("^(.+)%s+%((%d+)%s*/%s*(%d+)%)$")
        count, total = NS.GetNumber(count), NS.GetNumber(total)
        if name and total and total >= 1 and total <= 19 and count <= total then
            header = {name=NS.CleanText(name), equipped=count, total=total}
            headerIndex = index
        end
        local lower = text:lower()
        local required = setRequirement(lower)
        if required and required >= 1 and required <= 19 then
            requirements[#requirements+1] = {pieces=required}
        elseif not required and lower:match("^set%s*:") then
            -- An unlocked native bonus is "Set: ..."; only locked tiers
            -- retain "(N) Set: ...". Do not mistake those higher tiers for
            -- the minimum requirement of a set that is already active.
            hasActiveBonus = true
        end
    end
    setID = NS.GetNumber(setID)
    if setID and setID <= 0 then setID = nil end
    if setID or (header and (#requirements > 0 or hasActiveBonus)) then
        local set = header or {}
        set.id, set.requirements = setID, requirements
        set.hasActiveBonus = hasActiveBonus == true
        for _, requirement in ipairs(requirements) do
            set.required = math.min(set.required or requirement.pieces, requirement.pieces)
        end
        if setID and set.name then
            local key, previous = set.name:lower(), setIDsByName[set.name:lower()]
            if previous == nil or previous == setID then setIDsByName[key] = setID
            else setIDsByName[key] = false end -- Ambiguous names must not join different IDs.
        end
        metadata.set = set
        set.key = NS.GetSetKey(set)
    else headerIndex = nil end

    local enums = Enum and Enum.TooltipDataLineType or {}
    for index, source in ipairs(lines or {}) do
        local line = type(source) == "string" and {leftText=source} or source
        local text = NS.CleanText(line.leftText):lower()
        local kind = NS.IsSafe(line.type) and line.type
        local ignored = kind and (kind == enums.ItemEnchantmentPermanent or kind == enums.GemSocket
            or kind == enums.GemSocketEnchantment or kind == enums.FlavorText
            or kind == enums.ItemName or kind == enums.UsageRequirement)
        -- A set effect is a separate bonus, never a second intrinsic item proc.
        if not ignored and (not headerIndex or index < headerIndex)
            and not text:match("^%(%s*%d+%s*%)") and not text:find("set%s*:")
            and not text:match("^set%s*%(") then
            if text:match("^equip%s*:") or text:match("^chance on hit%s*:")
                or (kind and (kind == enums.ItemSpellTriggerOnEquip or kind == enums.ItemSpellTriggerOnProc)) then
                metadata.hasEffect = true
            end
            if text:match("^use%s*:")
                or (kind and kind == enums.ItemSpellTriggerOnUse) then
                metadata.hasUse = true
            end
        end
    end
    return metadata
end

-- At least one bonus tier must be unlocked. Apply one 1.05 factor per worn
-- piece plus one additional factor for activation, regardless of active tiers.
function NS.IsSetActive(set, count)
    count = NS.GetNumber(count) or 0
    if not set or count < 1 then return false end
    -- A native active line is evidence only for the wearer count it describes.
    -- Item links can otherwise describe your equipment while inspecting others.
    if set.hasActiveBonus and set.equipped == count then return true end
    -- Cosmetic colors are unreliable with tooltip skins. Numbered thresholds
    -- and the actual equipped count establish activation independently of RGB.
    return set.required ~= nil and count >= set.required
end

function NS.BuildSetGroups(results)
    local groups = {}
    for _, result in pairs(results) do
        local set = result.set
        local key = NS.GetSetKey(set)
        if key then
            local group = groups[key] or {count=0, requirements={}, members={}}
            groups[key] = group
            group.count = group.count + 1
            group.members[#group.members+1] = set
            if set.required then group.required = math.min(group.required or set.required, set.required) end
        end
    end
    for _, group in pairs(groups) do
        group.active = false
        for _, member in ipairs(group.members) do
            if NS.IsSetActive(member, group.count) then group.active = true; break end
        end
    end
    return groups
end

function NS.CalculateSetBonus(score, pieces, active)
    score, pieces = NS.GetNumber(score) or 0, NS.GetNumber(pieces) or 0
    if not active or pieces < 1 or pieces > 19 then return 0, score, 1 end
    local perPiece = NS.GetNumber(NS.SET_PIECE_MULTIPLIER) or 1.05
    if perPiece < 1 then perPiece = 1.05 end
    local multiplier = perPiece ^ (math.floor(pieces) + 1)
    local bonus = math.max(1, math.floor(score * multiplier) - score)
    return bonus, score + bonus, multiplier
end

function NS.ApplySetBonus(result, pieces, active)
    result.setBonusScore, result.totalScore, result.setMultiplier = NS.CalculateSetBonus(result.score, pieces, active)
    result.setPieces, result.setActive = pieces or 0, active == true
    return result
end
