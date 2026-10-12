local _, NS = ...
local unknownSlot = {}

local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function equipLocation(link, reads)
    reads.locations = reads.locations or {}
    local cached = reads.locations[link]
    if cached ~= nil then return cached or nil end
    local _, _, _, location = call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant, link)
    location = NS.IsSafe(location) and type(location) == "string" and location or nil
    reads.locations[link] = location or false
    return location
end

local function intrinsicScore(link, dynamic, classToken, reads)
    if not NS.IsSafe(link) or type(link) ~= "string" then return end
    -- Comparisons deliberately use the Item Score shown on the first line.
    -- Never resolve worn sets or recurse through the full equipment total.
    reads.items = reads.items or {}
    local result = reads.items[link]
    if result == nil then
        result = NS.ScoreItem(link, nil, {deferSet=true, classToken=classToken})
        reads.items[link] = result or false
    end
    if result and not result.partial then
        if dynamic then return NS.GetNumber(result.dynamicScore) end
        return NS.GetNumber(result.score)
    end
end

local function referenceScore(reference, dynamic, classToken, reads)
    if not NS.IsSafe(reference) or type(reference) ~= "table" then return end
    local link = reference.hyperlink
    if (not NS.IsSafe(link) or type(link) ~= "string") and NS.IsSafe(reference.guid) then
        local guid = reference.guid
        if guid ~= nil then
            reads.links = reads.links or {}
            link = reads.links[guid]
            if link == nil then
                link = call(C_Item and C_Item.GetItemLinkByGUID, guid)
                reads.links[guid] = NS.IsSafe(link) and type(link) == "string" and link or false
            end
        end
    end
    return intrinsicScore(link, dynamic, classToken, reads)
end

local function nativeDifference(result, dynamic, reads)
    if not reads.nativeChecked then
        reads.nativeChecked = true
        reads.native = call(C_TooltipComparison and C_TooltipComparison.GetItemComparisonInfo, {hyperlink=result.link})
    end
    local info = reads.native
    if not NS.IsSafe(info) or type(info) ~= "table" or not info.item then return nil, false end
    local equipped = referenceScore(info.item, dynamic, result.classToken, reads)
    if equipped == nil then return nil, true end
    local method = NS.GetNumber(info.method)
    local additional = NS.IsSafe(info.additionalItems) and info.additionalItems or nil
    if type(additional) ~= "table" then additional = {} end
    if method == 0 then -- Single: alternate equipped rings, trinkets or hands.
        local best = (dynamic and result.dynamicScore or result.score) - equipped
        for _, reference in ipairs(additional) do
            local other = referenceScore(reference, dynamic, result.classToken, reads)
            if other == nil then return nil, true end
            best = math.max(best, (dynamic and result.dynamicScore or result.score) - other)
        end
        return best, true
    elseif method == 1 then -- WithBothHands: both equipped items are removed.
        for _, reference in ipairs(additional) do
            local other = referenceScore(reference, dynamic, result.classToken, reads)
            if other == nil then return nil, true end
            equipped = equipped + other
        end
        return (dynamic and result.dynamicScore or result.score) - equipped, true
    elseif method == 2 or method == 3 then
        -- The native comparison proposes a bag partner when replacing a
        -- two-hander with two weapons. Include that partner exactly once.
        local best
        for _, reference in ipairs(additional) do
            local partner = referenceScore(reference, dynamic, result.classToken, reads)
            if partner == nil then return nil, true end
            local difference = (dynamic and result.dynamicScore or result.score) + partner - equipped
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

local function inventoryLink(slot, reads)
    reads.slots = reads.slots or {}
    local link = reads.slots[slot]
    if link == nil then
        local ok
        ok, link = pcall(GetInventoryItemLink, "player", slot)
        if not ok or not NS.IsSafe(link) then link = unknownSlot end
        reads.slots[slot] = link or false
    end
    if link == unknownSlot then return end
    return link or nil
end

local function slotScore(slot, dynamic, classToken, reads)
    if type(GetInventoryItemLink) ~= "function" then return end
    local link = inventoryLink(slot, reads)
    if reads.slots[slot] == unknownSlot then return end
    if type(link) == "string" then return intrinsicScore(link, dynamic, classToken, reads) end
    reads.emptySlots = reads.emptySlots or {}
    local empty = reads.emptySlots[slot]
    if empty == nil then
        local texture = call(GetInventoryItemTexture, "player", slot)
        empty = NS.IsSafe(texture) and not texture
        reads.emptySlots[slot] = empty
    end
    if not empty then return end -- occupied but loading
    return 0 -- genuinely empty equipment slot
end

local function fallbackDifference(result, dynamic, reads)
    local location = equipLocation(result.link, reads)
    if location == "INVTYPE_2HWEAPON" then
        local main, off = slotScore(16, dynamic, result.classToken, reads), slotScore(17, dynamic, result.classToken, reads)
        if main ~= nil and off ~= nil then return (dynamic and result.dynamicScore or result.score) - main - off end
        return
    end
    local slots = slotsByLocation[location]
    if location == "INVTYPE_WEAPON" then
        slots = call(CanDualWield) == true and {16,17} or {16}
    end
    if not slots then return end
    local best
    for _, slot in ipairs(slots) do
        local equipped = slotScore(slot, dynamic, result.classToken, reads)
        if equipped == nil then return end
        if slot == 17 then
            local mainLink = inventoryLink(16, reads)
            if reads.slots[16] == unknownSlot then return end
            if not NS.IsSafe(mainLink) then return end
            if type(mainLink) == "string" and equipLocation(mainLink, reads) == "INVTYPE_2HWEAPON" then
                local mainScore = slotScore(16, dynamic, result.classToken, reads)
                if mainScore == nil then return end
                equipped = equipped + mainScore
            end
        end
        local difference = (dynamic and result.dynamicScore or result.score) - equipped
        best = math.max(best or difference, difference)
    end
    return best
end

function NS.GetItemScoreDifference(result, dynamic, reads)
    if not result or result.partial or not NS.GetNumber(dynamic and result.dynamicScore or result.score) then return end
    if not NS.IsSafe(result.link) or type(result.link) ~= "string" then return end
    -- A tooltip may ask for both GS and DGS. Reuse native/item reads only
    -- within that decoration; another hover always starts with fresh data.
    reads = reads or {}
    local location = equipLocation(result.link, reads)
    -- Native comparison lists contain worn items, so an empty second ring
    -- or trinket slot may be omitted. Evaluate both slots explicitly.
    if location == "INVTYPE_FINGER" or location == "INVTYPE_TRINKET" then
        return fallbackDifference(result, dynamic, reads)
    end
    local difference, resolved = nativeDifference(result, dynamic, reads)
    if resolved then return difference end
    return fallbackDifference(result, dynamic, reads)
end

function NS.FormatScoreDifference(difference)
    difference = NS.GetNumber(difference)
    if difference == nil then return "|cffffffff(?)|r" end
    local color = difference > 0 and "|cff00ff00" or difference < 0 and "|cffff4040" or "|cffffffff"
    local text = difference > 0 and string.format("+%.0f", difference) or string.format("%.0f", difference)
    return color .. "(" .. text .. ")|r"
end

function NS.GetDynamicItemScoreDifference(result, reads)
    if result.dynamicScore == nil then return end
    return NS.GetItemScoreDifference(result, true, reads)
end
