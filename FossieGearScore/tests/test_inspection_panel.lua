-- Full Lua 5.1 integration: real scoring, inspection queue, talents, snapshots
-- and panel, with deterministic native API, menu and frame doubles.
local NS,count={},0
local function check(ok,why) assert(ok,why); count=count+1 end
local time,timers,frames,menus,units,db,requests=100,{},{},{},{},{},{}
local inspected,combat,inventoryReads,scoreCalls,textureCount=nil,false,0,0,0
local tooltipCallbacks={}
local metadataReadCount=0
local function region()
    local r={}
    function r:SetText(text) self.text=text end
    function r:GetText() return self.text end
    function r:SetPoint(...) self.point={...} end
    function r:ClearAllPoints() self.point=nil end
    function r:SetSize(w,h) self.width,self.height=w,h end
    function r:SetWidth(w) self.width=w end
    function r:SetHeight(h) self.height=h end
    function r:GetHeight() return self.height end
    function r:SetAllPoints() end
    function r:SetJustifyH() end
    function r:SetJustifyV() end
    function r:SetTextColor(...) self.color={...} end
    function r:SetShadowColor() end
    function r:SetShadowOffset() end
    function r:SetTexture(texture) self.texture=texture end
    function r:SetTexCoord() end
    function r:SetColorTexture(...) self.color={...} end
    function r:Show() self.shown=true end
    function r:Hide() self.shown=false end
    function r:IsShown() return self.shown==true end
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
    function f:CreateTexture() textureCount=textureCount+1; return region() end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:Show() local was=self.shown; self.shown=true; if not was then self:Run("OnShow") end end
    function f:Hide() local was=self.shown; self.shown=false; if was then self:Run("OnHide") end end
    function f:SetFrameStrata(strata) self.strata=strata end
    function f:SetClampedToScreen(value) self.clamped=value end
    function f:SetMovable(value) self.movable=value end
    function f:EnableMouse() end
    function f:EnableMouseWheel() end
    function f:SetScrollChild(child) self.scrollChild=child end
    function f:SetVerticalScroll(value) self.scroll=value end
    function f:GetVerticalScroll() return self.scroll or 0 end
    function f:GetVerticalScrollRange() return math.max(0,self.scrollChild.height-self.height) end
    function f:SetOrientation(value) self.orientation=value end
    function f:SetMinMaxValues(lo,hi) self.minValue,self.maxValue=lo,hi end
    function f:SetValueStep(value) self.step=value end
    function f:SetThumbTexture() self.thumb=region() end
    function f:GetThumbTexture() return self.thumb end
    function f:SetValue(value) self.value=value; self:Run("OnValueChanged",value) end
    function f:RegisterForDrag(...) self.drags={...} end
    function f:StartMoving() self.moving=true end
    function f:StopMovingOrSizing() self.moving=false end
    function f:SetBackdrop(backdrop) self.backdrop=backdrop end
    function f:SetBackdropColor(...) self.backdropColor={...} end
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
    function f:AddLine(text) self.additions[#self.additions+1]={text} end
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
        metadataReadCount=metadataReadCount+1
        local i=db[link]; if not i or i.noInstant then return end
        return i.id,"Equipment","Fixture",i.loc,i.icon or 100, i.itemClass or 4,i.subclass or 1
    end,
    IsItemDataCachedByID=function(link) return db[link] and not db[link].pending end,
    GetItemStats=function(link) local i=db[link]; return i and not i.pending and i.raw end,
    GetItemInfo=function(link)
        metadataReadCount=metadataReadCount+1
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
check(#menu.buttons==1 and menu.buttons[1].text=="|cff3399ffGearScore|r","target portrait gets one blue GearScore option")
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
check(panel.model.highlights[1].link==weapon and #panel.model.highlights==2,
    "two-handed weapon omits the unused off-hand row")
check(panel.model.highlights[2].link==head,"highest armor is selected by existing intrinsic GS")
check(#panel.model.dungeons==6 and panel.dungeons.rows[6]:IsShown() and not panel.dungeons.rows[7]:IsShown(),
    "level-filtered reference groups populate the native scroll list")
check(panel.model.dungeonStatus=="Score unavailable" and panel.dungeons.rows[1].rating.text=="Score unavailable",
    "unknown enchantment points withhold a rating instead of judging incomplete DGS")
check(panel.dungeons.rows[1].baseline.text==tostring(panel.model.dungeons[1].baseline),
    "each dungeon row shows its supplied benchmark")
check(panel.dungeons.rows[6].baseline.text=="265" and #panel.model.dungeons[6].instances==3,
    "three equal-reference instances share one reference cell")
check(panel.dungeons.rows[6].name.text:find("Gnomeregan  |cffa9a18f(29-38)|r\nRazorfen Kraul",1,true)
    and panel.dungeons.rows[6].name.text:find("\nScarlet Monastery: Graveyard  |cffa9a18f(30-38)|r",1,true),
    "grouped instance names and their level ranges are stacked vertically")
check(panel.dungeons.rows[6].height==56 and panel.dungeons.rows[6].name.height==48
    and panel.dungeons.rows[6].baseline.point[5]==-20,
    "group rows expand for all names and center the shared reference vertically")
check(panel.dungeons.scroll.scrollChild==panel.dungeons.content and panel.dungeons.scroll.height==128,
    "dungeon table has a bounded native scroll viewport")
check(panel.dungeons.slider:IsShown() and panel.dungeons.slider.maxValue==88,
    "overflowing dungeon rows expose a draggable scrollbar")
panel.dungeons.slider:SetValue(80)
check(panel.dungeons.scroll:GetVerticalScroll()==80,"dragging the scrollbar moves the native viewport")
panel.dungeons.slider:SetValue(0)
panel.dungeons.scroll:Run("OnMouseWheel",-1)
check(panel.dungeons.scroll:GetVerticalScroll()==32,"mouse wheel scrolls the dungeon table")
NS.RefreshInspectionPanel(); advance(0)
check(panel.dungeons.scroll:GetVerticalScroll()==32,"redraw keeps the current dungeon scroll position")
panel.dungeons.scroll:Run("OnMouseWheel",-100)
check(panel.dungeons.scroll:GetVerticalScroll()==88,"wheel scrolling clamps to the last dungeon row")
panel.dungeons.scroll:Run("OnMouseWheel",100)
check(panel.dungeons.scroll:GetVerticalScroll()==0,"wheel scrolling clamps to the first dungeon row")
check(not panel.dungeonDetails and not panel.dungeons.rows[1].scripts.OnClick,
    "dungeon rows do not implement the deferred detailed-description area")
check(panel.status.text=="","successful inspection has no status message")
check(not panel.rows[1].kind and not panel.rows[2].kind,"highlight rows have no slot headings")
check(not panel.rows[3]:IsShown(),"unused row is hidden")
check(panel.width==620 and panel.height==568 and panel.scoreTop and panel.scoreMiddle and panel.scoreBottom and panel.enchantDivider,
    "compact panel keeps the reference dividers at 620 by 568 with four dungeon rows")
do
    local reads,calculations,requestCount=inventoryReads,scoreCalls,#requests
    check(panel.backdropColor[4]==0.9 and panel.backdrop.bgFile=="Interface\\Buttons\\WHITE8X8",
        "new panel background uses an opaque texture with ninety-percent default alpha")
    NS.SetInspectionPanelAlpha(0.4)
    check(panel.backdropColor[4]==0.4 and math.abs(panel.rows[1].backdropColor[4]-0.26)<0.00001,
        "live opacity updates the window and item-card backgrounds")
    check(math.abs(panel.dungeons.rows[2].background.color[4]-0.048)<0.00001,
        "dungeon background shading follows the same opacity")
    NS.SetInspectionPanelAlpha(0)
    check(panel.backdropColor[4]==0 and panel.rows[1].backdropColor[4]==0
        and panel.player.color[1]==0.92 and panel.rows[1].icon.texture,
        "fully transparent backgrounds preserve readable text and item icons")
    NS.SetInspectionPanelAlpha(-5)
    check(NS.GetInspectionPanelAlpha()==0,"opacity clamps below zero")
    NS.SetInspectionPanelAlpha(5)
    check(NS.GetInspectionPanelAlpha()==1 and panel.backdropColor[4]==1,"opacity clamps above one")
    check(not NS.SetInspectionPanelAlpha("bad") and not NS.SetInspectionPanelAlpha(0/0)
        and not NS.SetInspectionPanelAlpha(math.huge) and NS.GetInspectionPanelAlpha()==1,
        "invalid opacity inputs preserve the current setting")
    NS.SetInspectionPanelAlpha(0.4)
    local reloaded={}
    assert(loadfile("Scoring.lua"))("FossieGearScore",reloaded)
    assert(loadfile("Settings.lua"))("FossieGearScore",reloaded)
    check(reloaded.GetInspectionPanelAlpha()==0.4,"opacity persists across an addon namespace reload")
    NS.SetInspectionPanelAlpha(1)
    check(reloaded.GetInspectionPanelAlpha()==1,"an explicitly saved one-hundred-percent choice survives the new ninety-percent default")
    check(inventoryReads==reads and scoreCalls==calculations and #requests==requestCount,
        "live opacity changes do not redraw item data, scan gear or request inspection")
end
check(panel.rows[1].point[5]==panel.rows[2].point[5]
    and panel.rows[2].point[4]>panel.rows[1].point[4]+panel.rows[1].width,
    "highlight cards share one row with a gap between them")
check(panel.rows[1].backdrop.edgeSize==1 and panel.rows[1].height==78,
    "item cards have a thin border with compact spacing")
local coverage=panel.model.coverage
check(coverage.eligible==5 and coverage.enchanted==4 and coverage.missing==1,
    "coverage includes supported armor kits and excludes rings, trinkets and wands")
check(coverage.unsupported==1 and coverage.unknown==0,"wrong-slot enhancement is separate from missing enchants")
check(panel.model.enchantments=="4/5 eligible pieces enchanted","coverage retains its eligible-piece fraction for hover")
check(not panel.enchantDetails and not panel.tiers,"diagnostic and tier counts do not clutter the window")
check(not panel.enchantTitle and not panel.summary,"no enhancement text appears beneath the heading and bar")
check(panel.rows[1].enchant.text=="Enchanted" and panel.rows[2].enchant.text=="Enchanted",
    "known and unsupported installed enhancements use the same concise highlight label")
check(panel.rows[1].enchant.color[1]==1 and panel.rows[1].enchant.color[2]==0.4
    and panel.rows[1].enchant.color[3]==0.7,"Enchanted highlight text is pink")
check(panel.model.highlights[2].score~=panel.model.highlights[2].dynamicScore
    and panel.rows[2].scores.text:find("DGS:",1,true),"different highlight DGS remains visible")
check(panel.enchantSegments[1]:IsShown() and panel.enchantSegments[5]:IsShown()
    and not panel.enchantSegments[6]:IsShown(),"coverage bar contains one segment per eligible piece")
check(panel.enchantSegments[1].color[3]==1 and panel.enchantSegments[2].color[2]==0.85
    and panel.enchantSegments[3].color[2]==0.25 and panel.enchantSegments[4].color[1]==0.8
    and panel.enchantSegments[5].color[1]==0.27,
    "bar fills highest-to-lowest tier, then unsupported installed enchants, with empty pieces last")
panel.enhancements:Run("OnEnter")
check(GameTooltip.additions[1][1]=="4/5 eligible pieces enchanted","enhancement fraction appears in the hover tooltip")
check(GameTooltip.owner==panel.enhancements and GameTooltip.additions[2][1]:find("1 missing",1,true)
    and GameTooltip.additions[2][1]:find("1 unsupported",1,true),"coverage hover separates missing from unsupported enhancements")
check(GameTooltip.additions[3][1]:find("Tier 1: 1",1,true),"coverage hover retains the tier breakdown")
panel.enhancements:Run("OnLeave")
check(not GameTooltip:IsShown(),"coverage tooltip closes on leave")
check(panel.model.enchantmentDetails:find("1 missing",1,true) and panel.model.enchantmentDetails:find("1 unsupported",1,true),
    "missing and unsupported counts are visibly distinct")
check(panel.model.tiers:find("Tier 1: 1",1,true) and not panel.model.summary:find("low tier",1,true),
    "catalogue tiers appear without invented quality thresholds")
check(panel.model.summary:find("mixed enchant tiers",1,true),"mixed known tiers are summarized factually")
panel.rows[1]:Run("OnEnter")
check(GameTooltip.link==weapon and GameTooltip.owner==panel.rows[1],"highlight opens the native full-instance item tooltip")
panel.rows[1]:Run("OnLeave")
check(not GameTooltip:IsShown(),"leaving a highlight closes only its owned tooltip")
panel.rows[2]:Run("OnEnter")
local hovered=NS.GetInspectionTooltipResult(GameTooltip,head)
check(hovered and hovered~=panel.model.record.itemDetails[1] and hovered.dynamicProfile.classToken==alice.class,
    "native highlight tooltips reuse a copy of the selected wearer's scored result")
check(NS.last and NS.last.dynamicProfile==panel.model.record.dynamicProfile and not NS.last.dynamicProfile.heal,
    "real tooltip decoration uses the selected Balance profile instead of the local Restoration profile")
check(NS.last.dynamicScore==panel.model.highlights[2].dynamicScore and GameTooltip.additions[1][1]=="Item Score",
    "native item tooltip preserves normal addon rows and agrees with the panel item score")
hovered.scoreDifference=123
check(not panel.model.record.itemDetails[1].scoreDifference,"tooltip diagnostic fields cannot mutate the equipped snapshot")
check(NS.GetInspectionTooltipResult(GameTooltip,chest)==nil,"tooltip context cannot borrow a different equipped link")
panel.rows[2]:Run("OnLeave")
local reads,calculations,requestCount=inventoryReads,scoreCalls,#requests
local frameCount,textures=#frames,textureCount
local metadataBefore=metadataReadCount
for i=1,100 do NS.RefreshInspectionPanel() end
advance(0)
check(inventoryReads==reads and scoreCalls==calculations and #requests==requestCount,
    "100 panel redraws coalesce without inventory scans, rescoring or inspect requests")
check(#frames==frameCount and textureCount==textures,"card and coverage redraws reuse their frames and textures")
check(metadataReadCount==metadataBefore,"cached panel redraws make no native item-metadata reads")
advance(16)
check(#requests==requestCount,"completed panel has no periodic inspection traffic")
local unchanged=panel.model
for i=1,100 do fire("GET_ITEM_INFO_RECEIVED",900000+i,true) end
advance(0)
check(panel.model==unchanged and inventoryReads==reads and scoreCalls==calculations,
    "100 unrelated item-load events do not redraw the panel, scan gear or recalculate scores")

do
    local scans,calculations,metadata,requestTotal=inventoryReads,scoreCalls,metadataReadCount,#requests
    local own=NS.gearCache[units.player.guid]
    for i=1,100 do fire("ADDON_LOADED","UnrelatedAddon"); advance(0) end
    check(inventoryReads==scans and scoreCalls==calculations and metadataReadCount==metadata
        and #requests==requestTotal and NS.gearCache[units.player.guid]==own,
        "unrelated addon loads attach UI without equipment scans, metadata reads, scoring or inspection traffic")
    do
        local pending={}; for key,value in pairs(own) do pending[key]=value end
        pending.partial,pending.dataPending=true,true
        NS.gearCache[units.player.guid]=pending
        fire("ADDON_LOADED","LateDataAddon"); advance(0)
        check(inventoryReads>scans and not NS.gearCache[units.player.guid].dataPending,
            "late addon loads still retry incomplete own equipment data")
        local incomplete={}; for key,value in pairs(NS.gearCache[units.player.guid]) do incomplete[key]=value end
        incomplete.dynamicAvailable=false
        incomplete.dynamicProfile={available=false,reason="talents-unavailable"}
        NS.gearCache[units.player.guid]=incomplete
        local before=inventoryReads
        fire("ADDON_LOADED","LateTalentAPI"); advance(0)
        check(inventoryReads>before and NS.gearCache[units.player.guid].dynamicAvailable,
            "late addon loads still retry unresolved own talent APIs")
    end
    local oldName=db[head].name
    db[head].name="Refreshed item name"
    fire("GET_ITEM_INFO_RECEIVED",1003,true); advance(0)
    check(panel.rows[2].name.text=="Refreshed item name" and metadataReadCount>metadata,
        "relevant item-data events invalidate metadata so a corrected name becomes visible")
    metadata=metadataReadCount
    NS.RefreshInspectionPanel(); advance(0)
    check(metadataReadCount==metadata,"refreshed complete metadata is reused on subsequent redraws")
    db[head].name=oldName; fire("GET_ITEM_INFO_RECEIVED",1003,true); advance(0)
    -- A fresh item result must not cache a missing native name indefinitely.
    local record=panel.model.record
    local clone={}; for key,value in pairs(record) do clone[key]=value end
    clone.itemDetails={}; for slot,value in pairs(record.itemDetails) do clone.itemDetails[slot]=value end
    local item={}; for key,value in pairs(record.itemDetails[1]) do item[key]=value end
    clone.itemDetails[1]=item
    NS.gearSnapshots[record.guid]=clone; db[head].noName=true
    local who=NS.CaptureInspectionSelection("focus")
    local loading=NS.BuildInspectionPanelData(who)
    check(loading.highlights[2].name=="Loading item...","an uncached name keeps its loading fallback")
    db[head].noName=false
    local loaded=NS.BuildInspectionPanelData(who)
    check(loaded.highlights[2].name==oldName,"failed metadata lookups retry without needing a new gear snapshot")
    NS.gearSnapshots[record.guid]=record
end

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
check(panel.model.spec=="Balance" and panel.spec.text:find("Restoration (override)",1,true),
    "actual spec stays distinct from an existing DGS preview override")
NS.SetTalentOverride(0,alice.guid); advance(0)

-- Hunter weapons, one-handed/off-hand equipment, and unknown spec handling.
NS.OpenGearScoreInspection("target"); ready(bob)
check(panel.model.guid==bob.guid and #panel.model.highlights==2 and panel.model.highlights[1].link==bow,
    "hunters highlight ranged weapon and highest armor instead of melee slots")
check(panel.dungeons.guid==bob.guid and panel.dungeons.bracket.text=="Level 30 bracket"
    and panel.dungeons.scroll:GetVerticalScroll()==0,"new selections reset scroll and keep the dungeon bracket tied to their GUID")
check(panel.height<=728 and not panel.rows[3]:IsShown(),"hunter layout and scrolling dungeon list stay within the default screen")
local single=item(1013,"INVTYPE_WEAPONMAINHAND",0)
local cara=person("Cara","PALADIN",{[5]=chest,[16]=single,[17]=shield},{0,26,0})
units.target=cara; NS.OpenGearScoreInspection("target"); ready(cara)
check(panel.model.highlights[2].link==shield,"shield appears in the off-hand highlight")
check(panel.rows[3].point[4]+panel.rows[3].width==604 and panel.rows[3].point[5]==panel.rows[1].point[5],
    "three cards fit inside the right content margin without changing rows")
cara.gear[17]=offhand; ready(cara)
check(panel.model.highlights[2].link==offhand,"held-in-off-hand items are highlighted and counted by their own rules")
cara.gear[17]=nil; ready(cara)
check(#panel.model.highlights==2 and panel.model.highlights[2].link==chest and not panel.rows[3]:IsShown(),
    "known empty off-hand has no row and armor moves up")
cara.gear[16]=nil; ready(cara)
check(#panel.model.highlights==1 and panel.model.highlights[1].link==chest and not panel.rows[2]:IsShown(),
    "known empty main hand has no row")
check(panel.rows[1].width==588,"one highlight expands to fill the available card row")
cara.gear[5]=nil; cara.gear[16]=single; ready(cara)
check(#panel.model.highlights==1 and panel.model.highlights[1].link==single,
    "no equipped armor produces no armor row")
cara.gear[5]=chest; cara.gear[16]=single; ready(cara)
cara.talents={0,13,13}; ready(cara)
check(panel.model.spec==NS.talentProfiles[cara.guid].name and panel.model.spec:find("Hybrid:",1,true)
    and panel.model.talents=="0/13/13","hybrids retain the existing classification and exact talent split")
cara.talents=nil; ready(cara)
check(panel.model.spec=="Spec unknown" and panel.model.talents=="Talents unknown" and panel.model.dgs=="Unavailable",
    "missing talents do not borrow another player's spec or display zero DGS")
check(panel.model.dungeonScoreType=="GS" and panel.dungeons.referenceHeader.text=="Reference GS"
    and panel.dungeons.ratingHeader.text=="Your rating (GS)" and panel.model.dungeons[1].rating,
    "missing talents fall back to normal GS with explicit dungeon column labels")
check(panel.model.dungeons[1].score==panel.model.record.score+panel.model.record.enchantmentScore,
    "fallback uses the selected player's existing GS and enhancement total")
check(not panel.rows[1].scores.text:find("DGS",1,true),"unavailable highlight DGS is omitted")
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
check(panel.model.enchantments=="Enhancement data unavailable","loading coverage does not present a misleading finished fraction")
check(not panel.enchantSegments[1]:IsShown(),"partial coverage does not draw a misleading completed bar")
units.target=bob
db[delayed].pending=false
fire("GET_ITEM_INFO_RECEIVED",1014,true); advance(0.51)
check(panel.model.guid==dan.guid and panel.model.complete,"late item data completes the original player's snapshot after target change")
check(panel.model.coverage.missing==2,"loaded explicit zero IDs can now be classified as missing")
local unknown=item(1015,"INVTYPE_CHEST",999999)
dan.gear[5]=unknown; units.target=dan; ready(dan)
check(panel.model.coverage.unsupported==1 and panel.model.coverage.enchanted==1,
    "unknown applied ID counts as installed while its tier stays unsupported")
check(panel.model.enchantments=="1/2 eligible pieces enchanted"
    and not panel.summary,"unknown tiers retain the hover fraction without an incomplete-data message")
db[unknown].noInstant=true; NS.RefreshInspectionPanel(); advance(0)
check(panel.model.coverage.unresolved==0,"known item equip location survives unavailable instant metadata")
local savedEnum=Enum.TooltipDataLineType.ItemEnchantmentPermanent
Enum.TooltipDataLineType.ItemEnchantmentPermanent=nil
NS.RefreshInspectionPanel(); advance(0)
check(panel.model.coverage.unknown==1 and panel.model.coverage.missing==0,
    "an unavailable permanent-line API cannot claim the zero-ID weapon is missing an enhancement")
check(panel.rows[1].enchant.text=="" and not panel.summary,
    "unknown enhancement coverage does not display unknown/incomplete messages")
check(panel.enchantSegments[2].color[1]==0.8 and panel.enchantSegments[2].color[3]==0.8,
    "unknown coverage is distinct from confirmed missing coverage in the bar")
Enum.TooltipDataLineType.ItemEnchantmentPermanent=savedEnum

-- WoW links may encode no enchant as an empty field rather than the digit zero.
local plain=item(1016,"INVTYPE_CHEST","")
dan.gear[5]=plain; ready(dan)
check(panel.model.coverage.missing==2 and panel.model.coverage.unknown==0,
    "a loaded empty enchant field is correctly recognized as unenchanted")
check(panel.model.enchantments=="0/2 eligible pieces enchanted" and not panel.summary
    and panel.model.highlights[2].enchantment=="" and panel.rows[2].enchant.text=="",
    "unenhanced gear retains hover coverage without highlight text")
local snapshot=panel.model.record
local original=snapshot.links[5]
snapshot.links[5]="item:1016:"
local truncated=NS.BuildInspectionPanelData(NS.CaptureInspectionSelection("target"))
check(truncated.coverage.unknown==1 and truncated.coverage.missing==1,
    "a truncated link cannot establish an empty permanent enchant field")
snapshot.links[5]=original
local kit=item(1017,"INVTYPE_CHEST","",{lines={{leftText="Kit fixture"},{leftText="+10 Stamina"},
    {type=15,leftText="Medium Armor Kit",enchantmentID=8481}}})
dan.gear[5]=kit; ready(dan)
check(panel.model.coverage.enchanted==1 and panel.model.coverage.missing==1
    and panel.model.highlights[2].enchantment=="Enchanted",
    "a permanent attachment on a blank-ID link is still recognized before checking for absence")

local equalItem=item(1018,"INVTYPE_CHEST",0,{raw={ITEM_MOD_STAMINA_SHORT=10},
    lines={{leftText="Equal score fixture"},{leftText="+10 Stamina"}}})
local equalPlayer=person("Equal","MAGE",{[5]=equalItem},{26,0,0})
units.target=equalPlayer; NS.OpenGearScoreInspection("target"); ready(equalPlayer)
check(panel.model.highlights[1].score==panel.model.highlights[1].dynamicScore
    and panel.rows[1].scores.text=="GS: " .. panel.model.highlights[1].score,
    "equal highlight scores collapse to GS alone")
check(panel.rows[1].enchant.text=="","an unenchanted highlight has no extra label")
check(panel.model.assessment.fit=="optimal" and panel.dgsCaption.text=="Gear optimal for Arcane",
    "equal GS/DGS shows an optimal spec-fit caption")
check(panel.model.assessment.dynamicRating.label=="Far below"
    and panel.dgsLevel.text:find("Far below for level 30",1,true)
    and panel.dgsLevel.color[1]==1 and panel.dgsLevel.color[2]==0.48,
    "optimal spec fit retains a separate red DGS level assessment for weak gear")
check(panel.dgsLevel.point[5]==-148 and panel.dgsCaption.point[5]==-164,
    "DGS level grade and spec-fit caption occupy separate lines")
check(panel.gsCaption.text==panel.model.assessment.rating.label .. " for level 30",
    "ordinary GS receives a visible level rating using the dungeon rating labels")

do
    local lowEnchants=person("LowEnchants","MAGE",{[9]=item(1121,"INVTYPE_WRIST",8208),[5]=chest},{26,0,0})
    units.target=lowEnchants; NS.OpenGearScoreInspection("target"); ready(lowEnchants)
    check(panel.enchantSegments[1].color[3]==1 and panel.enchantSegments[2].color[2]==0.85,
        "when the player's highest worn enchant is tier two, tier one is green and tier two blue")
    do
        local mixed=person("MixedOrder","MAGE",{[1]=item(1122,"INVTYPE_HEAD",0),
            [5]=chest,[8]=item(1123,"INVTYPE_FEET",0),[9]=item(1124,"INVTYPE_WRIST",8208),
            [16]=item(1125,"INVTYPE_2HWEAPON",803)},{26,0,0})
        units.target=mixed; NS.OpenGearScoreInspection("target"); ready(mixed)
        check(panel.enchantSegments[1].color[3]==1 and panel.enchantSegments[2].color[2]==0.85
            and panel.enchantSegments[3].color[2]==0.25 and panel.enchantSegments[4].color[1]==0.27
            and panel.enchantSegments[5].color[1]==0.27,
            "interleaved equipped and empty slots produce contiguous tier groups followed by grey")
        local text=panel.dgsLevel.text
        local reads,calculations=inventoryReads,scoreCalls
        mixed.level=31; NS.RefreshInspectionPanel(); advance(0)
        check(panel.dgsLevel.text~=text and panel.dgsLevel.text:find("level 31",1,true)
            and inventoryReads==reads and scoreCalls==calculations,
            "DGS level caption follows the current level without scanning or rescoring")
    end
    local mono=person("OneTier","MAGE",{[5]=chest},{26,0,0})
    units.target=mono; NS.OpenGearScoreInspection("target"); ready(mono)
    check(panel.enchantSegments[1].color[3]==1,"a player wearing only tier-one enchants has a blue top tier")
    for highest=1,5 do
        for tier=1,highest do
            local r,g,b=NS.GetEnchantmentBarColor({state="enchanted",tier=tier},highest)
            local gap=highest-tier
            check(gap==0 and b==1 or gap==1 and g==0.85 or gap==2 and r==1 and g==0.85
                or gap>=3 and r==1 and g==0.25,"bar colours follow every possible relative tier gap")
        end
    end
    local r,g,b=NS.GetEnchantmentBarColor({state="enchanted",tier=5,ambiguous=true},5)
    check(r==0.8 and g==0.8 and b==0.8,"uncertain tiers do not receive a misleading tier colour")
end

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
panel.enhancements:Run("OnEnter")
check(GameTooltip.additions[#GameTooltip.additions][1]=="Fully enchanted.",
    "the removed enhancement summary remains in the hover tooltip")
panel.enhancements:Run("OnLeave")
check(panel.model.dungeonScoreType=="DGS" and panel.dungeons.referenceHeader.text=="Reference DGS"
    and panel.dungeons.ratingHeader.text=="Your rating (DGS)","available DGS is identified in the dungeon column labels")
local comparison=panel.model.record.dynamicScore+panel.model.record.enchantmentScore
check(panel.model.dungeons[1].rating and panel.model.dungeons[1].score==comparison,
    "complete scans compare the selected player's numeric DGS plus enhancements")
NS.SetEnchantmentDisplayMode("character","separate"); advance(0)
check(panel.model.dungeons[1].score==comparison,"separate enchantment display does not change dungeon ratings")
NS.SetEnchantmentDisplayMode("character","combined"); advance(0)
check(panel.model.dungeons[1].score==comparison,"combined enchantment display does not double-count enhancements")
NS.SetTalentOverride(3,waiting.guid); advance(0)
check(panel.model.dungeons[1].score==panel.model.record.dynamicScore+panel.model.record.enchantmentScore
    and panel.model.record.dynamicProfile.overridden,"dungeon ratings follow the displayed DGS preview profile")
NS.SetTalentOverride(0,waiting.guid); advance(0)
local currentRequests=#requests
UIParent.height=480; fire("UI_SCALE_CHANGED"); advance(0)
check(panel.height<=480 and panel.dungeons.scroll.height==32,"small UI heights shrink the dungeon viewport")
UIParent.height=1080; fire("DISPLAY_SIZE_CHANGED"); advance(0)
check(panel.dungeons.scroll.height==128 and #requests==currentRequests,
    "large screens show four dungeon rows without another inspection")
waiting.level=60; NS.RefreshInspectionPanel(); advance(0)
check(#panel.model.dungeons==0 and not panel.dungeons.scroll:IsShown()
    and panel.dungeons.empty.text=="No dungeon benchmarks for this level.","levels with no supplied references show a neutral empty state")
check(not panel.dungeons.rows[1]:IsShown(),"switching to an empty bracket hides old dungeon rows")
check(not panel.dungeons.slider:IsShown(),"an empty bracket has no stale scrollbar")
waiting.level=30; UIParent.height=nil; NS.RefreshInspectionPanel(); advance(0)
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
local portrait=root(); units.target=bob
menus.MENU_UNIT_SELF(nil,portrait,{fromPlayerFrame=true,unit="player",ownerFrame={}})
check(#portrait.buttons==1 and portrait.buttons[1].text=="|cff3399ffGearScore|r","own portrait gets a blue GearScore option without a self target")
portrait.buttons[1].click()
check(panel.model.guid==units.player.guid and panel.model.complete and panel.status.text=="",
    "own portrait opens local gear with no success status")
check(#requests==queuedRequests,"own portrait reuses local scores without remote requests")
local unrelated=root(); menus.MENU_UNIT_SELF(nil,unrelated,{unit="player"})
check(#unrelated.buttons==0,"self menus outside portraits remain untouched")
panel.enhancements:Run("OnEnter"); panel:Hide()
check(not GameTooltip:IsShown(),"closing the panel hides its enhancement tooltip")
panel:Hide()
-- Alternative recommendations exercise the real cached item scorer, role
-- penalties, effects and wearer set bonuses, without changing talent previews.
do
    local healingSet={{leftText="Healing set"},{leftText="+1000 Healing"},
        {leftText="Trial Set (2/2)"},{leftText="Set: Increases healing."}}
    local healing=item(1100,"INVTYPE_CHEST",0,{raw={ITEM_MOD_SPELL_HEALING_DONE=1000},lines=healingSet})
    local gloves=item(1101,"INVTYPE_HAND",0,{raw={ITEM_MOD_SPELL_HEALING_DONE=500},
        lines={{leftText="Healing gloves"},{leftText="+500 Healing"},
            {leftText="Trial Set (2/2)"},{leftText="Set: Increases healing."}}})
    local effect=item(1102,"INVTYPE_FEET",0,{raw={ITEM_MOD_STAMINA_SHORT=10},
        lines={{leftText="Effect boots"},{leftText="+10 Stamina"},{leftText="Use: Restore mana."}}})
    local role=item(1103,"INVTYPE_TRINKET",0)
    NS.ITEM_ROLES[1103]={["Healer"]=true}
    local mismatch=person("Mismatch","DRUID",{[5]=healing,[10]=gloves,[8]=effect,[13]=role},{0,26,0})
    units.target=mismatch; NS.OpenGearScoreInspection("target"); ready(mismatch)
    local rec=panel.model.record
    local a=panel.model.assessment
    check(a.fit=="suboptimal" and a.fitPercent<80 and panel.dgsCaption.text:find("Gear suboptimal for Feral",1,true),
        "healing gear on Feral receives the visible suboptimal assessment")
    check(#a.alternatives==1 and a.alternatives[1].tree==3 and a.alternatives[1].percent==100
        and panel.suggestions.text=="Better fit: Restoration (100% of GS)",
        "the best adequate alternative uses the captured talent-tree name or canonical fallback")
    check(rec.itemDetails[5].setActive and rec.itemDetails[5].setPieces==2,
        "spec recommendation fixture has an active wearer set")
    local profile=NS.ClassifyTalents("DRUID",{0,0,31},30,"NightElf")
    local expected=0
    for slot,link in pairs(rec.links) do
        local actual=NS.ScoreItem(link,rec.itemDetails[slot].lines,{classToken="DRUID",dynamicProfile=profile,deferSet=true})
        local _,total=NS.CalculateSetBonus(actual.dynamicScore,rec.itemDetails[slot].setPieces,rec.itemDetails[slot].setActive)
        expected=expected+total
    end
    check(a.alternatives[1].score==expected,"cached recommendation matches the normal item-scoring path including effects, roles and sets")
    do
        local classifications,calculations,scans=0,scoreCalls,inventoryReads
        local classify=NS.ClassifyTalents
        NS.ClassifyTalents=function(...) classifications=classifications+1; return classify(...) end
        for i=1,100 do
            local clone={}; for key,value in pairs(rec) do clone[key]=value end
            local assessment=NS.BuildGearAssessment(30,clone,true)
            assert(assessment.alternatives[1].score==expected,"snapshot reuse changed an alternate score")
        end
        NS.ClassifyTalents=classify
        check(classifications==0 and scoreCalls==calculations and inventoryReads==scans,
            "unchanged gear snapshots reuse alternate profiles and intrinsic scores without recalculation")
    end
    local actualProfile=NS.talentProfiles[rec.guid]
    local oldPoints=table.concat(actualProfile.points,"/")
    local oldGS,oldDGS=rec.score,rec.dynamicScore
    local reads,calculations,requestCount=inventoryReads,scoreCalls,#requests
    for i=1,100 do NS.RefreshInspectionPanel() end
    advance(0)
    check(scoreCalls==calculations and inventoryReads==reads and #requests==requestCount,
        "repeated suboptimal-panel redraws reuse recommendations without scoring, scans or requests")
    check(rec.dynamicProfile==panel.model.record.dynamicProfile and rec.score==oldGS and rec.dynamicScore==oldDGS
        and table.concat(actualProfile.points,"/")==oldPoints and NS.GetTalentOverride(rec.guid)==0,
        "alternative previews do not alter scores, talent points or stored overrides")
    -- Force a fresh assessment-cache entry while denying all native item reads.
    local clone={}; for key,value in pairs(rec) do clone[key]=value end
    local scoreItem,stats,info,details=NS.ScoreItem,C_Item.GetItemStats,C_Item.GetItemInfo,C_Item.GetDetailedItemLevelInfo
    local function denied() error("spec suggestion attempted a live item read") end
    NS.ScoreItem,C_Item.GetItemStats,C_Item.GetItemInfo,C_Item.GetDetailedItemLevelInfo=denied,denied,denied,denied
    local cached=NS.BuildGearAssessment(30,clone,true)
    NS.ScoreItem,C_Item.GetItemStats,C_Item.GetItemInfo,C_Item.GetDetailedItemLevelInfo=scoreItem,stats,info,details
    check(cached.alternatives[1].score==expected,"a fresh alternative evaluation needs only captured intrinsic item data")
    NS.SetTalentOverride(3,rec.guid); advance(0)
    check(panel.model.assessment.fit=="optimal" and panel.model.assessment.spec:find("override",1,true)
        and panel.suggestions.text=="","a selected talent preview is labelled and replaces old recommendations")
    NS.SetTalentOverride(0,rec.guid); advance(0)
    check(panel.model.assessment.fit=="suboptimal" and #panel.model.assessment.alternatives==1,
        "returning to the actual spec recomputes its fit from the new snapshot")
    local priest=person("HealerTie","PRIEST",{[5]=healing,[10]=gloves},{0,0,26})
    units.target=priest; NS.OpenGearScoreInspection("target"); ready(priest)
    check(#panel.model.assessment.alternatives==2 and panel.model.assessment.alternatives[1].tree==1
        and panel.model.assessment.alternatives[2].tree==2,
        "equally good alternate specs are both suggested instead of choosing arbitrarily")
    local warrior=person("NoFit","WARRIOR",{[5]=healing,[10]=gloves})
    units.target=warrior; NS.OpenGearScoreInspection("target"); ready(warrior)
    check(panel.model.assessment.fit=="suboptimal" and #panel.model.assessment.alternatives==0
        and panel.suggestions.text=="","no alternative is suggested when all class specs retain below eighty percent")
    panel:Hide()
end
print("PASS: " .. count .. " inspection-panel integration checks (" .. _VERSION .. ")")
