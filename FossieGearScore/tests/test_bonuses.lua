local NS, count = {}, 0
for _, file in ipairs({"Weights.lua", "Scoring.lua", "Bonuses.lua"}) do
    assert(loadfile(file))("FossieGearScore", NS)
end
local function check(ok, label) assert(ok, label); count=count+1 end
local function close(a,b,label) check(math.abs(a-b)<0.000001,label) end
Enum={TooltipDataLineType={ItemName=22, FlavorText=37, ItemEnchantmentPermanent=15,
    GemSocket=3, GemSocketEnchantment=30, UsageRequirement=43,
    ItemSpellTriggerOnEquip=45, ItemSpellTriggerOnProc=46, ItemSpellTriggerOnUse=44}}

for _, text in ipairs({"Equip: +7 Spirit", "Chance on hit: Deals 40 Fire damage.",
    "|cff00ff00Equip: Random effect.|r", "  CHANCE ON HIT: Random effect."}) do
    check(NS.ReadItemBonuses({text}).hasEffect,"recognizes intrinsic effect: " .. text)
end
for _, text in ipairs({"Use: +50 Strength", "Story about Equip: effects", "(2) Set: Equip: +5 Strength",
    "Set: Chance on hit: Deals damage", "Requires Level 40"}) do
    check(not NS.ReadItemBonuses({text}).hasEffect,"does not infer intrinsic effect: " .. text)
end
for _, kind in ipairs({15,3,30,37,22,43}) do
    check(not NS.ReadItemBonuses({{type=kind,leftText="Equip: +50 Strength"}}).hasEffect,"ignores enchant/socket/flavor type " .. kind)
end
check(NS.ReadItemBonuses({{type=45,leftText="Localized passive effect"}}).hasEffect,"native equip type works without English wording")
check(NS.ReadItemBonuses({{type=46,leftText="Localized proc effect"}}).hasEffect,"native proc type works without English wording")
check(NS.ReadItemBonuses({{type=44,leftText="Localized use effect"}}).hasUse,"native on-use type qualifies for its own effect factor")
local multiple=NS.ReadItemBonuses({"Equip: Effect A", "Equip: Effect B", "Chance on hit: Effect C"})
check(multiple.hasEffect,"multiple effects remain a single boolean qualifier")
local afterHeader=NS.ReadItemBonuses({"Fortress (4/4)","(2) Set: +100 Strength",{type=45,leftText="Equip: Set effect"}},123)
check(not afterHeader.hasEffect,"effects in set section do not trigger intrinsic multiplier")
check(afterHeader.set.id==123 and afterHeader.set.equipped==4 and afterHeader.set.required==2,"reads set identity, header count and first threshold")
local beforeHeader=NS.ReadItemBonuses({"Equip: +10 Strength","Fortress (4/4)","(2) Set: +100 Strength"},123)
check(beforeHeader.hasEffect,"intrinsic equip bonus before set header still qualifies")
local byName=NS.ReadItemBonuses({"Unmapped Set (2 / 5)","(2) Set: +10 Spirit","(4) Set: +20 Strength"})
check(NS.GetSetKey(byName.set)=="name:unmapped set" and byName.set.required==2,"set name fallback and lowest bonus threshold")
check(not NS.ReadItemBonuses({"Durability (2/5)","Equip: +10 Spirit"}).set,"unrelated counts without a set bonus do not create a set")
check(NS.ReadItemBonuses({"Durability (2/5)","Equip: +10 Spirit"}).hasEffect,"unrelated count header does not hide equip effects")

local expected={[0]=28,[1]=35,[2]=40,[3]=41,[4]=43,[5]=47}
local factors={[0]=1,[1]=1,[2]=1.05,[3]=1.05,[4]=1.05,[5]=1.05}
for quality, score in pairs(expected) do
    local actual,_,details=NS.CalculateItemScore({Strength=10},100,quality,true)
    check(actual==score,"effect/base/rarity/divisor order for quality " .. quality)
    close(details.baseScore,120*factors[quality],"only the item-level base gets the extra factor")
    close(details.statScore,20,"effect multiplier does not multiply stat subtotal")
end
local noEffect,_,plain=NS.CalculateItemScore({Strength=10},100,3,false)
check(noEffect==40 and plain.effectMultiplier==1,"item without effect retains original calculation")
check(NS.CalculateItemScore({},100,4,true)==37,"proc-only epic item receives the 1.05 base factor")
for _, text in ipairs({"Use: +50 Strength", "  USE : Restores 50 mana.", "|cff00ff00Use: Random effect.|r"}) do
    check(NS.ReadItemBonuses({text}).hasUse,"recognizes intrinsic on-use effect: " .. text)
end
for _, kind in ipairs({15,3,30,37,22,43}) do
    check(not NS.ReadItemBonuses({{type=kind,leftText="Use: +50 Strength"}}).hasUse,
        "ignores use effect in enchant/socket/flavor type " .. kind)
