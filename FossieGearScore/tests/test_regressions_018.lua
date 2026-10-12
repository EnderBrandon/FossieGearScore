-- Report each regression independently so a first failure cannot hide the rest.
local NS, failures, count = {}, {}, 0
for _, file in ipairs({"Weights.lua", "Scoring.lua", "Bonuses.lua"}) do
    assert(loadfile(file))("FossieGearScore", NS)
end
local function check(ok, label)
    count = count + 1
    if not ok then failures[#failures+1] = label; print("FAIL: " .. label) end
end

local score, _, details = NS.CalculateItemScore({}, 15, 2, true)
check(score == 5 and math.abs(details.baseScore - 19.8) < 0.000001,
    "equip-only green item gets the item-level base and rarity factors")
check(NS.CalculateItemScore({}, 100, 4, false) == 0,
    "plain statless equipment retains zero intrinsic score")

local function fang(lines)
    return NS.ReadItemBonuses(lines, 162).set
end
local native = fang({"Embrace of the Viper (2/5)",
    "Set: +7 Nature Resistance.", "(3) Set: +10 Intellect.", "(4) Set: +10 Spirit."})
local group = NS.BuildSetGroups({{set=native}, {set=native}}, true)["id:162"]
check(group.active and group.count == 2,
    "active Set: line without a piece number overrides higher inactive tiers")
local footpadScore = NS.CalculateItemScore({Agility=6, Stamina=6, Armor=61}, 22, 3, false)
local footpads = NS.ApplySetBonus({score=footpadScore}, group.count, group.active)
check(footpads.score == 14 and footpads.setBonusScore == 2 and footpads.totalScore == 16,
    "reported Footpads of the Fang example remains active with the updated set formula")
local full = NS.ReadItemBonuses({"Fully Active Outfit (4/4)", "Set: +10 Strength."}).set
check(full and NS.IsSetActive(full, 4, true),
    "a fully active set remains identifiable without numbered inactive bonuses")
local gray = fang({"Embrace of the Viper (2/5)",
    {leftText="(2) Set: +7 Nature Resistance.", leftColor={r=0.5,g=0.5,b=0.5}}})
check(NS.BuildSetGroups({{set=gray}, {set=gray}}, true)["id:162"].active,
    "tooltip skin colors cannot disable a threshold reached by equipped items")
for _, line in ipairs({"Set (2): +7 Nature Resistance.", "Set: (2) +7 Nature Resistance."}) do
    local set = fang({"Embrace of the Viper (2/5)", line})
    check(set.required == 2 and NS.IsSetActive(set, 2, true),
        "alternate numbered set format: " .. line)
end
check(not NS.IsSetActive(native, 1, true),
    "active local tooltip state cannot activate a different one-piece wearer")

local bonus, total = NS.CalculateSetBonus(1, 2, true)
check(bonus == 1 and total == 2, "active set addition has a one-point minimum")
bonus, total = NS.CalculateSetBonus(0, 2, true)
check(bonus == 1 and total == 1, "active zero-base set item gets the requested minimum")
check(NS.CalculateSetBonus(1, 2, false) == 0, "inactive sets do not get the minimum")

local stats = NS.ExtractStats({}, {"+2 to All Resistances"}, {})
check(NS.CalculateScore(stats) == 5,
    "Rugged Spaulders wording expands to five two-point resistance bonuses")
stats = NS.ExtractStats({RESISTANCE2_NAME=2, RESISTANCE3_NAME=2,
    RESISTANCE4_NAME=2, RESISTANCE5_NAME=2, RESISTANCE6_NAME=2},
    {"+2 to All Resistances"}, {})
check(NS.CalculateScore(stats) == 5, "API and tooltip all-resistance bonuses are deduplicated")
stats = NS.ExtractStats({}, {"(2) Set: +2 to All Resistances",
    "Use: +2 to All Resistances", "Chance on hit: +2 to All Resistances"}, {})
check(NS.CalculateScore(stats) == 0, "conditional resistance effects remain outside the flat stat subtotal")
assert(#failures == 0, table.concat(failures, "\n"))
print("PASS: " .. count .. " build 0.1.8 regression checks (" .. _VERSION .. ")")
