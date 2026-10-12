local _, NS = ...
local controls=setmetatable({}, {__mode="k"})
local currentControl
NS.talentOverrideControls=controls
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok then return a,b end
end
local function ownGUID()
    local id=call(UnitGUID,"player")
    if NS.IsSafe(id) and type(id)=="string" then return id end
end
function NS.GetTalentOverride()
    local db=type(FossieGearScoreDB)=="table" and FossieGearScoreDB.talentOverrides
    local saved=type(db)=="table" and db[ownGUID() or ""]
    local index=type(saved)=="table" and NS.GetNumber(saved.tree)
    if index and index>=1 and index<=3 and index==math.floor(index)
        and saved.classToken==NS.GetClassToken("player") then return index end
    return 0
end
function NS.GetTalentOverrideChoices()
    local class=NS.GetClassToken("player")
    local specs=NS.DYNAMIC_SPECS[class]
    local choices={{value=0,label="Default"}}
    for i, spec in ipairs(specs or {}) do
        local _,name=call(C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo,i,false,false)
        if not NS.IsSafe(name) or type(name)~="string" or name=="" then name=spec.name end
        choices[#choices+1]={value=i,label=name}
    end
    return choices
end
function NS.ApplyTalentOverride(actual)
    local index=NS.GetTalentOverride()
    -- An override selects a scoring role; it does not grant talents to a player
    -- below ten or bypass the no-selected-talents rule.
    if index==0 or not actual or not actual.available then return actual end
    local points={0,0,0}; points[index]=31
    local effective=NS.ClassifyTalents(actual.classToken,points,actual.level,actual.race)
    effective.guid, effective.points=actual.guid,actual.points
    effective.overridden, effective.overrideTree=true,index
    effective.detectedName=actual.name
    effective.name=effective.name .. " (override)"
    return effective
end
function NS.SetTalentOverride(index)
    index=NS.GetNumber(index)
    local id,class=ownGUID(),NS.GetClassToken("player")
    if not id or not NS.DYNAMIC_SPECS[class] or not index or index<0 or index>3 or index~=math.floor(index) then return false end
    if type(FossieGearScoreDB)~="table" then FossieGearScoreDB={} end
    if type(FossieGearScoreDB.talentOverrides)~="table" then FossieGearScoreDB.talentOverrides={} end
    FossieGearScoreDB.talentOverrides[id]=index>0 and {classToken=class,tree=index} or nil
    if NS.SumEquippedItems then NS.SumEquippedItems("player") end
    if NS.RefreshTalentOverrideControl then NS.RefreshTalentOverrideControl() end
    if NS.RefreshItemTooltips then NS.RefreshItemTooltips() end
    if NS.RefreshGearDisplay then NS.RefreshGearDisplay() end
    if NS.RefreshGearHover then NS.RefreshGearHover() end
    return true
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
    control.host:ClearAllPoints()
    control.host:SetPoint("TOPRIGHT",control.anchor,"TOPRIGHT",-12,-10)
end
function NS.RefreshTalentOverrideControl()
    if not currentControl then return end
    position(currentControl)
    currentControl.button:GenerateMenu()
end
function NS.AttachTalentOverrideControl(parent,root)
    if controls[parent] then return controls[parent] end
    if currentControl then currentControl.host:Hide() end
    local host=CreateFrame("Frame",nil,parent)
    host.FossieGSTalentOverride=true
    host:SetSize(160,24)
    local ok,button=pcall(CreateFrame,"DropdownButton",nil,host,"WowStyle1DropdownTemplate")
    if not ok or not button or not button.SetupMenu then
        host:Hide()
        NS.talentOverrideUIError="Native talent override dropdown is unavailable"
        return
    end
    button:SetSize(160,24)
    button:SetPoint("TOPRIGHT",host,"TOPRIGHT",0,0)
    button:SetDefaultText("Default")
    local control={parent=parent,anchor=root and root.LeftPaneHost or parent,host=host,button=button}
    controls[parent],currentControl=control,control
    position(control)
    button:SetupMenu(function(_,menu)
        for _,choice in ipairs(NS.GetTalentOverrideChoices()) do
            menu:CreateRadio(choice.label,function(index) return NS.GetTalentOverride()==index end,
                function(index) NS.SetTalentOverride(index) end,choice.value)
        end
    end)
    parent:HookScript("OnShow",NS.RefreshTalentOverrideControl)
    return control
end
