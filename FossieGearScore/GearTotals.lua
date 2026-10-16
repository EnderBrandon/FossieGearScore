local _, NS = ...
local cache, snapshots, loaders, panels = {}, {}, {}, setmetatable({}, {__mode="k"})
local decorated, watched = setmetatable({}, {__mode="k"}), setmetatable({}, {__mode="k"})
local readyInspectGUID, unitHooked, queued = nil, false, false
local ownPanel, inspectPanel
local scheduleRefresh, updatePanels, refreshHover, recordChanged
NS.gearCache = cache -- Session cache keyed by player GUID, never character name.
NS.gearSnapshots = snapshots -- Latest inspection, including items still loading.
NS.gearPanels = panels
function NS.InvalidateInspectData() readyInspectGUID = nil; if NS.ClearTalentInspect then NS.ClearTalentInspect() end end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function guidFor(unit)
    local guid = call(UnitGUID, unit)
    if NS.IsSafe(guid) and type(guid) == "string" then return guid end
end
local function isPlayer(unit)
    local value = call(UnitIsPlayer, unit)
    return NS.IsSafe(value) and value == true
end
local function inspectUnit()
    if not InspectFrame then return nil end
    local unit = call(InspectFrame.GetInspectUnit, InspectFrame) or InspectFrame.unit
    if NS.IsSafe(unit) and type(unit) == "string" then return unit end
end

local function newRecord(guid, own, previous)
    local record = {guid=guid, score=0, dynamicScore=0, enchantmentScore=0, enchantmentUnknown=false, enchantmentScores={},
        dynamicItems={}, dynamicItemScores={}, dynamicSetBonusScores={},
        classToken=previous and previous.classToken, dynamicProfile=previous and previous.dynamicProfile, partial=false, items={}, itemScores={}, setBonusScores={},
        itemDetails={}, setItems={}, links={}, itemIDs={}, tooltipLines={}, tooltipDataIDs={}, missingSlots={}, own=own,
        dataPending=false, updated=call(GetTime) or 0,
        inspectedAt=previous and previous.inspectedAt or cache[guid] and cache[guid].inspectedAt}
    return record
end
local function trackTooltipData(record, data)
    local id=data and NS.GetNumber(data.dataInstanceID)
    if id then record.tooltipDataIDs[id]=true end
end
local function scoreSlot(record, slot, link, lines, previousLines, ownerSet)
    record.links[slot] = link -- Include unloaded items; retain the full instance link.
    if type(lines) ~= "table" or #lines == 0 then
        local data = call(C_TooltipInfo and C_TooltipInfo.GetHyperlink, link)
        trackTooltipData(record,data)
        lines = data and data.lines or {}
    end
    if type(previousLines) == "table" and #previousLines > #lines then lines = previousLines end
    record.tooltipLines[slot] = lines
    local result = call(NS.ScoreItem, link, lines, {unit=record.unit or "snapshot", slot=slot, deferSet=true, classToken=record.classToken, dynamicProfile=record.dynamicProfile})
    local itemID = result and result.itemID or tonumber(link:match("item:(%d+)"))
    if not itemID then itemID = NS.GetNumber(call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant, link)) end
    if itemID then record.itemIDs[itemID] = true end
    if ownerSet then
        -- Hyperlink tooltips use the local player's worn-set header. Keep the
        -- inspected owner's captured activation data when rescoring offline.
        local captured = {}
        for key, value in pairs(ownerSet) do captured[key] = value end
        captured.id = captured.id or (result and result.set and result.set.id) or NS.GetItemSetID(link)
        captured.key = NS.GetSetKey(captured)
        if result then result.set = captured end
        record.setItems[slot] = {set=captured}
    end
    if result then
        record.itemDetails[slot], record.setItems[slot] = result, result
        record.tooltipLines[slot] = result.lines
        record.partial = record.partial or result.partial
        record.dataPending = record.dataPending or result.dataPending
    else
        record.partial, record.dataPending = true, true
        if NS.RequestItemData then NS.RequestItemData(link) end
        if not ownerSet then
            local metadata = NS.ReadItemBonuses(lines, NS.GetItemSetID(link))
            if metadata.set then record.setItems[slot] = {set=metadata.set} end
        end
    end
