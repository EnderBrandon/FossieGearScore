local NS, count = {}, 0
for _, file in ipairs({"Weights.lua", "Scoring.lua", "Comparison.lua"}) do
    assert(loadfile(file))("FossieGearScore", NS)
end
local function check(ok, label) assert(ok, label); count=count+1 end
local gear, items, native, dualWield = {}, {}, nil, false
local scoreReads, nativeReads, inventoryReads, locationReads, guidReads = 0, 0, 0, 0, 0
C_Item={GetItemInfoInstant=function(link)
    locationReads=locationReads+1
    return 1,"Armor","Cloth",items[link].location
end,GetItemLinkByGUID=function(guid)
    guidReads=guidReads+1
    return guid=="instance-guid" and "item:42:0:0:0:0:0:-5:123"
end}
GetInventoryItemLink=function(_,slot) return gear[slot] end
GetInventoryItemTexture=function(_,slot) return gear[slot] and 1 end
CanDualWield=function() return dualWield end
C_TooltipComparison={GetItemComparisonInfo=function() nativeReads=nativeReads+1; return native end}
NS.ScoreItem=function(link,_,options)
    scoreReads=scoreReads+1
    assert(options.deferSet,"comparison must not resolve worn sets")
    local item=items[link]
    if item and item.loaded~=false then return {score=item.score,dynamicScore=item.dynamicScore,partial=item.partial} end
end
local function item(link,score,location,extra)
    items[link]=extra or {}; items[link].score=score; items[link].location=location
    return {link=link,score=score,partial=items[link].partial}
end
local candidate=item("head",10,"INVTYPE_HEAD")
check(NS.GetItemScoreDifference(candidate)==10,"empty head slot contributes zero baseline")
item("oldHead",12,"INVTYPE_HEAD"); gear[1]="oldHead"
check(NS.GetItemScoreDifference(candidate)==-2,"lower head score displays a decrease")
items.oldHead.score=10
check(NS.GetItemScoreDifference(candidate)==0,"equal head score is neutral")

candidate=item("ring",25,"INVTYPE_FINGER")
item("ringA",30,"INVTYPE_FINGER"); item("ringB",20,"INVTYPE_FINGER")
gear={[11]="ringA",[12]="ringB"}
check(NS.GetItemScoreDifference(candidate)==5,"ring compares with the better replacement choice")
gear[12]=nil
check(NS.GetItemScoreDifference(candidate)==25,"empty second ring slot is preferred")
native={method=0,item={hyperlink="ringA"},additionalItems={}}
check(NS.GetItemScoreDifference(candidate)==25,"native omission of an empty ring slot does not turn an upgrade into a downgrade")
native=nil
candidate=item("trinket",20,"INVTYPE_TRINKET")
item("trinketA",32,"INVTYPE_TRINKET"); item("trinketB",18,"INVTYPE_TRINKET")
gear={[13]="trinketA",[14]="trinketB"}
check(NS.GetItemScoreDifference(candidate)==2,"trinket compares with weaker occupied slot")

candidate=item("twoHand",50,"INVTYPE_2HWEAPON")
item("main",30,"INVTYPE_WEAPON"); item("off",25,"INVTYPE_SHIELD")
gear={[16]="main",[17]="off"}
check(NS.GetItemScoreDifference(candidate)==-5,"two-hander removes main-hand plus shield score")
candidate=item("oneHand",15,"INVTYPE_WEAPON")
items.main.score=20; items.off.score=10; dualWield=true
check(NS.GetItemScoreDifference(candidate)==5,"dual-wield replacement chooses the larger gain")
dualWield=false
check(NS.GetItemScoreDifference(candidate)==-5,"non-dual-wielder only compares a one-hander to main hand")
candidate=item("mainOnly",15,"INVTYPE_WEAPONMAINHAND"); dualWield=true
check(NS.GetItemScoreDifference(candidate)==-5,"main-hand-only weapon cannot compare to weaker offhand")
candidate=item("shield",10,"INVTYPE_SHIELD")
item("oldTwoHand",40,"INVTYPE_2HWEAPON"); gear={[16]="oldTwoHand"}
check(NS.GetItemScoreDifference(candidate)==-30,"shield removes an equipped two-hander in fallback")
candidate=item("wand",10,"INVTYPE_RANGEDRIGHT")
item("oldRanged",20,"INVTYPE_RANGED"); gear={[18]="oldRanged"}
check(NS.GetItemScoreDifference(candidate)==-10,"ranged weapon compares with ranged slot")

