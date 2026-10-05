# Changelog

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
