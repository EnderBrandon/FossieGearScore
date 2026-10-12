local _, NS = ...
local controls=setmetatable({}, {__mode="k"})
local ownControl,inspectControl
local remoteOverrides={} -- Preview choices for other GUIDs last for this session.
local effectiveProfiles=setmetatable({}, {__mode="k"})
NS.talentOverrideControls=controls
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok then return a,b end
end
local function safeGUID(unit)
    local id=call(UnitGUID,unit)
    if NS.IsSafe(id) and type(id)=="string" then return id end
end
local function context(owner)
    owner=owner or "player"
    if not NS.IsSafe(owner) or type(owner)~="string" then return end
    local id=safeGUID(owner)
    -- GUID arguments allow cached previews after a unit token disappears.
    if not id and ((NS.talentProfiles and NS.talentProfiles[owner]) or (NS.gearCache and NS.gearCache[owner])) then id=owner end
    if not id then return end
    local actual=NS.talentProfiles and NS.talentProfiles[id]
    local class=NS.GetClassToken(owner) or actual and actual.classToken
    return id,class,actual
end
local function overrideFor(id,class)
    local own=id==safeGUID("player")
    local db=own and type(FossieGearScoreDB)=="table" and FossieGearScoreDB.talentOverrides
    local saved=own and type(db)=="table" and db[id] or not own and remoteOverrides[id]
    local index=type(saved)=="table" and NS.GetNumber(saved.tree)
    if index and index>=1 and index<=3 and index==math.floor(index) and saved.classToken==class then return index end
    return 0
end
function NS.GetTalentOverride(owner)
    local id,class=context(owner)
    return id and overrideFor(id,class) or 0
