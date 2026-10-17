local _, NS = ...
local ARMOR_SLOTS={1,3,5,6,7,8,9,10,15}
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c,d,e,f,g=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g end
end
local function safeString(value)
    return NS.IsSafe(value) and type(value)=="string" and value~="" and value or nil
end
-- Weak item keys follow snapshot lifetimes; invalidation stamps are bounded.
local metadataCache=setmetatable({}, {__mode="k"})
local metadataVersions,metadataVersionCount={},0

-- Completed item metadata is stable within a snapshot. Do not retain failed
-- lookups; a loading item must be able to acquire its real name/icon later.
function NS.InvalidateInspectionMetadata(itemID)
    itemID=NS.GetNumber(itemID)
    if not itemID then return end
    if not metadataVersions[itemID] then
        if metadataVersionCount>=512 then
            metadataCache=setmetatable({}, {__mode="k"})
            metadataVersions,metadataVersionCount={},0
        end
        metadataVersionCount=metadataVersionCount+1
    end
    metadataVersions[itemID]=(metadataVersions[itemID] or 0)+1
end
local function metadata(link,item)
    local cached=item and metadataCache[item]
    local version=item and metadataVersions[item.itemID] or 0
    if cached and cached.link==link and cached.version==version then return cached.info end
    local _,_,_,loc,icon,_,subclass=call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,link)
    local name=call(C_Item and C_Item.GetItemInfo or GetItemInfo,link)
    local info={equipLoc=safeString(loc) or item and item.equipLoc,icon=NS.IsSafe(icon) and icon~=0 and icon or nil,
        subclass=NS.GetNumber(subclass),name=safeString(name) or link:match("%[([^]]+)%]") or "Loading item..."}
    if item and not item.dataPending and safeString(loc) and safeString(name) and info.icon and info.subclass then
        metadataCache[item]={link=link,version=version,info=info}
    end
    return info
end
local function enhancement(item,link)
    if not item or item.dataPending then return {state="unknown"} end
    local enchant=item.enchantment
    if enchant then
        if item.enchantmentUnknown or enchant.unknown then return {state="unsupported",enchanted=true} end
        local tier=NS.GetNumber(enchant.tier)
        if tier then return {state="enchanted",enchanted=true,tier=tier,ambiguous=enchant.ambiguous==true} end
    end
    -- A zero/empty link field and complete native permanent-line coverage establish
    -- absence. An unavailable API, truncated link or empty tooltip does not.
    local permanent=Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
    local id=link:match("item:%d+:([^:|]*):")
    if permanent and (id=="0" or id=="") and item.lines and #item.lines>0 and not item.partial and not item.enchantmentUnknown then
        return {state="missing",enchanted=false}
    end
    return {state="unknown"}
end
-- Tier colours are relative to the highest confirmed tier this player wears.
-- Unknown or uncertain tiers stay neutral white.
function NS.GetEnchantmentBarColor(enchant,highestTier)
    if enchant.state=="missing" then return 0.27,0.27,0.27,1 end
    if enchant.state~="enchanted" or enchant.ambiguous then return 0.8,0.8,0.8,1 end
    local gap=(highestTier or enchant.tier)-enchant.tier
    if gap==0 then return 0.2,0.6,1,1
    elseif gap==1 then return 0.3,0.85,0.35,1
    elseif gap==2 then return 1,0.85,0.1,1
    else return 1,0.25,0.2,1 end
end
local function enchantmentText(enchant)
    return enchant and enchant.enchanted and "Enchanted" or ""
end
local function talentText(who)
    if who.level and who.level<NS.TALENT_RULES.minLevel then return "Spec unknown","0/0/0" end
    local actual=NS.talentProfiles and NS.talentProfiles[who.guid]
    if not actual or actual.guid~=who.guid or actual.classToken~=who.classToken then return "Spec unknown","Talents unknown" end
    local points=actual.points
    local a,b,c=points and NS.GetNumber(points[1]),points and NS.GetNumber(points[2]),points and NS.GetNumber(points[3])
    local split=a and b and c and string.format("%.0f/%.0f/%.0f",a,b,c) or "Talents unknown"
    return actual.available and actual.name or "Spec unknown",split
end
local function itemView(record,slot,allMetadata,coverage)
    local item=record and record.itemDetails[slot]
    local link=record and record.links[slot]
    -- Known empty slots have no highlight. Unavailable data stays distinct
    -- from an empty slot and is explained by the panel's loading status.
    if not link then return end
    local view={slot=slot,link=link,item=item}
    local info=allMetadata[slot]
    view.name,view.icon=info.name,info.icon
    view.loading=not item or item.partial or item.dataPending
    if not view.loading then view.score,view.dynamicScore=item.score,item.dynamicScore end
    view.enchantment=enchantmentText(coverage.pieces[slot])
    return view
end

local function coverageRank(piece)
    if piece.state=="enchanted" and not piece.ambiguous then return 0 end
    if piece.enchanted then return 1 end
    return piece.state=="missing" and 3 or 2
end
local function compareCoverage(a,b)
    local ar,br=coverageRank(a),coverageRank(b)
    if ar~=br then return ar<br end
    if ar==0 and a.tier~=b.tier then return a.tier>b.tier end
    return a.slot<b.slot
