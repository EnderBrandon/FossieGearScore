local NS, count = {}, 0
for _, file in ipairs({"Weights.lua", "Scoring.lua", "EnchantmentData.lua", "Enchantments.lua"}) do
    assert(loadfile(file))("FossieGearScore", NS)
end
local function check(ok, label) assert(ok, label); count=count+1 end
local function enchant(id, slot, expected, label)
    local score, info = NS.ReadEnchantmentScore("item:100:"..id..":0:0:0:0:-101:99", nil, {equipLoc=slot})
    check(score==expected, label)
    check(info and info.source=="item-link" and info.id==id, label .. " uses applied ID")
    return info
end
Enum={TooltipDataLineType={ItemEnchantmentPermanent=15,ItemSpellTriggerOnUse=44,GemSocket=3}}

-- Independent client ID fixtures cover changed Forever enchants, crafted kits,
-- permanent utility and reputation upgrades, with raw grey-derived tiers.
enchant(41,"INVTYPE_CHEST",1,"Forever chest Inferior Stamina is tier 1")
enchant(8216,"INVTYPE_WEAPON",2,"Insight proc receives tier 2 flat points")
enchant(8218,"INVTYPE_NECK",4,"new necklace Spell Power is tier 3")
enchant(1894,"INVTYPE_WEAPON",8,"Icy Chill is tier 4")
enchant(1900,"INVTYPE_WEAPON",16,"Crusader is tier 5")
enchant(8482,"INVTYPE_FEET",1,"Mystic Medium Armor Kit applied ID is tier 1")
-- Live screenshot regression: basic kits use new native IDs, not simulator aliases.
for _,slot in ipairs({"INVTYPE_CHEST","INVTYPE_LEGS","INVTYPE_HAND","INVTYPE_FEET"}) do
    enchant(8481,slot,1,"current Medium Armor Kit on "..slot)
    enchant(8484,slot,2,"current Heavy Armor Kit on "..slot)
    enchant(8487,slot,2,"current Thick Armor Kit on "..slot)
    enchant(8490,slot,4,"current Rugged Armor Kit on "..slot)
end
enchant(16,"INVTYPE_LEGS",1,"legacy Medium Armor Kit alias retained")
enchant(17,"INVTYPE_CHEST",2,"legacy Heavy Armor Kit alias retained")
enchant(18,"INVTYPE_HAND",2,"legacy Thick Armor Kit alias retained")
enchant(1843,"INVTYPE_FEET",4,"legacy Rugged Armor Kit alias retained")
enchant(8485,"INVTYPE_CHEST",2,"Mystic Heavy Armor Kit is tier 2")
enchant(8489,"INVTYPE_HAND",2,"Mystic Thick Armor Kit grey 225 is tier 2")
enchant(8492,"INVTYPE_LEGS",4,"Mystic Rugged Armor Kit is tier 3")
enchant(8491,"INVTYPE_FEET",4,"Forceful Rugged Armor Kit is tier 3")
enchant(8720,"INVTYPE_RANGED",8,"SAF-T scope is tier 4")
enchant(8719,"INVTYPE_ROBE",8,"Wild Leather kit is tier 4")
enchant(37,"INVTYPE_WEAPONMAINHAND",2,"Weapon Chain utility earns reference tier")
enchant(43,"INVTYPE_SHIELD",2,"Iron spike is tier 2")
enchant(463,"INVTYPE_SHIELD",4,"Mithril spike is tier 3")
enchant(1704,"INVTYPE_SHIELD",4,"Thorium spike is tier 3")
enchant(464,"INVTYPE_FEET",4,"Mithril Spurs utility earns reference tier")
enchant(7657,"INVTYPE_RANGEDRIGHT",8,"unconfirmed Obsidian scope retains tier")
enchant(7920,"INVTYPE_WAIST",4,"permanent belt Nitro install retains tier")
enchant(2682,"INVTYPE_HEAD",4,"Ice Guard is manually tier 3")
enchant(2487,"INVTYPE_SHOULDER",4,"Shadow Mantle is manually tier 3")
enchant(2606,"INVTYPE_SHOULDER",8,"Zandalar Might signet is manually tier 4")
enchant(2583,"INVTYPE_LEGS",16,"Presence of Might is manually tier 5")
enchant(2721,"INVTYPE_SHOULDER",16,"Power of the Scourge is manually tier 5")
enchant(7942,"INVTYPE_2HWEAPON",8,"Grand Sorcerer retains grey 310 rather than guessed strength")
enchant(66,"INVTYPE_WRIST",1,"shared stamina ID uses bracer tier")
enchant(66,"INVTYPE_FEET",2,"shared stamina ID uses boots tier")
enchant(1887,"INVTYPE_HAND",4,"shared agility ID uses gloves tier")
enchant(1887,"INVTYPE_FEET",16,"shared agility ID uses boots tier")
local ambiguous = enchant(805,"INVTYPE_2HWEAPON",2,"indistinguishable 2H Impact/Striking uses lowest applicable tier")
check(ambiguous.ambiguous and ambiguous.policy=="lowest-applicable-tier","ambiguity is explicit")
enchant(805,"INVTYPE_WEAPON",8,"one handed Striking resolves different tier")
local missingSlot = enchant(851,nil,2,"unknown slot conservatively uses lowest tier")
check(missingSlot.ambiguous,"unknown-slot tier ambiguity recorded")