end
function NS.GetTalentOverrideChoices(owner)
    local _,class,actual=context(owner)
    local specs=NS.DYNAMIC_SPECS[class]
    local choices={{value=0,label="Default"}}
    for i,spec in ipairs(specs or {}) do
        local name=actual and actual.treeNames and actual.treeNames[i]
        if not NS.IsSafe(name) or type(name)~="string" or name=="" then name=spec.name end
        choices[#choices+1]={value=i,label=name}
    end
    return choices
end
function NS.ApplyTalentOverride(actual)
    if not actual then return end
    local index=actual.guid and overrideFor(actual.guid,actual.classToken) or 0
    -- A preview does not grant talents or bypass confirmed zero-spent profiles.
    if index==0 or not actual.available then return actual end
    local cached=effectiveProfiles[actual]
    if cached and cached.index==index then return cached.profile end
    local points={0,0,0}; points[index]=NS.TALENT_RULES.capstonePoints
    local effective=NS.ClassifyTalents(actual.classToken,points,actual.level,actual.race)
    effective.guid,effective.points=actual.guid,actual.points
    effective.treeNames,effective.api=actual.treeNames,actual.api
    effective.overridden,effective.overrideTree=true,index
    effective.detectedName=actual.name
    effective.name=effective.name .. " (override)"
    effectiveProfiles[actual]={index=index,profile=effective}
    return effective
end
function NS.SetTalentOverride(index,owner)
    index=NS.GetNumber(index)
    local id,class=context(owner)
    if not id or not NS.DYNAMIC_SPECS[class] or not index or index<0 or index>3 or index~=math.floor(index) then return false end
    local saved=index>0 and {classToken=class,tree=index} or nil
    if id==safeGUID("player") then
        if type(FossieGearScoreDB)~="table" then FossieGearScoreDB={} end
        if type(FossieGearScoreDB.talentOverrides)~="table" then FossieGearScoreDB.talentOverrides={} end
        FossieGearScoreDB.talentOverrides[id]=saved
        if NS.SumEquippedItems then NS.SumEquippedItems("player") end
    else
        remoteOverrides[id]=saved
        if NS.RefreshDynamicGearScore then NS.RefreshDynamicGearScore(id) end
    end
    if NS.RefreshItemTooltips then NS.RefreshItemTooltips() end
    if NS.RefreshGearDisplay then NS.RefreshGearDisplay()
    elseif NS.RefreshTalentOverrideControl then NS.RefreshTalentOverrideControl() end
    if NS.RefreshGearHover then NS.RefreshGearHover() end
    return true
end
local function controlUnit(control)
    if control.own then return "player" end
    local unit=call(control.root.GetInspectUnit,control.root) or control.root.unit
    if NS.IsSafe(unit) and type(unit)=="string" and safeGUID(unit) then return unit end
end
function NS.PositionGearAboveWeapons(region,parent,root,own,gap)
    -- The off-hand button is the center of Forever's three bottom weapon
    -- slots. Follow the actual slot if a skin moves the equipment pane.
    local slots=parent.WeaponSlots or root and root.WeaponSlots
    local slot=own and CharacterSecondaryHandSlot or not own and InspectSecondaryHandSlot
    slot=slot or slots and slots[2]
    region:ClearAllPoints()
    if slot then region:SetPoint("BOTTOM",slot,"TOP",0,gap or 8)
    else
        local pane=root and root.LeftPaneHost or own and CharacterFrameLeftPaneHost or parent
        region:SetPoint("BOTTOM",pane or parent,"BOTTOM",0,64+(gap or 8))
    end
end
local function position(control)
    local level=call(control.parent.GetFrameLevel,control.parent) or 0
    if control.parent.GetChildren then
        for _,child in ipairs({control.parent:GetChildren()}) do
            if child~=control.host and not child.FossieGSOverlay then level=math.max(level,call(child.GetFrameLevel,child) or 0) end
        end
    end
    control.host:SetFrameLevel(level+20)
    local strata=call(control.parent.GetFrameStrata,control.parent)
    if strata then control.host:SetFrameStrata(strata) end
    NS.PositionGearAboveWeapons(control.host,control.parent,control.root,control.own)
end
local function refreshControl(control)
    if not control then return end
    position(control)
    local unit=controlUnit(control)
    local enabled=unit~=nil
    if control.button.SetEnabled then control.button:SetEnabled(enabled) end
    local id=unit and safeGUID(unit)
    local choices=unit and NS.GetTalentOverrideChoices(unit) or {{value=0,label="Default"}}
    local state={id or "",unit and NS.GetTalentOverride(unit) or 0}
    for _,choice in ipairs(choices) do state[#state+1]=choice.label end
    state=table.concat(state,"\31")
    -- Equipment and tooltip updates do not change the role menu. Regenerate
    -- only for a different player, selected tree, or talent tree labels.
    if state~=control.menuState then
        control.menuState=state
        control.button:GenerateMenu()
    end
end
function NS.RefreshTalentOverrideControl()
    refreshControl(ownControl); refreshControl(inspectControl)
end
function NS.AttachTalentOverrideControl(parent,root,own)
    if controls[parent] then return controls[parent] end
    if own==nil then own=true end
    local previous=own and ownControl or inspectControl
    if previous then previous.host:Hide() end
    local host=CreateFrame("Frame",nil,parent)
    host.FossieGSTalentOverride=true
    host:SetSize(160,22)
    local ok,button=pcall(CreateFrame,"DropdownButton",nil,host,"WowStyle1DropdownTemplate")
    if not ok or not button or not button.SetupMenu then
        host:Hide(); NS.talentOverrideUIError="Native talent override dropdown is unavailable"; return
    end
    button:SetSize(160,22)
    button:SetPoint("TOPRIGHT",host,"TOPRIGHT",0,0)
    button:SetDefaultText("Default")
    local control={parent=parent,root=root or parent,host=host,button=button,own=own}
    controls[parent]=control
    if own then ownControl=control else inspectControl=control end
    position(control)
    button:SetupMenu(function(_,menu)
        local unit=controlUnit(control)
        local id=unit and safeGUID(unit)
        local choices=unit and NS.GetTalentOverrideChoices(unit) or {{value=0,label="Default"}}
        for _,choice in ipairs(choices) do
            local payload={index=choice.value,guid=id}
            menu:CreateRadio(choice.label,function(data)
                return data.guid~=nil and NS.GetTalentOverride(data.guid)==data.index
            end,function(data)
                -- Opening a different player before choosing cannot change
                -- the old player's preview or leak the selection to the new one.
                local current=controlUnit(control)
                if current and safeGUID(current)==data.guid then NS.SetTalentOverride(data.index,current) end
            end,payload)
        end
    end)
    refreshControl(control)
    parent:HookScript("OnShow",NS.RefreshTalentOverrideControl)
    return control
end
