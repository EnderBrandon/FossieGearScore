local NS,count={},0
local function check(ok,name) assert(ok,name); count=count+1 end
for _,file in ipairs({'Weights.lua','DynamicWeights.lua','Scoring.lua','Talents.lua'}) do assert(loadfile(file))('FossieGearScore',NS) end
local units={player={guid='own',class='DRUID',level=25},target={guid='remote',class='DRUID',level=29}}
UnitGUID=function(unit) return units[unit] and units[unit].guid end
UnitClass=function(unit) return 'Class',units[unit] and units[unit].class end
UnitLevel=function(unit) return units[unit] and units[unit].level end
UnitRace=function() return 'Night Elf','NightElf' end
local now=100
GetTime=function() return now end
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
local cachedCalls=traitCalls
for i=1,100 do NS.ResolveDynamicProfile('player') end
check(traitCalls==cachedCalls,'repeated tooltip profile lookups reuse the available native profile')
activeGroup=2
NS.InvalidateTalentProfile('player')
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
local waitingCalls=traitCalls
check(not NS.ResolveDynamicProfile('target').available and traitCalls==waitingCalls,
 'pending inspect lookups are throttled until a retry or native event')
now=now+0.5
p=NS.ResolveDynamicProfile('target')
check(p.available and p.name=='Restoration','matching ready profile recovers after trait data arrives')
spentByConfig[202]={0,0,0}
p=NS.CaptureTalentProfile('player',false)
check(not p.available and p.reason=='no-talents','unspent quantity does not count as spent talents')
units.player.level=9
local before=traitCalls
p=NS.CaptureTalentProfile('player',false)
check(not p.available and traitCalls==before and legacyCalls==0,'under ten makes no native or legacy queries')
units.player.level=25
spentByConfig[202]={0,15,0}
local currencies=C_Traits.GetGroupCurrencyInfo
C_Traits.GetGroupCurrencyInfo=function()return {} end
p=NS.CaptureTalentProfile('player',false)
check(not p.available and p.reason=='talents-unavailable' and legacyCalls==0,'incomplete native data stays unknown instead of falling back to empty legacy API')
-- Screenshot regression: active config exists, but currency group data is empty.
local originalConfigForGroup=C_SpecializationInfo.GetCombatConfigIDForSpecGroup
C_SpecializationInfo.GetCombatConfigIDForSpecGroup=function()return 715140 end
spentByConfig[715140]={0,15,0}
local nodeData={
 [1]={ranksPurchased=0,groupIDs={10}},
 [2]={ranksPurchased=5,groupIDs={20}},
 [3]={ranksPurchased=5,groupIDs={20}},
 [4]={ranksPurchased=5,ranksIncreased=2,activeRank=7,currentRank=7,groupIDs={20}},
 [5]={ranksPurchased=0,groupIDs={30}},
 [6]={ranksPurchased=0,ranksIncreased=7,activeRank=7,currentRank=7,groupIDs={10}},
 [7]={ranksPurchased=0,groupIDs={}},
}
local nodeCalls=0
C_Traits.GetTreeNodes=function(tree) check(tree==999,'node fallback uses active tree');return {1,2,3,4,5,6,7,4} end
C_Traits.GetNodeInfo=function(config,node)
 nodeCalls=nodeCalls+1
 check(config==715140 or config==-1,'node fallback uses owner-specific config')
 local source=nodeData[node]
 if config==-1 and source then
  local remote={ranksPurchased=source.ranksPurchased,groupIDs={}}
  for i,id in ipairs(source.groupIDs) do remote.groupIDs[i]=id==20 and 30 or id==30 and 20 or id end
  return remote
 end
 return source
end
p=NS.CaptureTalentProfile('player',false)
check(p.available and p.name=='Feral' and p.points[1]==0 and p.points[2]==15 and p.points[3]==0,
 'currency-pending screenshot now resolves 0/15/0 from purchased node ranks')
check(p.api.source=='trait-nodes' and p.api.configID==715140 and p.api.nodeCount==7,
 'node fallback reports exact source/config and deduplicates nodes')
