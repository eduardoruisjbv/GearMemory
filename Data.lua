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
    -- upgradeCurrency[trackName] = {currency=currencyID, cost=perRank}
    -- Left empty until the season's crest IDs and costs are confirmed in game;
    -- while empty, the upgrade ceiling is never counted.
    upgradeCurrency = {},
}
