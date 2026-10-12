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
function NS.CaptureTalentProfile(unit, inspect)
    local id=guid(unit)
    if not id then return end
    if inspect and id==guid("player") then inspect=false end
    local class=NS.GetClassToken(unit)
    local level=NS.GetNumber(call(UnitLevel,unit))
    local _,race=call(UnitRace,unit)
    if not NS.IsSafe(race) then race=nil end
    local points
    -- No talent API calls at all below level 10.
    if level and level>=10 then
        points={}
        for i=1,3 do points[i]=pointsFor(i,inspect==true,unit) end
    end
    if guid(unit)~=id then return end
    local profile=NS.ClassifyTalents(class,points,level,race)
    profile.guid=id
    profiles[id]=profile
    if inspect then readyGUID=id end
    return profile
end
function NS.ResolveDynamicProfile(unit)
    unit=unit or "player"
    local id=guid(unit)
    if not id then return end
    if id==guid("player") then return NS.CaptureTalentProfile(unit,false) end
    -- Read remote talents only immediately after a matching INSPECT_READY.
    -- A cached profile is GUID-bound, never borrowed from the active target.
    local cached=profiles[id]
    if id==readyGUID and cached and cached.reason=="talents-unavailable" then
        return NS.CaptureTalentProfile(unit,true)
    end
    return cached
end
function NS.ClearTalentInspect() readyGUID=nil end
