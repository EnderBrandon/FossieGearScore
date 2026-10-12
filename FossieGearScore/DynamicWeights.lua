local _, NS = ...

-- Independent baseline: editing dynamic values never changes normal GS.
-- All values intentionally start equal to the normal profile.
NS.DYNAMIC_WEIGHTS = {}
for stat, weight in pairs(NS.WEIGHTS) do NS.DYNAMIC_WEIGHTS[stat] = weight end

-- Level-60 class balancing can be added here later. An explicit zero overrides
-- the baseline; omitted stats retain their dynamic baseline weight.
NS.DYNAMIC_CLASS_WEIGHTS = {
    WARRIOR={}, PALADIN={}, HUNTER={}, ROGUE={}, PRIEST={},
    SHAMAN={}, MAGE={}, WARLOCK={}, DRUID={},
}

function NS.GetClassToken(unit)
    if type(UnitClass) ~= "function" then return end
    local ok, _, token = pcall(UnitClass, unit or "player")
    if ok and NS.IsSafe(token) and type(token) == "string" and token ~= "" then return token end
end

function NS.GetDynamicWeights(classToken)
    if not NS.IsSafe(classToken) or type(classToken) ~= "string" then classToken = nil end
    local overrides = classToken and NS.DYNAMIC_CLASS_WEIGHTS[classToken]
    if not overrides or not next(overrides) then return NS.DYNAMIC_WEIGHTS end
    local weights = {}
    for stat, weight in pairs(NS.DYNAMIC_WEIGHTS) do weights[stat] = weight end
    for stat, weight in pairs(overrides) do weights[stat] = weight end
    return weights
end
