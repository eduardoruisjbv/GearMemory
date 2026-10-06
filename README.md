# GearMemory 0.2.0 beta

GearMemory is a standalone World of Warcraft Retail 12.1 addon that compares your equipped gear, backpack items, and bank items against the priorities you choose for your current specialization. The interface follows the client language: Brazilian Portuguese for ptBR and English for other clients.

## Open and configure

Use `/gm`, `/gearmemory`, or the helmet button on the minimap. Choose **Prioridade 1** and **Prioridade 2** for secondary stats: Mastery, Haste, Critical Strike, or Versatility. Choosing a stat already selected in the other position swaps the two choices. Settings, including the optional automatic mode, are saved per character and specialization.

The main attribute is selected automatically from your specialization: Strength, Agility, or Intellect. It always wins over secondary stats. Warrior armor must be plate; inappropriate armor, weapons, and primary attributes cannot become upgrades because of item level. Accessories without a main attribute remain legitimate candidates. Inactive adaptive attributes are not added to the score or treated as competing attributes.

The comparison is deterministic. Each content profile (Raid, Dungeon/M+, Open world, PvP) keeps its own secondary priorities per specialization; **Perfil** chooses it automatically or lets you pin one.

1. Appropriate main attribute. A higher amount wins regardless of secondary score.
2. With the same main attribute, an item level lead of 5 or more wins.
3. Otherwise the weighted secondary score decides: priority 1 × 3, priority 2 × 2, other secondaries × 1. Tertiary stats (Speed, Leech, Avoidance) add small amounts and never justify losing item level.
4. Item level breaks any remaining tie.

Gems and enchants already on the equipped item count towards its stats. In PvP, including the open world with PvP or War Mode on, the buffed PvP item level is compared first, so a PvE item is only chosen when its item level is higher; those swaps are always left to you.

The interface shows the main attribute amount, secondary score, and item level separately; there is no misleading single combined score. This expresses your chosen priorities, rather than predicting damage or healing.

## Suggestions and categories

**Melhorias** compares complete compatible equipment arrangements. Both ring slots and both trinket slots are considered together, including unique category limits. Weapon arrangements consider two handed weapons, one handed/offhand pairs, tank shields, ranged Hunter weapons, Rogue dagger requirements, and Fury's two handed pairs. Existing equipped ring/trinket positions are retained to avoid pointless swaps.

**Melhores por categoria** lists leading compatible candidates for each armor/weapon type and separates PvE and PvP item categories. Two candidates are retained for paired categories. Items are never sold or destroyed. This addon does not provide an API that authorizes another addon to sell gear.

**Contexto** cycles through Automatic, PvE, and PvP. Automatic selects PvP in battlegrounds and arenas. PvP scaling item level is read from Blizzard's localized tooltip. The stat values available outside PvP can still be PvE values; affected comparisons are explicitly marked **Revisar**, and automatic equipment of such upgrades is blocked. PvP rankings are therefore rankings of the available base attributes, not a simulation of effective PvP performance.

## Equipment

Click **Equipar melhorias** to equip the currently available safe backpack upgrades. **Equipar automaticamente** is off by default and requires GearMemory's own confirmation. Its consent is stored for the current specialization. **Parar** or `/gm stop` disables it and cancels further equipment work.

Equipment only runs outside combat and pauses while vendors, banks, the auction house, trade, or quest dialogs are open. An optional BagMemory activity check prevents it from competing with BagMemory's vendor/bank/quest work. BagMemory is not a dependency, and GearMemory has no dependency on MuscleMemory.

Only fully identified backpack items are equipped. Item GUID, live bag contents, unique limits, item lock, refund status, and binding information are checked before the native equipment request. The actual destination GUID must then be confirmed by WoW. Ambiguous duplicates, unknown data, transferable/account-bound gear, and potential binding or refund changes remain manual. Weapon changes require a free general backpack slot. GearMemory does not clear the player's cursor, accept native binding/refund popups, or inject input.

Effects, trinkets, legendary/special items, saved equipment sets, set bonuses, and incomplete information are marked **Revisar**. The equipment button skips these items; equip them through WoW after reviewing them. GearMemory does not simulate procs, gems, set bonus value, weapon damage interactions, or DPS. Its suggestions describe attribute improvements according to your priorities, not guaranteed optimal equipment.

## Bank

Visiting the bank reads the currently viewable purchased bank tabs through Retail's bank APIs. A completed visit saves a character-local snapshot with a timestamp. Closed-bank entries are clearly described as records from the last visit and cannot be equipped. A bank item never suppresses a separate safe upgrade that is already in your backpack.

Bank equipment must be withdrawn by the player. The snapshot can become outdated after another character changes the Warband bank, after a specialization change, or after remote item modifications. Revisit the bank to refresh it. Partial bank reads do not replace a completed snapshot.

## Curated data and explanations

`Data.lua` holds the trinket ratings per specialization (Fury and Frost Death Knight, from Method.gg for Midnight 12.1) and the upgrade currency table. A trinket that is not listed is never equipped automatically. `/gm explain` prints why each slot keeps or changes its item, and every suggestion shows the reason in the list and its tooltip.

## Installation

Extract the `GearMemory` folder into `_retail_/Interface/AddOns/`, alongside BagMemory and MuscleMemory. Enable GearMemory on the character selection addon screen. A newly installed addon requires a full client restart to be discovered; later Lua changes can be picked up with `/reload`.

## Validation status

Lua source was checked for syntax by loading, without executing, each chunk. Offline tests (`~/Documentos/GearMemory/tests/run.lua`, run with `luajit`) cover the comparison rules, PvP, trinkets, weapon styles, set bonuses, upgrade tracks and tooltip reading with simulated data. Live Retail validation is still required for frames, tooltips, specialization metadata, bank APIs, adaptive item stats, unique equipment, protected actions, native confirmation behavior, and combat restrictions.

The addon uses native APIs from Blizzard's UI source mirror:

- [Item API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)
- [Tooltip API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoDocumentation.lua)
- [Bank API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/BankDocumentation.lua)

These API contracts document the integration; they do not replace verification inside WoW.

## Inventory analysis

Item events and background scans are suspended while native bags are closed. Opening a bag refreshes the analysis; during combat, automatic refresh waits until combat ends. Direct merchant/bank/Auction House operations and manual menu actions still perform the reads they need. GearMemory starts automatic equipment only while bags are open; closing the bags stops the automatic sequence.