candidate=item("head",10,"INVTYPE_HEAD")
gear={[1]="oldHead"}; items.oldHead.partial=true
check(NS.GetItemScoreDifference(candidate)==nil,"partial equipped score cannot produce a false upgrade")
items.oldHead.partial=false; items.oldHead.loaded=false
check(NS.GetItemScoreDifference(candidate)==nil,"unloaded equipped score is not treated as empty")
items.oldHead.loaded=true
candidate.partial=true
check(NS.GetItemScoreDifference(candidate)==nil,"partial candidate score has an unknown difference")
candidate.partial=false
GetInventoryItemLink=function() return nil end
GetInventoryItemTexture=function() return 1 end
check(NS.GetItemScoreDifference(candidate)==nil,"occupied slot with missing link is not zero")
GetInventoryItemLink=function(_,slot) return gear[slot] end
GetInventoryItemTexture=function(_,slot) return gear[slot] and 1 end

-- Exercise the real native comparison structures: these may contain GUIDs
-- and paired bag weapons, not just straightforward inventory slots.
candidate=item("twoHand",50,"INVTYPE_2HWEAPON")
items.main.score=30; items.off.score=25
native={method=1,item={hyperlink="main"},additionalItems={{hyperlink="off"}}}
check(NS.GetItemScoreDifference(candidate)==-5,"native BothHands subtracts both equipped items once")
candidate=item("oneHand",15,"INVTYPE_WEAPON")
native={method=0,item={hyperlink="main"},additionalItems={{hyperlink="off"}}}
check(NS.GetItemScoreDifference(candidate)==-10,"native Single considers alternate valid equipped replacements")
candidate=item("oneHand",25,"INVTYPE_WEAPON")
item("bagPartner",20,"INVTYPE_WEAPONOFFHAND")
native={method=2,item={hyperlink="oldTwoHand"},additionalItems={{hyperlink="bagPartner"}}}
check(NS.GetItemScoreDifference(candidate)==5,"native bag partner is included when replacing a two-hander")
native.method=3
check(NS.GetItemScoreDifference(candidate)==5,"native off-hand pairing uses the same gain arithmetic")
item("item:42:0:0:0:0:0:-5:123",24,"INVTYPE_WEAPON")
native={method=0,item={guid="instance-guid"},additionalItems={}}
check(NS.GetItemScoreDifference(candidate)==1,"native GUID is resolved to its full instance link")
items["item:42:0:0:0:0:0:-5:123"].loaded=false
check(NS.GetItemScoreDifference(candidate)==nil,"unloaded native comparison cannot produce a guessed gain")

-- Normal and dynamic rows share one native snapshot during a decoration,
-- but a new decoration must observe changed equipment and loading state.
candidate=item("twoHand",50,"INVTYPE_2HWEAPON"); candidate.dynamicScore=30
items.main.dynamicScore=17; items.off.dynamicScore=8
native={method=1,item={hyperlink="main"},additionalItems={{hyperlink="off"}}}
local reads={}
local beforeScores,beforeNative,beforeLocations=scoreReads,nativeReads,locationReads
check(NS.GetItemScoreDifference(candidate,false,reads)==-5,"shared comparison keeps normal two-hand replacement arithmetic")
check(NS.GetDynamicItemScoreDifference(candidate,reads)==5,"shared comparison uses dynamic values from the same items")
check(scoreReads-beforeScores==2 and nativeReads-beforeNative==1 and locationReads-beforeLocations==1,
    "both score rows read each worn item once and native comparison once")