end
-- Keep bar ordering in the projection, leaving rendering to draw colours only.
local function orderCoverage(coverage)
    local pieces,highestTier={},nil
    for slot=1,19 do
        local piece=coverage.pieces[slot]
        if piece then
            pieces[#pieces+1]=piece
            if piece.state=="enchanted" and not piece.ambiguous then highestTier=math.max(highestTier or 0,piece.tier) end
        end
    end
    table.sort(pieces,compareCoverage)
    coverage.orderedPieces,coverage.highestTier=pieces,highestTier
end

-- Project GUID-bound snapshots without inventory scans or inspection requests.
-- Alternative spec estimates reuse captured item data and cache per snapshot.
function NS.BuildInspectionPanelData(who)
    local model={name=who.name,className=who.className,level=who.level,guid=who.guid,highlights={}}
    model.spec,model.talents=talentText(who)
    local record=NS.gearSnapshots and NS.gearSnapshots[who.guid] or NS.gearCache and NS.gearCache[who.guid]
    if record and (record.guid~=who.guid or record.classToken~=who.classToken) then record=nil end
    model.record=record
    local complete=record and not record.partial and not record.dataPending and next(record.links)~=nil
    model.complete=complete==true
    model.assessment=NS.BuildGearAssessment(who.level,record,model.complete)
    model.dungeons,model.dungeonStatus,model.dungeonScoreType=NS.BuildDungeonRatings(who.level,record,model.complete)
    local allMetadata={}
    local coverage={eligible=0,enchanted=0,missing=0,unknown=0,unsupported=0,unresolved=0,tiers={},ambiguous=0,pieces={}}
    model.coverage=coverage
    if record then
        for slot,link in pairs(record.links) do
            local item=record.itemDetails[slot]
            local info=metadata(link,item)
            allMetadata[slot]=info
            local eligible=NS.IsPermanentEnhancementEligible(info.equipLoc,info.subclass)
            if eligible==nil then coverage.unresolved=coverage.unresolved+1
            elseif eligible then
                coverage.eligible=coverage.eligible+1
                local enchant=enhancement(item,link)
                enchant.slot=slot
                coverage.pieces[slot]=enchant
                if enchant.enchanted then coverage.enchanted=coverage.enchanted+1 end
                if enchant.state=="enchanted" then
                    if enchant.ambiguous then coverage.ambiguous=coverage.ambiguous+1
                    else coverage.tiers[enchant.tier]=(coverage.tiers[enchant.tier] or 0)+1 end
                else coverage[enchant.state]=coverage[enchant.state]+1 end
            end
        end
    end
    if record and next(record.missingSlots or {}) then coverage.unresolved=coverage.unresolved+1 end
    orderCoverage(coverage)
    local normal,dynamic="Loading...","Unavailable"
    if complete then
        normal=NS.FormatGearTotal(record,false,false,"character")
        if record.dynamicAvailable and record.dynamicScore~=nil then dynamic=NS.FormatGearTotal(record,false,true,"character") end
    end
    model.gs,model.dgs=normal,dynamic
    model.override=record and record.dynamicProfile and record.dynamicProfile.overridden and record.dynamicProfile.name or nil
    local function highlight(slot)
        local view=itemView(record,slot,allMetadata,coverage)
        if view then model.highlights[#model.highlights+1]=view end
    end
    if who.classToken=="HUNTER" then
        highlight(18)
    else
        highlight(16)
        local main=allMetadata[16]
        if not main or main.equipLoc~="INVTYPE_2HWEAPON" then highlight(17) end
    end
    local best
    if complete then
        for _,slot in ipairs(ARMOR_SLOTS) do
            local item=record.itemDetails[slot]
            if item and not item.partial and not item.dataPending and item.score~=nil
                and (not best or item.score>record.itemDetails[best].score) then best=slot end
        end
    end
    if best then highlight(best) end
    local known=complete and coverage.unknown==0 and coverage.unresolved==0
    local fraction=string.format("%d/%d eligible pieces enchanted",coverage.enchanted,coverage.eligible)
    model.enchantments=complete and coverage.unresolved==0 and fraction or "Enhancement data unavailable"
    local details={}
    if coverage.missing>0 then details[#details+1]=coverage.missing .. " missing" end
    if coverage.unknown>0 then details[#details+1]=coverage.unknown .. " unknown" end
    if coverage.unsupported>0 then details[#details+1]=coverage.unsupported .. " unsupported tiers" end
    if coverage.ambiguous>0 then details[#details+1]=coverage.ambiguous .. " uncertain tiers" end
    if coverage.unresolved>0 then details[#details+1]="Slot eligibility incomplete" end
    model.enchantmentDetails=table.concat(details,"; ")
    local tiers={}
    for tier=1,#NS.ENCHANTMENT_REFERENCE.tierPoints do
        if coverage.tiers[tier] then tiers[#tiers+1]="Tier " .. tier .. ": " .. coverage.tiers[tier] end
    end
    model.tiers=table.concat(tiers,"   ")
    if not known then model.summary="Inspection incomplete; no equipment assessment available."
    elseif coverage.eligible==0 then model.summary="No eligible equipped pieces."
    else
        local notes={}
        if coverage.enchanted==coverage.eligible then notes[#notes+1]="Fully enchanted" end
        if #tiers>1 then notes[#notes+1]="Mixed enchant tiers" end
        if coverage.unsupported>0 or coverage.ambiguous>0 then notes[#notes+1]="Some tiers unknown" end
        model.summary=#notes>0 and table.concat(notes,"; ") .. "." or ""
    end
    return model
end

