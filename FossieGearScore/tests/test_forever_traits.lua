local NS,count={},0
local function check(ok,name) assert(ok,name); count=count+1 end
for _,file in ipairs({'Weights.lua','DynamicWeights.lua','Scoring.lua','Talents.lua'}) do assert(loadfile(file))('FossieGearScore',NS) end
local units={player={guid='own',class='DRUID',level=25},target={guid='remote',class='DRUID',level=29}}
UnitGUID=function(unit) return units[unit] and units[unit].guid end
UnitClass=function(unit) return 'Class',units[unit] and units[unit].class end
UnitLevel=function(unit) return units[unit] and units[unit].level end
UnitRace=function() return 'Night Elf','NightElf' end
GetTime=function() return 100 end
local legacyCalls,traitCalls,activeGroup=0,0,1
GetTalentTabInfo=function() legacyCalls=legacyCalls+1; return 0,'Druid',nil,nil,0 end
C_SpecializationInfo={
 GetSpecializationInfo=function() legacyCalls=legacyCalls+1; return 0,'Druid',nil,nil,nil,nil,0 end,
 GetActiveSpecGroup=function() return activeGroup end,
 GetCombatConfigIDForSpecGroup=function(group) return group==1 and 101 or 202 end,
}
C_ClassTalents={GetActiveConfigID=function()return 101 end}
Constants={TraitConsts={INSPECT_TRAIT_CONFIG_ID=-1}}
local spentByConfig={[101]={0,15,0},[202]={0,0,15},[-1]={0,0,15}}
local ready=true
local groups={{groupID=30,orderIndex=3,displayName='Restoration'},
 {groupID=10,orderIndex=1,displayName='Balance'},{groupID=20,orderIndex=2,displayName='Feral Combat'}}
C_Traits={
 HasValidInspectData=function()return ready end,
 GetConfigInfo=function(id)traitCalls=traitCalls+1; if spentByConfig[id] then return {ID=id,treeIDs={999}} end end,
 GetGroupDisplayInfoByTreeID=function(id)check(id==999,'reads config talent tree');return groups end,
 GetGroupCurrencyInfo=function(id,ids)
  check(ids[1]==10 and ids[2]==20 and ids[3]==30,'uses native group order rather than response order')
  local p=spentByConfig[id]
  return {{traitNodeGroupID=20,currencyInfos={{spent=p[2],quantity=40}}},
   {traitNodeGroupID=30,currencyInfos={{spent=p[3],quantity=40}}},
   {traitNodeGroupID=10,currencyInfos={{spent=p[1],quantity=40}}}}
 end,
}
local p=NS.ResolveDynamicProfile('player')
check(p.available and p.name=='Feral' and p.points[2]==15,'native trait groups recover feral with zero legacy API values')
check(p.api.source=='traits' and p.api.configID==101 and legacyCalls==0,'native reader is authoritative')
check(p.treeNames[2]=='Feral Combat','names come from native group headers')
activeGroup=2
p=NS.ResolveDynamicProfile('player')
check(p.name=='Restoration' and p.api.configID==202,'active dual spec selected instead of primary or displayed spec')
p=NS.CaptureTalentProfile('target',true)
check(p.available and p.name=='Restoration' and p.api.configID==-1,'inspect uses dedicated trait config')
check(NS.ResolveDynamicProfile('target').name=='Restoration','inspected profile remains GUID-bound')
ready=false
p=NS.CaptureTalentProfile('target',true)
check(not p.available and p.reason=='talents-unavailable' and p.api.detail=='inspect-data-pending','pending inspect data never borrows local config')
check(p.retryAfter==105,'native missing data retains five-second retry eligibility')
ready=true
p=NS.ResolveDynamicProfile('target')
check(p.available and p.name=='Restoration','matching ready profile recovers after trait data arrives')
spentByConfig[202]={0,0,0}
p=NS.ResolveDynamicProfile('player')
check(not p.available and p.reason=='no-talents','unspent quantity does not count as spent talents')
units.player.level=9
local before=traitCalls
p=NS.ResolveDynamicProfile('player')
check(not p.available and traitCalls==before and legacyCalls==0,'under ten makes no native or legacy queries')
units.player.level=25
spentByConfig[202]={0,15,0}
local currencies=C_Traits.GetGroupCurrencyInfo
C_Traits.GetGroupCurrencyInfo=function()return {} end
p=NS.ResolveDynamicProfile('player')
check(not p.available and p.reason=='talents-unavailable' and legacyCalls==0,'incomplete native data stays unknown instead of falling back to empty legacy API')
C_Traits.GetGroupCurrencyInfo=currencies
local getActive=C_SpecializationInfo.GetActiveSpecGroup
C_SpecializationInfo.GetActiveSpecGroup=nil
p=NS.ResolveDynamicProfile('player')
check(p.name=='Feral' and p.api.configID==101,'active config API fallback works')
C_SpecializationInfo.GetActiveSpecGroup=getActive
local originalGroups=groups
groups={{groupID=10,orderIndex=1},{groupID=20,orderIndex=2}}
p=NS.ResolveDynamicProfile('player')
check(not p.available and p.api.detail=='talent-groups-pending','missing tree header is unknown rather than false zero')
groups=originalGroups
C_Traits=nil
p=NS.ResolveDynamicProfile('player')
check(p.reason=='no-talents' and p.api.source=='talent-tabs' and legacyCalls==3,'legacy fallback remains supported when trait API is absent')
print('PASS: '..count..' Forever native trait API regression checks ('.._VERSION..')')
