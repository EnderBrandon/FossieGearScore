local _, NS = ...
local alternatives=setmetatable({}, {__mode="k"})

local function betterSpecs(record,gs,dgs)
    local current=record.dynamicProfile
    local cached=alternatives[record]
    if cached and cached.profile==current and cached.gs==gs and cached.dgs==dgs then return cached.matches end
    local matches,best={},dgs
    for tree,definition in ipairs(NS.DYNAMIC_SPECS[record.classToken] or {}) do
        -- A hybrid can also be compared with each constituent pure tree.
        if current.hybrid or not current.trees or current.trees[1]~=tree then
            local points={0,0,0}; points[tree]=NS.TALENT_RULES.capstonePoints
            local profile=NS.ClassifyTalents(record.classToken,points,current.level,current.race)
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

-- Level ratings use the supplied unenchanted GS references. Spec fit compares
-- unenchanted DGS with the same gear's GS, independently of the level reference.
-- Only alternative profiles need calculation, once per published snapshot;
-- captured item stats, effects, role penalties, caps and wearer set counts apply.
function NS.BuildGearAssessment(level,record,complete)
    local result={alternatives={}}
    level=NS.GetNumber(level)
    local reference=level and NS.GetNumber(NS.LEVEL_BENCHMARKS.byLevel[level])
    result.reference=reference
    if not complete or not record or record.partial or record.dataPending then return result end
    local gs=NS.GetNumber(record.score)
    result.gs=gs
    if gs and reference and reference>0 then
        result.rating=NS.GetDungeonRating(gs,reference)
        result.levelPercent=gs*100/reference
    end
    local profile=record.dynamicProfile
    local dgs=record.dynamicAvailable and NS.GetNumber(record.dynamicScore)
    if not gs or gs<=0 or not dgs or not profile or not profile.available
        or profile.classToken~=record.classToken then return result end
    result.spec=profile.name
    result.fitPercent=dgs*100/gs
    if dgs==gs then result.fit="optimal"
    elseif dgs*100<gs*80 then
        result.fit="suboptimal"
        result.alternatives=betterSpecs(record,gs,dgs)
    else result.fit="partial" end
    return result
end
