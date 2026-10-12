local ADDON_NAME, NS = ...
local surfaces = {character=true, hover=true, items=true}
local validModes = {both=true, normal=true, dynamic=true, none=true}
local choices = {
    {value="both", label="Both Normal and Dynamic"},
    {value="normal", label="Normal"},
    {value="dynamic", label="Dynamic"},
    {value="none", label="None"},
}
local initialized, category

local function initializeDB()
    if type(FossieGearScoreDB) ~= "table" then FossieGearScoreDB = {} end
    for surface in pairs(surfaces) do
        if not validModes[FossieGearScoreDB[surface]] then FossieGearScoreDB[surface] = "both" end
    end
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

local function getOptions()
    local container = Settings.CreateControlTextContainer()
    for _, option in ipairs(choices) do container:Add(option.value, option.label) end
    return container:GetData()
end
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
