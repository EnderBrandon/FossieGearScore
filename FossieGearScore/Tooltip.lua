local ADDON_NAME, NS = ...
local decorated = setmetatable({}, {__mode="k"})
local watched = setmetatable({}, {__mode="k"})
local attached, reportedError = false, false
local itemRequests = {}
local parsedItems, parsedByItem, parsedCount = {}, {}, 0
local profileWeights=setmetatable({}, {__mode="k"})
local excludedTypeNames = {"ItemEnchantmentPermanent", "GemSocket", "GemSocketEnchantment",
    "ItemSpellTriggerOnUse", "ItemSpellTriggerOnProc", "FlavorText", "UsageRequirement", "ItemName"}
local excludedTypes, excludedEnumValues, excludedEnumTable = {}, {}, false

function NS.InvalidateItemScoreCache(itemID)
    itemID=NS.GetNumber(itemID)
    if not itemID then parsedItems,parsedByItem,parsedCount={},{},0; return end
    local keys=parsedByItem[itemID]
    if not keys then return end
    for key in pairs(keys) do
        parsedItems[key]=nil; parsedCount=parsedCount-1
    end
    parsedByItem[itemID]=nil
end

local function message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFossieGearScore:|r " .. text) end
end

local function fingerprint(raw,lines,context,quality,itemLevel,setID)
    local parts={}
    local function append(value)
        local kind=NS.IsSafe(value) and type(value)
        local text=(kind=="string" or kind=="number" or kind=="boolean") and tostring(value) or ""
        parts[#parts+1]=#text .. ":" .. text
    end
    append(context.itemID); append(context.equipLoc); append(context.ranged); append(context.english)
    append(quality); append(itemLevel); append(setID)
    local keys={}
    for key in pairs(raw or {}) do
        if NS.IsSafe(key) and type(key)=="string" then keys[#keys+1]=key end
    end
    table.sort(keys)
    for _,key in ipairs(keys) do append(key); append(raw[key]) end
    for _,source in ipairs(lines) do
        local line=type(source)=="string" and {leftText=source} or source
        append(line.leftText); append(line.rightText); append(line.type)
        local color=line.leftColor
        if NS.IsSafe(color) and type(color)=="table" then append(color.r); append(color.g); append(color.b) end
    end
    return table.concat(parts,"|")
end

local function readIntrinsic(link,raw,lines,context,quality,itemLevel,setID)
    local key=link .. "|" .. fingerprint(raw,lines,context,quality,itemLevel,setID)
    local cached=parsedItems[key]
    if cached and cached.converter==context.convertRating then return cached end
    local stats,warnings=NS.ExtractStats(raw,lines,context)
    local bonuses=NS.ReadItemBonuses(lines,setID)
    local score,breakdown,scoring,metadataWarnings=NS.CalculateItemScore(stats,itemLevel,quality,bonuses.hasEffect,bonuses.hasUse)
    for name,warning in pairs(metadataWarnings) do warnings[name]=warning end
    cached={stats=stats,warnings=warnings,bonuses=bonuses,score=score,breakdown=breakdown,scoring=scoring,converter=context.convertRating,itemID=context.itemID,
        dynamic=setmetatable({}, {__mode="k"})}
    -- Session-only and bounded: full instance links retain suffixes/bonus IDs.
    if parsedCount>=512 and not parsedItems[key] then NS.InvalidateItemScoreCache() end
    if not parsedItems[key] then parsedCount=parsedCount+1 end
    parsedItems[key]=cached
    if context.itemID then
        local keys=parsedByItem[context.itemID] or {}
        parsedByItem[context.itemID],keys[key]=keys,true
    end
    return cached
end
NS.Message = message

local function call(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g = pcall(func, ...)
    if ok then return a, b, c, d, e, f, g end
end

function NS.RequestItemData(link)
    if not C_Item or type(C_Item.RequestLoadItemDataByID) ~= "function" then return end
    local id = call(C_Item.GetItemInfoInstant or GetItemInfoInstant, link)
    id = NS.GetNumber(id) or tonumber(link:match("item:(%d+)"))
    if not id or id <= 0 then return end
    local time = NS.GetNumber(call(GetTime)) or 0
    if itemRequests[id] and time - itemRequests[id] < 2 then return end
    itemRequests[id] = time
    -- Request the base data by ID, but always score the original instance link.
    pcall(C_Item.RequestLoadItemDataByID, id)
end

local function displayedLink(tooltip, data)
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = call(TooltipUtil.GetDisplayedItem, tooltip)
        if NS.IsSafe(link) and type(link) == "string" then return link end
    end
    if data and NS.IsSafe(data.hyperlink) and type(data.hyperlink) == "string" then return data.hyperlink end
    if data and NS.IsSafe(data.guid) and data.guid and C_Item then
        local link = call(C_Item.GetItemLinkByGUID, data.guid)
        if NS.IsSafe(link) and type(link) == "string" then return link end
    end
    -- Compatibility path for frames from older addons. Forever itself uses TooltipUtil.
    if tooltip.GetItem then
        local _, link = call(tooltip.GetItem, tooltip)
        if NS.IsSafe(link) and type(link) == "string" then return link end
    end
    -- Do not rebuild a link from itemID: random suffixes must retain their stats.
end

local function frameLines(tooltip)
    local lines = {}
    local name = call(tooltip.GetName, tooltip)
    local count = call(tooltip.NumLines, tooltip)
    if not name or not count then return lines end
    for i=1,count do
        local left = _G[name .. "TextLeft" .. i]
        local right = _G[name .. "TextRight" .. i]
        local r, g, b = call(left and left.GetTextColor, left)
        lines[#lines+1] = {leftText=left and call(left.GetText, left), rightText=right and call(right.GetText, right),
            leftColor=r and {r=r, g=g, b=b} or nil}
    end
    return lines
end

local function currentExcludedTypes()
    local enums = Enum and Enum.TooltipDataLineType
    local changed = enums ~= excludedEnumTable
    for index, name in ipairs(excludedTypeNames) do
        local value = enums and enums[name]
        value = NS.IsSafe(value) and value or nil
        if value ~= excludedEnumValues[index] then changed = true end
    end
    if changed then
        -- Forever APIs may appear later, or fill an existing enum table.
        -- Reuse the map until its values change, and discard parses made
        -- with different exclusions even when the item itself is unchanged.
        excludedEnumTable, excludedTypes = enums, {}
        for index, name in ipairs(excludedTypeNames) do
            local value = enums and enums[name]
            value = NS.IsSafe(value) and value or nil
            excludedEnumValues[index] = value
            if value then excludedTypes[value] = true end
        end
        NS.InvalidateItemScoreCache()
    end
    return excludedTypes
end

local function contextFor(link)
    local getter = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local itemID, _, _, equipLoc, _, classID, subClassID = call(getter, link)
    if not NS.IsSafe(equipLoc) or not NS.IsSafe(classID) or not NS.IsSafe(subClassID) then return nil end
    local equippable = equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
    if not equippable then
        local isEquippable = call(C_Item and C_Item.IsEquippableItem or IsEquippableItem, link)
        equippable = NS.IsSafe(isEquippable) and isEquippable
    end
    if not equippable then return nil end
    local ranged = equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN" or equipLoc == "INVTYPE_AMMO" or classID == 6
    local locale = GetLocale and GetLocale() or "enUS"
    return {itemID=NS.GetNumber(itemID),equipLoc=equipLoc, ranged=ranged, english=locale == "enUS" or locale == "enGB", excludedTypes=currentExcludedTypes(),
        convertRating=GetCombatRatingBonusForCombatRatingValue}
end

local function watch(tooltip)
    if watched[tooltip] then return end
    watched[tooltip] = true
    -- Native ClearLines exists on data-driven tooltips and runs on every rebuild.
    -- Reset on rebuild, not only on Hide; the same item can be repopulated in place.
    if hooksecurefunc and type(tooltip.ClearLines) == "function" then
        pcall(hooksecurefunc, tooltip, "ClearLines", function() decorated[tooltip] = nil end)
    end
    if tooltip.HookScript then
        pcall(tooltip.HookScript, tooltip, "OnHide", function() decorated[tooltip] = nil end)
    end
end

-- Shared item reader for individual tooltips and equipped-item totals.
-- It does not overwrite /fgs debug's last hovered item when summing gear.
function NS.ScoreItem(link, lines, options)
    options = options or {}
    local context = contextFor(link)
    if not context then return end
    if call(C_Item and C_Item.IsItemDataCachedByID, link) == false then
        NS.RequestItemData(link)
        return
    end
    local baseLink=NS.GetUnenchantedItemLink and NS.GetUnenchantedItemLink(link) or link
    local raw = call(C_Item and C_Item.GetItemStats or GetItemStats, baseLink)
    if type(lines) ~= "table" or #lines == 0 then
        local data = call(C_TooltipInfo and C_TooltipInfo.GetHyperlink, link)
        lines = data and data.lines or {}
    end
    -- An uncached item will be handled by the game's normal tooltip refresh.
    -- Do not add a misleading zero before either source has loaded.
    if type(raw) ~= "table" and #lines == 0 then NS.RequestItemData(link); return end
    local _, _, quality, basicLevel = call(C_Item and C_Item.GetItemInfo or GetItemInfo, link)
    local detailedLevel = call(C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo, link)
    local itemLevel = NS.GetNumber(detailedLevel)
    if not itemLevel or itemLevel < 0 then itemLevel = basicLevel end
    local intrinsic=readIntrinsic(baseLink,type(raw)=="table" and raw or {},lines,context,quality,itemLevel,NS.GetItemSetID(link))
    local bonuses,score,breakdown,scoring=intrinsic.bonuses,intrinsic.score,intrinsic.breakdown,intrinsic.scoring
    local warnings={}
    for name,warning in pairs(intrinsic.warnings) do warnings[name]=warning end
    local classToken = options.classToken
    if not NS.IsSafe(classToken) or type(classToken) ~= "string" then
        classToken = NS.GetClassToken and NS.GetClassToken(options.unit or "player")
    end
    local profile = options.dynamicProfile or (NS.ResolveDynamicProfile and NS.ResolveDynamicProfile(options.unit or "player"))
    -- Explicit class must match the supplied wearer profile.
    if profile and profile.classToken ~= classToken then profile = nil end
    local dynamicAvailable = profile and profile.available == true or false
    local dynamicScore,dynamicBreakdown,dynamicScoring
    if dynamicAvailable then
        local dynamic=intrinsic.dynamic[profile]
        if not dynamic then
            local weights=profileWeights[profile]
            if not weights then
                weights=NS.GetDynamicWeights and NS.GetDynamicWeights(classToken,profile) or NS.WEIGHTS
                profileWeights[profile]=weights
            end
            local value,detail,calculation=NS.CalculateItemScore(intrinsic.stats,itemLevel,quality,bonuses.hasEffect,bonuses.hasUse,weights)
            dynamic={score=value,breakdown=detail,scoring=calculation}; intrinsic.dynamic[profile]=dynamic
        end
        dynamicScore,dynamicBreakdown,dynamicScoring=dynamic.score,dynamic.breakdown,dynamic.scoring
    end
    local enchantmentScore,enchantment=0,nil
    if NS.ReadEnchantmentScore then enchantmentScore,enchantment=NS.ReadEnchantmentScore(link,lines,context) end
    local dataPending = NS.GetNumber(quality) == nil or NS.GetNumber(itemLevel) == nil
        or (options.unit and options.unit ~= "player" and #lines == 0) or false
    if dataPending then
        NS.RequestItemData(link)
        warnings.ItemData = "Item data is still loading"
    end
    local partial = next(warnings) ~= nil or context.english == false
    local hasItemStats = scoring.hasStats
    -- An unsupported numeric stat still means this is not a plain cosmetic.
    if type(raw) == "table" then
        for _, value in pairs(raw) do
            local amount = NS.GetNumber(value)
            if amount and amount ~= 0 then hasItemStats = true; break end
        end
    end
    local result = {link=link, itemID=context.itemID, score=score, breakdown=breakdown, scoring=scoring, warnings=warnings,
        dynamicScore=dynamicScore, dynamicBreakdown=dynamicBreakdown, dynamicScoring=dynamicScoring,
        classToken=classToken, dynamicProfile=profile, dynamicAvailable=dynamicAvailable, dynamicPartial=partial,
        enchantmentScore=enchantmentScore or 0,enchantment=enchantment,
        enchantmentUnknown=enchantment and (enchantment.unknown==true or enchantment.unknownID~=nil) or false,
        raw=raw, lines=lines, partial=partial, dataPending=dataPending, english=context.english, set=bonuses.set,
        hideItemScore=(context.equipLoc == "INVTYPE_BODY" or context.equipLoc == "INVTYPE_TABARD")
            and not hasItemStats and not bonuses.hasEffect and not bonuses.hasUse}
    local pieces, active = 0, false
    if result.set and not options.deferSet then
        local setContext, incomplete
        if NS.ResolveSetContext then
            setContext, incomplete = call(NS.ResolveSetContext, options.unit or "player", NS.GetSetKey(result.set))
        else
            -- Standalone/legacy fallback when the equipped reader isn't loaded.
            pieces = result.set.equipped or 0
            active = NS.IsSetActive(result.set, pieces)
        end
        if setContext then pieces, active = setContext.count, setContext.active end
        result.setPartial = incomplete == true or (setContext and not setContext.required and not active)
            or (not NS.ResolveSetContext and not result.set.required and not active) or false
    end
    return NS.ApplySetBonus(result, pieces, active)
end

local function itemOwner(tooltip)
    local info = call(tooltip.GetPrimaryTooltipInfo, tooltip)
    if info and NS.IsSafe(info.getterName) and info.getterName == "GetInventoryItem" then
        local args = info.getterArgs
        local unit = args and NS.IsSafe(args) and args[1]
        if NS.IsSafe(unit) and type(unit) == "string" then return unit end
    end
    return "player" -- Bags, merchant items and links use your current set context.
end

local function isComparisonTooltip(tooltip)
    local info = call(tooltip.GetPrimaryTooltipInfo, tooltip)
    if not info or not NS.IsSafe(info.getterName) then return false end
    local getter = info.getterName
    if getter == "GetBagItem" or getter == "GetBagItemChild" then return true end
    if getter == "GetQuestItem" or getter == "GetQuestLogItem" then
        local args = info.getterArgs
        if not NS.IsSafe(args) or type(args) ~= "table" or not NS.IsSafe(args[1]) then return false end
        -- Both selectable and guaranteed rewards can replace equipped gear.
        -- Required quest items are objectives, not equipment candidates.
        return args[1] == "choice" or args[1] == "reward"
    end
    return false
end

local function addScore(tooltip, data)
    if not tooltip or not tooltip.AddDoubleLine then return end
    watch(tooltip)
    local showNormal, showDynamic = true, false
    if NS.GetDisplayVisibility then showNormal, showDynamic = NS.GetDisplayVisibility("items") end
    if not showNormal and not showDynamic then return end
    local mode = NS.GetDisplayMode and NS.GetDisplayMode("items") or "normal"
    local primary = call(tooltip.GetPrimaryTooltipData, tooltip)
    if primary and data and NS.IsSafe(primary.id) and NS.IsSafe(data.id) and primary.id ~= data.id then return end
    local link = displayedLink(tooltip, data or primary)
    if not link then return end
    if decorated[tooltip] and decorated[tooltip].link == link then
        if decorated[tooltip].mode ~= mode and tooltip.RefreshDataNextUpdate then tooltip:RefreshDataNextUpdate() end
        return
    end
    local lines = data and data.lines or primary and primary.lines
    if type(lines) ~= "table" then lines = frameLines(tooltip) end
    local result = NS.ScoreItem(link, lines, {unit=itemOwner(tooltip)})
    if not result then return end
    local value = string.format("%.0f", result.score) .. (result.partial and " (partial)" or "")
    local itemComparison = not result.hideItemScore and isComparisonTooltip(tooltip) and NS.GetItemScoreDifference ~= nil
    local comparisonReads = itemComparison and {} or nil
    if itemComparison and showNormal then
        local difference = call(NS.GetItemScoreDifference, result, false, comparisonReads)
        result.scoreDifference = difference
        value = value .. " " .. NS.FormatScoreDifference(difference)
    end
    if showNormal and not result.hideItemScore then
        tooltip:AddDoubleLine("Item Score", value, 1, 0.4, 0.7, 1, 0.82, 0)
    end
    if showNormal and result.set then
        local setValue = string.format("%.0f", result.setBonusScore)
            .. (result.setPartial and " (partial)" or "")
        tooltip:AddDoubleLine("Set Bonus Score", setValue, 1, 0.4, 0.7, 1, 0.82, 0)
    end
    if showDynamic and result.dynamicAvailable and not result.hideItemScore
        and (not showNormal or result.dynamicScore~=result.score) then
        local dynamicValue = string.format("%.0f", result.dynamicScore) .. (result.dynamicPartial and " (partial)" or "")
        if itemComparison and NS.GetDynamicItemScoreDifference then
            result.dynamicScoreDifference = call(NS.GetDynamicItemScoreDifference, result, comparisonReads)
            dynamicValue = dynamicValue .. " " .. NS.FormatScoreDifference(result.dynamicScoreDifference)
        end
        tooltip:AddDoubleLine("Dynamic Item Score", dynamicValue, 1, 0.4, 0.7, 1, 0.82, 0)
    end
    if showDynamic and result.dynamicAvailable and result.set
        and (not showNormal or result.dynamicSetBonusScore~=result.setBonusScore) then
        local dynamicSetValue = string.format("%.0f", result.dynamicSetBonusScore)
            .. (result.setPartial and " (partial)" or "")
        tooltip:AddDoubleLine("Dynamic Set Bonus Score", dynamicSetValue, 1, 0.4, 0.7, 1, 0.82, 0)
    end
    if result.enchantmentScore>0 or result.enchantmentUnknown then
        local enchantmentValue=result.enchantmentUnknown and "Unknown" or string.format("%.0f",result.enchantmentScore)
        tooltip:AddDoubleLine("Enchantment Score",enchantmentValue,1,0.4,0.7,1,0.82,0)
    end
    decorated[tooltip] = {link=link, mode=mode, isSet=result.set ~= nil, isComparison=itemComparison}
    NS.last = result
    -- Data-driven ProcessInfo calls Show after post-calls, so no recursive refresh.
    -- On the legacy path, Show resizes the frame to include the additional line.
    if not primary and tooltip.Show then tooltip:Show() end
end

function NS.RefreshItemTooltips()
    for tooltip in pairs(watched) do
        if call(tooltip.IsShown, tooltip) then
            if tooltip.RefreshDataNextUpdate then call(tooltip.RefreshDataNextUpdate, tooltip)
            elseif tooltip.RefreshData then call(tooltip.RefreshData, tooltip)
            elseif tooltip.SetHyperlink then
                local link = displayedLink(tooltip, call(tooltip.GetPrimaryTooltipData, tooltip))
                if link then call(tooltip.SetHyperlink, tooltip, link) end
            end
        end
    end
end

local function guardedAddScore(tooltip, data)
    local ok, err = pcall(addScore, tooltip, data)
    if not ok and not reportedError then
        reportedError = true
        message("Could not score this tooltip. Please send this error: " .. tostring(err))
    end
end

function NS.RefreshSetTooltips()
    for tooltip, record in pairs(decorated) do
        if (record.isSet or record.isComparison) and call(tooltip.IsShown, tooltip) then
            -- Rebuild scores and equipment comparisons when equipment changes.
            if tooltip.RefreshDataNextUpdate then call(tooltip.RefreshDataNextUpdate, tooltip)
            elseif tooltip.RefreshData then call(tooltip.RefreshData, tooltip) end
        end
    end
end

local function attach()
    if attached then return end
    local itemType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function"
        and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and itemType ~= nil then
        local ok = pcall(TooltipDataProcessor.AddTooltipPostCall, itemType, guardedAddScore)
        if ok then attached = true; return end
    end
    local any = false
    for _, name in ipairs({"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2"}) do
        local frame = _G[name]
        if frame and frame.HookScript then
            local ok = pcall(frame.HookScript, frame, "OnTooltipSetItem", guardedAddScore)
            any = any or ok
        end
    end
    attached = any
end

-- A small diagnostic command for beta testing, without adding tooltip clutter.
SLASH_FOSSIEGS1 = "/fgs"
SLASH_FOSSIEGS2 = "/fossiegs"
SlashCmdList.FOSSIEGS = function(input)
    if input:lower():match("^%s*debug%s*$") then
        local result = NS.last
        if not result then message("Hover a gear item first, then use /fgs debug."); return end
        if result.dynamicProfile then
            message("Dynamic profile: " .. (result.dynamicProfile.name or result.dynamicProfile.reason or "unavailable"))
        end
        message(result.link .. " = " .. string.format("%.0f", result.score))
        for _, entry in ipairs(result.breakdown) do
            message(string.format("%s: %.4g x %.4g = %.4g", entry.stat, entry.value, entry.weight, entry.points))
        end
        if result.breakdown.sharedSpellPower then
            message(string.format("Combined damage/healing: %.4g counted once under %s.",
                result.breakdown.sharedSpellPower, result.breakdown.sharedSpellStat))
        end
        local scoring = result.scoring
        if scoring.hasBase then
            message(string.format("Item level: %.4g x %.4g x effect %.4g = %.4g base points.",
                scoring.itemLevel, scoring.baseWeight, scoring.effectMultiplier, scoring.baseScore))
        else message("No scored stats or intrinsic Equip/Use/proc effect: item-level base omitted.") end
        message(string.format("(Stats %.4g + base %.4g) x %s %.4g = %.2f",
            scoring.statScore, scoring.baseScore, scoring.rarity or "Unknown", scoring.rarityMultiplier, scoring.rawScore))
        message(string.format("floor(%.4g / %.4g) = %.0f displayed points.",
            scoring.rawScore, scoring.divisor, result.score))
        if result.set then
            local calculation = result.setActive and "max(1, floor(%.0f x %.6g) - %.0f)" or "floor(%.0f x %.6g) - %.0f"
            message(string.format("Set %s: %d equipped, %s. " .. calculation .. " = %.0f Set Bonus Score; total %.0f.",
                result.set.name or tostring(result.set.id), result.setPieces, result.setActive and "active" or "inactive",
                result.score, result.setMultiplier, result.score, result.setBonusScore, result.totalScore))
        end
        if result.enchantmentScore>0 or result.enchantmentUnknown then
            message("Enchantment Score: " .. (result.enchantmentUnknown and "Unknown" or tostring(result.enchantmentScore))
                .. " (flat points, separate from item and set calculations).")
            local enchant=result.enchantment or {}
            message("Enchantment: ID " .. tostring(enchant.id or enchant.unknownID or "unavailable")
                .. " | source " .. (enchant.source or "unavailable")
                .. " | tier " .. tostring(enchant.tier or "?")
                .. (enchant.reason and " | " .. enchant.reason or ""))
        end
        if result.scoreDifference ~= nil then
            message(string.format("Item Score difference: %+.0f (intrinsic item scores; set changes excluded).", result.scoreDifference))
        end
        for _, warning in pairs(result.warnings) do message(warning) end
        if not result.english then message("English tooltip parsing is required for complete on-equip stat coverage.") end
    elseif input:lower():match("^%s*raw%s*$") then
        if not NS.last then message("Hover a gear item first, then use /fgs raw."); return end
        message("Raw stat fields for the last hovered item:")
        for key, value in pairs(NS.last.raw or {}) do
            if NS.IsSafe(value) and type(value) == "number" then message(tostring(key) .. " = " .. tostring(value)) end
        end
        message("Tooltip lines:")
        for _, line in ipairs(NS.last.lines or {}) do
            local text = NS.CleanText(line.leftText)
            if text ~= "" then message(text) end
        end
    elseif input:lower():match("^%s*talents%s*$") then
        if NS.PrintTalentInfo then NS.PrintTalentInfo() end
    elseif input:lower():match("^%s*settings%s*$") or input:lower():match("^%s*options%s*$") then
        if NS.OpenSettings then NS.OpenSettings() end
    elseif input:lower():match("^%s*minimap%s*$") then
        if NS.SetMinimapVisible then NS.SetMinimapVisible(not NS.GetMinimapVisible()) end
    elseif input:lower():match("^%s*ui%s*$") then
        if NS.PrintGearUI then NS.PrintGearUI() else message("Gear UI has not loaded.") end
    else message("v" .. NS.VERSION .. " | /fgs settings: display options; /fgs minimap: toggle icon; /fgs debug: item calculation; /fgs raw: input stats; /fgs ui: panel and player-tooltip status.") end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
for _,event in ipairs({"GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT","PLAYER_LEVEL_UP"}) do
    pcall(loader.RegisterEvent,loader,event)
end
loader:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then attach() end
    if event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then NS.InvalidateItemScoreCache(name)
    elseif event=="PLAYER_LEVEL_UP" then NS.InvalidateItemScoreCache() end
end)
attach()

-- Exposed namespace for in-game diagnosis and automated tests, not saved variables.
_G.FossieGearScore = NS
