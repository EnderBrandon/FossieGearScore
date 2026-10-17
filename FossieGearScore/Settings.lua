local ADDON_NAME, NS = ...
local surfaces = {character=true, hover=true, items=true}
local validModes = {both=true, normal=true, dynamic=true, none=true}
local enchantmentSurfaces = {character=true, hover=true}
local enchantmentModes = {separate=true, combined=true}
local defaultEnchantmentMode = "combined"
local enchantmentChoices = {
    {value="combined", label="Combined"},
    {value="separate", label="Separate"},
}
local choices = {
    {value="both", label="Both Normal and Dynamic"},
    {value="normal", label="Normal"},
    {value="dynamic", label="Dynamic"},
    {value="none", label="None"},
}
local initialized, category
local defaultPanelAlpha=1

local function initializeDB()
    if type(FossieGearScoreDB) ~= "table" then FossieGearScoreDB = {} end
    for surface in pairs(surfaces) do
        if not validModes[FossieGearScoreDB[surface]] then FossieGearScoreDB[surface] = "both" end
    end
    if type(FossieGearScoreDB.enchantmentDisplay) ~= "table" then FossieGearScoreDB.enchantmentDisplay = {} end
    for surface in pairs(enchantmentSurfaces) do
        if not enchantmentModes[FossieGearScoreDB.enchantmentDisplay[surface]] then
            FossieGearScoreDB.enchantmentDisplay[surface] = defaultEnchantmentMode
        end
    end
    if type(FossieGearScoreDB.minimap)~="table" then FossieGearScoreDB.minimap={} end
    if type(FossieGearScoreDB.minimap.show)~="boolean" then FossieGearScoreDB.minimap.show=true end
    local angle=NS.GetNumber(FossieGearScoreDB.minimap.angle)
    FossieGearScoreDB.minimap.angle=(angle or 225)%360
    local alpha=NS.GetNumber(FossieGearScoreDB.inspectionPanelAlpha)
    FossieGearScoreDB.inspectionPanelAlpha=math.max(0,math.min(1,alpha or defaultPanelAlpha))
    initialized = true
end

function NS.GetDisplayMode(surface)
    local mode = type(FossieGearScoreDB) == "table" and FossieGearScoreDB[surface]
    return validModes[mode] and mode or "both"
end
function NS.GetDisplayVisibility(surface)
    local mode = NS.GetDisplayMode(surface)
    return mode == "both" or mode == "normal", mode == "both" or mode == "dynamic"
end
function NS.SetDisplayMode(surface, mode)
    if not surfaces[surface] or not validModes[mode] then return false end
    initializeDB()
    FossieGearScoreDB[surface] = mode
    if NS.RefreshItemTooltips then NS.RefreshItemTooltips() end
    if NS.RefreshGearDisplay then NS.RefreshGearDisplay() end
    return true
end

function NS.GetEnchantmentDisplayMode(surface)
    local options = type(FossieGearScoreDB) == "table" and FossieGearScoreDB.enchantmentDisplay
    local mode = type(options) == "table" and options[surface]
    return enchantmentModes[mode] and mode or defaultEnchantmentMode
end
function NS.SetEnchantmentDisplayMode(surface, mode)
    if not enchantmentSurfaces[surface] or not enchantmentModes[mode] then return false end
    initializeDB()
    FossieGearScoreDB.enchantmentDisplay[surface] = mode
    if NS.RefreshGearDisplay then NS.RefreshGearDisplay() end
    if NS.RefreshGearHover then NS.RefreshGearHover() end
    return true
end

function NS.GetMinimapVisible()
    local options=type(FossieGearScoreDB)=="table" and FossieGearScoreDB.minimap
    return not (type(options)=="table" and options.show==false)
end
function NS.GetMinimapAngle()
    local options=type(FossieGearScoreDB)=="table" and FossieGearScoreDB.minimap
    local angle=type(options)=="table" and NS.GetNumber(options.angle)
    return (angle or 225)%360
end
function NS.SetMinimapVisible(visible)
    if not NS.IsSafe(visible) or type(visible)~="boolean" then return false end
    initializeDB(); FossieGearScoreDB.minimap.show=visible
    if NS.RefreshMinimapIcon then NS.RefreshMinimapIcon() end
    return true
end
function NS.SetMinimapAngle(angle)
    angle=NS.GetNumber(angle)
    if not angle then return false end
    initializeDB(); FossieGearScoreDB.minimap.angle=angle%360
    return true
