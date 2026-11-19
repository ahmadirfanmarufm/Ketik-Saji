# Final dish artwork — exact verified bindings

All fourteen PNGs were opened and verified as **32 × 32**. They represent thirteen recipes plus one ordinary plate. Paths below are handoff-relative; choose consistent final `res://` import paths and bind them explicitly through data.

| Stable recipe ID | Display name | Exact included path |
| --- | --- | --- |
| `nasi_telor` | Nasi Telur | `provided_assets/dishes/Nasi-Telur.png` |
| `nasi_tempe` | Nasi Tempe | `provided_assets/dishes/Nasi-Tempe.png` |
| `nasi_ayam` | Nasi Ayam | `provided_assets/dishes/Nasi-Ayam.png` |
| `nasi_telur_tempe` | Nasi Telur Tempe | `provided_assets/dishes/Nasi-TelurTempe.png` |
| `nasi_ayam_telur` | Nasi Ayam Telur | `provided_assets/dishes/Nasi-AyamTelur.png` |
| `egg_salad` | Egg Salad | `provided_assets/dishes/Egg-Salad.png` |
| `chicken_salad` | Chicken Salad | `provided_assets/dishes/Chicken-Salad.png` |
| `nasi_daging_sapi` | Nasi Daging Sapi | `provided_assets/dishes/Nasi-Beef.png` |
| `nasi_ayam_komplit` | Nasi Ayam Komplit | `provided_assets/dishes/Nasi-AyamTelurTempe.png` |
| `nasi_sapi_telur` | Nasi Sapi Telur | `provided_assets/dishes/Nasi-BeefTelur.png` |
| `beef_salad` | Beef Salad | `provided_assets/dishes/Beef-Salad.png` |
| `nasi_sapi_komplit` | Nasi Sapi Komplit | `provided_assets/dishes/Nasi-BeefTelurTempe.png` |
| `nasi_gila` | Nasi Gila | `provided_assets/dishes/Nasi-Gila(Semua ingredients).png` |
| Not a recipe | Ordinary clean plate | `provided_assets/dishes/plate.png` |

Preserve the exact file case, spaces, parentheses, and `TelurTempe`/`Beef` spelling unless deliberately renaming all references together. Stable `nasi_telor` retains its existing ID spelling while its player-facing name is Nasi Telur. Artwork filenames do not define command tokens or ingredient IDs.

The first ZIP contains the plate and nine rice-dish icons. The second contains Egg/Chicken/Beef Salad and Nasi Gila. Original source names are recorded in `ASSET_INTEGRITY.json`; extracted bytes are unchanged.

Use each final dish icon consistently in the daily-menu editor, recipe preview, customer/online order indicators, and completed plated-item presentation through the existing recipe-ID resolver. Raw parts and partially assembled plates retain their existing presentation until they match a complete recipe. Do not guess validation from what appears visible in the illustration: exact component and preparation data come from the recipe brief, including all six components for Nasi Gila and no rice for salads.

Use nearest filtering, preserve transparency, and retain aspect ratio. The original canvas is 32 × 32; do not squeeze icons to fill a wide text column. Use the ordinary plate for the appropriate empty-plate presentation. Continue using the separately supplied UI `icons/plate-dirty.png` for dirty tables; the clean plate must not replace that marker.

For quick acceptance, confirm thirteen unique recipe IDs each resolve to their intended icon, all unlock-day totals match 1/2/4/6/8/10/13, and the Resep descriptions fit with the real Grape Soda font. The original brief's detailed ingredient, demand, shop, and plate-conservation checks remain required.
