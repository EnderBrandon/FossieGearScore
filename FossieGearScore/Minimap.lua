local ADDON_NAME, NS = ...
local button
local iconPath="Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Icon.tga"

local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok then return a,b end
end
local function position()
    if not button then return end
    local angle=math.rad(NS.GetMinimapAngle())
    local x,y=math.cos(angle),math.sin(angle)
    local width=NS.GetNumber(call(Minimap.GetWidth,Minimap)) or 140
    local height=NS.GetNumber(call(Minimap.GetHeight,Minimap)) or width
    -- Square minimap skins expose this optional helper; the native map is round.
    local shape=call(GetMinimapShape)
    if NS.IsSafe(shape) and shape=="SQUARE" then
        local edge=math.max(math.abs(x),math.abs(y)); x,y=x/edge,y/edge
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER",Minimap,"CENTER",x*(width/2+10),y*(height/2+10))
end
local function stopDragging(self)
    self.dragging=false
    self:SetScript("OnUpdate",nil)
end
local function hideTooltip(self)
    if GameTooltip and call(GameTooltip.IsOwned,GameTooltip,self)==true then GameTooltip:Hide() end
end
local function dragPosition()
    local cx,cy=call(Minimap.GetCenter,Minimap)
    local x,y=call(GetCursorPosition)
    cx,cy,x,y=NS.GetNumber(cx),NS.GetNumber(cy),NS.GetNumber(x),NS.GetNumber(y)
    local scale=NS.GetNumber(call(Minimap.GetEffectiveScale,Minimap)) or 1
    if not cx or not cy or not x or not y or scale<=0 then return end
    local dx,dy=x/scale-cx,y/scale-cy
    if dx==0 and dy==0 then return end
    NS.SetMinimapAngle(math.deg(math.atan2(dy,dx)))
    position()
end
local function createButton()
    if button or not Minimap then return end
    button=CreateFrame("Button","FossieGearScoreMinimapButton",Minimap)
    NS.minimapButton=button
    button:SetSize(31,31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((call(Minimap.GetFrameLevel,Minimap) or 0)+5)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon=button:CreateTexture(nil,"ARTWORK")
    icon:SetSize(20,20); icon:SetPoint("TOPLEFT",button,"TOPLEFT",7,-5)
    icon:SetTexture(iconPath)
    local border=button:CreateTexture(nil,"OVERLAY")
    border:SetSize(53,53); border:SetPoint("TOPLEFT",button,"TOPLEFT",0,0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick",function(self)
        if not self.suppressClick then NS.OpenSettings() end
    end)
    button:SetScript("OnDragStart",function(self)
        self.dragging,self.suppressClick=true,true
        self:SetScript("OnUpdate",dragPosition)
    end)
    button:SetScript("OnDragStop",function(self)
        dragPosition(); stopDragging(self)
        -- Don't open settings when releasing a drag. Clear the guard next tick.
        if C_Timer and C_Timer.After then C_Timer.After(0,function() self.suppressClick=false end)
        else self.suppressClick=false end
    end)
    button:SetScript("OnHide",function(self)
        stopDragging(self); self.suppressClick=false
        hideTooltip(self)
    end)
    button:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("FossieGearScore",1,0.82,0)
        GameTooltip:AddLine("Left-click: settings",1,1,1)
        GameTooltip:AddLine("Drag: move",1,1,1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",hideTooltip)
    if Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged",position)
        Minimap:HookScript("OnShow",position)
    end
end
function NS.RefreshMinimapIcon()
    createButton()
    if not button then return end
    position()
    if NS.GetMinimapVisible() then button:Show() else button:Hide() end
end

local loader=CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent",NS.RefreshMinimapIcon)
NS.RefreshMinimapIcon()
