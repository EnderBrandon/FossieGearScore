local _, NS = ...

-- Explicit exceptions for items whose effects need a role designation.
-- Use numeric base item IDs and one or more of these exact role names:
-- [itemID] = {["Tank"]=true, ["Attack DPS"]=true, ["Spell DPS"]=true, ["Healer"]=true}
-- Leave unreviewed items absent; no role is inferred from an effect's wording.
-- Changes take effect after /reload, like the other scoring data tables.
NS.ITEM_ROLES = {}

function NS.GetItemRoleMultiplier(itemID, profile, breakdown, bonuses, complete)
    local designated = NS.ITEM_ROLES[itemID]
    if designated then
        -- Unknown profiles must not turn an unverified role into a mismatch.
        if not profile.roles or not next(profile.roles) then return 1 end
        for role in pairs(profile.roles) do
            if designated[role] then return 1 end
        end
        return 0.5, "role-mismatch"
    end
    if not complete or bonuses.hasEffect or bonuses.hasUse then return 1 end
    for _, entry in ipairs(breakdown) do
        if entry.value > 0 and entry.weight > 0 then return 1 end
    end
    return 0.5, "no-matching-stats"
end
