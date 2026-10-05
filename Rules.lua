local _, GM = ...
local L=GM.L

-- Constants shared by the evaluator, the interface and the offline tests.
GM.stats = {"mastery", "haste", "crit", "vers"}
GM.statNames = {mastery=L["Maestria"], haste=L["Aceleração"], crit=L["Crítico"], vers=L["Versatilidade"]}
GM.statKeys = {mastery="ITEM_MOD_MASTERY_RATING_SHORT", haste="ITEM_MOD_HASTE_RATING_SHORT",
    crit="ITEM_MOD_CRIT_RATING_SHORT", vers="ITEM_MOD_VERSATILITY"}
GM.primaryNames = {[1]=L["Força"], [2]=L["Agilidade"], [4]=L["Intelecto"]}
GM.slotNames = {[1]=L["Cabeça"], [2]=L["Pescoço"], [3]=L["Ombros"], [5]=L["Peito"], [6]=L["Cintura"],
    [7]=L["Pernas"], [8]=L["Pés"], [9]=L["Pulsos"], [10]=L["Mãos"], [11]=L["Anel 1"], [12]=L["Anel 2"],
    [13]=L["Berloque 1"], [14]=L["Berloque 2"], [15]=L["Costas"], [16]=L["Mão principal"], [17]=L["Mão secundária"]}

-- Content profiles. Each specialization keeps its own secondary priorities per
-- content type; "auto" resolves to one of these from where the player is.
GM.contexts = {"raid", "dungeon", "world", "pvp"}
GM.contextNames = {raid=L["Raide"], dungeon=L["Masmorra / M+"], world=L["Mundo aberto"], pvp="PvP"}

GM.rules = {
    -- With the same main attribute, an item level lead of at least this much
    -- beats any secondary-stat advantage (PvP compares item level first).
    ilvlThreshold = 5,
    -- Switching weapon style (two-handed <-> one-hand pair) needs this much
    -- item level per weapon slot, so the spec's style is respected.
    styleSwitchIlvl = 15,
    preferredStyle = {[72]="2h", [269]="1h", [251]="1h"},
    -- Curated trinkets count as extra virtual item level by rating (4 best).
    trinketBonus = {[4]=20, [3]=12, [2]=6, [1]=0},
    -- Tertiary stats are minor tie breakers, never a reason to give up item
    -- level. For DPS: Speed is the most useful, Leech second, Avoidance least,
    -- Indestructible (no repairs) worth nothing in combat. Sources: wowutils.com
    -- tertiary guide and Method.gg 12.1 stat guides, checked 2026-10-05.
    tertiaryWeights = {ITEM_MOD_CR_SPEED_SHORT=0.5, ITEM_MOD_CR_LIFESTEAL_SHORT=0.3,
        ITEM_MOD_CR_AVOIDANCE_SHORT=0.1, ITEM_MOD_CR_STURDINESS_SHORT=0},
    -- Rating bonus (percent) from which a secondary stat is in diminishing returns.
    drStart = 30,
    -- Estimated item level gained per remaining upgrade rank.
    upgradeStep = 3,
}

-- Which content profile applies. A flagged player in the open world is always
-- treated as PvP: they must be ready for battle at any time.
function GM:ContentFor(instanceType, pvpFlagged)
    if instanceType == "raid" then return "raid" end
    if instanceType == "party" or instanceType == "scenario" then return "dungeon" end
    if instanceType == "pvp" or instanceType == "arena" then return "pvp" end
    return pvpFlagged and "pvp" or "world"
end
