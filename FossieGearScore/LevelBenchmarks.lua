-- LevelBenchmarks.lua
-- Provisional GS references for WoW Forever / FossieGearScore 1.1.0.
-- Values are ordinary GS, not DGS. byLevel retains the supplied references.
-- splitsByLevel contains exact GS cutoffs; equality enters the higher band.
-- This module supplies data only and also returns its table for standalone use.
-- Unenchanted quest gear with a growing mix of dungeon blues is assumed.
-- These are estimates, not measured population averages or recalculated outfits.
-- Levels 1-30 use the revised curve accepted in the discussion.
-- Levels 31-60 use the accepted rough extension, anchored near Library at 34.
-- Level 60 represents a fresh level-60 character with leveling gear remaining.

local _, NS = ...

local benchmarks = {
    schemaVersion = 2,
    scoringVersion = "1.1.0",
    scoringFingerprint = "6095a2a4d41dffa0a68f1da9f523ed0fc07061235ca5f284aa4396d983d451bc",
    createdOn = "2026-10-17",
    status = "provisional-estimate",
    minLevel = 1,
    maxLevel = 60,
    includesEnchants = false,

    byLevel = {
        [1] = 0,
        [2] = 2,
        [3] = 5,
        [4] = 9,
        [5] = 14,
        [6] = 20,
        [7] = 26,
        [8] = 32,
        [9] = 38,
        [10] = 44,
        [11] = 48,
        [12] = 52,
        [13] = 56,
        [14] = 60,
        [15] = 65,
        [16] = 75,
        [17] = 85,
        [18] = 95,
        [19] = 110,
        [20] = 125,
        [21] = 140,
        [22] = 150,
        [23] = 160,
        [24] = 170,
        [25] = 180,
        [26] = 200,
        [27] = 210,
        [28] = 225,
        [29] = 245,
        [30] = 265,
        [31] = 280,
        [32] = 295,
        [33] = 310,
        [34] = 320,
        [35] = 335,
        [36] = 350,
        [37] = 365,
        [38] = 380,
        [39] = 395,
        [40] = 410,
        [41] = 425,
        [42] = 440,
        [43] = 455,
        [44] = 470,
        [45] = 485,
        [46] = 500,
        [47] = 515,
        [48] = 530,
        [49] = 545,
        [50] = 560,
        [51] = 575,
        [52] = 590,
        [53] = 605,
        [54] = 620,
        [55] = 635,
        [56] = 650,
        [57] = 665,
        [58] = 680,
        [59] = 695,
        [60] = 710,
    },
}

-- Fractions remain exact: do not round cutoffs before comparing a score.
-- The zero reference at level 1 is retained but cannot produce a ratio/rating.
benchmarks.percentSplits = {80, 90, 110, 120, 140}
benchmarks.ratingBands = {
    {minimum=140,label="Overgeared",color={0.75,0.57,1}},
    {minimum=120,label="Well geared",color={0.56,0.80,0.48}},
    {minimum=110,label="Geared",color={0.53,0.77,0.94}},
    {minimum=90,label="Average",color={0.95,0.79,0.43}},
    {minimum=80,label="Below average",color={1,0.65,0.35}},
    {minimum=-math.huge,label="Far below",color={1,0.48,0.40}},
}
benchmarks.splitsByLevel = {}
for level, reference in pairs(benchmarks.byLevel) do
    local splits = {}
    for _, percent in ipairs(benchmarks.percentSplits) do
        splits[percent] = reference * percent / 100
    end
    benchmarks.splitsByLevel[level] = splits
end

if type(NS) == "table" then
    NS.LEVEL_BENCHMARKS = benchmarks
end

return benchmarks
