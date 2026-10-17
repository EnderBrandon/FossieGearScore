local _, NS = ...
local alternatives=setmetatable({}, {__mode="k"})
local treeProfiles=setmetatable({}, {__mode="k"})

local function treeProfile(current,tree)
    local profiles=treeProfiles[current]
    if not profiles then profiles={}; treeProfiles[current]=profiles end
    if not profiles[tree] then
        local points={0,0,0}; points[tree]=NS.TALENT_RULES.capstonePoints
        profiles[tree]=NS.ClassifyTalents(current.classToken,points,current.level,current.race)
    end
    -- Reuse identity across gear snapshots so intrinsic item/profile scoring
    -- caches can retain the same alternate tree instead of recalculating it.
    return profiles[tree]
end

local function betterSpecs(record,gs,dgs)
    local current=record.dynamicProfile
    local cached=alternatives[record]
    if cached and cached.profile==current and cached.gs==gs and cached.dgs==dgs then return cached.matches end
    local matches,best={},dgs
    for tree,definition in ipairs(NS.DYNAMIC_SPECS[record.classToken] or {}) do
        -- A hybrid can also be compared with each constituent pure tree.
        if current.hybrid or not current.trees or current.trees[1]~=tree then
            local profile=treeProfile(current,tree)
            local total,valid=0,profile.available
            for slot in pairs(record.links) do
                local item=record.itemDetails[slot]
                local score=valid and NS.GetCachedItemDynamicScore(item,profile)
                if score==nil or score==false then valid=false; break end
                local _,withSet=NS.CalculateSetBonus(score,item.setPieces,item.setActive)
                total=total+withSet
            end
            if valid and total*100>=gs*80 and total>dgs then
                local name=current.treeNames and current.treeNames[tree] or definition.name
                if total>best then matches={}; best=total end
                if total==best then matches[#matches+1]={name=name,tree=tree,score=total,percent=total*100/gs} end
            end
        end
    end
    alternatives[record]={profile=current,gs=gs,dgs=dgs,matches=matches}
    return matches
end

-- Shared level rating for the menu and hover. This path never evaluates
-- alternative specs, so hovering only reads the already-published normal GS.
function NS.GetLevelGearRating(level,record,complete)
    level=NS.GetNumber(level)
    local reference=level and NS.GetNumber(NS.LEVEL_BENCHMARKS.byLevel[level])
    if not complete or not record or record.partial or record.dataPending then return nil,reference end
    return NS.GetDungeonRating(record.score,reference),reference
end
local hoverLabels={
    ["Overgeared"]="Overgeared", ["Well geared"]="Well Geared", ["Geared"]="Well Geared",
    ["Average"]="Averagely Geared", ["Below average"]="Badly Geared", ["Far below"]="Very Badly Geared",
}
function NS.GetHoverGearRating(level,record,complete)
    local rating=NS.GetLevelGearRating(level,record,complete)
    if rating then return hoverLabels[rating.label],rating.color end
end

-- Level ratings use the supplied unenchanted GS references. Spec fit compares
-- unenchanted DGS with the same gear's GS, independently of the level reference.
-- Only alternative profiles need calculation, once per published snapshot;
-- captured item stats, effects, role penalties, caps and wearer set counts apply.
function NS.BuildGearAssessment(level,record,complete)
    local result={alternatives={}}
    result.rating,result.reference=NS.GetLevelGearRating(level,record,complete)
    local reference=result.reference
    if not complete or not record or record.partial or record.dataPending then return result end
    local gs=NS.GetNumber(record.score)
    result.gs=gs
    if gs and reference and reference>0 then
        result.levelPercent=gs*100/reference
    end
    local profile=record.dynamicProfile
    local dgs=record.dynamicAvailable and NS.GetNumber(record.dynamicScore)
    if not dgs or not profile or not profile.available
        or profile.classToken~=record.classToken then return result end
    if reference and reference>0 then
        result.dynamicRating=NS.GetDungeonRating(dgs,reference)
        result.dynamicLevelPercent=dgs*100/reference
    end
    if not gs or gs<=0 then return result end
    result.spec=profile.name
    result.fitPercent=dgs*100/gs
    if dgs<=gs and dgs*100>gs*95 then result.fit="optimal"
    elseif dgs*100<gs*80 then
        result.fit="suboptimal"
        result.alternatives=betterSpecs(record,gs,dgs)
    else result.fit="partial" end
    return result
end