end
local function publish(record)
    record.dynamicAvailable = record.dynamicProfile and record.dynamicProfile.available == true or false
    if not record.dynamicAvailable then record.dynamicScore = nil end
    record.sets = NS.BuildSetGroups(record.setItems)
    for slot, result in pairs(record.itemDetails) do
        local key = NS.GetSetKey(result.set)
        local group = key and record.sets[key]
        NS.ApplySetBonus(result, group and group.count or 0, group and group.active or false)
        if group and not group.required and not group.active then record.partial = true end
        record.score = record.score + result.totalScore
        local enchantment=NS.GetNumber(result.enchantmentScore) or 0
        record.enchantmentScore=record.enchantmentScore+enchantment
        record.enchantmentScores[slot]=enchantment
        record.enchantmentUnknown=record.enchantmentUnknown or result.enchantmentUnknown==true
        if record.dynamicAvailable and result.dynamicTotalScore ~= nil then
            record.dynamicScore = record.dynamicScore + result.dynamicTotalScore
            record.dynamicItems[slot] = result.dynamicTotalScore
            record.dynamicItemScores[slot] = result.dynamicScore
            record.dynamicSetBonusScores[slot] = result.dynamicSetBonusScore
        end
        record.items[slot] = result.totalScore
        record.itemScores[slot], record.setBonusScores[slot] = result.score, result.setBonusScore
    end
    if not record.own then snapshots[record.guid] = record end
    local old = cache[record.guid]
    -- Keep a complete cache intact while a new inspection's items load.
    if record.own or not record.partial or not old or old.partial then cache[record.guid] = record end
    if not record.partial and NS.BackgroundInspectComplete then NS.BackgroundInspectComplete(record.guid) end
    return record
end
function NS.SumEquippedItems(unit, previous)
    local guid = guidFor(unit)
    if not guid or not isPlayer(unit) then return nil end
    local record = newRecord(guid, guid == guidFor("player"), previous)
    record.unit = unit
    record.classToken = NS.GetClassToken and NS.GetClassToken(unit) or record.classToken
    record.dynamicProfile = NS.ResolveDynamicProfile and NS.ResolveDynamicProfile(unit)
    if record.dynamicProfile and record.dynamicProfile.classToken ~= record.classToken then record.dynamicProfile=nil end
    -- Standard equipped slots, including shirt/tabard and all three weapon slots.
    -- Bags and carried inventory are deliberately outside the equipment total.
    for slot=1,19 do
        local link = call(GetInventoryItemLink, unit, slot)
        -- Within one ready inspection, saved links remain valid if the client
        -- temporarily loses an inventory lookup. A new ready event starts fresh.
        if not record.own and previous and (not NS.IsSafe(link) or not link) then link = previous.links[slot] end
        if NS.IsSafe(link) and type(link) == "string" then
            local data = call(C_TooltipInfo and C_TooltipInfo.GetInventoryItem, unit, slot)
            trackTooltipData(record,data)
            local previousLines = previous and previous.links[slot] == link and previous.tooltipLines[slot]
            scoreSlot(record, slot, link, data and data.lines, previousLines)
        else
            local texture = call(GetInventoryItemTexture, unit, slot)
            if not NS.IsSafe(link) or not NS.IsSafe(texture) or texture
                or previous and previous.missingSlots[slot] then
                record.partial, record.dataPending, record.missingSlots[slot] = true, true, true
            end
        end
    end
    -- A unit token may have changed while inspection data was being read.
    if guidFor(unit) ~= guid then return nil end
    return publish(record)
end

function NS.RescoreGearSnapshot(previous)
    local record = newRecord(previous.guid, false, previous)
    local actual=NS.talentProfiles and NS.talentProfiles[previous.guid]
    if actual then record.dynamicProfile=NS.ApplyTalentOverride and NS.ApplyTalentOverride(actual) or actual end
    for slot, link in pairs(previous.links) do
        local oldItem = previous.setItems[slot]
        local ownerSet = oldItem and oldItem.set
        if ownerSet and not ownerSet.equipped and not ownerSet.required and not ownerSet.hasActiveBonus then ownerSet = nil end
        scoreSlot(record, slot, link, nil, previous.tooltipLines[slot], ownerSet)
    end
    for slot in pairs(previous.missingSlots) do
        record.partial, record.dataPending, record.missingSlots[slot] = true, true, true
    end
    return publish(record)
