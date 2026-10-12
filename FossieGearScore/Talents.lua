local _, NS = ...
local profiles, readyGUID = {}, nil
NS.talentProfiles = profiles
local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a,b,c,d,e,f,g = pcall(fn,...)
    if ok then return a,b,c,d,e,f,g end
end
local function guid(unit)
    local value=call(UnitGUID,unit)
    if NS.IsSafe(value) and type(value)=="string" then return value end
end
local function pointsFor(index, inspect, unit)
    -- Classic compatibility signatures: points are return #5 or legacy #3.
    if type(GetTalentTabInfo)=="function" then
        local a,b,c,d,e=call(GetTalentTabInfo,index,inspect,false)
        if NS.IsSafe(a) and type(a)=="string" then return NS.GetNumber(c) end
        if NS.IsSafe(b) and type(b)=="string" then return NS.GetNumber(e) end
    end
    -- Forever's modern specialization API retains classic pointsSpent (#7).
    local _,name,_,_,_,_,points=call(C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo,
        index,inspect,false,inspect and unit or nil)
    if NS.IsSafe(name) and type(name)=="string" then return NS.GetNumber(points) end
end
-- Forever puts all three classic talent groups in one active trait config.
-- The native UI prints currencyInfos[1].spent for each ordered group.
local function purchasedNodePoints(configID,treeID,ordered)
    if type(C_Traits.GetTreeNodes)~="function" or type(C_Traits.GetNodeInfo)~="function" then
        return nil,"node-api-unavailable"
    end
    local nodes=call(C_Traits.GetTreeNodes,treeID)
    if not NS.IsSafe(nodes) or type(nodes)~="table" or #nodes==0 then return nil,"node-list-pending" end
    local indexByGroup,points,seen,groupSeen={},{0,0,0},{},{}
    for index,group in ipairs(ordered) do indexByGroup[group.id]=index end
    local count=0
    for _,nodeID in ipairs(nodes) do
        nodeID=NS.GetNumber(nodeID)
        if not nodeID then return nil,"node-data-pending" end
        if not seen[nodeID] then
            seen[nodeID]=true; count=count+1
            local node=call(C_Traits.GetNodeInfo,configID,nodeID)
            if not NS.IsSafe(node) or type(node)~="table" then return nil,"node-data-pending",count end
            -- Increased/free ranks are not purchased talent points.
            local rank=NS.GetNumber(node.ranksPurchased)
            if not rank or rank<0 or rank>55 or rank~=math.floor(rank) then return nil,"node-ranks-pending",count end
            local groups=node.groupIDs
            if not NS.IsSafe(groups) or type(groups)~="table" then return nil,"node-groups-pending",count end
            local owner
            for _,id in ipairs(groups) do
                local index=indexByGroup[NS.GetNumber(id) or -1]
                if index then
                    groupSeen[index]=true
                    if owner and owner~=index and rank>0 then return nil,"ambiguous-node-group",count end
                    owner=index
                end
            end
            if owner then points[owner]=points[owner]+rank
            elseif rank>0 then return nil,"purchased-node-unmapped",count end
        end
    end
    if not groupSeen[1] or not groupSeen[2] or not groupSeen[3] then return nil,"node-groups-pending",count end
    return points,nil,count
