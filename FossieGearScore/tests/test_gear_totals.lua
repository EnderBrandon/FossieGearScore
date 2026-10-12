-- Integration fixtures: load the real item reader and real equipped-score UI.
local NS, count = {}, 0
FossieGearScoreDB={character="normal",hover="normal",items="normal"}
local function check(ok, description) assert(ok, description); count=count+1 end
local events, timers, callbacks, units, db, messages = {}, {}, {}, {}, {}, {}
local function font()
    return {SetText=function(self, text) self.text=text end,
        GetText=function(self) return self.text end,
        SetPoint=function(self, ...) self.point={...} end,
        SetTextColor=function(self, ...) self.color={...} end,
        SetAllPoints=function(self, parent) self.parent=parent end,
        SetJustifyH=function() end, SetShadowColor=function() end, SetShadowOffset=function() end}
end
local function frame(name, parent, level, shown)
    local f={name=name, parent=parent, hooks={}, labels={}, additions={}, children={},
        level=level or (parent and parent.level+1) or 1, visible=shown or false}
    if parent then parent.children[#parent.children+1]=f end
    function f:RegisterEvent() end
    function f:SetScript(key, fn) self[key]=fn end
    function f:HookScript(key, fn)
        self.hooks[key]=self.hooks[key] or {}; table.insert(self.hooks[key],fn)
    end
    function f:Run(key) for _, fn in ipairs(self.hooks[key] or {}) do fn(self) end end
    function f:CreateFontString() local label=font(); self.labels[#self.labels+1]=label; return label end
    function f:GetName() return self.name end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(level) self.level=level end
    function f:GetFrameStrata() return self.strata or "MEDIUM" end
    function f:SetFrameStrata(strata) self.strata=strata end
    function f:GetChildren() return unpack(self.children) end
    function f:ClearAllPoints() self.point=nil end
    function f:SetPoint(...) self.point={...} end
    function f:SetSize(...) self.size={...} end
    function f:EnableMouse(enabled) self.mouse=enabled end
    function f:NumLines() return #self.additions end
    function f:GetPrimaryTooltipData() return self.data end
    function f:GetPrimaryTooltipInfo() return self.info end
    function f:RefreshDataNextUpdate() self.refreshRequested=true end
    function f:IsShown() return self.visible end
    function f:IsVisible() return self.visible and (not self.parent or self.parent:IsVisible()) end
    function f:Show() local was=self.visible; self.visible=true; if not was then self:Run("OnShow") end end
    function f:Hide() self.visible=false; self:Run("OnHide") end
    function f:ClearLines() self.additions={} end
    function f:AddDoubleLine(label, text)
        local right=font(); right:SetText(text)
        self.additions[#self.additions+1]={label=label,right=right}
        _G[self.name .. "TextRight" .. #self.additions]=right
    end
    return f
end
CreateFrame=function(_,name,parent)
    local f=frame(name or "Frame" .. #events,parent,nil,true); events[#events+1]=f; return f
end
hooksecurefunc=function(f,key,fn)
    local original=f[key]; f[key]=function(self, ...) original(self,...); fn(self,...) end
end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function flush()
    local pending=timers; timers={}; for _, fn in ipairs(pending) do fn() end
end
local function fire(event,...) for _, f in ipairs(events) do if f.OnEvent then f.OnEvent(f,event,...) end end end
UnitGUID=function(unit) return units[unit] and units[unit].guid end
UnitIsPlayer=function(unit) return units[unit] and units[unit].player == true or false end
UnitExists=function(unit) return units[unit]~=nil end
UnitTokenFromGUID=function(guid)
    for _, unit in ipairs({"player","target","mouseover","focus"}) do if UnitGUID(unit)==guid then return unit end end
end
GetTime=function() return 100 end
GetLocale=function() return "enUS" end
GetInventoryItemLink=function(unit,slot)
    local u=units[unit]; if u and not (u.hidden and u.hidden[slot]) then return u.gear[slot] end
end
GetInventoryItemTexture=function(unit,slot) return units[unit] and units[unit].gear[slot] and 999 end
Enum={TooltipDataType={Item=0,Unit=2},TooltipDataLineType={}}
TooltipDataProcessor={AddTooltipPostCall=function(kind,fn)
    callbacks[kind]=callbacks[kind] or {}; table.insert(callbacks[kind],fn)
end}
TooltipUtil={
    GetDisplayedItem=function(f) return "Item",f.link end,
    -- Forever's native helper returns name, unit token, then GUID.
    GetDisplayedUnit=function(f) return "Player",f.unit,UnitGUID(f.unit) end,
}
C_Item={
    GetItemInfoInstant=function(link) return db[link].id or 1,"Armor","Cloth",db[link].equipLoc or "INVTYPE_HEAD",0,4,1 end,
    IsItemDataCachedByID=function(link) return db[link].cached~=false end,
    GetItemStats=function(link) return db[link].raw end,
    GetItemInfo=function(link)
        local i=db[link]
        local setID=i.setID
        if i.noSetID then setID=nil end
        return "Item",link,i.quality or 1,i.level or 10,1,"Armor","Cloth",1,"INVTYPE_HEAD",0,0,4,1,1,0,setID
    end,
    GetDetailedItemLevelInfo=function(link) return db[link].level or 10 end,
}
local function itemLines(link,unit)
    local item=db[link]
    if not item.setID then return item.lines or {{leftText="Fixture Item"}} end
    local u=units[item.usePlayerHeader and "player" or unit or "player"]
    local pieces=0
    for _, equipped in pairs(u and u.gear or {}) do
        if db[equipped].setID==item.setID then pieces=pieces+1 end
    end
    if item.nativeSetText then
        return {
            {leftText=(item.setName or "Native Fixture Set") .. " (" .. pieces .. "/4)"},
            {leftText=pieces>=2 and "Set: +500 Strength" or "(2) Set: +500 Strength"},
            {leftText=pieces>=4 and "Set: Equip: +1000 Strength" or "(4) Set: Equip: +1000 Strength"},
        }
    end
    return {
        {leftText=(item.setName or "Fixture Set") .. " (" .. pieces .. "/4)"},
        {leftText="(2) Set: +500 Strength",leftColor=pieces>=2 and {r=0,g=1,b=0} or {r=0.5,g=0.5,b=0.5}},
        {leftText="(4) Set: Equip: +1000 Strength",leftColor=pieces>=4 and {r=0,g=1,b=0} or {r=0.5,g=0.5,b=0.5}},
    }
end
C_TooltipInfo={
    GetHyperlink=function(link) return {lines=itemLines(link,"player")} end,
    GetInventoryItem=function(unit,slot)
        local link=GetInventoryItemLink(unit,slot)
        return link and {lines=itemLines(link,unit)}
    end,
}
SlashCmdList={}; DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
CharacterFrame=frame("CharacterFrame")
CharacterFrame.LeftPaneHost=frame("CharacterFrameLeftPaneHost",CharacterFrame,2,true)
PaperDollFrame=frame("PaperDollFrame",CharacterFrame,1,true)
PaperDollFrame.CharacterModelScene=frame("CharacterModelScene",PaperDollFrame,50,true)
PaperDollFrame.ItemsFrame=frame("PaperDollItemsFrame",PaperDollFrame,100,true)
GameTooltip=frame("GameTooltip")
db.a={raw={ITEM_MOD_STRENGTH_SHORT=3}} -- 4 displayed points
db.b={raw={ITEM_MOD_INTELLECT_SHORT=7,ITEM_MOD_SPIRIT_SHORT=3}} -- 7
db.shirt={raw={},level=60,quality=4} -- zero, even at high level/quality
db.c={raw={ITEM_MOD_STRENGTH_SHORT=5},level=15,quality=2} -- 7
db.weapon={raw={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10.5},level=12,quality=3} -- 8
db.crit={raw={},lines={{leftText="Equip: Improves your chance to get a critical strike by 1.0%."}}} -- 6
units.player={guid="Player-Self",player=true,gear={[1]="a",[16]="b",[4]="shirt"}}
local enemy={guid="Player-Enemy",player=true,gear={[1]="c",[16]="weapon"}}
units.target=enemy; units.mouseover=enemy
units.npc={guid="Creature-NPC",player=false,gear={}}
for file in io.lines("FossieGearScore.toc") do
    if file:match("%.lua$") then assert(loadfile(file))("FossieGearScore",NS) end
end
check(#callbacks[0]==1 and #callbacks[2]==1,"separate item and unit tooltip callbacks registered")
local ownUI=NS.gearPanels[PaperDollFrame]
check(ownUI and #ownUI.overlay.labels==1,"character total label created on dedicated overlay")
check(ownUI.overlay.point[1]=="BOTTOMLEFT" and ownUI.overlay.point[2]==CharacterFrame.LeftPaneHost,"total anchored at bottom left of native left pane")
CharacterFrame:Show() -- Root can open while the gear child is already IsShown.
check(ownUI.label.text=="GS: 11","opening character root refreshes sum of individual integer item scores")
check(ownUI.overlay:GetFrameLevel()>PaperDollFrame.CharacterModelScene:GetFrameLevel()
    and ownUI.overlay:GetFrameLevel()>PaperDollFrame.ItemsFrame:GetFrameLevel(),"GS draws above native model background and item frames")
check(ownUI.overlay:IsVisible() and ownUI.overlay.mouse==false,"GS is visible without intercepting clicks")
local firstLevel=ownUI.overlay.level
CharacterFrame:Hide(); check(not ownUI.overlay:IsVisible(),"GS hides with the character panel")
CharacterFrame:Show(); check(ownUI.overlay.level==firstLevel,"reopening does not continually increase frame level")
PaperDollFrame.CharacterModelScene:SetFrameLevel(650)
CharacterFrame:Hide(); CharacterFrame:Show()
check(ownUI.overlay.level>650,"opening raises GS above a model whose level was changed by a skin")
PaperDollFrame:Hide(); check(not ownUI.overlay:IsVisible(),"GS hides when leaving the equipment tab")
PaperDollFrame:Show(); check(ownUI.overlay:IsVisible(),"returning to the equipment tab restores GS")
check(NS.gearCache["Player-Self"].items[4]==0,"statless equipment contributes zero to total")
NS.last={sentinel=true}
NS.SumEquippedItems("player")
check(NS.last.sentinel,"gear total does not overwrite last hovered item diagnostics")
local function hover(unit)
    GameTooltip:ClearLines(); GameTooltip.unit=unit
    GameTooltip.data={type=2,guid=UnitGUID(unit)}; GameTooltip:Show()
    for _, fn in ipairs(callbacks[2]) do fn(GameTooltip,GameTooltip.data) end
end
hover("player")
check(GameTooltip.additions[1].right.text=="11","native name/unit/GUID helper order shows self score")
callbacks[2][1](GameTooltip,GameTooltip.data)
check(#GameTooltip.additions==1,"repeat unit post-call does not add duplicate GS")
hover("target")
check(#GameTooltip.additions==1 and GameTooltip.additions[1].right.text=="Inspect to see GS","uninspected player gets the requested fallback without a guessed score")
hover("npc")
check(#GameTooltip.additions==0,"NPC tooltip does not show gear score")

InspectFrame=frame("InspectFrame"); InspectFrame.unit="target"
function InspectFrame:GetInspectUnit() return self.unit end
InspectPaperDollFrame=frame("InspectPaperDollFrame",InspectFrame,1,true)
InspectModelFrame=frame("InspectModelFrame",InspectPaperDollFrame,50,true)
fire("ADDON_LOADED","Blizzard_InspectUI"); flush()
local inspectUI=NS.gearPanels[InspectPaperDollFrame]
check(inspectUI and #inspectUI.overlay.labels==1,"load-on-demand inspect panel receives a label")
check(inspectUI.overlay.level>InspectModelFrame.level,"inspect GS draws above its model background")
InspectPaperDollFrame:Run("OnShow")
check(inspectUI.label.text=="GS: ...","inspect panel waits for matching data")
hover("target")
fire("INSPECT_READY","Player-Enemy")
check(inspectUI.label.text=="GS: 15","inspect panel shows completed total")
check(GameTooltip.additions[1].right.text=="15 (cached)","visible hover updates after inspect data arrives")
check(NS.gearCache["Player-Enemy"].items[16]==8,"weapon contributes its actual item score")
fire("ADDON_LOADED","OtherAddon"); flush()
check(#callbacks[2]==1 and #ownUI.overlay.labels==1 and #inspectUI.overlay.labels==1,"repeated addon loads do not duplicate hooks or labels")
InspectFrame:Hide(); InspectFrame.unit=nil
hover("target")
check(GameTooltip.additions[1].right.text=="15 (cached)","hover retains inspection snapshot after panel closes")

-- A skin can rebuild a tooltip without running the native unit post-call.
GameTooltip:Hide(); GameTooltip:ClearLines(); GameTooltip.unit="target"
GameTooltip.data={type=2,guid=UnitGUID("target")}; GameTooltip:Show()
check(#GameTooltip.additions==1 and GameTooltip.additions[1].right.text=="15 (cached)","OnShow restores known player scores without a post-call")
callbacks[2][1](GameTooltip,GameTooltip.data)
check(#GameTooltip.additions==1,"OnShow and native callback cooperate without duplicate GS")

local nativeHelper, nativeToken=TooltipUtil.GetDisplayedUnit, UnitTokenFromGUID
TooltipUtil.GetDisplayedUnit=nil; UnitTokenFromGUID=nil
hover("target")
check(GameTooltip.additions[1].right.text=="15 (cached)","GUID matching supports a skin without tooltip helpers")
GameTooltip:ClearLines(); GameTooltip.unit="player"
GameTooltip.data={type=2,guid="Player-Unknown"}
callbacks[2][1](GameTooltip,GameTooltip.data)
check(#GameTooltip.additions==0,"unresolved displayed GUID cannot borrow the hovered or self score")
TooltipUtil.GetDisplayedUnit=function() return "Stale Player","player","Player-Self" end
GameTooltip:ClearLines(); GameTooltip.unit="target"
GameTooltip.data={type=2,guid=UnitGUID("target")}
callbacks[2][1](GameTooltip,GameTooltip.data)
check(GameTooltip.additions[1].right.text=="15 (cached)","stale helper unit is rejected in favor of the displayed GUID")
TooltipUtil.GetDisplayedUnit=nativeHelper; UnitTokenFromGUID=nativeToken

GameTooltip:Hide(); GameTooltip:ClearLines(); GameTooltip.unit="target"
GameTooltip.data={type=0,guid=UnitGUID("target")}; GameTooltip:Show()
check(#GameTooltip.additions==0,"OnShow never adds player GS to an item tooltip")
hover("target")
SlashCmdList.FOSSIEGS("ui")
check(messages[#messages]:find("GS 15 (cached)",1,true)~=nil,"UI diagnostics include the resolved hovered player score")
check(messages[#messages-2]:find("Character: PaperDollFrame | overlay visible",1,true)~=nil,"UI diagnostics report character overlay visibility")

local nativeAdd=GameTooltip.AddDoubleLine
GameTooltip.AddDoubleLine=function() error("fixture unit tooltip failure") end
local beforeErrors=#messages
hover("target"); callbacks[2][1](GameTooltip,GameTooltip.data)
check(#messages==beforeErrors+1 and NS.gearUIError:find("fixture unit tooltip failure",1,true),"player tooltip errors are reported once instead of silently swallowed")
GameTooltip.AddDoubleLine=nativeAdd; hover("target")
check(GameTooltip.additions[1].right.text=="15 (cached)","player tooltips recover after a frame error")

units.player.gear[1]="c"
fire("PLAYER_EQUIPMENT_CHANGED",1); fire("UNIT_INVENTORY_CHANGED","player")
check(#timers==1,"equipment events are coalesced into one refresh")
flush()
check(ownUI.label.text=="GS: 14","self total updates after changing equipment")
hover("player")
check(GameTooltip.additions[1].right.text=="14","self hover follows gear changes")
units.player.gear[16]=nil
fire("PLAYER_EQUIPMENT_CHANGED",16); flush()
check(ownUI.label.text=="GS: 7","unequipped item removed from total")
units.player.gear[2]="crit"
fire("PLAYER_EQUIPMENT_CHANGED",2); flush()
check(ownUI.label.text=="GS: 13","equip-only tooltip stats use the same parser as item hover")

db.c.cached=false; fire("GET_ITEM_INFO_RECEIVED",1); flush()
check(ownUI.label.text=="GS: 6 (partial)","unloaded item marks a partial total")
db.c.cached=true; fire("GET_ITEM_INFO_RECEIVED",1); flush()
check(ownUI.label.text=="GS: 13","total recovers after item data loads")
units.player.hidden={[1]=true}; fire("PLAYER_EQUIPMENT_CHANGED",1); flush()
check(ownUI.label.text=="GS: 6 (partial)","occupied slot with missing link is not mistaken for empty")
units.player.hidden=nil

local stranger={guid="Player-Stranger",player=true,gear={[1]="a"}}
units.target=stranger; units.mouseover=stranger
hover("target")
check(#GameTooltip.additions==1 and GameTooltip.additions[1].right.text=="Inspect to see GS","switching players shows fallback rather than another GUID's score")
InspectFrame.unit="target"; InspectPaperDollFrame:Run("OnShow")
fire("INSPECT_READY","Player-Enemy")
check(inspectUI.label.text=="GS: ...","late inspect result for previous player does not populate new target")
fire("INSPECT_READY","Player-Stranger")
check(inspectUI.label.text=="GS: 4","matching new player inspection updates panel")
check(GameTooltip.additions[1].right.text=="4 (cached)","new player hover receives only their own cached total")
stranger.gear[1]="c"; fire("INSPECT_READY","Player-Stranger")
check(#GameTooltip.additions==1 and GameTooltip.additions[1].right.text=="7 (cached)","changed cached total updates existing line without duplication")
stranger.gear={}; fire("INSPECT_READY","Player-Stranger")
hover("target")
check(GameTooltip.additions[1].right.text=="0 (cached)","known naked player displays a valid zero total")
check(NS.GetGearScore("npc")==nil,"NPC scores remain unavailable")
units.player.gear={}; fire("PLAYER_EQUIPMENT_CHANGED",1); flush()
check(ownUI.label.text=="GS: 0","all items removed produces zero self total")

-- Real item reader + native inventory-owner context + per-player set totals.
for index=1,4 do
    db["set" .. index]={raw={ITEM_MOD_STRENGTH_SHORT=210},level=0,setID=501,usePlayerHeader=true}
end
units.player.gear={[1]="set1",[3]="set2",[5]="set3",[7]="set4"}
fire("PLAYER_EQUIPMENT_CHANGED",1); flush()
check(ownUI.label.text=="GS: 536","four-piece total sums four base-105 items plus their 29-point bonuses")
check(NS.gearCache["Player-Self"].itemScores[1]==105 and NS.gearCache["Player-Self"].setBonusScores[1]==29,"cache records intrinsic and set scores separately")
check(NS.gearCache["Player-Self"].sets["id:501"].count==4,"equipped set count spans different armor slots")
local itemTip=frame("FixtureSetItemTip"); itemTip.link="set1"
itemTip.info={getterName="GetInventoryItem",getterArgs={"player",1}}
local function showSetItem(unit)
    itemTip:ClearLines(); itemTip.info.getterArgs[1]=unit
    itemTip.data={type=0,id=1,hyperlink=itemTip.link,lines=itemLines(itemTip.link,unit)}
    itemTip:Show(); callbacks[0][1](itemTip,itemTip.data)
end
showSetItem("player")
check(#itemTip.additions==2 and itemTip.additions[1].label=="Item Score" and itemTip.additions[1].right.text=="105","tooltip retains intrinsic item score")
check(itemTip.additions[2].label=="Set Bonus Score" and itemTip.additions[2].right.text=="29","set score is the separate next line")
check(NS.last.totalScore==134 and NS.last.setPieces==4,"individual tooltip and total use identical four-piece calculation")
callbacks[0][1](itemTip,itemTip.data)
check(#itemTip.additions==2,"repeat callback does not duplicate either score line")
SlashCmdList.FOSSIEGS("debug")
check(messages[#messages]:find("= 29 Set Bonus Score; total 134",1,true)~=nil,"debug explains per-piece multiplier and combined item total")
hover("player")
check(GameTooltip.additions[1].right.text=="536","own player hover includes set bonuses")

local setEnemy={guid="Player-SetEnemy",player=true,gear={[1]="set1",[3]="set2"}}
units.target=setEnemy; units.mouseover=setEnemy; InspectFrame.unit="target"
fire("INSPECT_READY",setEnemy.guid)
check(inspectUI.label.text=="GS: 242","inspected two-piece total ignores local four-piece header and counts their equipment")
hover("target")
check(GameTooltip.additions[1].right.text=="242 (cached)","inspected player hover includes their own set bonuses")
showSetItem("target")
check(itemTip.additions[2].right.text=="16" and NS.last.setPieces==2,"native inventory tooltip owner resolves inspected set count instead of your own")
InspectFrame:Hide(); InspectFrame.unit=nil
check(NS.ScoreItem("set1",itemLines("set1","target"),{unit="target"}).setBonusScore==16,"closed inspection retains the correct per-player set context")

units.player.gear[7]=nil; fire("PLAYER_EQUIPMENT_CHANGED",7); flush()
check(ownUI.label.text=="GS: 381","three remaining pieces receive four factors per item")
check(itemTip.refreshRequested,"equipment refresh asks visible set tooltips to rebuild")
showSetItem("player")
check(itemTip.additions[2].right.text=="22","same item rebuilt after unequip updates its separate bonus")
units.player.gear[5]=nil; fire("PLAYER_EQUIPMENT_CHANGED",5); flush()
check(ownUI.label.text=="GS: 242","two pieces reduce both items to the two-piece multiplier")
units.player.gear[3]=nil; fire("PLAYER_EQUIPMENT_CHANGED",3); flush()
showSetItem("player")
check(ownUI.label.text=="GS: 105" and itemTip.additions[2].right.text=="0","losing the last active tier removes all set bonus points")

db.other1={raw={ITEM_MOD_STRENGTH_SHORT=210},level=0,setID=502,setName="Other Fixture Set"}
db.other2={raw={ITEM_MOD_STRENGTH_SHORT=210},level=0,setID=502,setName="Other Fixture Set"}
units.player.gear={[1]="set1",[3]="set2",[5]="other1",[7]="other2"}
fire("PLAYER_EQUIPMENT_CHANGED",1); flush()
check(ownUI.label.text=="GS: 484","two separate two-piece sets are not treated as one four-piece set")

units.player.gear={[1]="set1",[3]="set2",[5]="set3",[7]="set4"}
db.set4.cached=false; fire("GET_ITEM_INFO_RECEIVED",1); flush()
check(ownUI.label.text=="GS: 402 (partial)","known fourth-piece membership still activates correct bonuses while its stats load")
check(NS.gearCache["Player-Self"].sets["id:501"].count==4,"stat cache loading does not drop known set membership")
db.set4.cached=true; fire("GET_ITEM_INFO_RECEIVED",1); flush()
check(ownUI.label.text=="GS: 536","loading fourth item restores complete total")
db.set4.raw={}; fire("GET_ITEM_INFO_RECEIVED",1); flush()
check(ownUI.label.text=="GS: 403" and NS.gearCache["Player-Self"].items[7]==1
    and NS.gearCache["Player-Self"].itemScores[7]==0,"zero-base active set member contributes the one-point set minimum")
db.set4.raw={ITEM_MOD_STRENGTH_SHORT=210}

db.proc={raw={ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10},level=100,quality=3,
    lines={{leftText="Chance on hit: Deals 400 damage."},{leftText="Equip: Random effect."}}}
units.player.gear={[16]="proc"}; fire("PLAYER_EQUIPMENT_CHANGED",16); flush()
check(ownUI.label.text=="GS: 40","weapon proc and equip lines boost the item-level base once in equipment total")
local procItem=NS.ScoreItem("proc")
check(procItem.score==40 and procItem.scoring.effectMultiplier==1.05,"individual weapon tooltip shares effect/base calculation with total")

db.fallback1={raw={ITEM_MOD_STRENGTH_SHORT=210},level=0,setID=503,setName="Name Fallback Outfit",noSetID=true}
db.fallback2={raw={ITEM_MOD_STRENGTH_SHORT=210},level=0,setID=503,setName="Name Fallback Outfit",noSetID=true}
units.player.gear={[1]="fallback1",[3]="fallback2"}; fire("PLAYER_EQUIPMENT_CHANGED",1); flush()
check(ownUI.label.text=="GS: 242","set name/header fallback works when native GetItemInfo has no set ID")
check(NS.ScoreItem("fallback1").setBonusScore==16,"individual tooltip uses the same fallback set identity as total")

-- Native active lines omit their piece number. They must activate the set
-- without adding the actual set stats or intrinsic effect points a second time.
for index=1,4 do
    db["native" .. index]={raw={ITEM_MOD_STRENGTH_SHORT=210},level=0,
        setID=504,setName="Native Fixture Set",nativeSetText=true,noSetID=true}
end
units.player.gear={[1]="native1",[3]="native2"}
fire("PLAYER_EQUIPMENT_CHANGED",1); flush()
check(ownUI.label.text=="GS: 242","native active two-piece wording works with set-name fallback")
local nativeResult=NS.ScoreItem("native1")
check(nativeResult.score==105 and nativeResult.setBonusScore==16 and not nativeResult.setPartial,
    "active lower tier overrides a higher numbered inactive tier without scoring its flat effects")
units.player.gear[5]="native3"; units.player.gear[7]="native4"
fire("PLAYER_EQUIPMENT_CHANGED",5); flush()
check(ownUI.label.text=="GS: 536" and not NS.gearCache["Player-Self"].partial,
    "fully active native set without any numbered tiers produces a complete panel total")
check(NS.ScoreItem("native1").setBonusScore==29 and not NS.ScoreItem("native1").setPartial,
    "fully active set's individual tooltip agrees with panel total")
local nativeEnemy={guid="Player-NativeSetEnemy",player=true,gear={[1]="native1",[3]="native2"}}
units.target=nativeEnemy; units.mouseover=nativeEnemy
InspectFrame.unit="target"; InspectFrame:Show(); fire("INSPECT_READY",nativeEnemy.guid)
check(inspectUI.label.text=="GS: 242","native active set inspection uses the inspected player's two-piece count")
itemTip.link="native1"; showSetItem("target")
check(itemTip.additions[2].right.text=="16" and NS.last.setPieces==2,
    "native active set item tooltip does not use the local four-piece count")
hover("target")
check(GameTooltip.additions[1].right.text=="242 (cached)","native set additions reach cached player hover totals")
units.player.gear={[1]="native1"}; fire("PLAYER_EQUIPMENT_CHANGED",3); flush()
check(ownUI.label.text=="GS: 105","unequipping native active set removes bonuses at the last tier")

db.minimum1={raw={ITEM_MOD_STRENGTH_SHORT=2},level=0,setID=505,nativeSetText=true}
db.minimum2={raw={ITEM_MOD_STRENGTH_SHORT=2},level=0,setID=505,nativeSetText=true}
units.player.gear={[1]="minimum1",[3]="minimum2"}
fire("PLAYER_EQUIPMENT_CHANGED",1); flush()
check(ownUI.label.text=="GS: 4" and NS.gearCache["Player-Self"].setBonusScores[1]==1,
    "low-score active set applies a minimum of one point to every equipped piece")
itemTip.link="minimum1"; showSetItem("player"); SlashCmdList.FOSSIEGS("debug")
check(messages[#messages]:find("max(1, floor(1 x 1.15763) - 1) = 1",1,true)~=nil,
    "debug explains the minimum rather than showing an incorrect floor equality")

db.equipOnly={raw={},level=15,quality=2,lines={{leftText="Equip: Improves stealth detection."}}}
units.player.gear={[11]="equipOnly"}; fire("PLAYER_EQUIPMENT_CHANGED",11); flush()
check(ownUI.label.text=="GS: 5","effect-only equipped item contributes its enhanced base to the panel")
db.resistanceOnly={raw={},level=0,quality=1,lines={{leftText="+2 to All Resistances"}}}
units.player.gear={[3]="resistanceOnly"}; fire("PLAYER_EQUIPMENT_CHANGED",3); flush()
check(ownUI.label.text=="GS: 1","all-resistance wording contributes the same score to the equipment total")

db.useOnly={raw={},level=15,quality=2,equipLoc="INVTYPE_TRINKET",
    lines={{leftText="Use: Grants 100 attack power for 10 sec."}}}
units.player.gear={[13]="useOnly"}; fire("PLAYER_EQUIPMENT_CHANGED",13); flush()
check(ownUI.label.text=="GS: 7","on-use-only equipped item receives the 1.5 base factor in character total")
hover("player")
check(GameTooltip.additions[1].right.text=="7","own player hover includes on-use-only item score")
local useEnemy={guid="Player-UseOnly",player=true,gear={[14]="useOnly"}}
units.target=useEnemy; units.mouseover=useEnemy; InspectFrame.unit="target"
fire("INSPECT_READY",useEnemy.guid)
check(inspectUI.label.text=="GS: 7","inspection totals include on-use-only items")
hover("target")
check(GameTooltip.additions[1].right.text=="7 (cached)","inspected player hover caches on-use-only total")

units.player.gear={[1]="a"}; fire("PLAYER_EQUIPMENT_CHANGED",1); flush()
local bagTip=frame("FixtureBagTip"); bagTip.link="c"
bagTip.info={getterName="GetBagItem",getterArgs={0,1}}
local function showBag()
    bagTip:ClearLines(); bagTip.data={type=0,id=1,hyperlink=bagTip.link,lines=itemLines(bagTip.link,"player")}
    bagTip:Show(); callbacks[0][1](bagTip,bagTip.data)
end
showBag()
check(bagTip.additions[1].right.text=="7 |cff00ff00(+3)|r","bag gain uses real item reader and equipped head score")
units.player.gear[1]="c"; fire("PLAYER_EQUIPMENT_CHANGED",1); flush()
check(bagTip.refreshRequested,"equipment change requests a rebuild of a non-set bag comparison tooltip")
showBag()
check(bagTip.additions[1].right.text=="7 |cffffffff(0)|r","rebuilt bag comparison becomes neutral after that item is equipped")
units.player.gear[1]=nil; fire("PLAYER_EQUIPMENT_CHANGED",1); flush(); showBag()
check(bagTip.additions[1].right.text=="7 |cff00ff00(+7)|r","rebuilt bag comparison updates after unequipping the current item")
db.strongHead={raw={ITEM_MOD_STRENGTH_SHORT=20},level=15,quality=2}
units.player.gear[1]="strongHead"; fire("PLAYER_EQUIPMENT_CHANGED",1); flush(); showBag()
check(bagTip.additions[1].right.text=="7 |cffff4040(-8)|r","bag decrease updates when stronger equipment is worn")

-- Background inspection uses an actual clock and delayed timers. Inventory
-- links are unavailable until the matching ready event, like the live client.
local clock, delayed, requests, clearCalls = 1000, {}, {}, 0
local combat, unitCombat = false, false
GetTime=function() return clock end
C_Timer.After=function(delay,fn) delayed[#delayed+1]={at=clock+delay,fn=fn} end
local function advance(seconds)
    local finish=clock+seconds
    for iteration=1,1000 do
        local index
        for i, timer in ipairs(delayed) do
            if timer.at<=finish and (not index or timer.at<delayed[index].at) then index=i end
        end
        if not index then clock=finish; return end
        local timer=table.remove(delayed,index); clock=timer.at; timer.fn()
    end
    error("background inspection timer loop")
end
local tableHook=hooksecurefunc
hooksecurefunc=function(owner,key,fn)
    if type(owner)~="string" then return tableHook(owner,key,fn) end
    local original, callback=_G[owner], key
    _G[owner]=function(...) original(...); callback(...) end
end
NotifyInspect=function(unit)
    if units[unit].notifyError then error("fixture inspection request failure") end
    requests[#requests+1]={unit=unit,guid=UnitGUID(unit),at=clock}
end
CanInspect=function(unit) return units[unit]~=nil and not units[unit].uninspectable end
CheckInteractDistance=function(unit,index)
    assert(index==1); return units[unit]~=nil and not units[unit].outOfRange
end
InCombatLockdown=function() return combat end
UnitAffectingCombat=function() return unitCombat end
ClearInspectPlayer=function() clearCalls=clearCalls+1 end
local nativeInventory=GetInventoryItemLink
GetInventoryItemLink=function(unit,slot)
    if units[unit] and units[unit].waiting then return end
    return nativeInventory(unit,slot)
end
local function person(name,item)
    return {guid="Player-Background-" .. name,player=true,gear=item and {[1]=item} or {},waiting=true}
end
local function ready(person)
    person.waiting=nil; fire("INSPECT_READY",person.guid)
end
local function look(person)
    units.mouseover=person; hover("mouseover")
end
InspectFrame:Hide(); InspectFrame.unit=nil; advance(0)
units.target=nil; units.focus=nil
hover("player"); advance(1); hover("npc"); advance(1)
check(#requests==0,"background inspection never requests self or NPC data")
local alpha=person("Alpha","c")
look(alpha)
check(GameTooltip.additions[1].right.text=="Inspect to see GS","unknown player displays fallback while waiting for background data")
advance(0.29)
check(#requests==0,"brief hover does not immediately request inspection")
advance(0.02)
check(#requests==1 and requests[1].guid==alpha.guid,"stable hover issues a background inspection for the displayed player")
check(not InspectFrame:IsShown() and InspectFrame.unit==nil,"background request leaves manual inspect window closed")
check(NS.gearCache[alpha.guid]==nil,"unavailable remote inventory is not mistaken for a naked player before ready")
callbacks[2][1](GameTooltip,GameTooltip.data); advance(0.5)
check(#requests==1 and #GameTooltip.additions==1,"repeated hover callbacks neither resend pending requests nor duplicate fallback")
fire("INSPECT_READY","Player-Unrelated")
check(NS.gearCache[alpha.guid]==nil,"unrelated inspect result does not complete background request")
ready(alpha)
check(#GameTooltip.additions==1 and GameTooltip.additions[1].right.text=="7 (cached)","matching background result replaces fallback in the same tooltip line")
check(NS.gearCache[alpha.guid].score==7,"background result uses real equipped-item scoring")
look(alpha); advance(1)
check(#requests==1,"fresh cached scores prevent redundant inspection")
alpha.gear[1]="strongHead"; advance(60); look(alpha); advance(0.31)
check(#requests==2 and GameTooltip.additions[1].right.text=="7 (cached)","older cache remains visible while its background refresh is pending")
ready(alpha)
check(GameTooltip.additions[1].right.text=="15 (cached)","background refresh replaces an older cached score")

local beta, gamma=person("Beta","c"),person("Gamma","a")
look(beta); advance(0.15); look(gamma); advance(3.1)
check(#requests==3 and requests[3].guid==gamma.guid,"changing hover during delay inspects only the current GUID")
check(NS.gearCache[beta.guid]==nil,"player skipped during hover delay receives no invented score")
ready(gamma)
local delta=person("Delta","c")
look(delta); advance(0.5)
check(#requests==3,"cooldown prevents a second player's immediate request")
advance(2.6)
check(#requests==4 and requests[4].at-requests[3].at>=3,"requests for different players respect global cooldown")
ready(delta)

local timeoutPlayer=person("Timeout","c")
look(timeoutPlayer); advance(3.1)
check(#requests==5,"next uncached player is requested after cooldown")
advance(5.1)
check(GameTooltip.additions[1].right.text=="Inspect to see GS" and NS.gearCache[timeoutPlayer.guid]==nil,"timed-out inspection shows fallback without caching a zero")
look(timeoutPlayer); advance(0.5)
check(#requests==5,"failed player has a retry backoff")
advance(15); look(timeoutPlayer); advance(0.31)
check(#requests==6,"failed inspection can retry after backoff")
ready(timeoutPlayer)
check(GameTooltip.additions[1].right.text=="7 (cached)","successful retry replaces failure fallback")

local blockedPlayer=person("Unavailable","a"); blockedPlayer.uninspectable=true
look(blockedPlayer); advance(3.1)
check(#requests==6 and GameTooltip.additions[1].right.text=="Inspect to see GS","CanInspect rejection shows fallback and sends no request")
local farPlayer=person("Far","a"); farPlayer.outOfRange=true
look(farPlayer); advance(0.31)
check(#requests==6 and NS.gearCache[farPlayer.guid]==nil,"out-of-range player keeps fallback without a request or guessed total")
farPlayer.outOfRange=false; look(farPlayer); advance(0.5)
check(#requests==6,"range failure is not retried on every tooltip callback")
advance(15); look(farPlayer); advance(0.31); ready(farPlayer)
check(#requests==7 and GameTooltip.additions[1].right.text=="4 (cached)","range failure recovers when player is inspectable on a later hover")

local combatPlayer=person("Combat","c")
combat=true; look(combatPlayer); advance(10)
check(#requests==7 and GameTooltip.additions[1].right.text=="Inspect to see GS","combat blocks background inspection with the requested fallback")
combat=false; fire("PLAYER_REGEN_ENABLED"); advance(0.31)
check(#requests==8 and requests[8].guid==combatPlayer.guid,"ending combat retries the player whose tooltip remains open")
ready(combatPlayer)
local delayedCombat=person("DelayedCombat","a")
look(delayedCombat); unitCombat=true; advance(3.1)
check(#requests==8,"combat beginning during the hover delay cancels the request")
unitCombat=false; fire("PLAYER_REGEN_ENABLED"); advance(0.31); ready(delayedCombat)
check(#requests==9,"UnitAffectingCombat guard also recovers after combat")

local hidden=person("Hidden","c")
look(hidden); GameTooltip:Hide(); advance(3.1)
check(#requests==9 and NS.gearCache[hidden.guid]==nil,"closing a tooltip cancels its delayed background request")
local manualBlocked=person("ManualBlocked","c")
InspectFrame.unit="target"; look(manualBlocked); advance(3.1)
check(#requests==9,"pending manual inspection blocks background work even before its window opens")
InspectFrame.unit=nil; InspectFrame:Show(); look(manualBlocked); advance(3.1)
check(#requests==9,"visible manual inspection window blocks background requests")
InspectFrame:Hide(); advance(0.31)
check(#requests==10 and requests[10].guid==manualBlocked.guid,"closing manual inspection resumes background work for the current hover")
ready(manualBlocked)

local preempted, manualTarget=person("Preempted","a"),person("ManualTarget","strongHead")
look(preempted); advance(3.1)
check(#requests==11 and requests[11].guid==preempted.guid,"background request can be pending when manual inspection begins")
units.target=manualTarget; NotifyInspect("target"); InspectFrame.unit="target"
advance(6)
check(#requests==12 and NS.gearCache[preempted.guid]==nil,"manual NotifyInspect preempts pending background work without a later timeout retry")
ready(manualTarget)
check(GameTooltip.additions[1].right.text=="Inspect to see GS","manual result for a different GUID cannot replace hovered player's fallback")
check(NS.gearCache[manualTarget.guid].score==15,"manual inspections continue to populate their own cache")
GameTooltip:Hide(); InspectFrame.unit=nil; InspectFrame:Hide(); advance(0)

local otherAddon, afterOtherAddon=person("OtherAddon","a"),person("AfterOtherAddon","c")
units.target=otherAddon; NotifyInspect("target")
local beforeOtherAddon=#requests
look(afterOtherAddon); advance(0.5); ready(otherAddon); advance(2)
check(#requests==beforeOtherAddon,"other addon inspection receives priority without a visible inspect frame")
advance(2.6)
check(#requests==beforeOtherAddon+1 and requests[#requests].at-requests[beforeOtherAddon].at>=3,"background inspection resumes after another addon's request while respecting cooldown")
ready(afterOtherAddon)

local moved, nextHover=person("Moved","a"),person("NextHover","c")
look(moved); advance(0.31); units.focus=moved; look(nextHover)
ready(moved)
check(NS.gearCache[moved.guid].score==4,"completed background request finds the same GUID after its original unit token changes")
check(GameTooltip.additions[1].right.text=="Inspect to see GS","late result for previous hover does not display on the new player")
advance(3.1); ready(nextHover)
check(GameTooltip.additions[1].right.text=="7 (cached)","new hover is inspected after prior request completes")

local partialPlayer=person("Loading","c")
db.c.cached=false; look(partialPlayer); advance(3.1); ready(partialPlayer)
check(GameTooltip.additions[1].right.text=="Inspect to see GS","ready inspection with unloaded item stats does not publish an incomplete player score")
db.c.cached=true; fire("GET_ITEM_INFO_RECEIVED",1); advance(0)
check(GameTooltip.additions[1].right.text=="7 (cached)","item data loading refreshes background totals without opening inspect window")
local beforeExpiry=#requests
advance(59); fire("GET_ITEM_INFO_RECEIVED",2); advance(0)
advance(2); look(partialPlayer); advance(0.31)
check(#requests==beforeExpiry+1,"recalculating loaded stats does not postpone expiry of server inspection data")
ready(partialPlayer)
local naked=person("Naked")
look(naked); advance(3.1); ready(naked)
check(GameTooltip.additions[1].right.text=="0 (cached)","confirmed naked player has a known zero instead of failure fallback")

local errorPlayer=person("RequestError","a"); errorPlayer.notifyError=true
local beforeRequestError=#requests
look(errorPlayer); advance(3.1)
check(#requests==beforeRequestError and GameTooltip.additions[1].right.text=="Inspect to see GS","NotifyInspect error is contained and leaves the failure fallback")
local recovery=person("Recovery","a")
look(recovery); advance(3.1); ready(recovery)
check(GameTooltip.additions[1].right.text=="4 (cached)","a request API error does not leave subsequent players stuck pending")
check(clearCalls==0,"background completion, timeout, and preemption never clear another inspection's data")
ClearInspectPlayer(); recovery.waiting=true; fire("GET_ITEM_INFO_RECEIVED",1); advance(0)
check(GameTooltip.additions[1].right.text=="4 (cached)","engine inspection data cleared by another addon cannot overwrite a known cached score with missing inventory")

advance(61); look(alpha); advance(0.31)
check(GameTooltip.additions[1].right.text=="15 (cached)","older known score is shown while a refresh is still pending")
advance(5.1)
check(GameTooltip.additions[1].right.text=="Inspect to see GS","failed background refresh shows fallback even when an older score was cached")
ready(alpha)
check(GameTooltip.additions[1].right.text=="15 (cached)","manual or late successful inspection replaces a failed refresh fallback")

-- A real inspection can finish before the client has downloaded every item.
-- Keep the full item instances and finish their scores after the player moves
-- away or another inspection takes ownership of the live inventory data.
local loadRequests, loadActions = {}, {}
C_Item.RequestLoadItemDataByID=function(id)
    loadRequests[#loadRequests+1]=id
    local action=loadActions[id]
    if action then action(id) end
end
local function scorePair(prefix)
    local lowID, highID=prefix+69,prefix+146
    local low="|cffffffff|Hitem:" .. lowID .. ":0:0:0:0:0:0:0|h[Loaded item]|h|r"
    local high="|cffffffff|Hitem:" .. highID .. ":0:0:0:0:0:0:0|h[Loading item]|h|r"
    db[low]={id=lowID,raw={ITEM_MOD_STRENGTH_SHORT=138},level=0}
    db[high]={id=highID,raw={ITEM_MOD_STRENGTH_SHORT=292},level=0,cached=false}
    return low,high,highID
end
local function requestedItem(id)
    for _, requested in ipairs(loadRequests) do if requested==id then return true end end
    return false
end
local low215,high215,high215ID=scorePair(91000)
local delayed215=person("Delayed215"); delayed215.gear={[1]=low215,[2]=high215}
loadActions[high215ID]=function(id)
    C_Timer.After(0.2,function() db[high215].cached=true; fire("ITEM_DATA_LOAD_RESULT",id,true) end)
end
look(delayed215); advance(3.1); ready(delayed215)
local initial215=NS.gearSnapshots[delayed215.guid]
check(initial215.partial and initial215.score==69,"215-point player initially has only the loaded 69-point item available")
check(initial215.links[1]==low215 and initial215.links[2]==high215,"inspection retains both exact item links including the uncached item")
check(requestedItem(high215ID),"inspection explicitly requests the missing item's data by its native numeric ID")
check(GameTooltip.additions[1].right.text=="Inspect to see GS","69-point subtotal never appears as the 215-point player's tooltip score")
advance(0.3)
check(NS.gearCache[delayed215.guid].score==215 and not NS.gearSnapshots[delayed215.guid].partial,
    "item load result rebuilds the entire saved equipment score to 215")
check(#GameTooltip.additions==1 and GameTooltip.additions[1].right.text=="215 (cached)",
    "completed equipment data replaces fallback with the full score without duplicating the line")

local retryLow,retryHigh=scorePair(92000)
local retry215=person("Retry215"); retry215.gear={[1]=retryLow,[2]=retryHigh}
look(retry215); advance(3.1); ready(retry215)
C_Timer.After(0.4,function() db[retryHigh].cached=true end) -- Client update without an item-data event.
advance(1.5)
check(NS.gearCache[retry215.guid].score==215 and not NS.gearSnapshots[retry215.guid].partial,
    "bounded delayed rescan completes item loading even when no item-data event is emitted")
check(GameTooltip.additions[1].right.text=="215 (cached)","automatic delayed rescan refreshes the visible full score")

local movedLow,movedHigh,movedHighID=scorePair(93000)
local moved215=person("Moved215"); moved215.gear={[1]=movedLow,[2]=movedHigh}
look(moved215); advance(3.1); ready(moved215)
local newOwner=person("NewInspectionOwner","a")
look(newOwner); units.target=newOwner; NotifyInspect("target"); ready(newOwner)
db[movedHigh].cached=true; fire("ITEM_DATA_LOAD_RESULT",movedHighID,true); advance(0)
check(NS.gearCache[moved215.guid].score==215 and not NS.gearSnapshots[moved215.guid].partial,
    "saved links finish the old player's total after all their unit tokens and live inspect ownership are lost")
check(GameTooltip.additions[1].right.text=="4 (cached)","late item loading cannot put the previous player's 215 score on the current hover")

local missingLow,missingHigh=scorePair(94000); db[missingHigh].cached=true
local missing215=person("MissingSlot215"); missing215.gear={[1]=missingLow,[2]=missingHigh}; missing215.hidden={[2]=true}
look(missing215); advance(3.1); ready(missing215)
check(NS.gearSnapshots[missing215.guid].partial and GameTooltip.additions[1].right.text=="Inspect to see GS",
    "an occupied slot with a delayed item link also blocks publishing the incomplete score")
C_Timer.After(0.3,function() missing215.hidden=nil end)
advance(1.5)
check(NS.gearCache[missing215.guid].score==215 and not NS.gearSnapshots[missing215.guid].partial,
    "automatic inventory retry recovers a missing occupied-slot link while matching inspection data remains valid")

-- A refreshed snapshot may be incomplete even though an older complete score
-- is already cached. Retain the complete record without presenting the new
-- subtotal; the pending snapshot remains available to finish asynchronously.
loadActions[high215ID]=nil; db[high215].cached=false
look(delayed215); NotifyInspect("mouseover"); ready(delayed215)
check(NS.gearCache[delayed215.guid].score==215 and not NS.gearCache[delayed215.guid].partial,
    "a partial refresh cannot replace a previously completed cache entry with its 69-point subtotal")
check(NS.gearSnapshots[delayed215.guid].partial and NS.GetGearScore("mouseover").partial
    and GameTooltip.additions[1].right.text=="Inspect to see GS",
    "the newest incomplete refresh stays separate from the complete cache and still shows the requested fallback")
db[high215].cached=true; fire("TOOLTIP_DATA_UPDATE",high215ID); advance(0)
check(NS.gearSnapshots[delayed215.guid].score==215 and not NS.gearSnapshots[delayed215.guid].partial
    and GameTooltip.additions[1].right.text=="215 (cached)",
    "tooltip-data update completes a pending saved snapshot and restores the full score")

local staleLow,staleHigh=scorePair(95000)
local stalePartial=person("StalePartial"); stalePartial.gear={[1]=staleLow,[2]=staleHigh}
look(stalePartial); advance(3.1); ready(stalePartial)
local firstPartialRequest=#requests
advance(26); look(stalePartial); advance(3.1)
check(#requests>firstPartialRequest,"an unfinished partial record does not become a fresh cache that prevents future inspection")
check(GameTooltip.additions[1].right.text=="Inspect to see GS","failed or still-loading retry continues to hide its incomplete subtotal")
db[staleHigh].cached=true; ready(stalePartial)

db.sparseRemote={id=96001,raw={},level=15,quality=2,equipLoc="INVTYPE_TRINKET",lines={}}
local sparseRemote=person("SparseRemote"); sparseRemote.gear={[14]="sparseRemote"}
look(sparseRemote); advance(3.1); ready(sparseRemote)
check(NS.gearSnapshots[sparseRemote.guid].partial and GameTooltip.additions[1].right.text=="Inspect to see GS",
    "cached empty raw stats with missing tooltip lines do not publish an effect-only item as a completed zero")
db.sparseRemote.lines={{leftText="Fixture Item"},{leftText="Use: Grants 100 attack power for 10 sec."}}
fire("TOOLTIP_DATA_UPDATE",96001); advance(0)
check(NS.gearCache[sparseRemote.guid].score==7 and not NS.gearSnapshots[sparseRemote.guid].partial,
    "late tooltip effect data completes the same saved equipment snapshot")
check(GameTooltip.additions[1].right.text=="7 (cached)","late on-use effect data updates the player tooltip's full score")

-- A pending item-data download can overlap an equipment change. Tooltip
-- lines belong to the exact saved item instance, not just its worn slot.
local changedLow,changedHigh,changedHighID=scorePair(97000)
db[changedLow].raw={ITEM_MOD_STRENGTH_SHORT=129}; db[changedLow].level=15 -- Still exactly 69 points.
local oldUse="|cff1eff00|Hitem:97001:0:0:0:0:0:0:0|h[Old on-use item]|h|r"
db[oldUse]={id=97001,raw={},level=15,quality=2,equipLoc="INVTYPE_TRINKET",lines={
    {leftText="Old on-use item"},{leftText="Trinket"},
    {leftText="Use: Grants 100 attack power for 10 sec."},{leftText="Old flavor text"},
}}
local changedGear=person("ChangedItemWhileLoading"); changedGear.gear={[1]=oldUse,[2]=changedHigh}
look(changedGear); advance(3.1); ready(changedGear)
check(NS.gearSnapshots[changedGear.guid].partial and NS.gearSnapshots[changedGear.guid].score==7,
    "pending equipment snapshot initially contains the old effect-only item while another item loads")
changedGear.gear[1]=changedLow; db[changedHigh].cached=true
fire("ITEM_DATA_LOAD_RESULT",changedHighID,true); advance(0)
local changedRecord=NS.gearSnapshots[changedGear.guid]
check(not changedRecord.partial and changedRecord.links[1]==changedLow and changedRecord.itemScores[1]==69,
    "equipment change replaces the exact saved link and discards the previous item's richer tooltip lines")
check(changedRecord.score==215 and GameTooltip.additions[1].right.text=="215 (cached)",
    "completed rescan scores the new plain-stat item without inheriting the old on-use multiplier")

-- Hyperlink tooltips describe the local player's active set. A saved remote
-- snapshot must retain its captured two-piece set context after losing the
-- inspected unit, even when a newly loaded item's hyperlink shows four pieces.
local snapshotSet={}
for index=1,4 do
    local id=98000+index
    local link="|cffffffff|Hitem:" .. id .. ":0:0:0:0:0:0:0|h[Snapshot set item " .. index .. "]|h|r"
    snapshotSet[index]=link
    db[link]={id=id,raw={ITEM_MOD_STRENGTH_SHORT=210},level=0,setID=506,
        setName="Saved Remote Set",nativeSetText=true,usePlayerHeader=false}
end
units.player.gear={[1]=snapshotSet[1],[3]=snapshotSet[2],[5]=snapshotSet[3],[7]=snapshotSet[4]}
fire("PLAYER_EQUIPMENT_CHANGED",1); advance(0)
check(ownUI.label.text=="GS: 536","set snapshot regression uses a local four-piece set with complete scores")
db[snapshotSet[2]].cached=false
local remoteTwoSet=person("SavedTwoSet"); remoteTwoSet.gear={[1]=snapshotSet[1],[3]=snapshotSet[2]}
look(remoteTwoSet); advance(3.1); ready(remoteTwoSet)
local pendingSet=NS.gearSnapshots[remoteTwoSet.guid]
check(pendingSet.partial and pendingSet.sets["id:506"].count==2 and pendingSet.sets["id:506"].active,
    "pending remote snapshot captures its active native two-piece bonus before the second item's data loads")
local setOwner=person("SetInspectionOwner","a")
look(setOwner); units.target=setOwner; NotifyInspect("target"); ready(setOwner)
db[snapshotSet[2]].cached=true; fire("ITEM_DATA_LOAD_RESULT",98002,true); advance(0)
local remoteSetRecord=NS.gearSnapshots[remoteTwoSet.guid]
check(not remoteSetRecord.partial and remoteSetRecord.score==242,
    "saved remote set finishes at 242 after losing all unit tokens despite local hyperlink's four-piece context")
check(remoteSetRecord.itemScores[1]==105 and remoteSetRecord.setBonusScores[1]==16
    and remoteSetRecord.itemScores[3]==105 and remoteSetRecord.setBonusScores[3]==16,
    "both remote items retain their own two-piece set bonus when rescored from saved links")
check(remoteSetRecord.sets["id:506"].active and remoteSetRecord.sets["id:506"].count==2
    and GameTooltip.additions[1].right.text=="4 (cached)",
    "loaded set snapshot preserves remote membership without changing the currently hovered player's score")

-- Dynamic profiles and the actual native settings registration contract.
local registered, dropdowns, categoryCount = {}, {}, 0
Settings={VarType={String="string"}}
function Settings.RegisterVerticalLayoutCategory(name)
    categoryCount=categoryCount+1
    return {name=name,GetID=function() return 123 end}
end
function Settings.RegisterProxySetting(category, variable, kind, name, default, getter, setter)
    check(category.name=="FossieGearScore" and kind=="string" and default=="both", "native proxy setting arguments")
    local setting={name=name,get=getter,set=setter}; registered[variable]=setting; return setting
end
function Settings.CreateControlTextContainer()
    return {Add=function(self,value,label) self[#self+1]={value=value,label=label} end,GetData=function(self) return self end}
end
function Settings.CreateDropdown(category,setting,options) dropdowns[#dropdowns+1]={setting=setting,options=options()} end
function Settings.RegisterAddOnCategory(category) check(category:GetID()==123,"native addon category registered") end
function Settings.OpenToCategory(id) Settings.opened=id end
UnitClass=function(unit) return "Class",units[unit] and units[unit].class end
units.player.class="MAGE"
FossieGearScoreDB=nil
NS.gearUIError=nil
fire("ADDON_LOADED","FossieGearScore"); advance(0)
check(categoryCount==1 and #dropdowns==3,"exactly three native dropdowns")
for _, dropdown in ipairs(dropdowns) do
    check(#dropdown.options==4 and dropdown.options[1].label=="Both Normal and Dynamic"
        and dropdown.options[4].label=="None","dropdown has all requested choices")
end
for _,surface in ipairs({"character","hover","items"}) do
    check(NS.GetDisplayMode(surface)=="both","new installations default to both")
end
check(NS.DYNAMIC_WEIGHTS~=NS.WEIGHTS,"dynamic baseline is a separate table")
for stat,weight in pairs(NS.WEIGHTS) do check(NS.DYNAMIC_WEIGHTS[stat]==weight,"initial dynamic weight matches " .. stat) end
check(ownUI.label.text=="GS: 536\nDGS: 536","both panel totals initially match and include sets")
NS.OpenSettings(); check(Settings.opened==123,"slash settings target opens registered native category")
registered.FossieGearScore_character.set("dynamic")
check(ownUI.label.text=="DGS: 536" and ownUI.overlay.size[2]==18,"dynamic-only panel applies immediately")
registered.FossieGearScore_character.set("none")
check(not ownUI.overlay:IsShown(),"None hides panel overlay")
registered.FossieGearScore_character.set("normal")
check(ownUI.label.text=="GS: 536" and ownUI.overlay:IsShown(),"normal restores existing panel")
check(NS.GetDisplayMode("hover")=="both" and NS.GetDisplayMode("items")=="both","surface preferences are independent")
local saved=FossieGearScoreDB
fire("PLAYER_LOGIN"); advance(0)
check(FossieGearScoreDB==saved and saved.character=="normal" and categoryCount==1,"login preserves settings and avoids duplicate registration")
check(not NS.SetDisplayMode("character","invalid") and saved.character=="normal","invalid choice cannot corrupt saved preference")

-- Change weights only inside the fixture to prove class isolation before balancing.
NS.DYNAMIC_CLASS_WEIGHTS.MAGE.Strength=0
NS.DYNAMIC_CLASS_WEIGHTS.WARRIOR.Intellect=0
local mage=NS.ScoreItem("a",nil,{deferSet=true})
check(mage.classToken=="MAGE" and mage.score==4 and mage.dynamicScore==3,"local items use player's independent class profile")
check(NS.WEIGHTS.Strength==2 and NS.DYNAMIC_WEIGHTS.Strength==2,"class override never mutates either baseline")
local warrior=NS.ScoreItem("b",nil,{deferSet=true,classToken="WARRIOR"})
check(warrior.score==7 and warrior.dynamicScore==3,"explicit owner class overrides local class")
local shared=NS.CalculateScore({["Spell Damage"]=10,Healing=30,_sharedSpellPower=10},{["Spell Damage"]=1,Healing=2})
check(shared==60,"shared damage/healing dedup uses dynamic weights rather than normal weights")
local dynamicSet=NS.SumEquippedItems("player")
check(dynamicSet.score==536 and dynamicSet.dynamicScore==4 and dynamicSet.dynamicSetBonusScores[1]==1,
    "dynamic set extra uses dynamic intrinsic score and retains minimum-one failsafe")
local remoteDynamic=person("DynamicWarrior","b"); remoteDynamic.class="WARRIOR"
look(remoteDynamic); advance(3.1); ready(remoteDynamic)
check(#GameTooltip.additions==2 and GameTooltip.additions[1].right.text=="7 (cached)"
    and GameTooltip.additions[2].right.text=="3 (cached)","hover displays separate normal and owner-class dynamic totals")
local snapshot=NS.gearSnapshots[remoteDynamic.guid]
units.mouseover=nil; units.target=nil; units.focus=nil
local rescored=NS.RescoreGearSnapshot(snapshot)
check(rescored.classToken=="WARRIOR" and rescored.dynamicScore==3,"offline snapshot retains wearer class when tokens disappear")
for _, mode in ipairs({"normal","dynamic","none","both"}) do
    NS.SetDisplayMode("hover",mode)
    look(remoteDynamic)
    local expected=mode=="both" and 2 or mode=="none" and 0 or 1
    check(#GameTooltip.additions==expected,"hover row count follows " .. mode)
    if mode=="dynamic" then check(GameTooltip.additions[1].label=="DGS:","dynamic-only hover label") end
end
local disabled=person("DisabledHover","a")
NS.SetDisplayMode("hover","none")
local beforeDisabled=#requests
look(disabled); advance(10)
check(#requests==beforeDisabled and #GameTooltip.additions==0,"None hover sends no background inspection")
NS.SetDisplayMode("hover","both")
check(GameTooltip.refreshRequested,"enabling hover requests immediate native rebuild")
look(disabled); NS.SetDisplayMode("hover","none"); advance(10)
check(#requests==beforeDisabled,"disabling hover cancels queued background inspection")

-- Item rows, ordering, live refresh, comparisons and cosmetic hiding.
local itemTooltip=frame("DynamicItemTooltip",nil,nil,true)
itemTooltip.link=snapshotSet[1]
itemTooltip.data={type=0,lines=itemLines(itemTooltip.link,"player")}
itemTooltip.info={getterName="GetHyperlink"}
local function drawItem(mode)
    NS.SetDisplayMode("items",mode)
    itemTooltip:ClearLines()
    for _,fn in ipairs(callbacks[0]) do fn(itemTooltip,itemTooltip.data) end
end
drawItem("both")
check(#itemTooltip.additions==4 and itemTooltip.additions[1].label=="Item Score"
    and itemTooltip.additions[2].label=="Set Bonus Score"
    and itemTooltip.additions[3].label=="Dynamic Item Score"
    and itemTooltip.additions[4].label=="Dynamic Set Bonus Score","set tooltip places dynamic scores below normal rows")
check(itemTooltip.additions[3].right.text=="0" and itemTooltip.additions[4].right.text=="1","dynamic tooltip separates intrinsic and active-set values")
drawItem("dynamic"); check(#itemTooltip.additions==2 and itemTooltip.additions[1].label=="Dynamic Item Score","dynamic-only set rows")
drawItem("normal"); check(#itemTooltip.additions==2 and itemTooltip.additions[1].label=="Item Score","normal-only set rows")
drawItem("none"); check(#itemTooltip.additions==0,"None hides all addon item rows")
itemTooltip.refreshRequested=false; NS.SetDisplayMode("items","both")
check(itemTooltip.refreshRequested,"None-to-both rebuilds visible item tooltip immediately")
units.player.gear={[1]="a"}
itemTooltip.link="c"; itemTooltip.data={type=0,lines=itemLines("c","player")}
itemTooltip.info={getterName="GetBagItem",getterArgs={0,1}}
drawItem("both")
check(itemTooltip.additions[1].right.text=="7 |cff00ff00(+3)|r"
    and itemTooltip.additions[2].right.text=="4 |cff00ff00(+1)|r","bag differences independently compare both scoring profiles")
db.shirt.equipLoc="INVTYPE_BODY"
itemTooltip.link="shirt"; itemTooltip.data={type=0,lines=itemLines("shirt","player")}
drawItem("both"); check(#itemTooltip.additions==0,"plain shirt hides both item scores")
fire("PLAYER_EQUIPMENT_CHANGED",1); advance(0)
NS.SetDisplayMode("character","both")
check(ownUI.label.text=="GS: 4\nDGS: 3","equipment changes refresh both panel totals")
units.target=remoteDynamic; InspectFrame.unit="target"
NS.RefreshGearDisplay()
local dynamicInspect=NS.gearPanels[InspectPaperDollFrame or InspectFrame]
check(dynamicInspect.label.text:find("DGS: 3",1,true)~=nil,"inspect panel shows wearer's dynamic total")
local oldComparison=C_TooltipComparison
C_TooltipComparison={GetItemComparisonInfo=function() return {method=0,item={hyperlink="a"}} end}
local candidate=NS.ScoreItem("c",nil,{deferSet=true})
check(NS.GetItemScoreDifference(candidate)==3 and NS.GetDynamicItemScoreDifference(candidate)==1,
    "native comparison computes each profile independently")
C_TooltipComparison=oldComparison
NS.SetDisplayMode("hover","both")
local partialDynamic=person("PartialDynamic","c"); partialDynamic.class="WARRIOR"
db.c.cached=false
look(partialDynamic); ready(partialDynamic)
check(#GameTooltip.additions==2 and GameTooltip.additions[1].right.text=="Inspect to see GS"
    and GameTooltip.additions[2].right.text=="Inspect to see GS","neither hover profile leaks a partial subtotal")
db.c.cached=true; ready(partialDynamic)
check(GameTooltip.additions[1].right.text=="7 (cached)" and GameTooltip.additions[2].right.text=="7 (cached)",
    "both hover scores recover after missing item data arrives")
local reloadNS={}
assert(loadfile("Settings.lua"))("FossieGearScore",reloadNS)
events[#events].OnEvent(events[#events],"ADDON_LOADED","FossieGearScore")
check(reloadNS.GetDisplayMode("character")==FossieGearScoreDB.character
    and reloadNS.GetDisplayMode("items")=="both","new addon namespace reads persisted saved preferences")
check(NS.gearUIError==nil,"dynamic display paths report no guarded errors")

print("PASS: " .. count .. " equipped-total/panel/player-tooltip integration checks (" .. _VERSION .. ")")
