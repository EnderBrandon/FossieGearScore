local _, NS = ...
-- Only one request may own the client's inspection data at a time.
local HOVER_DELAY, REQUEST_GAP, TIMEOUT, RETRY_DELAY, CACHE_AGE = 0.3, 3, 5, 15, 60
local pending, scheduled, issuing, hooked, clearHooked
local lastRequest, externalUntil, externalGUID = -math.huge, 0, nil
local failures = {}

local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and NS.IsSafe(value) then return value end
end
local function now() return NS.GetNumber(call(GetTime)) or 0 end
local function guidFor(unit)
    local guid = call(UnitGUID, unit)
    if type(guid) == "string" then return guid end
end
local function samePlayer(unit, guid)
    return guidFor(unit) == guid and call(UnitIsPlayer, unit) == true
end
local function fresh(guid)
    local record = NS.gearSnapshots and NS.gearSnapshots[guid] or NS.gearCache and NS.gearCache[guid]
    return record and not record.partial and now() - (record.inspectedAt or record.updated) < CACHE_AGE
end
local function blocked()
    if type(InCombatLockdown) == "function" and call(InCombatLockdown) ~= false then return true end
    if type(UnitAffectingCombat) == "function" and call(UnitAffectingCombat, "player") ~= false then return true end
    if InspectFrame then
        local unit = call(InspectFrame.GetInspectUnit, InspectFrame) or InspectFrame.unit
        if not NS.IsSafe(unit) or unit or call(InspectFrame.IsShown, InspectFrame) then return true end
    end
    return false
end
local function fail(request)
    failures[request.guid] = now() + RETRY_DELAY
    if pending == request then pending = nil end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() if NS.RefreshGearHover then NS.RefreshGearHover() end end)
    end
end
local function watchRequests()
    if not clearHooked and type(ClearInspectPlayer) == "function" and type(hooksecurefunc) == "function" then
        clearHooked = pcall(hooksecurefunc, "ClearInspectPlayer", function()
            if NS.InvalidateInspectData then NS.InvalidateInspectData() end
        end)
    end
    if hooked or type(NotifyInspect) ~= "function" or type(hooksecurefunc) ~= "function" then return end
    hooked = pcall(hooksecurefunc, "NotifyInspect", function(unit)
        lastRequest = now()
        if NS.InvalidateInspectData then NS.InvalidateInspectData() end
        if not issuing then
            -- A manual inspection or another addon takes priority. Never clear
            -- the engine's inspection state, including on our own timeout.
            scheduled = nil
            if pending then fail(pending) end
            externalGUID, externalUntil = guidFor(unit), now() + TIMEOUT
        end
    end)
end

function NS.RequestBackgroundInspect(unit, stillHovered)
    local guid = guidFor(unit)
    if not guid or not samePlayer(unit, guid) or guid == guidFor("player") then return false end
    if fresh(guid) then return true end
    if NS.IsGearDataLoading and NS.IsGearDataLoading(guid) then return false end
    watchRequests()
    if pending then return false end
    if blocked() or (failures[guid] or 0) > now() then return false end
    if type(NotifyInspect) ~= "function" or not C_Timer or type(C_Timer.After) ~= "function" then return false end
    if scheduled and scheduled.guid == guid then
        scheduled.unit, scheduled.hover = unit, stillHovered
        return false
    end
    local request = {guid=guid, unit=unit, hover=stillHovered}
    scheduled = request
    local delay = math.max(HOVER_DELAY, lastRequest + REQUEST_GAP - now(), externalUntil - now())
    C_Timer.After(delay, function()
        if scheduled ~= request then return end
        scheduled = nil
        -- Unit tokens and tooltip contents can change during the hover delay.
        if not samePlayer(request.unit, guid) or call(request.hover) ~= true or fresh(guid) then return end
        if blocked() or pending then return end
        if call(CanInspect, request.unit) ~= true then fail(request); return end
        if type(CheckInteractDistance) == "function" and call(CheckInteractDistance, request.unit, 1) ~= true then
            fail(request); return
        end
        pending, issuing, lastRequest = request, true, now()
        if NS.InvalidateInspectData then NS.InvalidateInspectData() end
        local ok = pcall(NotifyInspect, request.unit)
        issuing = false
        if not ok then fail(request); return end
        C_Timer.After(TIMEOUT, function()
            if pending ~= request then return end
            fail(request)
        end)
    end)
    return false
end

function NS.BackgroundInspectReady(guid)
    if not NS.IsSafe(guid) or type(guid) ~= "string" then return end
    if guid == externalGUID then externalGUID, externalUntil = nil, 0 end
    failures[guid] = nil -- A successful manual inspection also resolves a failure.
    local request = pending
    if not request or request.guid ~= guid then return end
    pending, scheduled = nil, nil
    if samePlayer(request.unit, guid) then return request.unit end
    local unit = call(UnitTokenFromGUID, guid)
    if unit and samePlayer(unit, guid) then return unit end
end

function NS.BackgroundInspectFailed(unit)
    local guid = guidFor(unit)
    return guid and failures[guid] ~= nil or false
end

function NS.BackgroundInspectIncomplete(guid)
    if type(guid) == "string" then fail({guid=guid}) end
end
function NS.BackgroundInspectComplete(guid) failures[guid] = nil end

watchRequests()
