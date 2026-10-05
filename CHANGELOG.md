# Changelog

## 0.3.0-beta — 2026-10-05

- **Fixed: the automatic profile ignored your PvP choice.** It treated "War Mode active" as PvP, but after you switch War Mode off the game keeps it active (and keeps you flagged) until you rest in a city. The profile stayed on PvP and PvE gear lost every comparison. It now follows your choice (War Mode off = not PvP); a manual PvP flag without War Mode still counts.
- **Fixed: one unreadable item blocked every upgrade.** A single bag item with incomplete data put the whole addon in "Waiting for item/set data". Now only worn items and saved sets block everything; an unreadable bag item blocks just itself, and the addon retries reading by itself (up to 6 times, every 2 seconds).
- **Fixed: rings, necklaces and cloaks were never considered.** They have no specialization list, which was read as "data missing"; they now count for any specialization.
- **Changed: refund is no longer a reason to hold an upgrade.** The game already asks you to confirm before equipping a refundable item, and the addon never dismisses that dialog.
- **New: it reads the gear more often, without running all the time.** Besides opening the bags, a scan now runs when gear is looted and when the character panel opens (with the bags closed too). Loot windows with more than 6 items are ignored, and so are bursts of loots (more than 10 in 15 seconds) such as material farming; at least 3 seconds separate loot scans.
- **New: identical copies.** When a bag item is exactly the same as the equipped one (same level, stats, gems and enchants) but worth at least 1 silver less at the vendor, it is worn so the dearer copy can be sold (BagMemory 0.4.0 does the selling). Trinkets are excluded.
- **New: `/gm diag`** lists why each upgrade is held back and why an item does or does not qualify (the text is Portuguese-only for now).
- Validation: the 45 offline checks pass; the new triggers and rules were checked with simulations only. In-client validation is still pending.

## 0.2.1-beta — 2026-10-05

- **English and Portuguese.** The interface, messages and tooltips follow the client language (Portuguese for ptBR, English for every other client). `/gm toast` now also toggles the on-screen notice, next to the Portuguese `/gm aviso`.

## 0.2.0-beta — 2026-10-05

Smarter comparison, content profiles and explanations. Offline tests cover every rule below; in-client validation is still pending.

- **Comparison.** Main attribute still wins first. With the same main attribute, a lead of 5+ item level wins; below that, weighted secondaries decide, then item level.
- **PvP.** In PvP the buffed item level decides first. A flagged player in the open world (PvP on or War Mode) is always in the PvP profile, so a PvE item only wins when its item level beats the buffed PvP item level. PvE/PvP swaps are never equipped automatically.
- **Content profiles.** Secondary priorities are kept per specialization and per content: Raid, Dungeon/M+, Open world, PvP. Automatic mode picks the profile from the instance type and the PvP flag.
- **Gems and enchants** on the equipped item count towards its total. Empty sockets are reported.
- **Trinkets.** A curated list per spec (Fury, Frost DK for now) adds virtual item level by rating. Trinkets outside the list stay under review.
- **Weapons.** The spec's style (two-handed or one-hand pair) is respected; switching needs +15 item level per slot.
- **Tier sets.** A swap that would drop an active 2P/4P bonus is shown with a warning and never equipped automatically.
- **Upgrade tracks.** The upgrade ceiling counts only when the currency data is configured and the player can pay; such swaps are marked for review. Currency data is empty until confirmed in game.
- **Tertiary stats** (Speed, Leech, Avoidance) act as small tie breakers; **diminishing-return** excess is reported in the status line.
- **Bind-on-equip** items get a confirmation button ("Equipar (vincula)"); WoW's own binding popup still has to be accepted by the player.
- **Explanations.** Every suggestion says why (tooltip and list); `/gm explain` prints the decision for each slot.

## 0.1.2-beta — 2026-10-04

- Register inventory, item-data and equipment-change listeners only while a native bag is open; unregister them when the last bag closes.
- Refresh the inventory on opening bags and skip queued background scans after they close.
- Pause automatic equipment chains when bags close; explicit equipment/review actions remain available.
- Keep direct bank snapshots and manual menu changes current.
- Retain evaluation score/scratch-table optimizations.
- In-client validation and CPU measurements remain pending.

## 0.1.1-beta — 2026-10-04

- Reuse item/context scores within a single evaluation; discard the cache before the next scan.
- Reuse scratch equipment and score tables while evaluating complete ring, trinket and weapon pairs.
- Skip uniqueness work for combinations that cannot improve the current plan.
- Preserve main-attribute priority, class/spec suitability, complete pair searches and unique-item protection.
- In-client validation and CPU measurements remain pending.

## 0.1.0-beta — 2026-10-04

- Introduced the standalone GearMemory Retail addon with a Brazilian Portuguese menu and `/gm` and `/gearmemory` commands.
- Added automatic main attribute selection and two configurable secondary priorities per character and specialization.
- Added deterministic main-attribute-first comparison, weighted secondary score, and item-level tie breaking.
- Added class/spec compatibility, paired ring/trinket plans with unique limits, and compatible complete weapon arrangements.
- Added equipped/backpack analysis, leading candidates by category, and bank visits with dated review-only snapshots.
- Added PvE/PvP contexts and explicit review for unverified effective PvP attributes.
- Added click-authorized equipment and a separately confirmed, optional automatic equipment mode.
- Added conservative binding/refund/effect/set handling, service/combat pauses, live identity checks, and destination GUID confirmation.
- Published the initial installable beta package. In-client validation remains pending.
