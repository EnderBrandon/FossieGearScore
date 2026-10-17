local _, NS = ...

-- Recommended level bands, inclusive at both ends; not minimum entry levels.
-- Checked 2026-10-17 against the "Dungeon Level Ranges in Forever" chart:
-- https://www.wowhead.com/forever/guide/dungeons-overview-locations-details
-- Classic guides disagree on some ranges; use this one chart consistently.
-- Hall of Thanes/Ruins also match Blizzard's beta announcement:
-- https://worldofwarcraft.blizzard.com/en-us/news/24304160/
-- Ranges are per instance even when benchmarks share a group. Update this
-- table independently of DungeonBenchmarks.lua as the beta changes.
NS.DUNGEON_LEVELS = {
    ["Hall of Thanes"]                 = {minLevel=13, maxLevel=18},
    ["Ragefire Chasm"]                 = {minLevel=13, maxLevel=18},
    ["Ruins of Lordaeron"]             = {minLevel=15, maxLevel=20},
    ["Wailing Caverns"]                = {minLevel=15, maxLevel=25},
    ["The Deadmines"]                  = {minLevel=18, maxLevel=23},
    ["Shadowfang Keep"]                = {minLevel=22, maxLevel=30},
    ["Blackfathom Deeps"]              = {minLevel=24, maxLevel=32},
    ["The Stockade"]                   = {minLevel=22, maxLevel=30},
    ["Excavation Site: Wetlands"]      = {minLevel=24, maxLevel=29},
    ["City of Dalaran"]                = {minLevel=28, maxLevel=33},
    ["Razorfen Kraul"]                 = {minLevel=30, maxLevel=40},
    ["Gnomeregan"]                     = {minLevel=29, maxLevel=38},
    ["Scarlet Monastery: Graveyard"]   = {minLevel=28, maxLevel=38},
    ["Scarlet Monastery: Library"]     = {minLevel=29, maxLevel=39},
}

return NS.DUNGEON_LEVELS
