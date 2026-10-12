-- Mock the public Forever tooltip interface; run from the FossieGearScore folder.
local NS, count = {}, 0
local function check(condition, label)
    assert(condition, label)
    count = count + 1
end
local items, messages, callbacks, loaders = {}, {}, {}, {}
local locale, queriedLink = "enUS", nil
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage=function(_, text) messages[#messages+1]=text end}
Enum = {TooltipDataType={Item=0}, TooltipDataLineType={ItemName=22, ItemEnchantmentPermanent=15, ItemSpellTriggerOnUse=44, ItemSpellTriggerOnProc=46}}
C_TooltipInfo = {GetHyperlink=function() end}
TooltipDataProcessor = {AddTooltipPostCall=function(kind, fn)
    assert(kind == 0); callbacks[#callbacks+1]=fn
end}
TooltipUtil = {GetDisplayedItem=function(frame) return "Test Item", frame.link end}
GetLocale = function() return locale end
C_Item = {
    GetItemInfoInstant=function(link)
        local item=items[link]
        return item.id, "Armor", "Cloth", item.equipLoc or "INVTYPE_HEAD", 0, 4, 1
    end,
    IsEquippableItem=function(link) return items[link].equippable ~= false end,
    IsItemDataCachedByID=function(link) return items[link].cached ~= false end,
    GetItemStats=function(link) queriedLink=link; return items[link].raw end,
    GetItemLinkByGUID=function(guid) return guid end,
    GetItemInfo=function(link)
        local item=items[link]
        if item.metadataUnavailable then return end
        return "Test Item", link, item.quality or 1, item.itemLevel or 10, item.requiredLevel or 1
    end,
    GetDetailedItemLevelInfo=function(link)
        local item=items[link]
        if item.metadataUnavailable or item.noDetailed then return end
        return item.actualLevel or item.itemLevel or 10
    end,
}
CreateFrame = function()
    local frame = {RegisterEvent=function() end, SetScript=function(self, name, fn) self[name]=fn end}
    loaders[#loaders+1]=frame
    return frame
end
hooksecurefunc = function(frame, method, fn)
    local original=frame[method]
    frame[method]=function(self, ...) original(self, ...); fn(self, ...) end
end
local function tooltip(link)
    local frame={link=link, additions={}, shows=0, scripts={}}
    function frame:GetPrimaryTooltipData() return self.data end
    function frame:GetPrimaryTooltipInfo() return self.info end
    function frame:ClearLines() self.additions={} end
    function frame:HookScript(name, fn) self.scripts[name]=fn end
    function frame:AddDoubleLine(label, value, ...)
        self.additions[#self.additions+1]={label,value, colors={...}}
    end
    function frame:Show() self.shows=self.shows+1 end
    frame.data={id=items[link].id, hyperlink=link, lines=items[link].lines}
    return frame
end
local function item(link, raw, lines, extra)
    local record=extra or {}; record.id=record.id or 100; record.raw=raw
    record.lines={}
    for _, text in ipairs(lines or {}) do record.lines[#record.lines+1]={leftText=text} end
    items[link]=record
end

assert(loadfile("Weights.lua"))("FossieGearScore", NS)
assert(loadfile("Scoring.lua"))("FossieGearScore", NS)
assert(loadfile("Bonuses.lua"))("FossieGearScore", NS)
assert(loadfile("Comparison.lua"))("FossieGearScore", NS)
assert(loadfile("Tooltip.lua"))("FossieGearScore", NS)
check(#callbacks==1, "modern callback registered once")
loaders[1].OnEvent(loaders[1], "PLAYER_LOGIN")
loaders[1].OnEvent(loaders[1], "ADDON_LOADED", "SomeOtherAddon")
check(#callbacks==1, "events do not duplicate registration")
item("item:100:0:0:0:0:0:-42:123", {ITEM_MOD_INTELLECT_SHORT=7,ITEM_MOD_SPIRIT_SHORT=3}, {"+7 Intellect", "+3 Spirit"})
local a=tooltip("item:100:0:0:0:0:0:-42:123")
callbacks[1](a,a.data)
check(a.additions[1][1]=="Item Score" and a.additions[1][2]=="7", "score appended with stat and base points")
local color=a.additions[1].colors
check(color[1]==1 and color[2]==0.4 and color[3]==0.7, "Item Score label is pink")
check(queriedLink==a.link, "random suffix and full item link preserved")
check(a.shows==0, "post-call does not recursively refresh tooltip")
callbacks[1](a,a.data)
check(#a.additions==1, "duplicate post-call suppressed")
a:ClearLines()
a.data.lines={{leftText="+8 Intellect"},{leftText="+3 Spirit"}}
callbacks[1](a,a.data)
check(#a.additions==1 and a.additions[1][2]=="7", "same item rebuild recalculates")
local b=tooltip(a.link); callbacks[1](b,b.data)
check(b.additions[1][2]=="7", "independent tooltip frames scored")
a.scripts.OnHide(a); a.additions={}
callbacks[1](a,a.data)
check(a.additions[1][2]=="7", "hidden frame can be scored again")
a:ClearLines(); callbacks[1](a,{id=999, hyperlink=a.link, lines={{leftText="+100 Strength"}}})
check(#a.additions==0, "appended secondary item data ignored")

item("item:200", nil, {"Loading Item"}, {cached=false,id=200})
local loading=tooltip("item:200"); callbacks[1](loading,loading.data)
check(#loading.additions==0, "uncached item does not receive zero")
items[loading.link].cached=true; items[loading.link].raw={ITEM_MOD_STRENGTH_SHORT=5}
loading.data.lines={{leftText="+5 Strength"}}
callbacks[1](loading,loading.data)
check(loading.additions[1][2]=="5", "loaded item scores on refresh")

item("item:300", {}, {"Food", "Use: Restores 100 health."}, {id=300,equipLoc="",equippable=false})
local food=tooltip("item:300"); callbacks[1](food,food.data)
check(#food.additions==0, "non-equipment tooltip not scored")
item("item:301", {}, {"Plain Shirt"}, {id=301,equipLoc="INVTYPE_BODY"})
local shirt=tooltip("item:301"); callbacks[1](shirt,shirt.data)
check(#shirt.additions==0, "plain shirt has no Item Score line")
check(NS.ScoreItem(shirt.link).score==0, "hidden cosmetic shirt still contributes zero to equipped totals")
callbacks[1](shirt,shirt.data)
check(#shirt.additions==0, "repeated plain-shirt tooltip processing adds no score line")
item("item:302", {}, {"Plain Tabard", "A fashionable tabard."}, {id=302,equipLoc="INVTYPE_TABARD"})
local tabard=tooltip("item:302"); tabard.info={getterName="GetBagItem",getterArgs={0,1}}
callbacks[1](tabard,tabard.data)
check(#tabard.additions==0, "plain bag tabard has no Item Score or difference text")
item("item:303", {ITEM_MOD_INTELLECT_SHORT=7}, {"+7 Intellect"}, {id=303,equipLoc="INVTYPE_BODY"})
local statShirt=tooltip("item:303"); callbacks[1](statShirt,statShirt.data)
check(statShirt.additions[1][2]=="6", "shirt with a stat retains Item Score")
item("item:304", {}, {"Use: Creates a spark."}, {id=304,equipLoc="INVTYPE_TABARD"})
local useTabard=tooltip("item:304"); callbacks[1](useTabard,useTabard.data)
check(useTabard.additions[1][2]=="4", "tabard with a use effect retains Item Score")
item("item:305", {}, {"Equip: Improves stealth detection."}, {id=305,equipLoc="INVTYPE_BODY"})
local effectShirt=tooltip("item:305"); callbacks[1](effectShirt,effectShirt.data)
check(effectShirt.additions[1][2]=="3", "shirt with an equip effect retains Item Score")
item("item:306", {ITEM_MOD_MANA_SHORT=1}, {}, {id=306,equipLoc="INVTYPE_TABARD",itemLevel=0})
local smallTabard=tooltip("item:306"); callbacks[1](smallTabard,smallTabard.data)
check(smallTabard.additions[1][2]=="0", "stat-bearing tabard displays Item Score even when rounded to zero")
item("item:307", {}, {"Plain Helmet"}, {id=307,equipLoc="INVTYPE_HEAD"})
local plainHelmet=tooltip("item:307"); callbacks[1](plainHelmet,plainHelmet.data)
check(plainHelmet.additions[1][2]=="0", "other statless equipment retains its zero Item Score")
item("item:308", {ITEM_MOD_HASTE_RATING_SHORT=10}, {}, {id=308,equipLoc="INVTYPE_TABARD"})
local ratingTabard=tooltip("item:308"); callbacks[1](ratingTabard,ratingTabard.data)
check(ratingTabard.additions[1][2]=="0 (partial)", "unconverted tabard stat retains its partial Item Score")

locale="deDE"
item("item:400", {ITEM_MOD_INTELLECT_SHORT=7}, {"+7 Intelligenz"}, {id=400})
local german=tooltip("item:400"); callbacks[1](german,german.data)
check(german.additions[1][2]=="6 (partial)", "non-English coverage marked partial")
locale="enUS"
item("item:500", {ITEM_MOD_HASTE_RATING_SHORT=10}, {}, {id=500})
local unknown=tooltip("item:500"); callbacks[1](unknown,unknown.data)
check(unknown.additions[1][2]=="0 (partial)", "unconverted rating marked partial")
SlashCmdList.FOSSIEGS("debug")
check(#messages>=2, "debug command reports calculation and conversion warning")
SlashCmdList.FOSSIEGS("raw")
check(messages[#messages]:find("Tooltip lines:",1,true)~=nil, "raw command available")

item("item:600", {}, {}, {id=600})
local bad=tooltip("item:600")
bad.AddDoubleLine=function() error("fixture tooltip failure") end
callbacks[1](bad,bad.data)
check(messages[#messages]:find("fixture tooltip failure",1,true)~=nil, "tooltip error contained and reported")
local recovered=tooltip(b.link); callbacks[1](recovered,recovered.data)
check(recovered.additions[1][2]=="7", "scoring continues after another tooltip errors")

-- A GUID-backed tooltip keeps its actual instance link, too.
local guid=tooltip(b.link); guid.link=nil; guid.data.hyperlink=nil; guid.data.guid=b.link
callbacks[1](guid,guid.data)
check(guid.additions[1][2]=="7", "GUID link resolution works")
local noLink=tooltip(b.link); noLink.link=nil; noLink.data.hyperlink=nil
callbacks[1](noLink,noLink.data)
check(#noLink.additions==0, "missing instance link is not replaced by itemID")

item("item:700", {ITEM_MOD_SPELL_POWER=7,ITEM_MOD_SPELL_HEALING_DONE=17},
    {"Equip: Increases damage and healing done by magical spells and effects by up to 7.", "Equip: Increases healing done by spells and effects by up to 10."}, {id=700})
local shared=tooltip("item:700"); callbacks[1](shared,shared.data)
check(shared.additions[1][2]=="5", "tooltip counts shared power once and adds extra healing at 0.4")
SlashCmdList.FOSSIEGS("debug")
check(messages[#messages-3]:find("7 counted once under Spell Damage",1,true)~=nil, "debug explains shared scoring")
check(NS.last.breakdown[2].stat=="Healing" and NS.last.breakdown[2].value==10, "debug healing amount excludes shared power")
shared:ClearLines(); callbacks[1](shared,shared.data)
check(shared.additions[1][2]=="5", "rebuild retains shared scoring")
item("item:701", {ITEM_MOD_SPELL_HEALING_DONE=7}, {"+7 Healing"}, {id=701})
local heal=tooltip("item:701"); callbacks[1](heal,heal.data)
check(heal.additions[1][2]=="3", "healing-only tooltip uses new weight")
SlashCmdList.FOSSIEGS("")
check(messages[#messages]:find("v0.1.16",1,true)~=nil, "help reports incremented build")

item("item:800", {}, {"Chance on hit: Deals 40 damage."}, {id=800,itemLevel=15,quality=2})
local effect=tooltip("item:800"); callbacks[1](effect,effect.data)
check(effect.additions[1][2]=="5", "effect-only green receives the enhanced item-level base")
SlashCmdList.FOSSIEGS("debug")
check(messages[#messages-2]:find("18.9 base points",1,true)~=nil, "debug explains effect-only item-level base")
check(messages[#messages-1]:find("Stats 0 + base 18.9) x Uncommon 1.1 = 20.79",1,true)~=nil, "debug explains base and rarity without adding flat proc stats")
check(messages[#messages]:find("floor(20.79 / 4) = 5 displayed points",1,true)~=nil, "debug explains divide and floor stage")
item("item:801", {ITEM_MOD_STRENGTH_SHORT=1}, {}, {id=801,itemLevel=15,actualLevel=20,requiredLevel=5,quality=2})
local detailed=tooltip("item:801"); callbacks[1](detailed,detailed.data)
check(detailed.additions[1][2]=="7", "actual item level takes priority over sparse and required levels")
item("item:802", {ITEM_MOD_STRENGTH_SHORT=1}, {}, {id=802,itemLevel=15,requiredLevel=5,quality=2,noDetailed=true})
local fallback=tooltip("item:802"); callbacks[1](fallback,fallback.data)
check(fallback.additions[1][2]=="5", "basic item level fallback works")
for quality, expected in pairs({[0]="5",[1]="7",[2]="7",[3]="8",[4]="8",[5]="9"}) do
    local link="item:" .. (810+quality)
    item(link, {ITEM_MOD_INTELLECT_SHORT=7,ITEM_MOD_SPIRIT_SHORT=3}, {"+7 Intellect", "+3 Spirit"}, {quality=quality})
    local frame=tooltip(link); callbacks[1](frame,frame.data)
    check(frame.additions[1][2]==expected, "rarity multiplier for quality " .. quality)
end
item("item:820", {ITEM_MOD_INTELLECT_SHORT=7}, {"+7 Intellect"}, {id=820,metadataUnavailable=true})
local missing=tooltip("item:820"); callbacks[1](missing,missing.data)
check(missing.additions[1][2]=="3 (partial)", "missing metadata falls back to partial stat score")
item("item:821", {}, {}, {id=821,itemLevel=15,quality=6})
local unsupported=tooltip("item:821"); callbacks[1](unsupported,unsupported.data)
check(unsupported.additions[1][2]=="0 (partial)", "unsupported rarity uses marked neutral multiplier")
item("item:822", nil, {"Chance on hit: Deals 40 damage."}, {id=822,itemLevel=15,quality=2})
local noRaw=tooltip("item:822"); callbacks[1](noRaw,noRaw.data)
check(noRaw.additions[1][2]=="5", "effect-only item can score its base when no raw stats are returned")
items[missing.link].metadataUnavailable=false
missing:ClearLines(); callbacks[1](missing,missing.data)
check(missing.additions[1][2]=="6", "metadata refresh replaces the earlier partial score")
items[effect.link].quality=4
effect:ClearLines(); callbacks[1](effect,effect.data)
check(effect.additions[1][2]=="5" and math.abs(NS.last.scoring.rawScore-22.68)<0.00001,
    "rarity refresh recalculates the effect-only item base even when the displayed floor is unchanged")

item("item:823", {}, {"Equip: Improves stealth detection."}, {id=823,itemLevel=15,quality=2})
local equipOnly=tooltip("item:823"); callbacks[1](equipOnly,equipOnly.data)
check(equipOnly.additions[1][2]=="5" and not NS.last.scoring.hasStats,
    "unrecognized flat stat in a passive Equip effect still qualifies for the base")
item("item:824", {}, {"+2 to All Resistances"}, {id=824,itemLevel=0,actualLevel=0,quality=1})
local resistance=tooltip("item:824"); callbacks[1](resistance,resistance.data)
check(resistance.additions[1][2]=="1" and NS.last.scoring.statScore==5,
    "Rugged Spaulders resistance wording contributes to displayed item score")

item("item:825", {}, {"Use: Increases your attack power by 100 for 10 sec."},
    {id=825,itemLevel=15,quality=2,equipLoc="INVTYPE_TRINKET"})
local useOnly=tooltip("item:825"); callbacks[1](useOnly,useOnly.data)
check(useOnly.additions[1][2]=="7" and NS.last.scoring.statScore==0 and NS.last.scoring.effectMultiplier==1.5,
    "on-use-only item scores its enhanced base without counting temporary AP as a flat stat")
SlashCmdList.FOSSIEGS("debug")
check(messages[#messages-2]:find("effect 1.5 = 27 base points",1,true)~=nil,
    "debug explains the on-use base multiplier")

-- Real item scoring with bag context and colored inline differences.
local gear={[1]="item:801"}
GetInventoryItemLink=function(_,slot) return gear[slot] end
GetInventoryItemTexture=function(_,slot) return gear[slot] and 1 end
C_TooltipInfo.GetHyperlink=function(link) return {lines=items[link].lines} end
item("item:830", {ITEM_MOD_STRENGTH_SHORT=10}, {}, {id=830,itemLevel=15,quality=2})
local bag=tooltip("item:830"); bag.info={getterName="GetBagItem",getterArgs={0,1}}
callbacks[1](bag,bag.data)
check(bag.additions[1][2]=="10 |cff00ff00(+3)|r","bag tooltip appends the green gain on the Item Score line")
check(#bag.additions==1 and NS.last.scoreDifference==3,"bag comparison stays on the existing line")
callbacks[1](bag,bag.data)
check(#bag.additions==1,"repeated bag post-call cannot duplicate the score difference")
gear[1]="item:830"; bag:ClearLines(); callbacks[1](bag,bag.data)
check(bag.additions[1][2]=="10 |cffffffff(0)|r","equal-score bag comparison is white")
item("item:831", {ITEM_MOD_STRENGTH_SHORT=20}, {}, {id=831,itemLevel=15,quality=2})
gear[1]="item:831"; bag:ClearLines(); callbacks[1](bag,bag.data)
check(bag.additions[1][2]=="10 |cffff4040(-5)|r","lower-score bag comparison is red")
gear[1]=nil; bag:ClearLines(); callbacks[1](bag,bag.data)
check(bag.additions[1][2]=="10 |cff00ff00(+10)|r","empty equipped slot displays the whole candidate score as gain")
gear[1]="item:831"; items["item:831"].cached=false
bag:ClearLines(); callbacks[1](bag,bag.data)
check(bag.additions[1][2]=="10 |cffffffff(?)|r","loading equipped item produces an explicit unknown difference")
items["item:831"].cached=true
bag.info.getterName="GetHyperlink"; bag:ClearLines(); callbacks[1](bag,bag.data)
check(bag.additions[1][2]=="10","chat links do not receive a bag comparison")
bag.info.getterName="GetMerchantItem"; bag:ClearLines(); callbacks[1](bag,bag.data)
check(bag.additions[1][2]=="10","merchant tooltips keep the item score without bag delta")
bag.info.getterName="GetInventoryItem"; bag.info.getterArgs={"player",1}
bag:ClearLines(); callbacks[1](bag,bag.data)
check(bag.additions[1][2]=="10","equipped item tooltips do not receive a bag delta")
bag.info.getterName="GetBagItemChild"; bag:ClearLines(); callbacks[1](bag,bag.data)
check(bag.additions[1][2]:find("|cffff4040(-5)",1,true)~=nil,"native bag-child getter also gets a comparison")

local hidden=setmetatable({}, {})
issecretvalue=function(value) return value==hidden end
local secretScore, _, _, secretWarnings=NS.CalculateItemScore({Intellect=7}, hidden, hidden)
check(secretScore==3 and secretWarnings.ItemLevel and secretWarnings.Rarity, "secret metadata is skipped without comparison errors")
issecretvalue=nil

local fractional, _, fractionalDetails=NS.CalculateItemScore({Healing=1.2}, 1, 3)
check(fractional==0 and math.abs(fractionalDetails.rawScore-1.932)<0.00001, "fractional stats and rarity retained until final floor")
local below=NS.CalculateItemScore({Mana=133}, 0, 1)
local above=NS.CalculateItemScore({Mana=134}, 0, 1)
check(below==0 and above==1, "floor boundary works on either side of one displayed point")
local negative=NS.CalculateItemScore({Healing=-2.2}, 0, 1)
check(negative==-1, "negative penalties round down rather than toward zero")

print("PASS: " .. count .. " tooltip lifecycle/integration checks (" .. _VERSION .. ")")