end
local function traitPoints(inspect)
    if not C_Traits or type(C_Traits.GetConfigInfo)~="function"
        or type(C_Traits.GetGroupDisplayInfoByTreeID)~="function" then return nil,nil,nil,false end
    local configID
    if inspect then
        if type(C_Traits.HasValidInspectData)=="function" and call(C_Traits.HasValidInspectData)~=true then
            return nil,nil,{source="traits",detail="inspect-data-pending"},true
        end
        configID=NS.GetNumber(Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID) or -1
    else
        local group=NS.GetNumber(call(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup))
        if group then configID=NS.GetNumber(call(C_SpecializationInfo.GetCombatConfigIDForSpecGroup,group)) end
        configID=configID or NS.GetNumber(call(C_ClassTalents and C_ClassTalents.GetActiveConfigID))
    end
    local info={source="traits",configID=configID}
    if not configID then info.detail="config-pending"; return nil,nil,info,true end
    local config=call(C_Traits.GetConfigInfo,configID)
    if not NS.IsSafe(config) or type(config)~="table" or not NS.IsSafe(config.treeIDs) or type(config.treeIDs)~="table" then
        info.detail="config-data-pending"; return nil,nil,info,true
    end
    for _,treeID in ipairs(config.treeIDs) do
        local groups=call(C_Traits.GetGroupDisplayInfoByTreeID,treeID)
        if NS.IsSafe(groups) and type(groups)=="table" and #groups==3 then
            local ordered,ids={},{}
            for index,group in ipairs(groups) do
                local id=NS.IsSafe(group) and type(group)=="table" and NS.GetNumber(group.groupID)
                if not id then info.detail="group-data-pending"; return nil,nil,info,true end
                ordered[#ordered+1]={id=id,order=NS.GetNumber(group.orderIndex) or index,
                    name=NS.IsSafe(group.displayName) and type(group.displayName)=="string" and group.displayName or nil}
            end
            table.sort(ordered,function(a,b) return a.order<b.order end)
            for _,group in ipairs(ordered) do ids[#ids+1]=group.id end
            local currencies=call(C_Traits.GetGroupCurrencyInfo,configID,ids)
            local byID={}
            if NS.IsSafe(currencies) and type(currencies)=="table" then
                for _,group in pairs(currencies) do
                    local id=NS.IsSafe(group) and type(group)=="table" and NS.GetNumber(group.traitNodeGroupID)
                    if id and NS.IsSafe(group.currencyInfos) and type(group.currencyInfos)=="table" then
                        local currency=group.currencyInfos[1]
                        if NS.IsSafe(currency) and type(currency)=="table" then byID[id]=NS.GetNumber(currency.spent) end
                    end
                end
            end
            local points,names,complete,total={},{},true,0
            for index,group in ipairs(ordered) do
                local amount=byID[group.id]
                names[index]=group.name
                if not amount or amount<0 or amount>55 or amount~=math.floor(amount) then complete=false
                else points[index]=amount; total=total+amount end
            end
            if total>55 then complete=false end
            -- Some live Forever configs expose headers/nodes but no per-group
            -- currencies. Recover the same three totals from purchased ranks.
            if not complete or total==0 then
                local counted,detail,nodeCount=purchasedNodePoints(configID,treeID,ordered)
                info.nodeCount=nodeCount
                if counted then
                    points=counted; info.source="trait-nodes"
                elseif not complete then
                    info.detail="currency-data-pending"
                    info.nodeDetail=detail
                    return nil,names,info,true
                end
            end
            info.treeID=treeID
            return points,names,info,true
        end
    end
    info.detail="talent-groups-pending"; return nil,nil,info,true
end
NS.ReadTraitTalentPoints=traitPoints
function NS.CaptureTalentProfile(unit, inspect)
    local id=guid(unit)
    if not id then return end
    if inspect and id==guid("player") then inspect=false end
    local class=NS.GetClassToken(unit)
    local level=NS.GetNumber(call(UnitLevel,unit))
    local _,race=call(UnitRace,unit)
    if not NS.IsSafe(race) then race=nil end
    local points,names,api
    -- No talent API calls at all below level 10.
    if level and level>=10 then
        local supported
        points,names,api,supported=traitPoints(inspect==true)
        if not supported then
            api={source="talent-tabs"}; points={}
            for i=1,3 do points[i]=pointsFor(i,inspect==true,unit) end
        end
    end
    if guid(unit)~=id then return end
    local profile=NS.ClassifyTalents(class,points,level,race)
    profile.guid,profile.treeNames,profile.api=id,names,api
    if inspect and level and level>=10 and (profile.reason=="no-talents" or profile.reason=="talents-unavailable") then
        profile.retryAfter=(NS.GetNumber(call(GetTime)) or 0)+5
    end
    profiles[id]=profile
    if inspect then readyGUID=id end
    return profile
end
function NS.ResolveDynamicProfile(unit)
    unit=unit or "player"
    local id=guid(unit)
    if not id then return end
    if id==guid("player") then
        local actual=NS.CaptureTalentProfile(unit,false)
        return NS.ApplyTalentOverride and NS.ApplyTalentOverride(actual) or actual
    end
    -- Read remote talents only immediately after a matching INSPECT_READY.
    -- A cached profile is GUID-bound, never borrowed from the active target.
    local cached=profiles[id]
    if id==readyGUID and cached and cached.reason=="talents-unavailable" then
        cached=NS.CaptureTalentProfile(unit,true)
    end
    return NS.ApplyTalentOverride and NS.ApplyTalentOverride(cached) or cached
end
function NS.RefreshReadyTalentProfile(unit)
    if guid(unit)==readyGUID then return NS.CaptureTalentProfile(unit,true) end
end
function NS.PrintTalentInfo()
    if not NS.Message then return end
    local function report(unit,label)
        local profile=NS.ResolveDynamicProfile(unit)
        if not profile then NS.Message(label .. ": no talent data"); return end
        local points=profile.points or {}
        local api=profile.api or {}
        NS.Message(label .. ": " .. (profile.classToken or "unknown class") .. " level " .. tostring(profile.level)
            .. " | " .. tostring(points[1] or "?") .. "/" .. tostring(points[2] or "?") .. "/" .. tostring(points[3] or "?")
            .. " | " .. (profile.name or profile.reason or "unavailable") .. " | API " .. (api.source or "none")
            .. " config " .. tostring(api.configID or "?") .. (api.detail and " (" .. api.detail .. ")" or "")
            .. (api.nodeDetail and " | fallback " .. api.nodeDetail or "")
            .. (api.nodeCount and " | nodes " .. tostring(api.nodeCount) or ""))
    end
    report("player","Own talents")
    local unit=InspectFrame and (call(InspectFrame.GetInspectUnit,InspectFrame) or InspectFrame.unit)
    if NS.IsSafe(unit) and type(unit)=="string" then report(unit,"Inspected talents") end
end
function NS.IsTalentRetryDue(id)
    local profile=profiles[id]
    return profile and profile.retryAfter and (NS.GetNumber(call(GetTime)) or 0)>=profile.retryAfter or false
end
function NS.ClearTalentInspect() readyGUID=nil end