items.main.score=20; items.main.dynamicScore=10
reads={}
check(NS.GetItemScoreDifference(candidate,false,reads)==5 and NS.GetDynamicItemScoreDifference(candidate,reads)==12,
    "a new decoration sees changed normal and dynamic equipped scores")

native={method=0,item={guid="instance-guid"},additionalItems={}}
items["item:42:0:0:0:0:0:-5:123"].loaded=true
items["item:42:0:0:0:0:0:-5:123"].dynamicScore=11
reads={}; local beforeGUID=guidReads; beforeScores=scoreReads; beforeNative=nativeReads
check(NS.GetItemScoreDifference(candidate,false,reads)==26 and NS.GetDynamicItemScoreDifference(candidate,reads)==19,
    "native GUID comparison preserves full-link scores for both rows")
check(guidReads-beforeGUID==1 and scoreReads-beforeScores==1 and nativeReads-beforeNative==1,
    "a GUID and its item are resolved only once per decoration")

candidate=item("ring",25,"INVTYPE_FINGER"); candidate.dynamicScore=10
items.ringA.dynamicScore=5; items.ringB.dynamicScore=15
gear={[11]="ringA",[12]="ringB"}; native=nil
GetInventoryItemLink=function(_,slot) inventoryReads=inventoryReads+1; return gear[slot] end
reads={}; beforeScores=scoreReads; beforeNative=nativeReads; local beforeInventory=inventoryReads
check(NS.GetItemScoreDifference(candidate,false,reads)==5 and NS.GetDynamicItemScoreDifference(candidate,reads)==5,
    "ring replacement can choose different equipped slots for normal and dynamic scores")
check(scoreReads-beforeScores==2 and inventoryReads-beforeInventory==2 and nativeReads==beforeNative,
    "both ring rows read their two inventory slots and items once")
gear[12]=nil; reads={}
check(NS.GetItemScoreDifference(candidate,false,reads)==25 and NS.GetDynamicItemScoreDifference(candidate,reads)==10,
    "a later decoration notices an empty second ring slot")

candidate=item("head",10,"INVTYPE_HEAD"); candidate.dynamicScore=7
native={method=0,item={hyperlink="oldHead"},additionalItems={}}
items.oldHead.partial=true; reads={}; beforeScores=scoreReads
check(NS.GetItemScoreDifference(candidate,false,reads)==nil and NS.GetDynamicItemScoreDifference(candidate,reads)==nil,
    "partial comparison data stays unknown for both score rows")
check(scoreReads-beforeScores==1,"partial equipped data is read once per decoration")
items.oldHead.partial=false; items.oldHead.loaded=false; reads={}; beforeScores=scoreReads
check(NS.GetItemScoreDifference(candidate,false,reads)==nil and NS.GetDynamicItemScoreDifference(candidate,reads)==nil,
    "missing item data stays unknown for both score rows")
check(scoreReads-beforeScores==1,"failed item reads are reused within the decoration")
items.oldHead.loaded=true; items.oldHead.dynamicScore=3; reads={}
check(NS.GetItemScoreDifference(candidate,false,reads)==0 and NS.GetDynamicItemScoreDifference(candidate,reads)==4,
    "a new decoration observes an item that has finished loading")

native=nil; GetInventoryItemLink=function() error("inventory unavailable") end
GetInventoryItemTexture=function() return nil end; reads={}
check(NS.GetItemScoreDifference(candidate,false,reads)==nil and NS.GetDynamicItemScoreDifference(candidate,reads)==nil,
    "an inventory API error cannot become an empty-slot upgrade")

check(NS.FormatScoreDifference(5)=="|cff00ff00(+5)|r","positive difference is green with a plus sign")
check(NS.FormatScoreDifference(-5)=="|cffff4040(-5)|r","negative difference is red")
check(NS.FormatScoreDifference(0)=="|cffffffff(0)|r","neutral difference is white")
check(NS.FormatScoreDifference(nil)=="|cffffffff(?)|r","unknown difference is white and explicit")
print("PASS: " .. count .. " bag comparison checks (" .. _VERSION .. ")")
