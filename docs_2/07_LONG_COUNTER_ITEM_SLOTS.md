# Three-tile long counters — three independent item slots

Requests C-01 and clarification C-02 · 19 November 2026 (WIB) · Clarified in cumulative v004

This is the cleaned implementation brief derived from the coordinator's initial request, screenshot, and explicit three-tile clarification. The source wording is preserved in [02_COORDINATOR_REQUEST_LOG.md](02_COORDINATOR_REQUEST_LOG.md#c-01--long-counters-one-item-per-tile). Technical details below explain a proposed integration with existing work-surface behavior; they are not additional verbatim coordinator decisions.

## Source and intended result

**Clarification C-02 is explicit: each long counter concerned is three tiles long and must hold three items simultaneously, with one item on each tile. The entire counter must not share a single item slot.**

```text
by one item per tile, i dont mean 1 item per long counter. but since the long counter is 3 tiles long, it should be able to hold 3 items, one per tile
```

```text
these long counters should be able to hold 1 item per tile
```

![Coordinator reference showing the long dark-topped counter](<references/gameplay/image(20261119-153901).png>)

The screenshot shows the continuous dark-topped counter along the lower boundary of the tiled kitchen. Treat its usable surface as multiple independent item positions, aligned to the actual world tile grid. **Each usable counter tile holds one item.** Capacity is per tile, rather than one shared item slot for the entire connected counter.

The three-tile length is now confirmed by the coordinator, rather than inferred from screenshot pixel width. Register all three surface tiles of each affected long counter. Inspect the authored grid to identify their cells and align hit regions; do not let one decorative object or one existing station ID reduce the confirmed total capacity to one.

| Tile within one long counter | Capacity | Example simultaneous contents |
| --- | --- | --- |
| Tile 1 | 1 item | Item A |
| Tile 2 | 1 item | Item B |
| Tile 3 | 1 item | Item C |
| Entire three-tile counter | **3 items total** | A, B, and C coexist independently. |

## Required behavior

| Situation | Expected behavior |
| --- | --- |
| Player places an eligible held item on an empty counter tile | That tile holds the item and other counter tiles remain unchanged. |
| Another tile on the same long counter is empty | It can hold a separate item while its neighbors are occupied. |
| Player takes an item from a particular tile | Retrieve that tile's item only; its slot becomes empty. |
| A counter tile already holds an item | It cannot acquire a second separate stored item. Preserve existing valid plate-combination behavior where applicable. |
| A placement or pickup fails | Do not lose, duplicate, or silently overwrite either the held item or counter contents. |

Use the game's existing definition of one placed item. A plated dish or partially assembled plate is one held/placed aggregate under the existing model, rather than several independent tile occupants. The request does not increase the number of things the player can carry.

## Proposed integration with the existing game

1. Identify the long counter surface tiles represented in the screenshot and any matching authored long-counter runs. Register three independent work-surface item slots, one on each of its three tiles. Reuse the existing work-table placement/retrieval mechanisms and controller ownership where practical, rather than adding a separate inventory system.
2. Key occupancy by stable tile/cell or per-tile surface ID. A shared sprite or connected counter group must not collapse occupancy into one dictionary entry for the whole run. Visual tiles and clickable surface IDs must agree.
3. Resolve a counter click to the specific world-grid tile under the pointer. Keep the existing cardinal-neighbor movement/access rules. Clicking a counter is an interaction with that surface, not an attempt to stand on its blocked tile. Do not introduce walking on counters.
4. Recommended input behavior is the existing work-surface interaction: eligible held item + empty tile places; empty hands + occupied tile retrieves. Reuse existing valid plate/ingredient combination handling if it applies. Do not invent a new typing verb, menu, auto-spread operation, or automatic swap for this request.
5. Preserve existing phase and item-eligibility rules. Serving is the primary placement/retrieval verification context. This request alone does not enable cooking/preparation in Planning, turn counters into purchased-ingredient storage, or assign them a new fridge/spoilage policy.
6. Render each stored item over the corresponding counter-top tile, using existing item/plate art and offsets. Items on neighboring tiles must be distinguishable and follow the correct world/camera transform. Do not render all items at the long counter's group origin.
7. Refresh available commands/interaction presentation from that tile's live occupancy and the held state, following the existing rule to show only available actions. Decorative counter art must not consume or misroute clicks separately from its actual surface target.

“Usable counter tile” refers to the intended free counter surface. A stove, sink, rice cooker, or other dedicated station drawn on a counter retains its existing station function unless the current authored map explicitly defines a separate free work surface there. Do not indiscriminately convert every kitchen utility tile into another storage slot.

The three-tile capacity is confirmed. Inspect the exact authored cell coordinates, IDs, accessible sides, and existing item-placement eligibility in the implementation branch; those details must implement all three slots. Record what was included in `/docs/PROJECT_STATUS.md`. If the current counter is only decorative art, the implementation must add per-tile interaction/occupancy as well as icons; drawing an item alone does not satisfy this request.

## Acceptance checks

- Place three distinct eligible items on the three tiles of one long counter. All three must be present simultaneously, each centered on its own tile.
- Retrieve the middle item: the two end items remain unchanged. Put another item on the middle tile: all three slots are occupied again.
- Verify total capacity is exactly three separate placed items per three-tile long counter. Attempting to place a fourth item on an occupied tile must not create another slot or overwrite contents.
- Repeat on any other affected three-tile long counter; each counter maintains its own three independent slots.
- Attempt to put a second separate item on an occupied tile. It must not overwrite, duplicate, or spill an item into a neighboring slot. Existing valid plate composition may update one plate aggregate atomically.
- With empty hands, click each occupied tile and confirm only its own item is retrieved. Put it back and repeat for an end tile and a middle tile.
- Check tile-edge clicks, camera/scale transforms, and access from a legal adjacent floor tile. No teleport onto the counter and no interaction with a different tile.
- Place/retrieve an existing plate or plated aggregate if work-surface eligibility supports it, preserving its identity, components, and plate counts.
- Confirm dedicated station tiles, customer tables, selected-container ingredient purchasing, and existing Planning restrictions retain their intended behavior.

These checks are instructions for the future implementation. No counter behavior has been changed or tested by preparing this ZIP. Include actual results and any remaining errors in `/docs/PROJECT_STATUS.md` on the next relevant push.