end
function NS.RefreshDynamicGearScore(guid)
    local previous=snapshots[guid] or cache[guid]
    if previous and not previous.own then return NS.RescoreGearSnapshot(previous) end
end
local function readyUnit(guid)
    if guid ~= readyInspectGUID then return end
    local record = snapshots[guid]
    for _, unit in ipairs({inspectUnit() or "", record and record.unit or "", call(UnitTokenFromGUID, guid) or ""}) do
        if guidFor(unit) == guid and isPlayer(unit) then return unit end
    end
end
local function rescoreSnapshot(guid)
    local previous = snapshots[guid]
    if not previous then return end
    local unit = readyUnit(guid)
    local record = unit and NS.SumEquippedItems(unit, previous) or NS.RescoreGearSnapshot(previous)
    if record and not record.dataPending then loaders[guid] = nil end
    return record
end
function NS.IsGearDataLoading(guid)
    local loader = loaders[guid]
    return loader ~= nil and (call(GetTime) or 0) < loader.deadline
end
local function startLoading(record)
    loaders[record.guid] = nil
    if record.own then return end
    if not record.dataPending then
        if record.partial and NS.BackgroundInspectIncomplete then NS.BackgroundInspectIncomplete(record.guid) end
        return
    end
    if not C_Timer or not C_Timer.After then return end
    local guid, loader = record.guid, {deadline=(call(GetTime) or 0) + 10}
    loaders[guid] = loader
    local function poll()
        if loaders[guid] ~= loader then return end
        local previous=snapshots[guid]
        local current = rescoreSnapshot(guid)
        if not current or not current.dataPending then
            loaders[guid] = nil
            if current and current.partial and NS.BackgroundInspectIncomplete then NS.BackgroundInspectIncomplete(guid) end
        elseif (call(GetTime) or 0) >= loader.deadline then
            loaders[guid] = nil
            if NS.BackgroundInspectIncomplete then NS.BackgroundInspectIncomplete(guid) end
        else C_Timer.After(0.5, poll) end
        if not loaders[guid] or recordChanged(previous,current) then
            updatePanels(); refreshHover()
            if NS.RefreshSetTooltips then NS.RefreshSetTooltips() end
        end
    end
    C_Timer.After(0.5, poll)
end

function NS.ResolveSetContext(unit, key)
    local guid = guidFor(unit)
    if not guid or not key or not isPlayer(unit) then return nil, true end
    -- Equipment/inspection events maintain this record. Reading a set bonus
    -- while drawing a shopping tooltip must not scan the whole inventory.
    local record = snapshots[guid] or cache[guid]
    if not record and (guid == guidFor("player") or guid == readyInspectGUID) then
        record = NS.SumEquippedItems(unit)
    end
    return record and record.sets[key], not record or record.partial
end

function NS.GetGearScore(unit)
    if not isPlayer(unit) then return nil end
    local guid = guidFor(unit)
    if not guid then return nil end
    local own = guid == guidFor("player")
    return (not own and snapshots[guid]) or cache[guid] or (own and NS.SumEquippedItems("player")), not own
end

local function textFor(record, cached, dynamic)
    if not record then return "..." end
    local suffix = record.partial and (cached and " (cached, partial)" or " (partial)")
        or (cached and " (cached)" or "")
    local value=string.format("%.0f", dynamic and record.dynamicScore or record.score)
    if record.enchantmentScore and record.enchantmentScore>0 then
        value=value .. " + " .. string.format("%.0f",record.enchantmentScore)
    end
    if record.enchantmentUnknown then value=value .. " + ?" end
    return value .. suffix
