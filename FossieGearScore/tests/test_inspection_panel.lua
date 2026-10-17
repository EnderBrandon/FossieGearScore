-- Full Lua 5.1 integration: real scoring, inspection queue, talents, snapshots
-- and panel, with deterministic native API, menu and frame doubles.
local NS,count={},0
local function check(ok,why) assert(ok,why); count=count+1 end
local time,timers,frames,menus,units,db,requests=100,{},{},{},{},{},{}
local inspected,combat,inventoryReads,scoreCalls=nil,false,0,0
local tooltipCallbacks={}
local function region()
    local r={}
    function r:SetText(text) self.text=text end
    function r:GetText() return self.text end
    function r:SetPoint(...) self.point={...} end
    function r:ClearAllPoints() self.point=nil end
    function r:SetSize(w,h) self.width,self.height=w,h end
    function r:SetWidth(w) self.width=w end
    function r:SetHeight(h) self.height=h end
    function r:SetAllPoints() end
    function r:SetJustifyH() end
    function r:SetJustifyV() end
    function r:SetTextColor(...) self.color={...} end
    function r:SetShadowColor() end
    function r:SetShadowOffset() end
    function r:SetTexture(texture) self.texture=texture end
    function r:SetTexCoord() end
    function r:SetColorTexture() end
    function r:GetStringWidth() return #(self.text or "")*6 end
    function r:GetStringHeight() return 16 end
    return r