end
check(not NS.ReadItemBonuses({"Fortress (4/4)","Set: Use: Random effect.",
    {type=44,leftText="Use: Set effect"}},123).hasUse,"set section does not create an intrinsic use multiplier")
for quality, expected in pairs({[0]=36,[1]=45,[2]=49,[3]=51,[4]=54,[5]=58}) do
    local actual,_,details=NS.CalculateItemScore({},100,quality,false,true)
    check(actual==expected and details.baseScore==180 and details.effectMultiplier==1.5,
        "on-use-only base gets one 1.5 factor for quality " .. quality)
end
local mixed=NS.ReadItemBonuses({"Equip: Effect A", "Use: Effect B", "Chance on hit: Effect C", "Use: Effect D"})
local useScore,_,useDetails=NS.CalculateItemScore({Strength=10},100,4,mixed.hasEffect,mixed.hasUse)
check(useScore==60 and useDetails.statScore==20 and useDetails.effectMultiplier==1.5,
    "multiple use/equip/proc lines apply a single use factor only on the base")
local two,total,multiplier=NS.CalculateSetBonus(105,2,true)
check(two==16 and total==121,"two-piece bonus uses three 1.05 factors")
close(multiplier,1.157625,"active two-piece exponent is pieces plus one")
local four,fourTotal=NS.CalculateSetBonus(105,4,true)
check(four==29 and fourTotal==134,"four-piece example uses five 1.05 factors")
local three,threeTotal=NS.CalculateSetBonus(105,3,true)
check(three==22 and threeTotal==127,"three worn pieces use four 1.05 factors")
check(NS.CalculateSetBonus(105,4,false)==0,"inactive set does not grant extra score")
check(NS.CalculateSetBonus(0,4,true)==1,"active set on zero-base item gets the requested minimum")
check(NS.CalculateSetBonus(105,0,true)==0,"zero pieces cannot activate a bonus")

local function member(id,name,header,required,enabled)
    local line={leftText="(" .. required .. ") Set: +500 Strength"}
    if enabled~=nil then line.leftColor=enabled and {r=0,g=1,b=0} or {r=0.5,g=0.5,b=0.5} end
    return {set=NS.ReadItemBonuses({name .. " (" .. header .. "/5)",line},id).set}
end
local a,b,c,d=member(100,"Counted Set",4,2),member(100,"Counted Set",4,2),member(100,"Counted Set",4,2),member(100,"Counted Set",4,2)
local grouped=NS.BuildSetGroups({[1]=a,[3]=b},true)["id:100"]
check(grouped.count==2 and grouped.active,"equipment scan count overrides a misleading four-piece header")
check(not NS.BuildSetGroups({a},true)["id:100"].active,"single piece of a two-piece set is inactive")
check(NS.BuildSetGroups({a,b,c},true)["id:100"].count==3,"three pieces do not round down to a two-piece tier")
local other=member(200,"Other Set",0,2)
local groups=NS.BuildSetGroups({a,b,c,d,other},true)
check(groups["id:100"].count==4 and groups["id:200"].count==1,"different sets maintain separate counts")
local disabledA,disabledB=member(300,"Disabled Set",2,2,false),member(300,"Disabled Set",2,2,false)
check(NS.BuildSetGroups({disabledA,disabledB},true)["id:300"].active,"equipped threshold activates despite gray tooltip text")
check(NS.BuildSetGroups({disabledA,disabledB},false)["id:300"].active,"inspect thresholds do not inherit local tooltip eligibility colors")
local green=member(300,"Disabled Set",2,2,true)
check(NS.BuildSetGroups({green,disabledB},true)["id:300"].active,"unlocked green bonus confirms own set is active")
local incomplete={set=NS.ReadItemBonuses({},400).set}
check(not NS.BuildSetGroups({incomplete},true)["id:400"].active,"unknown bonus requirements are never guessed")

local queried
C_Item={GetItemInfo=function(link)
    queried=link
    return "Item",link,3,40,30,"Armor","Plate",1,"INVTYPE_HEAD",0,0,4,4,1,0,123
end}
check(NS.GetItemSetID("item:123:0:0:0:0:0:-42:123")==123 and queried=="item:123:0:0:0:0:0:-42:123","native sixteenth return uses full instance link")
C_Item.GetItemInfo=function() error("uncached metadata") end
check(NS.GetItemSetID("uncached")==nil,"item-set metadata errors are contained")
local secret={}
issecretvalue=function(v) return v==secret end
local safe=NS.ReadItemBonuses({{leftText=secret},{leftText="Secret Set (2/4)"},
    {leftText="(2) Set: +10 Strength",leftColor={r=secret,g=secret,b=secret}}},secret)
check(safe.set and safe.set.required==2 and not safe.hasEffect,"secret colors and ID are safely skipped")
issecretvalue=nil
print("PASS: " .. count .. " effect/set scoring checks (" .. _VERSION .. ")")
