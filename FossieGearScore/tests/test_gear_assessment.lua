local NS,count={},0
local function check(ok,why) assert(ok,why); count=count+1 end
for _,file in ipairs({"Weights.lua","DynamicWeights.lua","Scoring.lua","LevelBenchmarks.lua",
    "DungeonBenchmarks.lua","DungeonLevels.lua","Dungeons.lua","GearAssessment.lua"}) do
    assert(loadfile(file))("FossieGearScore",NS)
end
local standalone=assert(loadfile("LevelBenchmarks.lua"))()
check(standalone.byLevel[30]==265 and standalone.scoringFingerprint==NS.LEVEL_BENCHMARKS.scoringFingerprint,
    "the adjusted attachment remains usable standalone and retains its scoring identity")
local labels={"Below average","Average","Geared","Well geared","Overgeared"}
for level=1,60 do
    local ref=NS.LEVEL_BENCHMARKS.byLevel[level]
    check(ref~=nil,"all supplied level references are retained")
    for index,percent in ipairs({80,90,110,120,140}) do
        local split=NS.LEVEL_BENCHMARKS.splitsByLevel[level][percent]
        check(split==ref*percent/100,"every level has all five exact percentage cutoffs")
        if ref>0 then
            local a=NS.BuildGearAssessment(level,{score=split,enchantmentScore=9999},true)
            check(a.rating.label==labels[index],"an exact level cutoff enters the higher rating band")
            local before=NS.BuildGearAssessment(level,{score=split-0.001},true)
            check(before.rating.label~=labels[index],"scores just below a level cutoff remain in the lower band")
        end
    end
end
local profile=NS.ClassifyTalents("DRUID",{26,0,0},30,"NightElf")
local function record(gs,dgs)
    return {score=gs,dynamicScore=dgs,dynamicAvailable=true,classToken="DRUID",dynamicProfile=profile,
        itemDetails={},links={}}
end
check(not NS.BuildGearAssessment(1,record(100,100),true).rating,"level one's zero reference cannot produce a level ratio")
check(NS.BuildGearAssessment(1,record(100,100),true).fit=="optimal","spec fit is independent of the level reference")
for _,level in ipairs({0,-1,1.5,61,false,"unknown",math.huge,0/0}) do
    check(not NS.BuildGearAssessment(level,record(265,265),true).rating,"invalid or unsupported levels do not invent a reference")
end
check(NS.BuildGearAssessment(30,record(371,371),true).rating.label=="Overgeared","normal GS is rated against the level reference")
check(NS.BuildGearAssessment(30,record(265,1),true).rating.label=="Average","level grading uses GS even when DGS is much lower")
check(NS.BuildGearAssessment(30,record(265,265),true).fit=="optimal","equal positive GS and DGS is optimal")
check(NS.BuildGearAssessment(30,record(100,79.999),true).fit=="suboptimal","strictly below eighty percent is suboptimal")
check(NS.BuildGearAssessment(30,record(100,80),true).fit=="partial","exactly eighty percent is not suboptimal")
check(NS.BuildGearAssessment(30,record(100,99.999),true).fit=="optimal","a loss of less than five percent is optimal")
check(NS.BuildGearAssessment(30,record(100,95.001),true).fit=="optimal","just under five percent loss is optimal")
check(NS.BuildGearAssessment(30,record(100,95),true).fit=="partial","exactly five percent loss is outside optimal")
check(NS.BuildGearAssessment(30,record(100,94.999),true).fit=="partial","more than five percent loss remains partial")
check(not NS.BuildGearAssessment(30,record(0,0),true).fit,"empty or zero-score gear is not labelled optimal")
check(not NS.BuildGearAssessment(30,record(-1,-1),true).fit,"negative GS cannot define a fit percentage")
for _,bad in ipairs({false,"unknown",math.huge,0/0}) do
    check(not NS.BuildGearAssessment(30,record(bad,100),true).rating,"invalid GS is unavailable rather than poorly rated")
    check(not NS.BuildGearAssessment(30,record(100,bad),true).fit,"invalid DGS cannot label a spec's fit")
end
for _,key in ipairs({"partial","dataPending"}) do
    local r=record(265,265); r[key]=true
    local a=NS.BuildGearAssessment(30,r,true)
    check(not a.rating and not a.fit and #a.alternatives==0,"incomplete snapshots cannot receive an assessment")
end
check(not NS.BuildGearAssessment(30,record(265,265),false).rating,"incomplete menu state withholds assessment")
check(not NS.BuildGearAssessment(30,nil,true).fit,"missing record is neutral")
local r=record(265,265); r.enchantmentScore=9999; r.enchantmentUnknown=true
local a=NS.BuildGearAssessment(30,r,true)
check(a.rating.label=="Average" and a.fit=="optimal","enchantments and their unknown tiers cannot distort unenchanted comparisons")
r.dynamicAvailable=false; a=NS.BuildGearAssessment(30,r,true)
check(a.rating.label=="Average" and not a.fit,"ordinary GS still receives its level rating when talents are unknown")
r.dynamicAvailable=true; r.dynamicProfile=NS.ClassifyTalents("WARRIOR",{26,0,0},30)
check(not NS.BuildGearAssessment(30,r,true).fit,"a mismatched class profile cannot assess the selected wearer")
-- Controlled cached-score fixtures exercise alternative filtering independently
-- of native inventory APIs (real scorer parity is covered by panel integration).
NS.GetCachedItemDynamicScore=function(item,p) return item.byTree[p.trees[1]] end
local item={byTree={70,79,80},setPieces=0,setActive=false}
assert(loadfile("Bonuses.lua"))("FossieGearScore",NS)
profile.treeNames={"Native Balance","Native Feral","Native Restoration"}
r=record(100,70); r.links={[5]="captured"}; r.itemDetails={[5]=item}
a=NS.BuildGearAssessment(30,r,true)
check(#a.alternatives==1 and a.alternatives[1].tree==3 and a.alternatives[1].percent==80 and a.alternatives[1].name=="Native Restoration",
    "an alternative at exactly eighty percent qualifies while one below it does not")
local noFit=record(100,70); noFit.links=r.links; noFit.itemDetails={[5]={byTree={70,70,69}}}
check(#NS.BuildGearAssessment(30,noFit,true).alternatives==0,"equal or worse alternatives cannot be recommended")
local missing=record(100,70); missing.links=r.links; missing.itemDetails={}
NS.GetCachedItemDynamicScore=function(i,p) return i and i.byTree[p.trees[1]] end
check(#NS.BuildGearAssessment(30,missing,true).alternatives==0,"uncaptured item stats cannot become a speculative recommendation")
print("PASS: " .. count .. " level-benchmark/spec-fit checks (" .. _VERSION .. ")")
