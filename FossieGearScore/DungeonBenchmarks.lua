-- DungeonBenchmarks.lua
-- WoW Forever / FossieGearScore: manually selected GS references.
-- Add this file before InspectionPanel.lua in the addon .toc to expose
-- NS.DUNGEON_BENCHMARKS. This is a data module; the panel must read it.
-- Standalone Lua loaders can also use the returned table.
-- GS only: these are shared instance references, not class-specific DGS values.
-- Integration: compare the player's DGS against these same reference values,
-- as requested for the inspection panel; this does not alter item scoring.
-- Percent points are rounded to the nearest integer, with halves rounded up.
-- [100] is the reference midpoint. This file does not implement rating labels.
-- referenceLevel records the example character level, not a dungeon level range.
-- The three explicitly requested pairs share groups: Hall of Thanes/RFC,
-- Wailing Caverns/Deadmines, and Razorfen Kraul/Gnomeregan.

local _, NS = ...

local benchmarks = {
    schemaVersion = 1,
    scoringVersion = "1.1.0",
    scoringFingerprint = "6095a2a4d41dffa0a68f1da9f523ed0fc07061235ca5f284aa4396d983d451bc",
    researchedOn = "2026-10-17",
    percentPoints = { 80, 90, 100, 110, 120, 140 },
    groupOrder = {
        "hall_of_thanes_ragefire_chasm",
        "ruins_of_lordaeron",
        "wailing_caverns",
        "shadowfang_keep",
        "blackfathom_deeps",
        "the_stockade",
        "excavation_site_wetlands",
        "city_of_dalaran",
        "razorfen_kraul_gnomeregan",
        "scarlet_monastery_graveyard",
        "scarlet_monastery_library",
    },
    groups = {
        ["hall_of_thanes_ragefire_chasm"] = {
            instances = { "Hall of Thanes", "Ragefire Chasm" },
            baselineGS = 62,
            referenceLevel = 15,
            points = { [80] = 50, [90] = 56, [100] = 62, [110] = 68, [120] = 74, [140] = 87 },
            sourceFile = "Hall-of-Thanes-Human-Frost-Mage-L15.json",
            note = "Hall of Thanes reference shared with Ragefire Chasm by user decision. Based on the original nine-item core; unresolved slots excluded.",
            legacyAverageMinimumGS = 50,
            legacyNote = "The original discussion called rounded 80% (50 GS) Average. The later 90% point is 56 GS. Choose rating labels in the panel; this data export does not silently redefine the original rating.",
        },
        ["ruins_of_lordaeron"] = {
            instances = { "Ruins of Lordaeron" },
            baselineGS = 79,
            referenceLevel = 17,
            points = { [80] = 63, [90] = 71, [100] = 79, [110] = 87, [120] = 95, [140] = 111 },
            sourceFile = "Ruins-of-Lordaeron-Human-Frost-Mage-L17.json",
        },
        ["wailing_caverns"] = {
            instances = { "Wailing Caverns", "The Deadmines" },
            baselineGS = 104,
            referenceLevel = 19,
            points = { [80] = 83, [90] = 94, [100] = 104, [110] = 114, [120] = 125, [140] = 146 },
            sourceFile = "Wailing-Caverns-Human-Arms-Warrior-L19.json",
            note = "Shared 104 GS reference explicitly chosen for Wailing Caverns and The Deadmines.",
        },
        ["shadowfang_keep"] = {
            instances = { "Shadowfang Keep" },
            baselineGS = 144,
            referenceLevel = 22,
            points = { [80] = 115, [90] = 130, [100] = 144, [110] = 158, [120] = 173, [140] = 202 },
            sourceFile = "Shadowfang-Keep-Human-Affliction-Warlock-L22.json",
        },
        ["blackfathom_deeps"] = {
            instances = { "Blackfathom Deeps" },
            baselineGS = 165,
            referenceLevel = 25,
            points = { [80] = 132, [90] = 149, [100] = 165, [110] = 182, [120] = 198, [140] = 231 },
            note = "Manual reference chosen from the user's actual level-25 Feral Druid at 165 GS. Calculated comparison outfits were 151 GS and 185 GS.",
        },
        ["the_stockade"] = {
            instances = { "The Stockade" },
            baselineGS = 197,
            referenceLevel = 26,
            points = { [80] = 158, [90] = 177, [100] = 197, [110] = 217, [120] = 236, [140] = 276 },
            sourceFile = "The-Stockade-Gnome-Arms-Warrior-L26.json",
        },
        ["excavation_site_wetlands"] = {
            instances = { "Excavation Site: Wetlands" },
            baselineGS = 204,
            referenceLevel = 28,
            points = { [80] = 163, [90] = 184, [100] = 204, [110] = 224, [120] = 245, [140] = 286 },
            sourceFile = "Excavation-Site-Wetlands-Dwarf-Combat-Rogue-L28.json",
        },
        ["city_of_dalaran"] = {
            instances = { "City of Dalaran" },
            baselineGS = 216,
            referenceLevel = 30,
            points = { [80] = 173, [90] = 194, [100] = 216, [110] = 238, [120] = 259, [140] = 302 },
            sourceFile = "City-of-Dalaran-Gnome-Frost-Mage-L30.json",
        },
        ["razorfen_kraul_gnomeregan"] = {
            instances = { "Razorfen Kraul", "Gnomeregan" },
            baselineGS = 265,
            referenceLevel = 31,
            points = { [80] = 212, [90] = 239, [100] = 265, [110] = 292, [120] = 318, [140] = 371 },
            sourceFile = "Gnomeregan-Human-Retribution-Paladin-L31.json",
            note = "Shared 265 GS reference explicitly chosen for Razorfen Kraul and Gnomeregan. Supersedes the earlier RFK 217 GS entry calculation.",
        },
        ["scarlet_monastery_graveyard"] = {
            instances = { "Scarlet Monastery: Graveyard" },
            baselineGS = 265,
            referenceLevel = 32,
            points = { [80] = 212, [90] = 239, [100] = 265, [110] = 292, [120] = 318, [140] = 371 },
            sourceFile = "Scarlet-Monastery-Graveyard-Alliance-Skyborne-Arms-Warrior-L32.json",
            note = "Separate group with the same numerical reference as Razorfen Kraul/Gnomeregan.",
        },
        ["scarlet_monastery_library"] = {
            instances = { "Scarlet Monastery: Library" },
            baselineGS = 320,
            referenceLevel = 34,
            points = { [80] = 256, [90] = 288, [100] = 320, [110] = 352, [120] = 384, [140] = 448 },
            sourceFile = "Scarlet-Monastery-Library-Upgraded-Alliance-Skyborne-Frost-Mage-L34.json",
            note = "Manual 320 GS Library reference explicitly chosen by the user from the level-34 upgraded Mage outfit. Supersedes the earlier 260 GS reference.",
            comparison = {
                earlierEntryGS = 260,
                earlierEntryLevel = 33,
                earlierEntrySourceFile = "Scarlet-Monastery-Library-Alliance-Skyborne-Frost-Mage-L33.json",
            },
        },
    },
    byInstance = {
        ["Hall of Thanes"] = "hall_of_thanes_ragefire_chasm",
        ["Ragefire Chasm"] = "hall_of_thanes_ragefire_chasm",
        ["Ruins of Lordaeron"] = "ruins_of_lordaeron",
        ["Wailing Caverns"] = "wailing_caverns",
        ["The Deadmines"] = "wailing_caverns",
        ["Shadowfang Keep"] = "shadowfang_keep",
        ["Blackfathom Deeps"] = "blackfathom_deeps",
        ["The Stockade"] = "the_stockade",
        ["Excavation Site: Wetlands"] = "excavation_site_wetlands",
        ["City of Dalaran"] = "city_of_dalaran",
        ["Razorfen Kraul"] = "razorfen_kraul_gnomeregan",
        ["Gnomeregan"] = "razorfen_kraul_gnomeregan",
        ["Scarlet Monastery: Graveyard"] = "scarlet_monastery_graveyard",
        ["Scarlet Monastery: Library"] = "scarlet_monastery_library",
        ["The Hall of Thanes"] = "hall_of_thanes_ragefire_chasm",
        ["Deadmines"] = "wailing_caverns",
        ["Stockade"] = "the_stockade",
        ["The Stockades"] = "the_stockade",
    },
}

if type(NS) == "table" then
    NS.DUNGEON_BENCHMARKS = benchmarks
end

return benchmarks
