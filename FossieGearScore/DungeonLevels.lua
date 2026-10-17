local _, NS = ...

-- Display level bands, inclusive at both ends; not minimum entry levels.
-- Source: in-game ranges reported by the addon author on 2026-10-17.
-- Gnomeregan was not included in that report, so its existing 29-38 range
-- remains from the "Dungeon Level Ranges in Forever" chart checked that day:
-- https://www.wowhead.com/forever/guide/dungeons-overview-locations-details
-- Ranges are per instance even when benchmarks share a group. Update this
-- table independently of DungeonBenchmarks.lua as the beta changes.
NS.DUNGEON_LEVELS = {
    ["Hall of Thanes"]                 = {minLevel=13, maxLevel=20},
    ["Ragefire Chasm"]                 = {minLevel=13, maxLevel=20},
    ["Ruins of Lordaeron"]             = {minLevel=15, maxLevel=22},
    ["Wailing Caverns"]                = {minLevel=15, maxLevel=24},
    ["The Deadmines"]                  = {minLevel=17, maxLevel=26},
    ["Shadowfang Keep"]                = {minLevel=20, maxLevel=30},
    ["Blackfathom Deeps"]              = {minLevel=24, maxLevel=32},
    ["The Stockade"]                   = {minLevel=24, maxLevel=32},
    ["Excavation Site: Wetlands"]      = {minLevel=26, maxLevel=33},
    ["City of Dalaran"]                = {minLevel=28, maxLevel=35},
    ["Razorfen Kraul"]                 = {minLevel=29, maxLevel=38},
    ["Gnomeregan"]                     = {minLevel=29, maxLevel=38},
    ["Scarlet Monastery: Graveyard"]   = {minLevel=30, maxLevel=38},
    ["Scarlet Monastery: Library"]     = {minLevel=33, maxLevel=41},
}

return NS.DUNGEON_LEVELS
