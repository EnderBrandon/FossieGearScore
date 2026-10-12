local NS,count={},0
local function check(ok,label) assert(ok,label); count=count+1 end
local frames,timers={},{}
local function texture()
    return {SetSize=function(self,...) self.size={...} end,SetPoint=function(self,...) self.point={...} end,
        SetTexture=function(self,value) self.texture=value end}
end
local function frame(kind,name,parent)
    local f={kind=kind,name=name,parent=parent,scripts={},hooks={},visible=true,textures={},level=2}
    function f:RegisterEvent() end
    function f:SetScript(key,fn) self.scripts[key]=fn end
    function f:HookScript(key,fn) self.hooks[key]=fn end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:SetPoint(...) self.point={...} end
    function f:ClearAllPoints() self.point=nil end
    function f:SetFrameStrata(value) self.strata=value end
    function f:SetFrameLevel(value) self.level=value end
    function f:GetFrameLevel() return self.level end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetCenter() return 100,100 end
    function f:GetEffectiveScale() return 2 end
    function f:RegisterForClicks(...) self.clicks={...} end
    function f:RegisterForDrag(...) self.drags={...} end
    function f:SetHighlightTexture(value) self.highlight=value end
    function f:CreateTexture() local t=texture(); self.textures[#self.textures+1]=t; return t end
    function f:Show() self.visible=true end
    function f:Hide()
        local visible=self.visible; self.visible=false
        if visible and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    return f
end
CreateFrame=function(...) local f=frame(...); frames[#frames+1]=f; return f end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local cursorX,cursorY=400,200
GetCursorPosition=function() return cursorX,cursorY end
GameTooltip={lines={},visible=false}
function GameTooltip:SetOwner(owner) self.owner=owner end
function GameTooltip:IsOwned(owner) return self.owner==owner end
function GameTooltip:ClearLines() self.lines={} end
function GameTooltip:AddLine(text) self.lines[#self.lines+1]=text end
function GameTooltip:Show() self.visible=true end
function GameTooltip:Hide() self.visible=false end
for _,file in ipairs({"Weights.lua","Scoring.lua","Settings.lua","Minimap.lua"}) do
    assert(loadfile(file))("FossieGearScore",NS)
end
check(NS.minimapButton==nil,"missing minimap at load does not create a broken button")
check(NS.GetMinimapVisible() and NS.GetMinimapAngle()==225,"fresh minimap defaults are visible at the saved default angle")
NS.SetMinimapVisible(false)
check(FossieGearScoreDB.minimap.show==false,"minimap preference can be saved before the map loads")
Minimap=frame("Frame","Minimap"); Minimap:SetSize(200,180)
NS.RefreshMinimapIcon()
local button=NS.minimapButton
check(button and not button.visible,"late minimap creation honors hidden preference")
check(button.textures[1].texture=="Interface\\AddOns\\FossieGearScore\\Media\\Icon.tga","minimap uses the approved shield texture")
check(button.scripts.OnUpdate==nil,"idle minimap icon has no frame update loop")
NS.SetMinimapVisible(true)
check(button.visible and FossieGearScoreDB.minimap.show,"showing the icon updates and persists visibility")
local frameCount=#frames
for i=1,100 do NS.RefreshMinimapIcon() end
check(#frames==frameCount and NS.minimapButton==button,"refreshes reuse the same button")
local opened=0
NS.OpenSettings=function() opened=opened+1 end
button.scripts.OnClick(button)
check(opened==1,"left click opens addon settings")
button.scripts.OnEnter(button)
check(GameTooltip.visible and GameTooltip.lines[1]=="FossieGearScore" and #GameTooltip.lines==3,
    "minimap hover explains settings and dragging")
button.scripts.OnLeave(button)
check(not GameTooltip.visible,"leaving the button closes its tooltip")
GameTooltip.owner={}; GameTooltip.visible=true
NS.SetMinimapVisible(false)
check(GameTooltip.visible,"hiding the button does not hide another frame's tooltip")
NS.SetMinimapVisible(true)
button.scripts.OnDragStart(button)
check(button.dragging and type(button.scripts.OnUpdate)=="function","dragging starts position updates only while needed")
button.scripts.OnUpdate(button)
check(NS.GetMinimapAngle()==0 and math.abs(button.point[4]-110)<0.001 and math.abs(button.point[5])<0.001,
    "dragging uses minimap scale and keeps the button on the map edge")
button.scripts.OnDragStop(button)
check(not button.dragging and button.scripts.OnUpdate==nil,"releasing the icon stops all frame updates")
button.scripts.OnClick(button)
check(opened==1,"releasing a drag does not open settings")
for _,fn in ipairs(timers) do fn() end; timers={}
button.scripts.OnClick(button)
check(opened==2,"a later click still opens settings")
check(FossieGearScoreDB.minimap.angle==0,"dragged position persists in saved preferences")
GetMinimapShape=function() return "SQUARE" end
NS.SetMinimapAngle(45); NS.RefreshMinimapIcon()
check(math.abs(button.point[4]-110)<0.001 and math.abs(button.point[5]-100)<0.001,"square skins position the icon at their edge")
Minimap:SetSize(300,280); Minimap.hooks.OnSizeChanged(Minimap)
check(math.abs(button.point[4]-160)<0.001 and math.abs(button.point[5]-150)<0.001,"minimap resizing refreshes position without an idle loop")
button.scripts.OnDragStart(button); NS.SetMinimapVisible(false)
check(button.scripts.OnUpdate==nil and not button.dragging,"hiding during drag stops position updates")
check(not NS.SetMinimapAngle("bad") and not NS.SetMinimapVisible("bad"),"invalid preference values do not replace saved data")
NS.SetMinimapAngle(450)
check(NS.GetMinimapAngle()==90,"saved angles normalize around the map")
local reloaded={}
assert(loadfile("Scoring.lua"))("FossieGearScore",reloaded)
assert(loadfile("Settings.lua"))("FossieGearScore",reloaded)
check(not reloaded.GetMinimapVisible() and reloaded.GetMinimapAngle()==90,"new addon namespace preserves icon visibility and position")
print("PASS: "..count.." minimap interaction/settings checks (".._VERSION..")")