check(p.points[2]==15,'increased and active ranks do not inflate purchased talent points')
p=NS.CaptureTalentProfile('target',true)
check(p.name=='Restoration' and p.points[3]==15 and p.points[2]==0,
 'remote fallback uses inspect node ranks instead of local ranks')
C_Traits.GetGroupCurrencyInfo=currencies
local callsBefore=nodeCalls
p=NS.CaptureTalentProfile('player',false)
check(p.name=='Feral' and p.api.source=='traits' and nodeCalls==callsBefore,
 'complete positive currency totals avoid scanning nodes')
C_Traits.GetGroupCurrencyInfo=function(_,ids)
 local result={}
 for _,id in ipairs(ids) do result[#result+1]={traitNodeGroupID=id,currencyInfos={{spent=0}}} end
 return result
end
p=NS.CaptureTalentProfile('player',false)
check(p.name=='Feral' and p.points[2]==15 and p.api.source=='trait-nodes',
 'zero-filled currency rows do not hide populated purchased nodes')
C_Traits.GetGroupCurrencyInfo=function()return {} end
local oldNode=nodeData[3]; nodeData[3]=nil
p=NS.CaptureTalentProfile('player',false)
check(not p.available and p.reason=='talents-unavailable' and p.api.nodeDetail=='node-data-pending',
 'incomplete nodes do not publish a false partial talent spread')
nodeData[3]=oldNode
local oldGroups=nodeData[2].groupIDs; nodeData[2].groupIDs={20,30}
p=NS.CaptureTalentProfile('player',false)
check(not p.available and p.api.nodeDetail=='ambiguous-node-group',
 'purchased node shared between two spec groups cannot be counted twice')
nodeData[2].groupIDs=oldGroups
local savedRanks={}
for id,node in pairs(nodeData) do savedRanks[id]=node.ranksPurchased;node.ranksPurchased=0 end
p=NS.CaptureTalentProfile('player',false)
check(not p.available and p.reason=='no-talents','zero purchased nodes still hide dynamic scoring despite free ranks')
for id,rank in pairs(savedRanks) do nodeData[id].ranksPurchased=rank end
local beforeLowLevel=nodeCalls
units.player.level=9; NS.ResolveDynamicProfile('player')
check(nodeCalls==beforeLowLevel,'under-ten profile never scans nodes')
units.player.level=25
C_Traits.GetGroupCurrencyInfo=nil
p=NS.CaptureTalentProfile('player',false)
check(p.name=='Feral' and p.api.source=='trait-nodes','missing currency function does not prevent native node fallback')
C_Traits.GetGroupCurrencyInfo=currencies
C_SpecializationInfo.GetCombatConfigIDForSpecGroup=originalConfigForGroup

local getActive=C_SpecializationInfo.GetActiveSpecGroup
C_SpecializationInfo.GetActiveSpecGroup=nil
p=NS.CaptureTalentProfile('player',false)
check(p.name=='Feral' and p.api.configID==101,'active config API fallback works')
C_SpecializationInfo.GetActiveSpecGroup=getActive
local originalGroups=groups
groups={{groupID=10,orderIndex=1},{groupID=20,orderIndex=2}}
p=NS.CaptureTalentProfile('player',false)
check(not p.available and p.api.detail=='talent-groups-pending','missing tree header is unknown rather than false zero')
local pendingCalls=traitCalls
for i=1,100 do NS.ResolveDynamicProfile('player') end
check(traitCalls==pendingCalls,'pending own talent data is not rescanned for every tooltip callback')
groups=originalGroups
now=now+0.5
p=NS.ResolveDynamicProfile('player')
check(p.available and p.name=='Feral','pending own talent profile recovers on a bounded retry')
C_Traits=nil
p=NS.CaptureTalentProfile('player',false)
check(p.reason=='no-talents' and p.api.source=='talent-tabs' and legacyCalls==3,'legacy fallback remains supported when trait API is absent')
print('PASS: '..count..' Forever native trait API regression checks ('.._VERSION..')')
