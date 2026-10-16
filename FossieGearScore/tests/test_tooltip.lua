-- Mock the public Forever tooltip interface; run from the FossieGearScore folder.
local NS, count = {}, 0
local function check(condition, label)
    assert(condition, label)
    count = count + 1
end
local items, messages, callbacks, loaders = {}, {}, {}, {}
local nativeReads = {metadata=0, primaryInfo=0}
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
        nativeReads.metadata=nativeReads.metadata+1
        local item=items[link]
        if item.metadataUnavailable then return end
        return "Test Item", link, item.quality or 1, item.itemLevel or 10, item.requiredLevel or 1,
            nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, item.setID
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
    function frame:GetPrimaryTooltipInfo()
        nativeReads.primaryInfo=nativeReads.primaryInfo+1
        return self.info
    end
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
assert(loadfile("EnchantmentData.lua"))("FossieGearScore", NS)
assert(loadfile("Enchantments.lua"))("FossieGearScore", NS)
assert(loadfile("Bonuses.lua"))("FossieGearScore", NS)
assert(loadfile("ItemRoles.lua"))("FossieGearScore", NS)
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
check(nativeReads.metadata==1,"quality, item level and set membership share one native metadata read")
check(nativeReads.primaryInfo==1,"one decoration shares primary tooltip info between owner and comparison checks")
local color=a.additions[1].colors
check(color[1]==1 and color[2]==0.4 and color[3]==0.7, "Item Score label is pink")
check(queriedLink==a.link, "random suffix and full item link preserved")
check(a.shows==0, "post-call does not recursively refresh tooltip")
callbacks[1](a,a.data)
check(#a.additions==1, "duplicate post-call suppressed")
check(nativeReads.metadata==1 and nativeReads.primaryInfo==1,"duplicate post-call does not repeat native metadata reads")
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
item("item:309",{ITEM_MOD_STRENGTH_SHORT=5},{"+5 Strength"},{id=309,setID=1234})
local beforeMetadata=nativeReads.metadata
local nativeSet=NS.ScoreItem("item:309")
check(nativeSet.set and nativeSet.set.id==1234 and nativeReads.metadata==beforeMetadata+1,
    "one metadata read retains the native sixteenth-return set ID")
local getNumber,rawScans=NS.GetNumber,0
NS.GetNumber=function(value)
    if value==123456789 then rawScans=rawScans+1 end
    return getNumber(value)
end
item("item:310",{FUTURE_STAT=123456789},{},{id=310,equipLoc="INVTYPE_HEAD"})
check(not NS.ScoreItem("item:310").hideItemScore and rawScans==0,"ordinary equipment skips the cosmetic-only raw-stat scan")
item("item:311",{FUTURE_STAT=123456789},{},{id=311,equipLoc="INVTYPE_BODY"})
check(not NS.ScoreItem("item:311").hideItemScore and rawScans==1,"unknown numeric shirt stats still retain the score row")
NS.GetNumber=getNumber

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
check(messages[#messages]:find("v" .. NS.VERSION,1,true)~=nil, "help reports the current addon version")

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

-- Quest offers, turn-ins and quest-log rewards use distinct native getters.
for _, getter in ipairs({"GetQuestItem", "GetQuestLogItem"}) do
    for _, kind in ipairs({"choice", "reward"}) do
        local reward=tooltip("item:830")
        reward.info={getterName=getter,getterArgs={kind,1}}
        gear[1]="item:801"
        callbacks[1](reward,reward.data)
        check(reward.additions[1][2]=="10 |cff00ff00(+3)|r",getter .. " " .. kind .. " shows an upgrade")
        callbacks[1](reward,reward.data)
        check(#reward.additions==1,"repeated quest reward post-call does not duplicate the comparison")
        gear[1]="item:831"; reward:ClearLines(); callbacks[1](reward,reward.data)
        check(reward.additions[1][2]=="10 |cffff4040(-5)|r",getter .. " " .. kind .. " shows a downgrade")
        gear[1]="item:830"; reward:ClearLines(); callbacks[1](reward,reward.data)
        check(reward.additions[1][2]=="10 |cffffffff(0)|r","equal quest reward shows zero difference")
        gear[1]=nil; reward:ClearLines(); callbacks[1](reward,reward.data)
        check(reward.additions[1][2]=="10 |cff00ff00(+10)|r","quest reward compares against an empty slot")
        gear[1]="item:831"; items["item:831"].cached=false
        reward:ClearLines(); callbacks[1](reward,reward.data)
        check(reward.additions[1][2]=="10 |cffffffff(?)|r","quest reward does not guess a loading equipped score")
        items["item:831"].cached=true
        local refreshes=0
        reward.IsShown=function() return true end
        reward.RefreshDataNextUpdate=function() refreshes=refreshes+1 end
        NS.RefreshSetTooltips()
        check(refreshes==1,"visible quest reward comparison refreshes after equipment changes")
        reward.IsShown=function() return false end
    end
end
for _, info in ipairs({
    {getterName="GetQuestItem",getterArgs={"required",1}},
    {getterName="GetQuestLogItem",getterArgs={"required",1}},
    {getterName="GetQuestLogSpecialItem",getterArgs={1}},
    {getterName="GetQuestItem"},
}) do
    local objective=tooltip("item:830"); objective.info=info
    callbacks[1](objective,objective.data)
    check(objective.additions[1][2]=="10","quest objectives and missing reward context do not get comparisons")
end

local savedScoreItem,savedComparison=NS.ScoreItem,C_TooltipComparison
local savedClass,savedProfile,savedWeights=NS.GetClassToken,NS.ResolveDynamicProfile,NS.GetDynamicWeights
local savedVisibility,savedMode=NS.GetDisplayVisibility,NS.GetDisplayMode
local profile={classToken="MAGE",available=true}
NS.GetClassToken=function() return "MAGE" end
NS.ResolveDynamicProfile=function() return profile end
NS.GetDynamicWeights=function()
    local weights={}; for stat,weight in pairs(NS.WEIGHTS) do weights[stat]=weight end
    weights.Strength=0; return weights
end
NS.GetDisplayVisibility=function() return true,true end
NS.GetDisplayMode=function() return "both" end
local comparisonQueries,wornReads=0,0
C_TooltipComparison={GetItemComparisonInfo=function()
    comparisonQueries=comparisonQueries+1
    return {method=0,item={hyperlink="item:831"},additionalItems={}}
end}
NS.ScoreItem=function(link,...)
    if link=="item:831" then wornReads=wornReads+1 end
    return savedScoreItem(link,...)
end
bag:ClearLines(); callbacks[1](bag,bag.data)
check(#bag.additions==2 and bag.additions[1][2]:find("(-5)",1,true)
    and bag.additions[2][1]=="Dynamic Item Score" and bag.additions[2][2]:find("(0)",1,true),
    "both bag rows keep their independent normal and dynamic comparisons")
check(comparisonQueries==1 and wornReads==1,"one tooltip decoration reads the worn item and native comparison once for both rows")
check(NS.last.itemID==830,"scored item retains its numeric item ID for load-event filtering")
items["item:831"].raw.ITEM_MOD_STRENGTH_SHORT=50
bag:ClearLines(); callbacks[1](bag,bag.data)
check(bag.additions[1][2]:find("(-22)",1,true) and comparisonQueries==2 and wornReads==2,
    "a new decoration rechecks equipment instead of retaining comparison data")
items["item:831"].raw.ITEM_MOD_STRENGTH_SHORT=20
for _, getter in ipairs({"GetQuestItem", "GetQuestLogItem"}) do
    local reward=tooltip("item:830"); reward.info={getterName=getter,getterArgs={"choice",1}}
    local beforeQueries,beforeReads,beforeInfo=comparisonQueries,wornReads,nativeReads.primaryInfo
    callbacks[1](reward,reward.data)
    check(#reward.additions==2 and reward.additions[1][2]:find("(-5)",1,true)
        and reward.additions[2][1]=="Dynamic Item Score" and reward.additions[2][2]:find("(0)",1,true),
        "quest reward shows independent GS and DGS differences in Both mode")
    check(comparisonQueries==beforeQueries+1 and wornReads==beforeReads+1,
        "quest GS and DGS share one equipment comparison read")
    check(nativeReads.primaryInfo==beforeInfo+1,"quest comparisons reuse the owner's primary tooltip info read")
    NS.GetDisplayVisibility=function() return false,true end
    NS.GetDisplayMode=function() return "dynamic" end
    reward:ClearLines(); callbacks[1](reward,reward.data)
    check(#reward.additions==1 and reward.additions[1][1]=="Dynamic Item Score"
        and reward.additions[1][2]:find("(0)",1,true),"dynamic-only quest reward includes its comparison")
    NS.GetDisplayVisibility=function() return true,true end
    NS.GetDisplayMode=function() return "both" end
end
NS.ScoreItem,C_TooltipComparison=savedScoreItem,savedComparison
NS.GetClassToken,NS.ResolveDynamicProfile,NS.GetDynamicWeights=savedClass,savedProfile,savedWeights
NS.GetDisplayVisibility,NS.GetDisplayMode=savedVisibility,savedMode

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

-- A repeated hover should reuse parsed stats while still detecting live data.
local originalExtract,originalCalculate=NS.ExtractStats,NS.CalculateItemScore
local parseCalls,calculateCalls=0,0
NS.ExtractStats=function(...) parseCalls=parseCalls+1; return originalExtract(...) end
NS.CalculateItemScore=function(...) calculateCalls=calculateCalls+1; return originalCalculate(...) end
NS.InvalidateItemScoreCache()
item("cacheFixture",{ITEM_MOD_INTELLECT_SHORT=8},{"+8 Intellect"})
local cachedTip=tooltip("cacheFixture")
for i=1,200 do cachedTip:ClearLines(); callbacks[1](cachedTip,cachedTip.data) end
check(parseCalls==1 and calculateCalls==1,"200 unchanged tooltip rebuilds parse and calculate the item once")
check(#cachedTip.additions==1 and cachedTip.additions[1][2]=="7","cache keeps a single correct tooltip score row")
loaders[1].OnEvent(loaders[1],"ITEM_DATA_LOAD_RESULT",101,true)
cachedTip:ClearLines(); callbacks[1](cachedTip,cachedTip.data)
check(parseCalls==1,"unrelated item loads preserve a warm hover cache")
items.cacheFixture.raw.ITEM_MOD_INTELLECT_SHORT=12
items.cacheFixture.lines[1].leftText="+12 Intellect"
cachedTip:ClearLines(); callbacks[1](cachedTip,cachedTip.data)
check(parseCalls==2 and cachedTip.additions[1][2]=="9","changed raw stats and native lines replace cached arithmetic")
items.cacheFixture.actualLevel=20
cachedTip:ClearLines(); callbacks[1](cachedTip,cachedTip.data)
check(parseCalls==3 and cachedTip.additions[1][2]=="12","metadata changes invalidate the intrinsic cache signature")
loaders[1].OnEvent(loaders[1],"ITEM_DATA_LOAD_RESULT",100,true)
cachedTip:ClearLines(); callbacks[1](cachedTip,cachedTip.data)
check(parseCalls==4,"item-data events clear parsed hover data")

local variantA="item:1000:0:0:0:0:0:-42:123"
local variantB="item:1000:0:0:0:0:0:-43:124"
item(variantA,{ITEM_MOD_INTELLECT_SHORT=7},{"+7 Intellect"},{id=1000})
item(variantB,{ITEM_MOD_INTELLECT_SHORT=11},{"+11 Intellect"},{id=1000})
item("indexedOther",{ITEM_MOD_INTELLECT_SHORT=9},{"+9 Intellect"},{id=1001})
NS.InvalidateItemScoreCache()
local beforeParse=parseCalls
local variantScoreA,variantScoreB=NS.ScoreItem(variantA).score,NS.ScoreItem(variantB).score
local otherScore=NS.ScoreItem("indexedOther").score
check(parseCalls-beforeParse==3 and variantScoreA~=variantScoreB,"cache indexes distinct suffix instances without joining their stats")
loaders[1].OnEvent(loaders[1],"GET_ITEM_INFO_RECEIVED",1000,true)
beforeParse=parseCalls
check(NS.ScoreItem(variantA).score==variantScoreA and NS.ScoreItem(variantB).score==variantScoreB
    and NS.ScoreItem("indexedOther").score==otherScore and parseCalls-beforeParse==2,
    "item-ID invalidation drops every cached instance of that item and preserves other items")
beforeParse=parseCalls
for i=1,100 do NS.InvalidateItemScoreCache(999999) end
NS.ScoreItem(variantA); NS.ScoreItem(variantB); NS.ScoreItem("indexedOther")
check(parseCalls==beforeParse,"unrelated repeated load events leave all indexed items warm")
NS.InvalidateItemScoreCache(); NS.InvalidateItemScoreCache(1000)
beforeParse=parseCalls
NS.ScoreItem(variantA); NS.ScoreItem(variantB); NS.ScoreItem("indexedOther")
check(parseCalls-beforeParse==3,"a full cache reset discards the item-ID index alongside parsed entries")

NS.InvalidateItemScoreCache()
for i=1,512 do
    local link="boundedOld" .. i
    item(link,{ITEM_MOD_INTELLECT_SHORT=i%20},{},{id=2000+i})
    NS.ScoreItem(link)
end
NS.ScoreItem(variantA) -- Capacity reset: only this new entry remains.
NS.InvalidateItemScoreCache(2512) -- Its old index must have been removed.
for i=1,512 do
    local link="boundedNew" .. i
    item(link,{ITEM_MOD_INTELLECT_SHORT=i%20},{},{id=3000+i})
    NS.ScoreItem(link)
end
beforeParse=parseCalls; NS.ScoreItem(variantA)
check(parseCalls==beforeParse+1,"capacity reset clears old item indexes without corrupting the bounded entry count")
NS.ExtractStats,NS.CalculateItemScore=originalExtract,originalCalculate

local ratingDivisor=10
GetCombatRatingBonusForCombatRatingValue=function(_,value) return value/ratingDivisor end
item("ratingCache",{ITEM_MOD_HIT_RATING_SHORT=10},{"+10 Hit Rating"})
local ratingTip=tooltip("ratingCache")
callbacks[1](ratingTip,ratingTip.data)
local initialRatingScore=NS.last.score
ratingDivisor=5
loaders[1].OnEvent(loaders[1],"PLAYER_LEVEL_UP",40)
ratingTip:ClearLines(); callbacks[1](ratingTip,ratingTip.data)
check(NS.last.score>initialRatingScore,"level updates recalculate rating conversion with unchanged raw stats and lines")
GetCombatRatingBonusForCombatRatingValue=nil

-- Permanent points remain separate from every item/set calculation.
local enchantedLink="item:900:803:0:0:0:0:-42:123"
local bareLink="item:900:0:0:0:0:0:-42:123"
item(bareLink,{ITEM_MOD_STRENGTH_SHORT=50},{"+50 Strength"},{id=900,quality=5,itemLevel=100,equipLoc="INVTYPE_WEAPON"})
item(enchantedLink,{ITEM_MOD_STRENGTH_SHORT=999},{"+50 Strength"},{id=900,quality=5,itemLevel=100,equipLoc="INVTYPE_WEAPON"})
items[enchantedLink].lines[#items[enchantedLink].lines+1]={type=15,leftText="Equip: Fiery Weapon grants +999 Strength."}
items[enchantedLink].lines[#items[enchantedLink].lines+1]={leftText="Fixture Set (2/4)"}
items[enchantedLink].lines[#items[enchantedLink].lines+1]={leftText="(2) Set: +500 Strength"}
local enchantedTip=tooltip(enchantedLink)
callbacks[1](enchantedTip,enchantedTip.data)
local enchantResult=NS.last
check(queriedLink==bareLink,"base stat query removes only the permanent enchant field")
check(enchantResult.score==NS.ScoreItem(bareLink).score and not enchantResult.scoring.hasEffect,
    "permanent proc/text does not alter intrinsic stats or item-level effect multiplier")
check(enchantResult.enchantmentScore==8 and enchantResult.totalScore==enchantResult.score+enchantResult.setBonusScore,
    "tier-four enchant contributes exactly eight separate points on legendary set gear")
check(#enchantedTip.additions==3 and enchantedTip.additions[2][1]=="Set Bonus Score"
    and enchantedTip.additions[3][1]=="Enchantment Score" and enchantedTip.additions[3][2]=="8",
    "one flat enchantment row is last below the set bonus")
local unknownLink="item:900:999999:0:0:0:0:-42:123"
items[unknownLink]=items[enchantedLink]
local unknownEnchTip=tooltip(unknownLink); callbacks[1](unknownEnchTip,unknownEnchTip.data)
check(unknownEnchTip.additions[#unknownEnchTip.additions][2]=="Unknown" and NS.last.enchantmentUnknown,
    "unknown applied enchants do not silently display a confirmed zero")
local missingEnchLink="item:900:0:0:0:0:0:-99:123"
items[missingEnchLink]=items[enchantedLink]
local missingEnchTip=tooltip(missingEnchLink); callbacks[1](missingEnchTip,missingEnchTip.data)
check(NS.last.enchantmentUnknown and missingEnchTip.additions[#missingEnchTip.additions][2]=="Unknown",
    "typed permanent rows without usable IDs preserve unknown enhancement status")

local mediumKitLink="item:99013:8481:0:0:0:0:-42:123"
local mediumKitBare=NS.GetUnenchantedItemLink(mediumKitLink)
local leggingsLines={"Slick Deviate Leggings","68 Armor","+4 Agility","+4 Stamina"}
item(mediumKitBare,{ITEM_MOD_ARMOR_SHORT=52,ITEM_MOD_AGILITY_SHORT=4,ITEM_MOD_STAMINA_SHORT=4},leggingsLines,
    {id=99013,quality=2,itemLevel=20,equipLoc="INVTYPE_LEGS"})
item(mediumKitLink,{ITEM_MOD_ARMOR_SHORT=68,ITEM_MOD_AGILITY_SHORT=4,ITEM_MOD_STAMINA_SHORT=6},leggingsLines,
    {id=99013,quality=2,itemLevel=20,equipLoc="INVTYPE_LEGS"})
items[mediumKitLink].lines[#items[mediumKitLink].lines+1]={type=15,leftText="Enchanted: Stamina +2 and Armor +16"}
local mediumKitTip=tooltip(mediumKitLink); callbacks[1](mediumKitTip,mediumKitTip.data)
check(#mediumKitTip.additions==2 and mediumKitTip.additions[1][2]=="11"
    and mediumKitTip.additions[2][1]=="Enchantment Score" and mediumKitTip.additions[2][2]=="1",
    "live leggings regression recognizes the current Medium kit as one separate point")
check(NS.last.enchantment.id==8481 and not NS.last.enchantmentUnknown
    and math.abs(NS.last.scoring.statScore-17.04)<0.00001,"current kit recognition does not add its armor/stamina to base scoring")
SlashCmdList.FOSSIEGS("debug")
check(messages[#messages]:find("Enchantment: ID 8481 | source item-link | tier 1",1,true)~=nil,
    "enchantment diagnostic reports the exact ID, recognition source and tier")

-- Exclusion maps are shared by item reads, but APIs that appear late must
-- still correct an already-cached score for the same native tooltip lines.
local savedEnums,savedExtract=Enum.TooltipDataLineType,NS.ExtractStats
local observedExclusions
NS.ExtractStats=function(raw,lines,context)
    observedExclusions=context.excludedTypes
    return savedExtract(raw,lines,context)
end
Enum.TooltipDataLineType={}
item('lateEnumsA',{}, {}, {id=99501})
item('lateEnumsB',{}, {}, {id=99502})
items.lateEnumsA.lines={{leftText='+10 Strength',type=987}}
items.lateEnumsB.lines={{leftText='+10 Strength',type=988}}
check(NS.ScoreItem('lateEnumsA').scoring.statScore==20,'unknown line types retain ordinary stat extraction')
local firstMap=observedExclusions
NS.ScoreItem('lateEnumsB')
check(observedExclusions==firstMap,'independent item reads reuse the unchanged exclusion map')
Enum.TooltipDataLineType.FlavorText=987
check(NS.ScoreItem('lateEnumsA').score==0,'in-place enum population corrects an already-cached flavor-text score')
local updatedMap=observedExclusions
check(updatedMap~=firstMap,'changed exclusions replace the shared map')
check(NS.ScoreItem('lateEnumsB').scoring.statScore==20 and observedExclusions==updatedMap,
 'new exclusions leave other numeric stat lines unchanged and reuse the rebuilt map')
Enum.TooltipDataLineType={FlavorText=988}
check(NS.ScoreItem('lateEnumsA').scoring.statScore==20 and NS.ScoreItem('lateEnumsB').score==0,
 'replacing enum definitions removes obsolete exclusions and recognizes their new IDs')
Enum.TooltipDataLineType.ItemEnchantmentPermanent=987
local lateEnchant=NS.ScoreItem('lateEnumsA')
check(lateEnchant.score==0 and lateEnchant.enchantmentUnknown,
 'late permanent-enchantment types are excluded from item stats and retain unknown enhancement status')
Enum.TooltipDataLineType=nil
check(NS.ScoreItem('lateEnumsA').scoring.statScore==20,'temporary API absence does not retain obsolete exclusions')
Enum.TooltipDataLineType=savedEnums
check(NS.ScoreItem(mediumKitLink).score==11 and NS.ScoreItem(mediumKitLink).enchantmentScore==1,
 'restored native enums retain the existing item and permanent-kit scores')
NS.ExtractStats=savedExtract

-- Real role classification and the final item penalty, through ScoreItem.
assert(loadfile("DynamicWeights.lua"))("FossieGearScore",NS)
local roleExpectations={
    WARRIOR={"Attack DPS","Attack DPS","Tank"}, PALADIN={"Healer","Tank","Attack DPS"},
    HUNTER={"Attack DPS","Attack DPS","Attack DPS"}, ROGUE={"Attack DPS","Attack DPS","Attack DPS"},
    PRIEST={"Healer","Healer","Spell DPS"}, SHAMAN={"Spell DPS","Attack DPS","Healer"},
    MAGE={"Spell DPS","Spell DPS","Spell DPS"}, WARLOCK={"Spell DPS","Spell DPS","Spell DPS"},
    DRUID={"Spell DPS","Tank","Healer"},
}
for class,roles in pairs(roleExpectations) do
    for tree,role in ipairs(roles) do
        local points={0,0,0}; points[tree]=15
        local p=NS.ClassifyTalents(class,points,60)
        check(NS.DYNAMIC_SPECS[class][tree].role==role and p.roles[role],class .. " tree has its designated role")
    end
end
local mageRole=NS.ClassifyTalents("MAGE",{15,0,0},60)
local healerRole=NS.ClassifyTalents("DRUID",{0,0,15},60)
local feralRole=NS.ClassifyTalents("DRUID",{0,15,0},60)
local hybridRole=NS.ClassifyTalents("DRUID",{0,28,27},60)
check(feralRole.roles.Tank and feralRole.roles["Attack DPS"],"feral accepts bear and cat items")
check(hybridRole.roles.Tank and hybridRole.roles["Attack DPS"] and hybridRole.roles.Healer,
    "hybrid accepts the union of its talent roles")
local function roleScore(link,p)
    return NS.ScoreItem(link,nil,{classToken=p.classToken,dynamicProfile=p,deferSet=true})
end
item("item:9001",{}, {"Use: Your next heal is free."},{id=9001,itemLevel=15,quality=3})
NS.ITEM_ROLES[9001]={Healer=true}
local wrongRole=roleScore("item:9001",mageRole)
local rightRole=roleScore("item:9001",healerRole)
check(wrongRole.dynamicScore==math.floor(rightRole.dynamicScore/2) and wrongRole.score==rightRole.score,
    "effect-only healer item receives half final DGS for a caster without changing GS")
check(wrongRole.dynamicScoring.rolePenaltyReason=="role-mismatch" and rightRole.dynamicScoring.roleMultiplier==1,
    "role mismatch is explained in calculation metadata")
check(roleScore("item:9001",hybridRole).dynamicScore==rightRole.dynamicScore,"hybrid healer role accepts healer items")
item("item:9002",{ITEM_MOD_INTELLECT_SHORT=20},{"+20 Intellect"},{id=9002,itemLevel=15,quality=2})
NS.ITEM_ROLES[9002]={Healer=true}
local taggedStats=roleScore("item:9002",mageRole)
check(taggedStats.dynamicScore==math.floor(taggedStats.dynamicScoring.scoreBeforeRolePenalty/2),
    "explicit role designation takes priority even when flat stats are useful")
item("item:9003",{ITEM_MOD_STRENGTH_SHORT=20},{"+20 Strength"},{id=9003,itemLevel=15,quality=2})
local useless=roleScore("item:9003",mageRole)
check(useless.dynamicScore==2 and useless.dynamicScoring.rolePenaltyReason=="no-matching-stats",
    "unassigned stat-only item halves the remaining item-level score when every stat is useless")
check(roleScore("item:9003",feralRole).dynamicScore==useless.score,"useful physical stats avoid fallback penalty")
item("item:9004",{ITEM_MOD_STRENGTH_SHORT=20,ITEM_MOD_STAMINA_SHORT=1},{},{id=9004,itemLevel=15,quality=2})
check(roleScore("item:9004",mageRole).dynamicScoring.roleMultiplier==1,"one useful shared stat prevents fallback penalty")
for index,text in ipairs({"Equip: Sometimes deals 100 Arcane damage when casting a spell.",
    "Use: Deals 100 Arcane damage.","Chance on hit: Deals 100 Arcane damage."}) do
    local link="item:" .. (9010+index)
    item(link,{ITEM_MOD_STRENGTH_SHORT=20},{text},{id=9010+index,itemLevel=15,quality=2})
    check(roleScore(link,mageRole).dynamicScoring.roleMultiplier==1,"unassigned effects prevent a speculative stat-only penalty")
end
item("item:9020",{}, {"Chance on hit: Gains a combat benefit."},{id=9020,itemLevel=15,quality=2})
NS.ITEM_ROLES[9020]={["Tank"]=true,["Spell DPS"]=true}
check(roleScore("item:9020",mageRole).dynamicScoring.roleMultiplier==1,"item may accept multiple roles")
check(roleScore("item:9020",feralRole).dynamicScoring.roleMultiplier==1,"feral can match tank role")
check(roleScore("item:9020",healerRole).dynamicScoring.roleMultiplier==0.5,"multiple-role item still rejects unrelated roles")
locale="deDE"
NS.InvalidateItemScoreCache()
check(roleScore("item:9003",mageRole).dynamicScoring.roleMultiplier==1,"incomplete stat parsing does not assert that all stats are useless")
check(roleScore("item:9001",mageRole).dynamicScoring.roleMultiplier==0.5,"explicit item role works independently of tooltip language")
locale="enUS"
local enchantedRoleLink="item:9030:803:0:0:0:0:0:0:60:0:0:0:0"
item(enchantedRoleLink,{}, {"Use: Your next heal is free."},{id=9030,itemLevel=15,quality=3,equipLoc="INVTYPE_WEAPON"})
items[NS.GetUnenchantedItemLink(enchantedRoleLink)]=items[enchantedRoleLink]
NS.ITEM_ROLES[9030]={Healer=true}
local enchantedRole=roleScore(enchantedRoleLink,mageRole)
check(enchantedRole.enchantmentScore==8 and enchantedRole.dynamicScoring.roleMultiplier==0.5,
    "role penalty never halves flat enchantment points")
local cachedRoleCalls=0
local roleMultiplier=NS.GetItemRoleMultiplier
NS.GetItemRoleMultiplier=function(...)
    cachedRoleCalls=cachedRoleCalls+1; return roleMultiplier(...)
end
NS.InvalidateItemScoreCache()
local firstRole=roleScore("item:9001",mageRole)
for i=1,100 do
    local again=roleScore("item:9001",mageRole)
    assert(again.dynamicScore==firstRole.dynamicScore and again.dynamicScoring==firstRole.dynamicScoring)
end
check(cachedRoleCalls==1,"repeated item reads reuse the cached role calculation")
NS.GetItemRoleMultiplier=roleMultiplier

-- Dynamic filtering may remove a penalty, but DGS must never exceed GS.
do
local function checkDynamicCap()
    local affliction=NS.ClassifyTalents("WARLOCK",{15,0,0},60)
    item("item:279870",{ITEM_MOD_STRENGTH_SHORT=3,ITEM_MOD_STAMINA_SHORT=6},{"-3 Strength","+6 Stamina"},
        {id=279870,itemLevel=24,quality=2,equipLoc="INVTYPE_NECK"})
    local locket=roleScore("item:279870",affliction)
    check(locket.score==9 and locket.dynamicScore==9,"Tarnished Locket caps Affliction DGS at its normal score")
    check(locket.scoring.statScore==6 and locket.dynamicScoring.statScore==12,
        "negative Strength remains signed without changing the spec's zero Strength weight")
    check(locket.dynamicScoring.scoreBeforeCap==11,"calculation records the uncapped dynamic score for diagnostics")
    local again=roleScore("item:279870",affliction)
    check(again.dynamicScore==9 and again.dynamicScoring==locket.dynamicScoring,"cached item retains the final capped score")
    local warriorRole=NS.ClassifyTalents("WARRIOR",{15,0,0},60)
    local physical=roleScore("item:279870",warriorRole)
    check(physical.dynamicScore==9 and physical.dynamicScoring.scoreBeforeCap==nil,
        "relevant negative stats keep their usual deduction without an unnecessary cap")
    local useful=roleScore("item:9003",mageRole)
    check(useful.dynamicScore==2 and useful.dynamicScoring.scoreBeforeCap==nil,"DGS already below GS remains unchanged")
    for index,stats in ipairs({
        {ITEM_MOD_STRENGTH_SHORT=-100},
        {ITEM_MOD_STRENGTH_SHORT=-6,ITEM_MOD_STAMINA_SHORT=6},
    }) do
        local link="item:" .. (9040+index)
        item(link,stats,{}, {id=9040+index,itemLevel=0,quality=1})
        local candidate=roleScore(link,affliction)
        check(candidate.score<=0 and candidate.dynamicScore==candidate.score,"cap also respects zero or negative GS")
        for pieces=1,19 do
            NS.ApplySetBonus(candidate,pieces,true)
            check(candidate.dynamicTotalScore<=candidate.totalScore,"active set totals retain the DGS ceiling")
        end
    end
    local oldClass,oldProfile=NS.GetClassToken,NS.ResolveDynamicProfile
    local oldVisibility,oldMode=NS.GetDisplayVisibility,NS.GetDisplayMode
    NS.GetClassToken=function() return "WARLOCK" end
    NS.ResolveDynamicProfile=function() return affliction end
    NS.GetDisplayVisibility=function() return true,true end
    NS.GetDisplayMode=function() return "both" end
    local capTip=tooltip("item:279870")
    callbacks[1](capTip,capTip.data)
    check(#capTip.additions==1 and capTip.additions[1][2]=="9","Both mode hides the newly equal dynamic row")
    NS.GetDisplayVisibility=function() return false,true end
    NS.GetDisplayMode=function() return "dynamic" end
    capTip:ClearLines(); callbacks[1](capTip,capTip.data)
    check(#capTip.additions==1 and capTip.additions[1][1]=="Dynamic Item Score" and capTip.additions[1][2]=="9",
        "dynamic-only mode displays the capped score")
    local oldNeck=gear[2]
    item("item:9043",{ITEM_MOD_STAMINA_SHORT=6},{"+6 Stamina"},{id=9043,itemLevel=24,quality=2,equipLoc="INVTYPE_NECK"})
    gear[2]="item:9043"
    check(NS.GetItemScoreDifference(locket,false)==-2 and NS.GetItemScoreDifference(locket,true)==-2,
        "equipped comparisons use the capped score for candidate and reference")
    gear[2]=oldNeck
    local capEnchant="item:9044:803:0:0:0:0:0:0:60:0:0:0:0"
    item(capEnchant,{ITEM_MOD_STRENGTH_SHORT=-3,ITEM_MOD_STAMINA_SHORT=6},{"-3 Strength","+6 Stamina"},
        {id=9044,itemLevel=24,quality=2,equipLoc="INVTYPE_WEAPON"})
    items[NS.GetUnenchantedItemLink(capEnchant)]=items[capEnchant]
    local enchanted=roleScore(capEnchant,affliction)
    check(enchanted.dynamicScore==enchanted.score and enchanted.enchantmentScore==8,
        "capping intrinsic DGS preserves separate flat enchantment points")
    item("item:9045",{ITEM_MOD_STRENGTH_SHORT=-20,ITEM_MOD_STAMINA_SHORT=10},{},
        {id=9045,itemLevel=24,quality=2})
    NS.ITEM_ROLES[9045]={Healer=true}
    local roleCapped=roleScore("item:9045",affliction)
    check(roleCapped.score==2 and roleCapped.dynamicScore==2 and roleCapped.dynamicScoring.scoreBeforeCap==6,
        "normal GS ceiling is applied after the explicit role penalty")
    NS.last=roleCapped; SlashCmdList.FOSSIEGS("debug")
    check(messages[#messages-1]:find("floor(13 x 0.5) = 6.",1,true)
        and messages[#messages]:find("DGS capped at GS: 6 -> 2.",1,true),
        "debug explains the role reduction and ceiling as separate calculation steps")
    NS.ITEM_ROLES[9041]={Healer=true}
    NS.InvalidateItemScoreCache(9041)
    local negativeRole=roleScore("item:9041",affliction)
    check(negativeRole.dynamicScore==-50 and negativeRole.dynamicScoring.roleMultiplier==0.5,
        "halving a negative role score cannot raise DGS above negative GS")
    NS.GetClassToken,NS.ResolveDynamicProfile=oldClass,oldProfile
    NS.GetDisplayVisibility,NS.GetDisplayMode=oldVisibility,oldMode
end
checkDynamicCap()
end

-- Exercise the cap through the real cached item reader for every spec and
-- role designation, including penalties, shared spell power and pure effects.
do
local function checkCapMatrix()
    local cases={
        {ITEM_MOD_STRENGTH_SHORT=-20,ITEM_MOD_STAMINA_SHORT=6},
        {ITEM_MOD_INTELLECT_SHORT=-50,ITEM_MOD_STAMINA_SHORT=1},
        {ITEM_MOD_AGILITY_SHORT=-30,ITEM_MOD_STRENGTH_SHORT=1},
        {ITEM_MOD_SPELL_POWER_SHORT=-100,ITEM_MOD_INTELLECT_SHORT=3},
        {ITEM_MOD_SPELL_HEALING_DONE_SHORT=-100,ITEM_MOD_SPELL_DAMAGE_DONE_SHORT=5},
        {ITEM_MOD_DEFENSE_SKILL_SHORT=-100,ITEM_MOD_BONUS_ARMOR_SHORT=-20},
        {ITEM_MOD_STRENGTH_SHORT=10,ITEM_MOD_INTELLECT_SHORT=10,ITEM_MOD_STAMINA_SHORT=10},
        {},
    }
    local itemID=600000
    for class,trees in pairs(NS.DYNAMIC_SPECS) do
        for tree in ipairs(trees) do
            local points={0,0,0}; points[tree]=15
            local p=NS.ClassifyTalents(class,points,60)
            for index,stats in ipairs(cases) do
                for _,role in ipairs({false,"Tank","Attack DPS","Spell DPS","Healer"}) do
                    itemID=itemID+1
                    local link="item:"..itemID
                    item(link,stats,index==8 and {"Use: Deals Arcane damage."} or {},
                        {id=itemID,itemLevel=index==2 and 0 or 24,quality=2})
                    if role then NS.ITEM_ROLES[itemID]={[role]=true} end
                    local candidate=roleScore(link,p)
                    local duplicate=roleScore(link,p)
                    local valid=candidate.dynamicScore<=candidate.score and duplicate.dynamicScore==candidate.dynamicScore
                    for _,pieces in ipairs({0,2,19}) do
                        NS.ApplySetBonus(candidate,pieces,pieces>0)
                        valid=valid and candidate.dynamicTotalScore<=candidate.totalScore
                            and candidate.dynamicSetBonusScore<=candidate.setBonusScore
                    end
                    check(valid,"DGS cap survives cache/set/role combination: "..class.." "..tree.." "..index.." "..tostring(role))
                end
            end
        end
    end
end
checkCapMatrix()
end

-- Inactive rows stay hidden, but remain subscribed to set-context refreshes.
do
local function checkSetRowVisibility()
    local oldContext,oldClass,oldProfile=NS.ResolveSetContext,NS.GetClassToken,NS.ResolveDynamicProfile
    local oldVisibility,oldMode=NS.GetDisplayVisibility,NS.GetDisplayMode
    local oldExtract,oldCalculate=NS.ExtractStats,NS.CalculateItemScore
    local active,mode,incomplete=false,"both",false
    NS.ResolveSetContext=function() return {count=active and 2 or 1,active=active,required=2},incomplete end
    NS.GetClassToken=function() return "MAGE" end
    NS.ResolveDynamicProfile=function() return mageRole end
    NS.GetDisplayMode=function() return mode end
    NS.GetDisplayVisibility=function() return mode~="dynamic",mode~="normal" end
    local link="item:700001:803:0:0:0:0:0:0:60:0:0:0:0"
    item(link,{ITEM_MOD_STRENGTH_SHORT=100,ITEM_MOD_INTELLECT_SHORT=1},
        {"+100 Strength","+1 Intellect","Visibility Set (0/2)","(2) Set: +10 Strength"},
        {id=700001,itemLevel=24,quality=2,equipLoc="INVTYPE_WEAPON"})
    items[NS.GetUnenchantedItemLink(link)]=items[link]
    local f=tooltip(link)
    local function row(label)
        for _,entry in ipairs(f.additions) do if entry[1]==label then return entry[2] end end
    end
    for _,choice in ipairs({"normal","dynamic","both"}) do
        mode=choice
        for _,enabled in ipairs({false,true,false}) do
            active=enabled; f:ClearLines(); callbacks[1](f,f.data)
            check((row("Set Bonus Score")~=nil)==(active and mode~="dynamic"),"normal set row requires an active bonus in "..mode)
            check((row("Dynamic Set Bonus Score")~=nil)==(active and mode~="normal"),"dynamic set row requires an active bonus in "..mode)
            check(f.additions[#f.additions][1]=="Enchantment Score" and row("Enchantment Score")=="8",
                "enchantment points stay last while set rows appear and disappear")
        end
    end
    active,incomplete,mode=false,true,"both"
    f:ClearLines(); callbacks[1](f,f.data)
    check(not row("Set Bonus Score") and not row("Dynamic Set Bonus Score") and NS.last.setPartial,
        "uncertain inactive set context does not display an unearned bonus")
    local refreshes=0
    f.IsShown=function() return true end
    f.RefreshDataNextUpdate=function() refreshes=refreshes+1 end
    NS.RefreshSetTooltips()
    check(refreshes==1,"an inactive set still requests a rebuild when equipment changes")
    f.IsShown=function() return false end
    active,incomplete=true,false
    f:ClearLines(); callbacks[1](f,f.data)
    check(row("Set Bonus Score") and row("Dynamic Set Bonus Score"),"activating a previously hidden set restores both earned rows")
    local extracts,calculations=0,0
    NS.ExtractStats=function(...) extracts=extracts+1; return oldExtract(...) end
    NS.CalculateItemScore=function(...) calculations=calculations+1; return oldCalculate(...) end
    for i=1,100 do
        active=i%2==0
        f:ClearLines(); callbacks[1](f,f.data)
    end
    check(extracts==0 and calculations==0,"100 set visibility rebuilds reuse cached stats and GS/DGS calculations")
    NS.ExtractStats,NS.CalculateItemScore=oldExtract,oldCalculate
    NS.ResolveSetContext,NS.GetClassToken,NS.ResolveDynamicProfile=oldContext,oldClass,oldProfile
    NS.GetDisplayVisibility,NS.GetDisplayMode=oldVisibility,oldMode
end
checkSetRowVisibility()
end
print("PASS: " .. count .. " tooltip lifecycle/integration checks (" .. _VERSION .. ")")
