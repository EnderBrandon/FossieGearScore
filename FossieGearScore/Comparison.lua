local _, NS = ...

local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function equipLocation(link)
    local _, _, _, location = call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant, link)
    if NS.IsSafe(location) and type(location) == "string" then return location end
end

local function intrinsicScore(link)
    if not NS.IsSafe(link) or type(link) ~= "string" then return end
    -- Comparisons deliberately use the Item Score shown on the first line.
    -- Never resolve worn sets or recurse through the full equipment total.
    local result = NS.ScoreItem(link, nil, {deferSet=true})
    if result and not result.partial then return NS.GetNumber(result.score) end
end

local function referenceScore(reference)
    if not NS.IsSafe(reference) or type(reference) ~= "table" then return end
    local link = reference.hyperlink
    if (not NS.IsSafe(link) or type(link) ~= "string") and NS.IsSafe(reference.guid) then
        link = call(C_Item and C_Item.GetItemLinkByGUID, reference.guid)
    end
    return intrinsicScore(link)
end

local function nativeDifference(result)
    local info = call(C_TooltipComparison and C_TooltipComparison.GetItemComparisonInfo, {hyperlink=result.link})
    if not NS.IsSafe(info) or type(info) ~= "table" or not info.item then return nil, false end
    local equipped = referenceScore(info.item)
    if equipped == nil then return nil, true end
    local method = NS.GetNumber(info.method)
    local additional = NS.IsSafe(info.additionalItems) and info.additionalItems or nil
    if type(additional) ~= "table" then additional = {} end
    if method == 0 then -- Single: alternate equipped rings, trinkets or hands.
        local best = result.score - equipped
        for _, reference in ipairs(additional) do
            local other = referenceScore(reference)
            if other == nil then return nil, true end
            best = math.max(best, result.score - other)
        end
        return best, true
    elseif method == 1 then -- WithBothHands: both equipped items are removed.
        for _, reference in ipairs(additional) do
            local other = referenceScore(reference)
            if other == nil then return nil, true end
            equipped = equipped + other
        end
        return result.score - equipped, true
    elseif method == 2 or method == 3 then
        -- The native comparison proposes a bag partner when replacing a
        -- two-hander with two weapons. Include that partner exactly once.
        local best
        for _, reference in ipairs(additional) do
            local partner = referenceScore(reference)
            if partner == nil then return nil, true end
            local difference = result.score + partner - equipped
            best = math.max(best or difference, difference)
        end
        return best, true
    end
    return nil, false
end

local slotsByLocation = {
    INVTYPE_HEAD={1}, INVTYPE_NECK={2}, INVTYPE_SHOULDER={3}, INVTYPE_BODY={4},
    INVTYPE_CHEST={5}, INVTYPE_ROBE={5}, INVTYPE_WAIST={6}, INVTYPE_LEGS={7},
    INVTYPE_FEET={8}, INVTYPE_WRIST={9}, INVTYPE_HAND={10}, INVTYPE_FINGER={11,12},
    INVTYPE_TRINKET={13,14}, INVTYPE_CLOAK={15}, INVTYPE_WEAPONMAINHAND={16},
    INVTYPE_WEAPONOFFHAND={17}, INVTYPE_SHIELD={17}, INVTYPE_HOLDABLE={17},
    INVTYPE_RANGED={18}, INVTYPE_RANGEDRIGHT={18}, INVTYPE_THROWN={18},
    INVTYPE_RELIC={18}, INVTYPE_TABARD={19},
}

local function slotScore(slot)
    if type(GetInventoryItemLink) ~= "function" then return end
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    if not ok or not NS.IsSafe(link) then return end
    if type(link) == "string" then return intrinsicScore(link) end
    local texture = call(GetInventoryItemTexture, "player", slot)
    if not NS.IsSafe(texture) or texture then return end -- occupied but loading
    return 0 -- genuinely empty equipment slot
end

local function fallbackDifference(result)
    local location = equipLocation(result.link)
    if location == "INVTYPE_2HWEAPON" then
        local main, off = slotScore(16), slotScore(17)
        if main ~= nil and off ~= nil then return result.score - main - off end
        return
    end
    local slots = slotsByLocation[location]
    if location == "INVTYPE_WEAPON" then
        slots = call(CanDualWield) == true and {16,17} or {16}
    end
    if not slots then return end
    local best
    for _, slot in ipairs(slots) do
        local equipped = slotScore(slot)
        if equipped == nil then return end
        if slot == 17 then
            local mainLink = call(GetInventoryItemLink, "player", 16)
            if not NS.IsSafe(mainLink) then return end
            if type(mainLink) == "string" and equipLocation(mainLink) == "INVTYPE_2HWEAPON" then
                local mainScore = slotScore(16)
                if mainScore == nil then return end
                equipped = equipped + mainScore
            end
        end
        local difference = result.score - equipped
        best = math.max(best or difference, difference)
    end
    return best
end

function NS.GetItemScoreDifference(result)
    if not result or result.partial or not NS.GetNumber(result.score) then return end
    local location = equipLocation(result.link)
    -- Native comparison lists contain worn items, so an empty second ring
    -- or trinket slot may be omitted. Evaluate both slots explicitly.
    if location == "INVTYPE_FINGER" or location == "INVTYPE_TRINKET" then
        return fallbackDifference(result)
    end
    local difference, resolved = nativeDifference(result)
    if resolved then return difference end
    return fallbackDifference(result)
end

function NS.FormatScoreDifference(difference)
    difference = NS.GetNumber(difference)
    if difference == nil then return "|cffffffff(?)|r" end
    local color = difference > 0 and "|cff00ff00" or difference < 0 and "|cffff4040" or "|cffffffff"
    local text = difference > 0 and string.format("+%.0f", difference) or string.format("%.0f", difference)
    return color .. "(" .. text .. ")|r"
end