end
CreateFrame=function(_,name,parent,template)
    local f=region(); f.name,f.parent,f.template=name,parent,template
    f.shown,f.scripts,f.hooks,f.events=true,{},{},{}
    function f:SetScript(event,fn) self.scripts[event]=fn end
    function f:HookScript(event,fn)
        local old=self.hooks[event]
        self.hooks[event]=function(...) if old then old(...) end; fn(...) end
    end
    function f:Run(event,...)
        if self.scripts[event] then self.scripts[event](self,...) end
        if self.hooks[event] then self.hooks[event](self,...) end
    end
    function f:RegisterEvent(event) self.events[event]=true end
    function f:CreateFontString() return region() end
    function f:CreateTexture() return region() end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:Show() local was=self.shown; self.shown=true; if not was then self:Run("OnShow") end end
    function f:Hide() local was=self.shown; self.shown=false; if was then self:Run("OnHide") end end
    function f:SetFrameStrata(strata) self.strata=strata end
    function f:SetClampedToScreen(value) self.clamped=value end
    function f:SetMovable(value) self.movable=value end
    function f:EnableMouse() end
    function f:RegisterForDrag(...) self.drags={...} end
    function f:StartMoving() self.moving=true end
    function f:StopMovingOrSizing() self.moving=false end
    function f:SetBackdrop(backdrop) self.backdrop=backdrop end
    function f:SetBackdropColor() end
    function f:SetBackdropBorderColor(...) self.border={...} end
    function f:GetName() return self.name end
    function f:SetOwner(owner,anchor) self.owner,self.anchor=owner,anchor end
    function f:GetOwner() return self.owner end
    function f:SetHyperlink(link)
        self.link=link; self:ClearLines()
        self.data={type=0,id=db[link].id,hyperlink=link,lines=db[link].lines}
        for _,fn in ipairs(tooltipCallbacks[0] or {}) do fn(self,self.data) end
    end
    function f:ClearLines() self.additions={} end
    function f:AddDoubleLine(left,right) self.additions[#self.additions+1]={left,right} end
    function f:GetPrimaryTooltipData() return self.data end
    function f:GetPrimaryTooltipInfo() return {getterName="GetHyperlink",getterArgs={self.link}} end
    frames[#frames+1]=f
    if name then _G[name]=f end
    return f
end
UIParent=CreateFrame("Frame","UIParent")
GameTooltip=CreateFrame("GameTooltip","GameTooltip")
UISpecialFrames={}; SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
Menu={ModifyMenu=function(tag,fn)
    assert(not menus[tag],"duplicate menu hook"); menus[tag]=fn
end}
local function fire(event,...)
    for _,f in ipairs(frames) do if f.events[event] then f:Run("OnEvent",event,...) end end
end
C_Timer={After=function(delay,fn) timers[#timers+1]={at=time+delay,fn=fn} end}
local function advance(seconds)
    local stop=time+seconds
    for i=1,10000 do
        local index,at
        for j,t in ipairs(timers) do if t.at<=stop and (not at or t.at<at) then index,at=j,t.at end end
        if not index then time=stop; return end
        local t=table.remove(timers,index); time=t.at; t.fn()
    end
    error("timer loop")
end
GetTime=function() return time end
GetLocale=function() return "enUS" end
UnitGUID=function(unit) return units[unit] and units[unit].guid end
UnitIsPlayer=function(unit) return units[unit] and units[unit].player~=false or false end
UnitName=function(unit) return units[unit] and units[unit].name end
UnitLevel=function(unit) return units[unit] and units[unit].level end
UnitClass=function(unit)
    local u=units[unit]; if u then return u.className,u.class end
end
UnitRace=function() return "Night Elf","NightElf" end
UnitTokenFromGUID=function(guid)
    for token,u in pairs(units) do if u.guid==guid then return token end end
end
InCombatLockdown=function() return combat end
UnitAffectingCombat=function() return combat end
CanInspect=function(unit) return units[unit] and units[unit].inspectable~=false or false end
CheckInteractDistance=function(unit) return units[unit] and units[unit].inRange~=false or false end
NotifyInspect=function(unit) requests[#requests+1]={unit=unit,guid=UnitGUID(unit)} end
ClearInspectPlayer=function() inspected=nil end
hooksecurefunc=function(object,key,fn)
    if type(object)=="string" then
        local name,callback=object,key; local old=_G[name]
        _G[name]=function(...) old(...); callback(...) end
    else
        local old=object[key]; object[key]=function(...) old(...); fn(...) end
    end
end
GetTalentTabInfo=function(index,inspect)
    local u=inspect and inspected or units.player
    if not u or not u.talents then return end
    return "Tree " .. index,0,u.talents[index]
end
GetInventoryItemLink=function(unit,slot)
    inventoryReads=inventoryReads+1
    local u=units[unit]
    if u and not (u.hidden and u.hidden[slot]) then return u.gear[slot] end
end
GetInventoryItemTexture=function(unit,slot) return units[unit] and units[unit].gear[slot] and 100 end
Enum={TooltipDataType={Item=0,Unit=2},TooltipDataLineType={ItemEnchantmentPermanent=15}}
TooltipDataProcessor={AddTooltipPostCall=function(kind,fn)
    tooltipCallbacks[kind]=tooltipCallbacks[kind] or {}; table.insert(tooltipCallbacks[kind],fn)
end}
TooltipUtil={GetDisplayedItem=function(t) return "Item",t.link end}
C_Item={
    GetItemInfoInstant=function(link)
        local i=db[link]; if not i or i.noInstant then return end
        return i.id,"Equipment","Fixture",i.loc,i.icon or 100, i.itemClass or 4,i.subclass or 1
    end,
    IsItemDataCachedByID=function(link) return db[link] and not db[link].pending end,
    GetItemStats=function(link) local i=db[link]; return i and not i.pending and i.raw end,
    GetItemInfo=function(link)
        local i=db[link]; if not i or i.pending or i.noName then return end
        return i.name,link,3,30,25,"Equipment","Fixture",1,i.loc,i.icon or 100,0,4,i.subclass or 1
    end,
    GetDetailedItemLevelInfo=function(link) return db[link] and not db[link].pending and 30 or nil end,
    RequestLoadItemDataByID=function() end,
}
C_TooltipInfo={
    GetHyperlink=function(link) local i=db[link]; return i and {lines=i.pending and {} or i.lines} end,
    GetInventoryItem=function(unit,slot)
        local u=units[unit]; local link=u and u.gear[slot]
        return link and C_TooltipInfo.GetHyperlink(link)
    end,
}
local function item(id,loc,enchant,options)
    local link="item:" .. id .. ":" .. (enchant or 0) .. ":0:0:0:0:0:0"
    local i=options or {}; i.id,i.loc,i.name=id,loc,"Fixture " .. id
    i.raw=i.raw or {ITEM_MOD_STAMINA_SHORT=10,ITEM_MOD_INTELLECT_SHORT=10}
    i.lines=i.lines or {{leftText=i.name},{leftText="+10 Stamina"},{leftText="+10 Intellect"}}
    db[link]=i
    db[link:gsub("(item:%d+:)[^:]*","%10",1)]=i
    return link
end
local function person(name,class,gear,talents)
    return {name=name,guid="Player-" .. name,class=class,className=class=="DRUID" and "Druid" or class,
        level=30,gear=gear or {},talents=talents or {26,0,0}}
end
local chest=item(1001,"INVTYPE_CHEST",8481) -- Medium kit: tier 1 attachment.
local boots=item(1002,"INVTYPE_FEET",0)
local head=item(1003,"INVTYPE_HEAD",803,{raw={ITEM_MOD_STAMINA_SHORT=20,ITEM_MOD_INTELLECT_SHORT=20,ITEM_MOD_SPELL_HEALING_DONE=30}})
-- Head enchant 803 is not valid for this slot: known installation, unsupported tier.
local weapon=item(1004,"INVTYPE_2HWEAPON",803)
local bracer=item(1005,"INVTYPE_WRIST",8208)
local ring=item(1006,"INVTYPE_FINGER",0)
local trinket=item(1007,"INVTYPE_TRINKET",0)
local wand=item(1008,"INVTYPE_RANGEDRIGHT",0,{subclass=19,itemClass=2})
local relic=item(1009,"INVTYPE_RELIC",0)
local bow=item(1010,"INVTYPE_RANGED",33,{subclass=2,itemClass=2})
local shield=item(1011,"INVTYPE_SHIELD",66)
local offhand=item(1012,"INVTYPE_HOLDABLE",0)
units.player=person("Self","DRUID",{[5]=chest,[8]=boots,[16]=weapon},{0,0,26})
local alice=person("Alice","DRUID",{[1]=head,[5]=chest,[8]=boots,[9]=bracer,[11]=ring,[13]=trinket,[16]=weapon,[18]=wand})
local bob=person("Bob","HUNTER",{[5]=chest,[16]=weapon,[18]=bow})
units.target=alice; units.focus=alice
for file in io.lines("FossieGearScore.toc") do
    if file:match("%.lua$") then assert(loadfile(file))("FossieGearScore",NS) end
end
local calculate=NS.CalculateItemScore
NS.CalculateItemScore=function(...) scoreCalls=scoreCalls+1; return calculate(...) end
local function ready(u)
    inspected=u; fire("INSPECT_READY",u.guid); advance(0)
end
local function root()
    local r={buttons={},dividers=0}
    function r:CreateDivider() self.dividers=self.dividers+1 end
    function r:CreateButton(text,fn) self.buttons[#self.buttons+1]={text=text,click=fn} end
    return r
end

check(NS.VERSION=="1.1.0","development version incremented once")
for _,tag in ipairs({"SELF","PLAYER","ENEMY_PLAYER","PARTY","RAID_PLAYER"}) do
    check(type(menus["MENU_UNIT_" .. tag])=="function","Forever player tag registered: " .. tag)
end
check(not menus.MENU_UNIT_TARGET,"NPC target tag is not used for player integration")
fire("ADDON_LOADED","OtherAddon"); NS.AttachGearScorePortraitMenu()
check(not NS.inspectionPanel,"panel is lazy and menu registration is idempotent")
local menu=root(); menus.MENU_UNIT_PLAYER(nil,menu,{fromTargetFrame=true,unit="target"})
check(#menu.buttons==1 and menu.buttons[1].text=="GearScore","target portrait gets one GearScore option")
local other=root(); menus.MENU_UNIT_PLAYER(nil,other,{unit="target"})
check(#other.buttons==0,"unrequested menus are left untouched")
units.npc={name="NPC",guid="Creature-NPC",player=false,gear={}}
local npc=root(); menus.MENU_UNIT_PLAYER(nil,npc,{fromTargetFrame=true,unit="npc"})
check(#npc.buttons==0 and not NS.OpenGearScoreInspection("npc"),"NPCs cannot open a player panel")

-- Freeze the menu selection, even if the target changes before clicking it.
units.target=bob; menu.buttons[1].click()
local panel=NS.inspectionPanel
check(panel.model.guid==alice.guid and panel.player.text=="Alice","menu click keeps the captured player's identity")
check(panel.movable and panel.clamped and panel.backdrop.edgeFile and panel.strata=="DIALOG","native window is movable, clamped and bordered")
check(UISpecialFrames[1]==panel.name and panel.refreshButton,"window supports Escape and explicit refresh")
check(panel.gs.text=="GS: Loading..." and panel.model.spec=="Spec unknown","initial inspection never invents a zero or spec")
advance(0.31)
check(#requests==1 and requests[1].guid==alice.guid,"panel reuses the background queue for the captured player")
ready(bob)
check(panel.model.guid==alice.guid and panel.gs.text=="GS: Loading...","another player's ready event cannot fill this panel")
ready(alice)
check(panel.model.complete and panel.model.spec=="Balance" and panel.model.talents=="26/0/0","ready data reuses actual detected spec and split")
check(panel.model.gs~="Loading..." and panel.model.dgs~="Unavailable","matching inspection fills both scores")
check(panel.model.highlights[1].link==weapon and not panel.model.highlights[2].link
    and panel.model.highlights[2].name:find("two%-handed"),"two-handed weapon suppresses off-hand highlight")
check(panel.model.highlights[3].link==head,"highest armor is selected by existing intrinsic GS")
local coverage=panel.model.coverage
check(coverage.eligible==5 and coverage.enchanted==4 and coverage.missing==1,
    "coverage includes supported armor kits and excludes rings, trinkets and wands")
check(coverage.unsupported==1 and coverage.unknown==0,"wrong-slot enhancement is separate from missing enchants")
check(panel.model.enchantmentDetails:find("1 missing",1,true) and panel.model.enchantmentDetails:find("1 unsupported",1,true),
    "missing and unsupported counts are visibly distinct")
check(panel.model.tiers:find("Tier 1: 1",1,true) and not panel.model.summary:find("low tier",1,true),
    "catalogue tiers appear without invented quality thresholds")
check(panel.model.summary:find("mixed enchant tiers",1,true),"mixed known tiers are summarized factually")
panel.rows[1]:Run("OnEnter")
check(GameTooltip.link==weapon and GameTooltip.owner==panel.rows[1],"highlight opens the native full-instance item tooltip")
panel.rows[1]:Run("OnLeave")
check(not GameTooltip:IsShown(),"leaving a highlight closes only its owned tooltip")
panel.rows[3]:Run("OnEnter")
local hovered=NS.GetInspectionTooltipResult(GameTooltip,head)
check(hovered and hovered~=panel.model.record.itemDetails[1] and hovered.dynamicProfile.classToken==alice.class,
    "native highlight tooltips reuse a copy of the selected wearer's scored result")
check(NS.last and NS.last.dynamicProfile==panel.model.record.dynamicProfile and not NS.last.dynamicProfile.heal,
    "real tooltip decoration uses the selected Balance profile instead of the local Restoration profile")
check(NS.last.dynamicScore==panel.model.highlights[3].dynamicScore and GameTooltip.additions[1][1]=="Item Score",
    "native item tooltip preserves normal addon rows and agrees with the panel item score")
hovered.scoreDifference=123
check(not panel.model.record.itemDetails[1].scoreDifference,"tooltip diagnostic fields cannot mutate the equipped snapshot")
check(NS.GetInspectionTooltipResult(GameTooltip,chest)==nil,"tooltip context cannot borrow a different equipped link")
panel.rows[3]:Run("OnLeave")
local reads,calculations,requestCount=inventoryReads,scoreCalls,#requests
for i=1,100 do NS.RefreshInspectionPanel() end
advance(0)
check(inventoryReads==reads and scoreCalls==calculations and #requests==requestCount,
    "100 panel redraws coalesce without inventory scans, rescoring or inspect requests")
advance(16)
check(#requests==requestCount,"completed panel has no periodic inspection traffic")
local unchanged=panel.model
for i=1,100 do fire("GET_ITEM_INFO_RECEIVED",900000+i,true) end
advance(0)
check(panel.model==unchanged and inventoryReads==reads and scoreCalls==calculations,
    "100 unrelated item-load events do not redraw the panel, scan gear or recalculate scores")

local who=NS.CaptureInspectionSelection("focus")
units.focus=nil
local model=NS.BuildInspectionPanelData(who)
check(model.guid==alice.guid and model.complete,"frozen snapshot remains usable after all unit tokens disappear")
NS.SetEnchantmentDisplayMode("character","separate"); advance(0)
check(panel.gs.text:find(" + ",1,true),"panel totals share the existing separate-enchantment setting")
NS.SetEnchantmentDisplayMode("character","combined"); advance(0)
check(panel.gs.text:find(" + ?",1,true),"combined totals preserve the existing unknown-enchantment marker")
local normal=NS.gearSnapshots[alice.guid].score
check(panel.model.gs==tostring(normal+NS.gearSnapshots[alice.guid].enchantmentScore) .. " + ?","panel combined GS matches the existing total")
NS.SetTalentOverride(3,alice.guid); advance(0)
check(panel.model.spec=="Balance" and panel.status.text:find("Restoration (override)",1,true),
    "actual spec stays distinct from an existing DGS preview override")
NS.SetTalentOverride(0,alice.guid); advance(0)

-- Hunter weapons, one-handed/off-hand equipment, and unknown spec handling.
NS.OpenGearScoreInspection("target"); ready(bob)
check(panel.model.guid==bob.guid and #panel.model.highlights==2 and panel.model.highlights[1].link==bow,
    "hunters highlight ranged weapon and highest armor instead of melee slots")
check(panel.height==498 and not panel.rows[3]:IsShown(),"hunter layout compacts without leaving an empty weapon row")
local single=item(1013,"INVTYPE_WEAPONMAINHAND",0)
local cara=person("Cara","PALADIN",{[5]=chest,[16]=single,[17]=shield},{0,26,0})
units.target=cara; NS.OpenGearScoreInspection("target"); ready(cara)
check(panel.model.highlights[2].link==shield,"shield appears in the off-hand highlight")
cara.gear[17]=offhand; ready(cara)
check(panel.model.highlights[2].link==offhand,"held-in-off-hand items are highlighted and counted by their own rules")
cara.gear[17]=nil; ready(cara)
check(panel.model.highlights[2].name=="Empty slot","known empty off-hand is separate from loading data")
cara.talents={0,13,13}; ready(cara)
check(panel.model.spec==NS.talentProfiles[cara.guid].name and panel.model.spec:find("Hybrid:",1,true)
    and panel.model.talents=="0/13/13","hybrids retain the existing classification and exact talent split")
cara.talents=nil; ready(cara)
check(panel.model.spec=="Spec unknown" and panel.model.talents=="Talents unknown" and panel.model.dgs=="Unavailable",
    "missing talents do not borrow another player's spec or display zero DGS")
cara.talents={0,0,0}; ready(cara)
check(panel.model.spec=="Spec unknown" and panel.model.talents=="0/0/0" and panel.model.dgs=="Unavailable",
    "confirmed no talents preserves the addon's no-DGS rule")
cara.level=9; cara.talents={26,0,0}; ready(cara)
check(panel.model.spec=="Spec unknown" and panel.model.talents=="0/0/0" and panel.model.dgs=="Unavailable",
    "under-ten players have no talent points and do not receive invented talent roles")
cara.level=30; cara.talents={26,0,0}

local delayed=item(1014,"INVTYPE_CHEST",0,{pending=true})
local dan=person("Dan","DRUID",{[5]=delayed,[16]=single})
units.target=dan; NS.OpenGearScoreInspection("target"); ready(dan)
check(not panel.model.complete and panel.model.gs=="Loading..." and panel.model.coverage.missing==1,
    "pending item data never becomes zero GS or a missing enchant")
check(panel.model.coverage.unknown==1,"known eligible loading slot has unknown enhancement data")
units.target=bob
db[delayed].pending=false
fire("GET_ITEM_INFO_RECEIVED",1014,true); advance(0.51)
check(panel.model.guid==dan.guid and panel.model.complete,"late item data completes the original player's snapshot after target change")
check(panel.model.coverage.missing==2,"loaded explicit zero IDs can now be classified as missing")
local unknown=item(1015,"INVTYPE_CHEST",999999)
dan.gear[5]=unknown; units.target=dan; ready(dan)
check(panel.model.coverage.unsupported==1 and panel.model.coverage.enchanted==1,
    "unknown applied ID counts as installed while its tier stays unsupported")
db[unknown].noInstant=true; NS.RefreshInspectionPanel(); advance(0)
check(panel.model.coverage.unresolved==0,"known item equip location survives unavailable instant metadata")
local savedEnum=Enum.TooltipDataLineType.ItemEnchantmentPermanent
Enum.TooltipDataLineType.ItemEnchantmentPermanent=nil
NS.RefreshInspectionPanel(); advance(0)
check(panel.model.coverage.unknown==1 and panel.model.coverage.missing==0,
    "an unavailable permanent-line API cannot claim the zero-ID weapon is missing an enhancement")
Enum.TooltipDataLineType.ItemEnchantmentPermanent=savedEnum

local naked=person("Naked","DRUID",{})
units.target=naked; NS.OpenGearScoreInspection("target"); ready(naked)
check(panel.model.gs=="Loading..." and not panel.model.complete and panel.model.enchantments=="Enhancement data unavailable",
    "an empty inspection buffer never implies zero gear or poor equipment")
local lost=person("Lost","DRUID",{[5]=chest})
units.target=lost; NS.OpenGearScoreInspection("target"); units.target=bob
advance(16)
check(panel.model.guid==lost.guid and panel.status.text:find("Player unavailable",1,true),"lost units remain selected with a clear unavailable state")
check(panel.model.summary:find("incomplete",1,true),"unavailable data never generates a negative equipment assessment")
local far=person("Far","DRUID",{[5]=chest}); far.inRange=false
units.target=far; NS.OpenGearScoreInspection("target"); advance(16)
check(panel.status.text:find("unavailable",1,true) and panel.model.gs=="Unavailable","out-of-range inspection fails without a fake score")
local timed=person("Timed","DRUID",{[5]=chest})
units.target=timed; NS.OpenGearScoreInspection("target"); advance(16)
check(panel.status.text:find("unavailable",1,true) and not panel.model.complete,"timeout remains unavailable rather than becoming empty equipment")
local waiting=person("Waiting","DRUID",{[5]=chest})
units.target=waiting; combat=true; local prior=#requests
NS.OpenGearScoreInspection("target"); advance(2)
check(#requests==prior and panel.status.text:find("combat",1,true),"combat blocks inspection through the existing queue")
combat=false; fire("PLAYER_REGEN_ENABLED"); advance(3.1)
check(#requests==prior+1 and requests[#requests].guid==waiting.guid,"combat end resumes the same selected player")
ready(waiting)
check(panel.model.summary=="Fully enchanted.","complete kit-only equipment may truthfully be fully enchanted")
panel:Hide(); local closedRequests=#requests
advance(30)
check(#requests==closedRequests,"closing the panel cancels all of its delayed work")
check(not panel.scripts.OnUpdate,"panel has no per-frame polling")
check(NS.IsPermanentEnhancementEligible("INVTYPE_RELIC",1)==false
    and NS.IsPermanentEnhancementEligible("INVTYPE_RANGEDRIGHT",19)==false
    and NS.IsPermanentEnhancementEligible("INVTYPE_RANGED",2)==true
    and NS.IsPermanentEnhancementEligible("INVTYPE_RANGEDRIGHT",3)==true
    and NS.IsPermanentEnhancementEligible("INVTYPE_RANGEDRIGHT",18)==true
    and NS.IsPermanentEnhancementEligible("INVTYPE_RANGEDRIGHT",nil)==nil,
    "scope eligibility distinguishes bows, guns, crossbows, wands, relics and unknown subclasses")
local cancelled=person("Cancelled","DRUID",{[5]=chest})
units.target=cancelled
NS.OpenGearScoreInspection("target"); local queuedRequests=#requests; panel:Hide(); advance(4)
check(#requests==queuedRequests,"closing before the shared inspect delay cancels this panel's scheduled request")
local selfMenu=root(); units.target=units.player
menus.MENU_UNIT_SELF(nil,selfMenu,{fromTargetFrame=true,unit="target"})
selfMenu.buttons[1].click()
check(panel.model.guid==units.player.guid and panel.model.spec=="Restoration" and panel.model.complete,
    "self-target menu reuses local scores and talents without an inspection")
check(#requests==queuedRequests,"opening local gear adds no remote inspection requests")
panel:Hide()
print("PASS: " .. count .. " inspection-panel integration checks (" .. _VERSION .. ")")