end
local function positionPanel(panel)
    -- OVERLAY orders regions within one frame. Forever's model background is
    -- on a child at level 50, above the old parent FontString.
    local level = 0
    for _, owner in ipairs({panel.root, panel.frame}) do
        level = math.max(level, call(owner.GetFrameLevel, owner) or 0)
        if owner.GetChildren then
            for _, child in ipairs({owner:GetChildren()}) do
                if child ~= panel.overlay and not child.FossieGSTalentOverride then
                    level = math.max(level, call(child.GetFrameLevel, child) or 0)
                end
            end
        end
    end
    panel.overlay:SetFrameLevel(level + 20)
    local strata = call(panel.frame.GetFrameStrata, panel.frame)
    if strata then panel.overlay:SetFrameStrata(strata) end
    local control=NS.talentOverrideControls and NS.talentOverrideControls[panel.frame]
    if control then
        panel.overlay:ClearAllPoints()
        panel.overlay:SetPoint("BOTTOM",control.host,"TOP",0,6)
    elseif NS.PositionGearAboveWeapons then
        NS.PositionGearAboveWeapons(panel.overlay,panel.frame,panel.root,panel.own,36)
    end
end
local function inspectedSpec(record)
    local actual = record and NS.talentProfiles and NS.talentProfiles[record.guid]
    if not actual or actual.guid ~= record.guid or actual.classToken ~= record.classToken then
        return "Spec: Unknown"
    end
    if actual.reason == "no-talents" or actual.reason == "below-level-10" then return "Spec: None" end
    if not actual.available then return "Spec: Unknown" end
    local names, specs = {}, NS.DYNAMIC_SPECS[actual.classToken] or {}
    for _, index in ipairs(actual.trees or {}) do
        local name = actual.treeNames and actual.treeNames[index]
        if not NS.IsSafe(name) or type(name) ~= "string" or name == "" then
            name = specs[index] and specs[index].name
        end
        if name then names[#names+1] = name end
    end
    if #names == 0 then return "Spec: Unknown" end
    return "Spec: " .. (actual.hybrid and "Hybrid: " or "") .. table.concat(names, " / ")
end
local function setPanel(panel, record, cached)
    if not panel then return end
    positionPanel(panel)
    local normal, dynamic = true, false
    if NS.GetDisplayVisibility then normal, dynamic = NS.GetDisplayVisibility("character") end
    local rows = {}
    if normal then rows[#rows+1] = "GS: " .. textFor(record, cached) end
    if dynamic and record and record.dynamicAvailable and (not normal or record.dynamicScore~=record.score) then
        rows[#rows+1] = "DGS: " .. textFor(record, cached, true)
    end
    panel.label:SetText(table.concat(rows, "\n"))
    if #rows == 0 then
        if panel.specLabel then panel.specLabel:SetText("") end
        panel.overlay:Hide()
        return
    end
    -- Measure at the maximum width first, then fit the backing to the text.
    panel.label:SetWidth(220)
    local width = call(panel.label.GetStringWidth, panel.label) or 180
    if panel.specLabel then
        panel.specLabel:SetWidth(220)
        panel.specLabel:SetText(inspectedSpec(record))
        width = math.max(width, call(panel.specLabel.GetStringWidth, panel.specLabel) or 180)
    end
    width = math.ceil(math.min(220, math.max(96, width)))
    panel.label:SetWidth(width)
    local height = math.max(#rows * 18, call(panel.label.GetStringHeight, panel.label) or 0)
    panel.label:SetHeight(height)
    if panel.specLabel then
        panel.specLabel:SetWidth(width)
        local specHeight = call(panel.specLabel.GetStringHeight, panel.specLabel) or 18
        panel.specLabel:SetHeight(specHeight)
        height = height + specHeight + 3
    end
    panel.overlay:SetSize(width + 16, height + 10)
    panel.overlay:Show()
end
updatePanels = function()
    local own = cache[guidFor("player") or ""]
    setPanel(ownPanel, own, false)
    local unit = inspectUnit()
    local guid = unit and guidFor(unit)
    setPanel(inspectPanel, guid and (snapshots[guid] or cache[guid]), guid ~= readyInspectGUID)
    if NS.RefreshTalentOverrideControl then NS.RefreshTalentOverrideControl() end
end

local function displayedUnit(tooltip, data)
    -- Native return order is name, unit token, GUID (not name, GUID, unit).
    local _, unit, helperGUID = call(TooltipUtil and TooltipUtil.GetDisplayedUnit, tooltip)
    local guid = data and data.guid or helperGUID
    if not NS.IsSafe(guid) then return end
    local function matches(candidate)
        if not NS.IsSafe(candidate) or type(candidate) ~= "string" then return false end
        local candidateGUID = guidFor(candidate)
        return candidateGUID and (type(guid) ~= "string" or candidateGUID == guid)
    end
    if matches(unit) then return unit end
    if NS.IsSafe(guid) and type(guid) == "string" then
        unit = call(UnitTokenFromGUID, guid)
        if matches(unit) then return unit end
    end
    -- Older tooltip implementations return name, unit from GetUnit.
    local _, legacyUnit = call(tooltip.GetUnit, tooltip)
    if matches(legacyUnit) then return legacyUnit end
    -- Some skins lack the helper. Only accept a token matching the tooltip's
    -- GUID, so another player cannot inherit a cached score.
    if type(guid) == "string" then
        for _, candidate in ipairs({"mouseover", "target", "player", "focus"}) do
            if matches(candidate) then return candidate end
        end
    end
end
local function addUnitScore(tooltip, data, resize)
    if not tooltip or not tooltip.AddDoubleLine then return end
    local primary = call(tooltip.GetPrimaryTooltipData, tooltip)
    if primary and data and primary ~= data and NS.IsSafe(primary.guid) and NS.IsSafe(data.guid)
        and primary.guid ~= data.guid then return end
    local unit = displayedUnit(tooltip, data or primary)
    if not unit or not isPlayer(unit) then return end
    local guid = guidFor(unit)
    if not guid then return end
    if not watched[tooltip] then
        watched[tooltip] = true
        if hooksecurefunc and type(tooltip.ClearLines) == "function" then
            pcall(hooksecurefunc, tooltip, "ClearLines", function() decorated[tooltip] = nil end)
        end
        if tooltip.HookScript then pcall(tooltip.HookScript, tooltip, "OnHide", function() decorated[tooltip] = nil end) end
    end
    local normal, dynamic = true, false
    if NS.GetDisplayVisibility then normal, dynamic = NS.GetDisplayVisibility("hover") end
    if not normal and not dynamic then return end
    local mode = NS.GetDisplayMode and NS.GetDisplayMode("hover") or "normal"
    if NS.RequestBackgroundInspect then
        NS.RequestBackgroundInspect(unit, function()
            local n, d = true, false
            if NS.GetDisplayVisibility then n, d = NS.GetDisplayVisibility("hover") end
            return (n or d) and call(tooltip.IsShown, tooltip) == true
                and guidFor(displayedUnit(tooltip, call(tooltip.GetPrimaryTooltipData, tooltip))) == guid
        end)
    end
    local record, cached = NS.GetGearScore(unit)
    local failed = NS.BackgroundInspectFailed and NS.BackgroundInspectFailed(unit)
    local complete = record and not failed and (not cached or not record.partial)
    local dynamicVisible = dynamic and record and record.dynamicAvailable == true
        and (not normal or record.dynamicScore~=record.score) or false
    local actual=NS.talentProfiles and NS.talentProfiles[guid]
    local level=NS.GetNumber(call(UnitLevel,unit))
    local talentText="Inspect to see talents"
    if level and level>=0 and level<NS.TALENT_RULES.minLevel then talentText="0/0/0"
    elseif actual and (actual.available or actual.reason=="no-talents")
        and actual.guid==guid and actual.classToken==NS.GetClassToken(unit) then
        local points=actual.points
        local a,b,c=points and NS.GetNumber(points[1]),points and NS.GetNumber(points[2]),points and NS.GetNumber(points[3])
        if a and b and c then talentText=string.format("%.0f/%.0f/%.0f",a,b,c) end
    end
    local shape=tostring(normal) .. "/" .. tostring(dynamicVisible)
    local old = decorated[tooltip]
    if old and old.guid~=guid then
        -- A skin can replace native unit data before clearing our old rows.
        -- Hide the previous player's values while the native rebuild runs.
        for key,previous in pairs(old.rows) do
            if previous.right then previous.right:SetText(key=="talents" and "Inspect to see talents" or "Inspect to see GS") end
        end
        if tooltip.RefreshDataNextUpdate then tooltip:RefreshDataNextUpdate() end
        return
    end
    if old and old.guid == guid and (old.mode ~= mode or old.shape~=shape) then
        if tooltip.RefreshDataNextUpdate then tooltip:RefreshDataNextUpdate() end
        return
    end
    if not old or old.guid ~= guid then
        old = {guid=guid, mode=mode, rows={}}
        decorated[tooltip] = old
    end
    old.dynamicVisible,old.shape = dynamicVisible,shape
    local function row(key, label, value)
        local previous = old.rows[key]
        if previous then
            if previous.value ~= value and previous.right then previous.right:SetText(value) end
            previous.value = value
        else
            tooltip:AddDoubleLine(label, value, 1, 0.4, 0.7, 1, 0.82, 0)
            local name, lines = call(tooltip.GetName, tooltip), call(tooltip.NumLines, tooltip)
            old.rows[key] = {value=value, right=name and lines and _G[name .. "TextRight" .. lines]}
        end
    end
    if normal then row("normal", "GS:", complete and textFor(record, cached) or "Inspect to see GS") end
    if dynamicVisible then row("dynamic", "DGS:", complete and textFor(record, cached, true) or "Inspect to see GS") end
    row("talents","Talents:",talentText)
    if (resize or not primary) and tooltip.Show then tooltip:Show() end
end
local function guardedUnitScore(...)
    local ok, err = pcall(addUnitScore, ...)
    if not ok and not NS.gearUIError then
        NS.gearUIError = tostring(err)
        if NS.Message then NS.Message("Player tooltip error: " .. NS.gearUIError) end
    end
end
refreshHover = function(resize)
    if not GameTooltip or not call(GameTooltip.IsShown, GameTooltip) then return end
    local data = call(GameTooltip.GetPrimaryTooltipData, GameTooltip)
    local unitType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
    if data and NS.IsSafe(data.type) and data.type == unitType then
        guardedUnitScore(GameTooltip, data, resize ~= false)
    elseif not data and GameTooltip.GetUnit then
        guardedUnitScore(GameTooltip, nil, resize ~= false)
    end
end
NS.RefreshGearHover = refreshHover

function NS.RefreshGearDisplay()
    updatePanels()
    for tooltip in pairs(watched) do
        if call(tooltip.IsShown, tooltip) then
            if tooltip.RefreshDataNextUpdate then tooltip:RefreshDataNextUpdate()
            elseif tooltip.RefreshData then tooltip:RefreshData()
            elseif tooltip.SetUnit then
                local unit = displayedUnit(tooltip, call(tooltip.GetPrimaryTooltipData, tooltip))
                if unit then tooltip:SetUnit(unit) end
            end
        end
    end
end


local function attachPanel(frame, root, own)
    if not frame or panels[frame] or not frame.HookScript then return end
    local previous = own and ownPanel or inspectPanel
    if previous then previous.overlay:Hide() end
    local overlay = CreateFrame("Frame", nil, frame)
    overlay.FossieGSOverlay=true
    overlay:SetSize(260, 18)
    overlay:EnableMouse(false)
    local background = overlay:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(overlay)
    background:SetColorTexture(0, 0, 0, 0.85)
    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", overlay, "TOP", 0, -5)
    label:SetJustifyH("CENTER")
    label:SetTextColor(1, 0.82, 0)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    label:SetText("GS: ...")
    local panel = {frame=frame, root=root or frame, overlay=overlay, label=label, background=background, own=own}
    if not own then
        local specLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        specLabel:SetPoint("TOP", label, "BOTTOM", 0, -3)
        specLabel:SetJustifyH("CENTER")
        specLabel:SetTextColor(1, 1, 1)
        specLabel:SetShadowColor(0, 0, 0, 1)
        specLabel:SetShadowOffset(1, -1)
        panel.specLabel = specLabel
    end
    panels[frame] = panel
    if own then ownPanel = panel else inspectPanel = panel end
    if NS.AttachTalentOverrideControl then NS.AttachTalentOverrideControl(frame,root,own) end
    local function onShow()
        if (own and ownPanel or inspectPanel) ~= panel then return end
        if own then NS.SumEquippedItems("player") end
        updatePanels()
    end
    frame:HookScript("OnShow", onShow)
    if root and root ~= frame then root:HookScript("OnShow", onShow) end
    positionPanel(panel)
end
local function attach()
    attachPanel(PaperDollFrame or CharacterFrame, CharacterFrame, true)
    attachPanel(InspectPaperDollFrame or InspectFrame, InspectFrame, false)
    if InspectFrame and not InspectFrame.FossieGSCacheHooked and InspectFrame.HookScript then
        InspectFrame.FossieGSCacheHooked = true
        InspectFrame:HookScript("OnHide", function()
            readyInspectGUID = nil
            if NS.ClearTalentInspect then NS.ClearTalentInspect() end
            if scheduleRefresh then scheduleRefresh() end
        end)
    end
    if not unitHooked then
        local unitType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
        if TooltipDataProcessor and unitType ~= nil then
            unitHooked = pcall(TooltipDataProcessor.AddTooltipPostCall, unitType, guardedUnitScore)
        elseif GameTooltip and GameTooltip.HookScript then
            unitHooked = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", guardedUnitScore)
        end
    end
    if GameTooltip and not GameTooltip.FossieGSShowHooked and GameTooltip.HookScript then
        GameTooltip.FossieGSShowHooked = true
        GameTooltip:HookScript("OnShow", function() refreshHover(false) end)
    end
end
local function refresh()
    NS.SumEquippedItems("player")
    local unit = inspectUnit()
    if not unit or guidFor(unit) ~= readyInspectGUID then
        unit = readyInspectGUID and call(UnitTokenFromGUID, readyInspectGUID)
    end
    local refreshedGUID
    if unit and guidFor(unit) == readyInspectGUID then
        local record = NS.SumEquippedItems(unit, snapshots[readyInspectGUID])
        refreshedGUID = record and record.guid
    end
    -- Item loads can finish after another inspection has taken the client data.
    -- A successful active read already retried its items, even if still pending.
    -- Failed reads retain the saved-snapshot fallback below.
    for guid, record in pairs(snapshots) do
        if record.dataPending and guid ~= refreshedGUID then rescoreSnapshot(guid) end
    end
    updatePanels()
    refreshHover()
    if NS.RefreshSetTooltips then NS.RefreshSetTooltips() end
end
scheduleRefresh = function()
    if queued then return end
    queued = true
    local function run() queued = false; refresh() end
    if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
end

local function sameValues(a,b)
    for key,value in pairs(a) do if b[key]~=value then return false end end
    for key,value in pairs(b) do if a[key]~=value then return false end end
    return true
end
recordChanged = function(old,new)
    if not old or not new then return old~=new end
    for _,key in ipairs({"score","dynamicScore","dynamicAvailable","enchantmentScore","enchantmentUnknown","partial","dataPending"}) do
        if old[key]~=new[key] then return true end
    end
    for _,key in ipairs({"links","items","itemScores","setBonusScores","enchantmentScores","dynamicItems","dynamicItemScores","dynamicSetBonusScores"}) do
        if not sameValues(old[key],new[key]) then return true end
    end
    for key,set in pairs(old.sets) do
        local other=new.sets[key]
        if not other or set.count~=other.count or set.active~=other.active or set.required~=other.required then return true end
    end
    for key in pairs(new.sets) do if not old.sets[key] then return true end end
    return false
end
local function refreshRecords(affected)
    local changed=false
    for guid in pairs(affected) do
        local old=snapshots[guid] or cache[guid]
        local current
        if old and old.own then current=NS.SumEquippedItems("player")
        else current=rescoreSnapshot(guid) end
        changed=recordChanged(old,current) or changed
    end
    -- Unchanged data must not restart visible tooltip rebuilds.
    if changed then
        updatePanels(); refreshHover()
        if NS.RefreshSetTooltips then NS.RefreshSetTooltips() end
    end
end
local dataQueued,dataGUIDs=false,{}
local function scheduleTooltipDataRefresh(dataInstanceID)
    local id=NS.GetNumber(dataInstanceID)
    local function consider(record)
        -- Tooltip IDs are distinct from item IDs; comparisons often update
        -- without changing any equipped item.
        if record and (record.dataPending and (record.own or record.guid==readyInspectGUID)
            or id and record.tooltipDataIDs[id]) then dataGUIDs[record.guid]=true end
    end
    consider(cache[guidFor("player") or ""])
    for _,record in pairs(snapshots) do consider(record) end
    if dataQueued or not next(dataGUIDs) then return end
    dataQueued=true
    local function run()
        local affected=dataGUIDs
        dataQueued,dataGUIDs=false,{}
        refreshRecords(affected)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.25,run) else run() end
end
local itemsQueued,itemGUIDs=false,{}
local function scheduleItemDataRefresh(itemID)
    local id=NS.GetNumber(itemID)
    if not id then scheduleRefresh(); return end
    local function consider(record)
        -- Unrelated merchant/bag loads do not require equipment scans. Keep
        -- the active missing-link fallback until its item ID becomes known.
        if record and (record.itemIDs[id] or record.dataPending and next(record.missingSlots)
            and (record.own or record.guid==readyInspectGUID)) then itemGUIDs[record.guid]=true end
    end
    consider(cache[guidFor("player") or ""])
    for _,record in pairs(snapshots) do consider(record) end
    if itemsQueued or not next(itemGUIDs) then return end
    itemsQueued=true
    local function run()
        local affected=itemGUIDs
        itemsQueued,itemGUIDs=false,{}
        refreshRecords(affected)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,run) else run() end
end

function NS.PrintGearUI()
    if not NS.Message then return end
    NS.Message("v" .. NS.VERSION .. " | final divisor " .. tostring(NS.SCORE_DIVISOR)
        .. " | player-tooltip callback " .. (unitHooked and "attached" or "missing"))
    for _, entry in ipairs({{name="Character", panel=ownPanel}, {name="Inspect", panel=inspectPanel}}) do
        local panel = entry.panel
        if panel then
            NS.Message(entry.name .. ": " .. (call(panel.frame.GetName, panel.frame) or "unnamed")
                .. " | overlay " .. (call(panel.overlay.IsVisible, panel.overlay) and "visible" or "hidden")
                .. " at level " .. tostring(call(panel.overlay.GetFrameLevel, panel.overlay))
                .. " | " .. (call(panel.label.GetText, panel.label) or "no label"))
        else NS.Message(entry.name .. ": frame not loaded") end
    end
    local data = GameTooltip and call(GameTooltip.GetPrimaryTooltipData, GameTooltip)
    local unit = GameTooltip and displayedUnit(GameTooltip, data)
    local record, cached = NS.GetGearScore(unit)
    NS.Message("Hover: " .. (unit or "no player unit") .. " | GS " .. textFor(record, cached))
    if NS.gearUIError then NS.Message("Last UI error: " .. NS.gearUIError) end
end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "INSPECT_READY", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "TOOLTIP_DATA_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED", "TRAIT_CONFIG_CREATED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then attach(); scheduleRefresh()
    elseif event == "INSPECT_READY" then
        if not NS.IsSafe(arg) or type(arg) ~= "string" then return end
        local backgroundUnit = NS.BackgroundInspectReady and NS.BackgroundInspectReady(arg)
        local candidates = {inspectUnit() or "", backgroundUnit or "", call(UnitTokenFromGUID, arg) or "", "target", "mouseover", "focus"}
        for _, unit in ipairs(candidates) do
            if guidFor(unit) == arg and isPlayer(unit) then
                readyInspectGUID = arg
                if NS.CaptureTalentProfile then NS.CaptureTalentProfile(unit, true) end
                local record = NS.SumEquippedItems(unit)
                if record then
                    record.inspectedAt = call(GetTime) or 0
                    startLoading(record)
                end
                break
            end
        end
        updatePanels(); refreshHover()
        if NS.RefreshSetTooltips then NS.RefreshSetTooltips() end
    elseif event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED"
        or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_LEVEL_UP"
        or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" or event == "TRAIT_CONFIG_CREATED" then
        local inspectConfig=Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or -1
        if event=="TRAIT_CONFIG_UPDATED" and arg==inspectConfig and NS.RefreshReadyTalentProfile then
            local unit=readyInspectGUID and readyUnit(readyInspectGUID)
            if unit then NS.RefreshReadyTalentProfile(unit) end
        elseif NS.InvalidateTalentProfile then
            NS.InvalidateTalentProfile("player")
        end
        scheduleRefresh()
        if NS.RefreshItemTooltips then NS.RefreshItemTooltips() end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then scheduleRefresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then scheduleItemDataRefresh(arg)
    elseif event == "TOOLTIP_DATA_UPDATE" then scheduleTooltipDataRefresh(arg)
    elseif event == "PLAYER_REGEN_ENABLED" then refreshHover()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg == "player" then scheduleRefresh() end
    end
end)
attach()
