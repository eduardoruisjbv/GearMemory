local _, GM = ...

-- Curated data. Everything here is data, not logic: edit freely.
GM.data = {
    -- trinkets[specID] = {pve={[itemID]=rating}, pvp={[itemID]=rating}}
    -- rating 4 = best in slot ... 1 = acceptable. A trinket missing here is
    -- never equipped automatically ("Revisar"). PvP lists are empty for now.
    -- Source: Method.gg gearing guides, Midnight 12.1 (Season 2), checked 2026-10-05.
    trinkets = {
        -- Fury Warrior
        [72] = {pve={
            [270173]=4, -- Zul'jin's Guillotine Technique
            [270175]=4, -- Voracious Heart of Ula'tek
            [270164]=3, -- Gebbo's Bottomless Bag
            [250238]=2, -- Seed of the Devouring Wild
            [270168]=2, -- Font of Venomous Rage
        }, pvp={}},
        -- Frost Death Knight
        [251] = {pve={
            [270175]=4, -- Voracious Heart of Ula'tek
            [270173]=4, -- Zul'jin's Guillotine Technique
            [270164]=3, -- Gebbo's Bottomless Bag
            [273797]=3, -- Tattered Amani War Banner
            [250259]=2, -- Sapling of the Dawnroot
        }, pvp={}},
    },
    -- Estimated average primary-stat value for recognized chance-based procs.
    -- 280097 / 270558: 206-207 primary stat for 20 sec at ilvl 263. We model
    -- one proc per minute (20/60 uptime); this is an estimate, not a DPS model.
    trinketProcAverages = {
        [280097]={primaryAtReference=206, referenceLevel=263, duration=20, interval=60},
        [270558]={primaryAtReference=207, referenceLevel=263, duration=20, interval=60},
    },
    -- upgradeCurrency[trackName] = {currency=currencyID, cost=perRank}
    -- Left empty until the season's crest IDs and costs are confirmed in game;
    -- while empty, the upgrade ceiling is never counted.
    upgradeCurrency = {},
}