local link="|cff0070dd|Hitem:123:1900:2401:2402:0:0:-123:987654:60:0:0:0:1:3524|h[Blade of the Owl]|h|r"
check(NS.GetUnenchantedItemLink(link)=="|cff0070dd|Hitem:123:0:2401:2402:0:0:-123:987654:60:0:0:0:1:3524|h[Blade of the Owl]|h|r","strip only permanent field, preserve gems/random suffix/instance/bonuses")
check(NS.GetUnenchantedItemLink("item:123::0:0:-42")=="item:123:0:0:0:-42","empty permanent field is handled")
check(NS.GetUnenchantedItemLink("item:123")=="item:123","minimal item string is preserved")
check(NS.GetUnenchantedItemLink(nil)==nil,"nil link is safe")
local score, info=NS.ReadEnchantmentScore("item:123:0:2401:0:0:0:-1900:999",{"Use: Wizard Oil", "+15 Strength"})
check(score==0 and info==nil,"gems, suffix and untyped text do not become permanent enchants")
score,info=NS.ReadEnchantmentScore("item:123:999999",{{type=15,leftText="|Hspell:20034|hCrusader|h"}})
check(score==0 and info.unknownID==999999,"unknown applied ID cannot be replaced by familiar tooltip spell")
score,info=NS.ReadEnchantmentScore("item:123:1900",nil,{equipLoc="INVTYPE_NECK"})
check(score==0 and info.reason=="unmatched-slot","impossible slot cannot receive unrelated enchant tier")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=15,spellID=1254742,leftText="Localized kit"}},{equipLoc="INVTYPE_FEET"})
check(score==1 and info.source=="tooltip-spell-id","typed native apply spell fallback works without English names")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=15,enchantmentID=8482},{type=15,enchantmentID=8482}},{equipLoc="INVTYPE_FEET"})
check(score==1,"duplicate permanent rows count once")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=15,enchantID=8482},{type=15,enchantID=8491}},{equipLoc="INVTYPE_FEET"})
check(score==0 and info.reason=="conflicting-permanent-lines","conflicting rows do not establish stackability")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=44,spellID=1254742},{type=3,spellID=20034}}, {equipLoc="INVTYPE_FEET"})
check(score==0 and info==nil,"use effects and sockets are excluded")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=15,leftText="Unknown permanent effect"}})
check(score==0 and info.unknown,"unidentified permanent line is reported, not guessed")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=15,enchantID=999999}})
check(score==0 and info.unknownID==999999,"unknown native permanent ID is retained")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=15,enchantID=1900},{type=15,enchantID=999999}})
check(score==0 and info.unknown,"mixed known/unknown native installs do not pretend complete coverage")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=15,leftText="|Hspell:20034|hLocalized text|h"}},{equipLoc="INVTYPE_WEAPON"})
check(score==16,"typed hyperlink spell can identify native permanent enchant")
score,info=NS.ReadEnchantmentScore("item:123:1900",nil,{equipLoc="INVTYPE_WEAPON",rarity=0,classToken="MAGE",setPieces=19,effectMultiplier=20})
check(score==16,"flat points ignore rarity, talent role, set and proc multipliers")

local secret={}
issecretvalue=function(value) return value==secret end
score,info=NS.ReadEnchantmentScore(secret,nil)
check(score==0 and info==nil,"secret item link is not parsed")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=secret,enchantID=1900,leftText=secret}})
check(score==0 and info==nil,"secret native line type is not compared")
score,info=NS.ReadEnchantmentScore("item:123:0",{{type=15,enchantmentID=secret,enchantID=8482,spellID=secret,leftText=secret}},{equipLoc="INVTYPE_FEET"})
check(score==1,"secret optional IDs/text cannot prevent safe alternate enchant ID")
score,info=NS.ReadEnchantmentScore("item:123:1900",nil,{equipLoc=secret})
check(score==16,"secret equipment location cannot be used as table key")
check(NS.GetUnenchantedItemLink(secret)==secret,"secret link stripping is bypassed")
issecretvalue=nil

check(#NS.ENCHANTMENT_CATALOG==249,"all 249 assigned reference entries are retained")
check(#NS.ENCHANTMENT_PENDING==7,"seven unverified families stay separate and unscored")
local recipeCount, manualCount, craftedCount, unconfirmedCount=0,0,0,0
for _, entry in ipairs(NS.ENCHANTMENT_CATALOG) do
    check(entry.enchantIDs and #entry.enchantIDs>0,"applied mapping present for "..entry.name)
    check(entry.spellIDs and #entry.spellIDs>0,"spell mapping present for "..entry.name)
    check(NS.ENCHANTMENT_SOURCES[entry.source]~=nil,"source retained for "..entry.name)
    if entry.profession=="Enchanting" then recipeCount=recipeCount+1
    elseif entry.profession=="Quest/reputation" then manualCount=manualCount+1
    else craftedCount=craftedCount+1 end
    if entry.availability=="unconfirmed" then unconfirmedCount=unconfirmedCount+1 end
end
check(recipeCount==179 and manualCount==38 and craftedCount==32,"reference recipe/attachment/manual coverage matches")
check(unconfirmedCount==14,"unconfirmed recipes and attachments retain availability metadata")
print("Passed " .. count .. " enchantment checks")
