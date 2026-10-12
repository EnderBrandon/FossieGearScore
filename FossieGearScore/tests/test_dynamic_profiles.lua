local NS,count={},0
local function check(ok,name) assert(ok,name); count=count+1 end
for _,file in ipairs({'Weights.lua','DynamicWeights.lua','Scoring.lua','Talents.lua'}) do
    assert(loadfile(file))('FossieGearScore',NS)
end
local function profile(class,points,race,level) return NS.ClassifyTalents(class,points,level or 60,race) end
local function weights(class,points,race) local p=profile(class,points,race); return NS.GetDynamicWeights(class,p),p end
local p=profile('DRUID',{0,31,24})
check(p.available and not p.hybrid and p.name=='Feral','31/24 is feral, not hybrid')
for _,points in ipairs({{0,30,25},{0,25,30},{10,24,21},{15,15,15},{0,15,15}}) do
    p=profile('DRUID',points)
    check(p.hybrid and p.name:find('Hybrid:',1,true)==1,'within-five spread is marked hybrid')
end
check(not profile('DRUID',{0,29,23}).hybrid,'six-point difference is single spec')
check(not profile('DRUID',{0,1,0}).hybrid,'one spent point and two empty trees is single spec')
check(#profile('DRUID',{15,15,15}).trees==3,'three close trees join hybrid profile')
check(not profile('DRUID',{0,0,0}).available,'zero talents unavailable')
check(not profile('DRUID',nil).available,'unknown talents unavailable')
check(not profile('DRUID',{0,0,15},nil,9).available,'under-ten unavailable')
check(profile('DRUID',{0,0,1},nil,10).available,'first talent at ten enables dynamic scoring')
check(not profile('DRUID',{31,25,0}).available,'over 55 points rejected')
check(not profile('DRUID',{-1,0,15}).available,'negative points rejected')
check(not profile('DRUID',{0,0,1.5}).available,'fractional points rejected')
local w,r=weights('DRUID',{0,0,15})
check(r.name=='Restoration' and r.heal and not r.melee and not r.tank,'restoration role detected')
check(w.Healing==0.4 and w.Strength==0 and w['Attack Power']==0 and w['Feral Attack Power']==0,'restoration values')
check(w.Agility==1 and w.Armor==0.01 and w['Armor (Bonus)']==0.01 and w.Defense==0,'restoration defensive values')
w,r=weights('DRUID',{0,15,0})
check(r.name=='Feral' and r.melee and r.tank and not r.heal,'combined cat/bear profile')
check(w.Armor==0.02 and w.Defense==2 and w.Strength==2 and w['Feral Attack Power']==0.8,'feral tank and melee values')
check(w['Spell Damage']==0 and w['Nature Damage']==0 and w['Arcane Damage']==0,'feral excludes spell damage')
check(w.Intellect==2 and w.Healing==0.2,'feral keeps base-form intellect and halves healing')
w=weights('DRUID',{15,0,0})
check(w['Arcane Damage']==1 and w['Nature Damage']==1 and w['Shadow Damage']==0 and w.Healing==0.2,'balance spell schools and healing')
w,r=weights('DRUID',{0,30,25})
check(r.hybrid and r.tank and r.melee and r.heal,'hybrid unions feral and restoration roles')
check(w.Healing==0.4 and w.Strength==2 and w.Armor==0.02 and w['Nature Damage']==0.5,'hybrid keeps useful stats for either role')
for class,trees in pairs(NS.DYNAMIC_SPECS) do
    for i=1,3 do
        local points={0,0,0};points[i]=15
        w,r=weights(class,points)
        check(r.name==trees[i].name and not r.hybrid,'native tree order '..class..' '..i)
        check(w.Armor==(r.tank and 0.02 or 0.01) and w['Armor (Bonus)']==w.Armor,'armor role '..class..' '..i)
        check(w.Defense==(r.tank and 2 or 0),'defense role '..class..' '..i)
        if not r.melee then
            check(w.Strength==0 and w['Attack Power']==0 and w.Agility==1,'caster physical stats '..class..' '..i)
            for stat in pairs(NS.WEIGHTS) do
                if stat:match(' Skill$') then check(w[stat]==0,'caster skill '..class..' '..stat) end
            end
        end
        for _,school in ipairs({'Arcane','Fire','Nature','Frost','Shadow','Holy'}) do
            check(w[school..' Damage']==(r.schools[school] and (r.tank and 0.5 or 1) or 0),'school '..class..' '..i..' '..school)
        end
    end
end
for _,class in ipairs({'WARRIOR','ROGUE'}) do
    w=weights(class,{15,0,0});check(w.Intellect==0,class..' no intellect')
end
w=weights('PALADIN',{0,15,0})
check(w['Holy Damage']==0.5 and w['Spell Damage']==0.5,'protection halves useful spell damage')
w=weights('PALADIN',{0,0,15})
check(w['Holy Damage']==1 and w.Healing==0.2 and w.Armor==0.01,'retribution DPS weights')
w=weights('PALADIN',{15,0,0})
check(w.Healing==0.4 and w.Strength==0,'holy paladin healer weights')
w=weights('SHAMAN',{0,15,0})
check(w['Attack Power']==0.8 and w.Healing==0.2 and w.Armor==0.01 and w.Defense==0,'enhancement not a tank')
w=weights('HUNTER',{0,15,0})
check(w['Ranged Attack Power']==0.8 and w['Attack Power']==0.8 and w.Strength==0 and w.Agility==2,'hunter ranged AP and agility')
check(w['Gun Skill']==14 and w['Crossbow Skill']==14 and w['Sword Skill']==0,'hunter ranged skills')
w=weights('PRIEST',{0,0,15},'NightElf')
check(w['Arcane Damage']==1 and w['Shadow Damage']==1 and w['Holy Damage']==0,'night elf shadow priest racial')
w=weights('PRIEST',{0,0,15},'Human')
check(w['Arcane Damage']==0 and w['Shadow Damage']==1 and w.Healing==0.2,'human shadow priest')
check(NS.WEIGHTS.Armor==0.02 and NS.WEIGHTS.Defense==2 and NS.WEIGHTS.Healing==0.4,'normal baseline preserved')
local raw={Strength=10,Agility=10,Intellect=10,Armor=100,Defense=5,['Spell Damage']=30,Healing=60,_sharedSpellPower=30}
local mageWeights=weights('MAGE',{15,0,0})
local score=NS.CalculateScore(raw,mageWeights)
check(score==61,'mage arithmetic includes agility/armor/intellect and shared spell power once')
local restoWeights=weights('DRUID',{0,0,15})
check(NS.CalculateScore(raw,restoWeights)==73,'restoration arithmetic keeps extra healing additive')

-- Talent API contracts and GUID isolation, independent from gear loading.
local units={player={guid='self',class='DRUID',level=60,points={0,0,15}},target={guid='other',class='DRUID',level=60,points={0,15,0}}}
UnitGUID=function(unit)return units[unit] and units[unit].guid end
UnitClass=function(unit)return 'class',units[unit] and units[unit].class end
UnitLevel=function(unit)return units[unit] and units[unit].level end
UnitRace=function()return 'Human','Human' end
local calls=0
C_SpecializationInfo={GetSpecializationInfo=function(i,inspect,pet,unit)
    calls=calls+1
    check(pet==false and (not inspect or unit=='target'),'modern API target arguments')
    local u=units[inspect and unit or 'player'];return i,'Tree',nil,nil,nil,nil,u.points[i]
end}
check(NS.ResolveDynamicProfile('player').name=='Restoration','modern API reads own points return seven')
check(NS.ResolveDynamicProfile('target')==nil,'uncaptured remote never reads local talent data')
local captured=NS.CaptureTalentProfile('target',true)
check(captured.name=='Feral' and NS.ResolveDynamicProfile('target')==captured,'inspection caches GUID-bound feral profile')
units.target={guid='different',class='DRUID',level=60,points={0,0,15}}
local before=calls
check(NS.ResolveDynamicProfile('target')==nil and calls==before,'target swap cannot reuse previous profile or call inspect API')
units.player.level=9;before=calls
check(not NS.ResolveDynamicProfile('player').available and calls==before,'under ten makes no talent API calls')
units.player.level=60;units.player.points={0,0,0}
check(NS.ResolveDynamicProfile('player').reason=='no-talents','reset replaces cached own profile')
GetTalentTabInfo=function(i,inspect) local u=units[inspect and 'target' or 'player'];return 'Tree',123,u.points[i],'File' end
units.player.points={0,15,0}
check(NS.ResolveDynamicProfile('player').name=='Feral','legacy four-return API reads points return three')
GetTalentTabInfo=function(i) return i,'Tree','description',123,units.player.points[i] end
check(NS.ResolveDynamicProfile('player').name=='Feral','classic compatibility API reads points return five')
GetTalentTabInfo=function() error('unsupported') end
check(NS.ResolveDynamicProfile('player').name=='Feral','failed legacy API falls back to modern')
C_SpecializationInfo=nil
check(NS.ResolveDynamicProfile('player').reason=='talents-unavailable','unavailable APIs hide dynamic profile')
print('PASS: '..count..' talent/class dynamic scoring checks ('.._VERSION..')')