end

function NS.GetInspectionPanelAlpha()
    local alpha=type(FossieGearScoreDB)=="table" and NS.GetNumber(FossieGearScoreDB.inspectionPanelAlpha)
    return math.max(0,math.min(1,alpha or defaultPanelAlpha))
end
function NS.SetInspectionPanelAlpha(alpha)
    alpha=NS.GetNumber(alpha)
    if not alpha then return false end
    initializeDB()
    FossieGearScoreDB.inspectionPanelAlpha=math.max(0,math.min(1,alpha))
    if NS.RefreshInspectionPanelOpacity then NS.RefreshInspectionPanelOpacity() end
    return true
end

local function dropdownOptions(options)
    local container = Settings.CreateControlTextContainer()
    for _, option in ipairs(options) do container:Add(option.value, option.label) end
    return container:GetData()
end
local function getOptions() return dropdownOptions(choices) end
local function getEnchantmentOptions() return dropdownOptions(enchantmentChoices) end
local function registerSettings()
    if category or not Settings or type(Settings.RegisterProxySetting) ~= "function" then return end
    category = Settings.RegisterVerticalLayoutCategory("FossieGearScore")
    NS.settingsCategory = category
    for _, definition in ipairs({
        {surface="character", label="Show GS on Character Panel", tooltip="Choose scores for your character and inspect equipment panels."},
        {surface="hover", label="Show GS on Hover", tooltip="Choose scores on player hover tooltips."},
        {surface="items", label="Show GS on Items", tooltip="Choose normal and dynamic scores on equipment tooltips."},
    }) do
        local surface = definition.surface
        local setting = Settings.RegisterProxySetting(category, "FossieGearScore_" .. surface,
            Settings.VarType.String, definition.label, "both",
            function() return NS.GetDisplayMode(surface) end,
            function(value) NS.SetDisplayMode(surface, value) end)
        Settings.CreateDropdown(category, setting, getOptions, definition.tooltip)
        if enchantmentSurfaces[surface] then
            local enchantmentSetting = Settings.RegisterProxySetting(category, "FossieGearScore_enchantments_" .. surface,
                Settings.VarType.String, surface == "character" and "Enchantment Score on Character Panel" or "Enchantment Score on Hover", defaultEnchantmentMode,
                function() return NS.GetEnchantmentDisplayMode(surface) end,
                function(value) NS.SetEnchantmentDisplayMode(surface, value) end)
            Settings.CreateDropdown(category, enchantmentSetting, getEnchantmentOptions,
                "Separate shows gear + enchantment points (365 + 8). Combined adds them into one score (373).")
        end
    end
    if type(Settings.CreateSlider)=="function" and type(Settings.CreateSliderOptions)=="function" then
        local setting=Settings.RegisterProxySetting(category,"FossieGearScore_inspectionPanelAlpha",
            Settings.VarType.Number,"GearScore menu background opacity",100,
            function() return math.floor(NS.GetInspectionPanelAlpha()*100+0.5) end,
            function(value)
                value=NS.GetNumber(value)
                if value then NS.SetInspectionPanelAlpha(value/100) end
            end)
        local options=Settings.CreateSliderOptions(0,100,1)
        local labels=MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
        if labels and options.SetLabelFormatter then
            options:SetLabelFormatter(labels.Min,function() return "0%" end)
            options:SetLabelFormatter(labels.Max,function() return "100%" end)
            options:SetLabelFormatter(labels.Right,function(value) return string.format("%.0f%%",value) end)
        end
        Settings.CreateSlider(category,setting,options,
            "Set the GearScore menu background opacity from 0 (transparent) to 100 (opaque). Text and icons stay fully visible.")
    end
    if type(Settings.CreateCheckbox)=="function" then
        local setting=Settings.RegisterProxySetting(category,"FossieGearScore_minimap",
            Settings.VarType.Boolean,"Show minimap icon",true,NS.GetMinimapVisible,NS.SetMinimapVisible)
        Settings.CreateCheckbox(category,setting,"Show the shield button. Click it to open these settings; drag it to move.")
    end
    Settings.RegisterAddOnCategory(category)
end

function NS.OpenSettings()
    initializeDB(); registerSettings()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif NS.Message then NS.Message("The game's addon settings panel is not available yet.") end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" and name == ADDON_NAME then
        initializeDB(); registerSettings()
    elseif event == "ADDON_LOADED" and initialized then registerSettings() end
end)
