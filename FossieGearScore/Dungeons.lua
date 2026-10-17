local _, NS = ...

-- Flatten the supplied shared references once. Rendering only filters this
-- small catalogue and reads existing scores; it never scans gear or talents.
local catalogue={}
local benchmarks=NS.DUNGEON_BENCHMARKS or {}
for _,key in ipairs(benchmarks.groupOrder or {}) do
    local group=benchmarks.groups and benchmarks.groups[key]
    local baseline=group and NS.GetNumber(group.baselineGS)
    for _,name in ipairs(group and group.instances or {}) do
        local range=NS.DUNGEON_LEVELS and NS.DUNGEON_LEVELS[name]
        local lo,hi=range and NS.GetNumber(range.minLevel),range and NS.GetNumber(range.maxLevel)
        if baseline and baseline>0 and lo and hi and lo<=hi then
            catalogue[#catalogue+1]={name=name,group=key,baseline=baseline,minLevel=lo,maxLevel=hi}
        end
    end
end
table.sort(catalogue,function(a,b)
    if a.minLevel~=b.minLevel then return a.minLevel<b.minLevel end
    if a.maxLevel~=b.maxLevel then return a.maxLevel<b.maxLevel end
    return a.name<b.name
end)
NS.DUNGEON_CATALOGUE=catalogue

local ratings={
    {minimum=140,label="Overgeared",color={0.75,0.57,1}},
    {minimum=120,label="Well geared",color={0.56,0.80,0.48}},
    {minimum=110,label="Geared",color={0.53,0.77,0.94}},
    {minimum=90,label="Average",color={0.95,0.79,0.43}},
    {minimum=80,label="Below average",color={1,0.65,0.35}},
    {minimum=-math.huge,label="Far below",color={1,0.48,0.40}},
}
function NS.GetDungeonRating(score,baseline)
    score,baseline=NS.GetNumber(score),NS.GetNumber(baseline)
    if not score or not baseline or baseline<=0 then return end
    -- Exact percentages of the midpoint, not the export's rounded points.
    -- A boundary belongs to the higher band: 90% Average, 110% Geared, etc.
    for _,rating in ipairs(ratings) do
        if score*100>=baseline*rating.minimum then return rating end
    end
end

function NS.BuildDungeonRatings(level,record,complete)
    level=NS.GetNumber(level)
    if not level or level<=0 then return {},"Player level unavailable" end
    local score,scoreType
    if complete and record and not record.partial and not record.dataPending
        and not record.enchantmentUnknown then
        local dynamic=record.dynamicAvailable and NS.GetNumber(record.dynamicScore)
        local normal,enchantments=NS.GetNumber(record.score),NS.GetNumber(record.enchantmentScore)
        local base=dynamic or normal
        if base and enchantments then
            score=base+enchantments
            scoreType=dynamic and "DGS" or "GS"
        end
    end
    local rows,byReference={},{}
    for _,instance in ipairs(catalogue) do
        if level>=instance.minLevel and level<=instance.maxLevel then
            local row=byReference[instance.baseline]
            if not row then
                row={baseline=instance.baseline,instances={},score=score,scoreType=scoreType,
                    rating=score and NS.GetDungeonRating(score,instance.baseline)}
                byReference[instance.baseline]=row
                rows[#rows+1]=row
            end
            -- Filter each instance first. Equal references can span distinct
            -- source groups (e.g. RFK/Gnomeregan and Scarlet Graveyard).
            row.instances[#row.instances+1]=instance
        end
    end
    return rows,not score and "Score unavailable" or nil,scoreType
end
