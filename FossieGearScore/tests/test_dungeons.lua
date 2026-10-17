local NS,count={},0
local function check(ok,why) assert(ok,why); count=count+1 end
for _,file in ipairs({"Weights.lua","Scoring.lua","DungeonBenchmarks.lua","DungeonLevels.lua","Dungeons.lua"}) do
    assert(loadfile(file))("FossieGearScore",NS)
end
local function has(rows,name)
    for _,row in ipairs(rows) do
        for _,instance in ipairs(row.instances) do if instance.name==name then return row end end
    end
end
local record={score=9999,dynamicAvailable=true,dynamicScore=265,enchantmentScore=0}
check(#NS.DUNGEON_CATALOGUE==14,"all fourteen benchmarked instances have researched ranges")
for _,dungeon in ipairs(NS.DUNGEON_CATALOGUE) do
    local range=NS.DUNGEON_LEVELS[dungeon.name]
    check(range.minLevel==dungeon.minLevel and range.maxLevel==dungeon.maxLevel,"range is read from its separate table")
    check(has(NS.BuildDungeonRatings(range.minLevel,record,true),dungeon.name),"lower level boundary is inclusive: " .. dungeon.name)
    check(has(NS.BuildDungeonRatings(range.maxLevel,record,true),dungeon.name),"upper level boundary is inclusive: " .. dungeon.name)
    check(not has(NS.BuildDungeonRatings(range.minLevel-1,record,true),dungeon.name),"below-range dungeon is hidden: " .. dungeon.name)
    check(not has(NS.BuildDungeonRatings(range.maxLevel+1,record,true),dungeon.name),"above-range dungeon is hidden: " .. dungeon.name)
    check(NS.GetDungeonRating(dungeon.baseline,dungeon.baseline).label=="Average","midpoint yields Average for every supplied baseline")
end
local boundaries={
    {800,"Far below","Below average"},{900,"Below average","Average"},
    {1100,"Average","Geared"},{1200,"Geared","Well geared"},{1400,"Well geared","Overgeared"},
}
for _,boundary in ipairs(boundaries) do
    check(NS.GetDungeonRating(boundary[1]-1,1000).label==boundary[2],"immediately below the percentage cutoff")
    check(NS.GetDungeonRating(boundary[1],1000).label==boundary[3],"exact cutoff enters the higher band")
    check(NS.GetDungeonRating(boundary[1]+1,1000).label==boundary[3],"immediately above the percentage cutoff")
end
check(NS.GetDungeonRating(0,62).label=="Far below" and NS.GetDungeonRating(-1,62).label=="Far below",
    "confirmed nonpositive scores can be rated")
check(NS.GetDungeonRating(74,62).label=="Geared" and NS.GetDungeonRating(75,62).label=="Well geared",
    "ratings use exact ratios rather than rounded exported points")
for _,bad in ipairs({false,"unknown",math.huge,0/0}) do
    check(not NS.GetDungeonRating(bad,100),"invalid DGS is never Far below")
    check(not NS.GetDungeonRating(100,bad),"invalid reference has no rating")
end
check(not NS.GetDungeonRating(nil,100) and not NS.GetDungeonRating(100,nil)
    and not NS.GetDungeonRating(100,0) and not NS.GetDungeonRating(100,-1),"missing/nonpositive references cannot be rated")
local rows,status,scoreType=NS.BuildDungeonRatings(30,record,true)
check(#rows==6 and status==nil and scoreType=="DGS","level thirty groups eight eligible instances into six references")
check(has(rows,"Razorfen Kraul").baseline==265 and has(rows,"Gnomeregan").baseline==265,
    "shared references retain their benchmark")
check(has(rows,"Razorfen Kraul")==has(rows,"Gnomeregan")
    and has(rows,"Razorfen Kraul")==has(rows,"Scarlet Monastery: Graveyard")
    and #has(rows,"Razorfen Kraul").instances==3,"equal reference values merge even across different source groups")
check(#NS.BuildDungeonRatings(13,record,true)==1 and #NS.BuildDungeonRatings(13,record,true)[1].instances==2,
    "Hall of Thanes and Ragefire share one reference row")
do
    local before=NS.BuildDungeonRatings(29,record,true)
    local group=has(before,"Razorfen Kraul")
    check(group==has(before,"Gnomeregan") and #group.instances==2
        and not has(before,"Scarlet Monastery: Graveyard"),"filter each instance before grouping equal references")
    local wc=has(NS.BuildDungeonRatings(17,record,true),"Wailing Caverns")
    check(#wc.instances==2 and wc.instances[1].minLevel==15 and wc.instances[1].maxLevel==24
        and wc.instances[2].minLevel==17 and wc.instances[2].maxLevel==26,
        "grouped names retain each instance's own level range")
    local seen={}
    for _,row in ipairs(rows) do
        check(not seen[row.baseline],"a reference appears only once in the grouped list")
        seen[row.baseline]=true
    end
end
check(has(rows,"Razorfen Kraul").rating.label=="Average", "comparison uses DGS rather than the much higher normal GS")
local normalOnly={score=265,enchantmentScore=20,dynamicAvailable=false,dynamicScore=1}
rows,status,scoreType=NS.BuildDungeonRatings(30,normalOnly,true)
check(scoreType=="GS" and status==nil and rows[1].score==285 and rows[1].scoreType=="GS",
    "unavailable DGS falls back to normal GS plus enhancement points")
check(has(rows,"Razorfen Kraul").rating.label=="Average","fallback does not use an unavailable/stale dynamic score")
normalOnly.dynamicAvailable=true; normalOnly.dynamicScore=nil
rows,status,scoreType=NS.BuildDungeonRatings(30,normalOnly,true)
check(scoreType=="GS" and rows[1].score==285,"a missing numeric DGS also uses the complete normal score")
normalOnly.score=0; normalOnly.enchantmentScore=0
rows,status,scoreType=NS.BuildDungeonRatings(30,normalOnly,true)
check(scoreType=="GS" and rows[1].score==0 and rows[1].rating.label=="Far below","confirmed zero normal GS is a valid fallback")
check(not has(rows,"Scarlet Monastery: Library") and has(rows,"Excavation Site: Wetlands"),
    "in-game bands exclude Library and include Excavation Site at level thirty")
check(has(NS.BuildDungeonRatings(33,record,true),"Scarlet Monastery: Library").baseline==320,
    "Library uses the user's final 320 reference at its new entry band")
check(has(NS.BuildDungeonRatings(15,record,true),"Wailing Caverns")
    and not has(NS.BuildDungeonRatings(15,record,true),"The Deadmines")
    and has(NS.BuildDungeonRatings(25,record,true),"The Deadmines")
    and not has(NS.BuildDungeonRatings(25,record,true),"Wailing Caverns"),"shared WC/DM benchmark keeps separate in-game filtering")
check(has(NS.BuildDungeonRatings(38,record,true),"Razorfen Kraul")
    and has(NS.BuildDungeonRatings(38,record,true),"Gnomeregan")
    and not has(NS.BuildDungeonRatings(39,record,true),"Razorfen Kraul")
    and not has(NS.BuildDungeonRatings(39,record,true),"Gnomeregan"),"RFK and Gnomeregan end at level thirty-eight")
record.dynamicScore,record.enchantmentScore=280,20
rows=NS.BuildDungeonRatings(33,record,true)
check(has(rows,"Scarlet Monastery: Library").rating.label=="Average"
    and has(rows,"Scarlet Monastery: Library").score==300,"known enchantment points are included once in comparison DGS")
local missing={
    {dynamicAvailable=false,dynamicScore=265,enchantmentScore=0},
    {dynamicAvailable=true,enchantmentScore=0},
    {dynamicAvailable=true,dynamicScore=265},
    {dynamicAvailable=true,dynamicScore=265,enchantmentScore=0,partial=true},
    {dynamicAvailable=true,dynamicScore=265,enchantmentScore=0,dataPending=true},
    {dynamicAvailable=true,dynamicScore=265,enchantmentScore=0,enchantmentUnknown=true},
}
for _,incomplete in ipairs(missing) do
    rows,status=NS.BuildDungeonRatings(30,incomplete,true)
    check(#rows==6 and status=="Score unavailable","eligible groups survive unavailable scores")
    for _,row in ipairs(rows) do check(not row.rating and row.score==nil,"incomplete DGS cannot become a zero or low rating") end
end
rows,status=NS.BuildDungeonRatings(30,record,false)
check(#rows==6 and not rows[1].rating and status=="Score unavailable","incomplete scans do not expose even otherwise cached numeric scores")
rows,status=NS.BuildDungeonRatings(30,nil,false)
check(#rows==6 and not rows[1].rating and status=="Score unavailable","no inspection still shows thresholds without fabricated ratings")
rows,status=NS.BuildDungeonRatings(nil,record,true)
check(#rows==0 and status=="Player level unavailable","unknown levels do not borrow a bracket")
check(#NS.BuildDungeonRatings(60,record,true)==0,"unbenchmarked endgame dungeons and raids receive no invented values")
print("PASS: " .. count .. " dungeon range/rating checks (" .. _VERSION .. ")")
