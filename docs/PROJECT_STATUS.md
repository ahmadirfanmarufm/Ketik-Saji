# Project status

Updated: 2026-11-20 12:15 +07:00 (WIB) · Antigravity Developer Agent
Branch / tested baseline: `main` @ `15d5cfc` + local uncommitted `docs_2/` recovery, Main Menu/Display fixes, M8 Employee Hiring System & M9 Tutorial/Modal/Typography Polish
Build / platform: Godot Engine `4.7.2.stable.official.ed1daf0bf` · Windows 11 (`x86_64`) · GL Compatibility renderer

---

## Current playable state

**Ketik Saji launches directly to the Main Menu (without starting a run or Story prematurely), applies live Windowed/Fullscreen/Resolution/VSync display settings via `DisplayServer` + `Window` with read-back verification and `user://settings.cfg` persistence, includes the M8 + M8.1 Employee Hiring & Workforce System (`Koki`, `Kasir`, `Pelayan`) with unified `KetikUiArt` `GrapeSoda.ttf` Employee UI typography, isolates `Cara Main` from `PauseOverlay` (`Escape` / outside-click / `Pause -> Cara Main -> Pause` round-trip), provides the 15-section `Cara Main` reference and 8-chapter interactive guided tutorial + 9 contextual feature tips with `[tutorial]` persistence in `GameAudio`, and passes all `27/27` automated headless suites (`fails=0`) plus GL visual verification (`480x270`–`1600x900`).**

- **Initial Main Menu Flow (`GameRoot` + `RunController` + `GameUI`):** Fixed `_is_app_main_scene_boot()` so real `project.godot` boots (`get_tree().current_scene` still `null` inside `Main::start()` `_ready()`) and `change_scene_to_file()` launches set `_in_main_menu = true` **before** `_wire_controllers()`, keeping `RunController._run_started == false`, `MainMenuOverlay.visible = true`, `LeftHUDRegion` hidden, and Opening Story stopped until the player explicitly selects `Play`. `request_start_play_from_menu()` runs `_reset_run_world_and_controllers(true)` so both initial `Play` and returning via `Menu utama` -> `Play` start a fresh Day 1 run with zero stale cash/day state.
- **Functional Display Mode, Resolution & VSync (`GameAudio` + `SettingsOverlay`):** `DisplayModeButton` (`Berjendela` / `Layar Penuh`), `ResolutionOptionButton` (`480x270`, `640x360`, `1280x720`, `1600x900`), `VsyncToggleButton` (`Aktif` / `Mati`), and `SettingsResetButton` call real `DisplayServer` + `Window` APIs (`window_set_mode`, `window_set_flag`, `window_set_size`, screen-bounds clamping + centered positioning, deferred fullscreen-exit bounds enforcement, `window_set_vsync_mode`), verify read-back `window_get_mode()` / `window_get_size()` / `window_get_vsync_mode()`, and update `DisplayStatusLabel` (`Aktif: Layar Penuh (1920x1080) · Resolusi jendela (...)` or `Aktif: Berjendela · WxH · VSync ...`) rather than displaying unverified requested values.
- **Audio, Settings, Exit Confirmation & Gameplay:** Retains `Backsound.ogg` (`193.85s` imported), 3 `AudioServer` buses (`Master`, `Music`, `SFX`), `191.392s` loop, `5.0s` fade, `ConfigFile` (`user://settings.cfg`) persistence, `ExitConfirmOverlay`, `LeftHUDRegion` (`136px`), `Edit menu` + `Resep`, `Belanja Bahan`, 3-tile counter slots, and `CARA MAIN`.

---

## Requirement status

| Area / request | Status | Evidence and remaining work |
| --- | --- | --- |
| Thirteen recipes / `M-01` | **Implemented & verified** | All 13 `.tres` files in `data/recipes/` verified by `tests/test_track_a3.gd` & `tests/test_docs2_final.gd`. |
| Ingredient unlocks / demand | **Implemented & verified** | `RunController` Day 1–5 ingredient gating (`beras, telur` -> `sapi`), `+3/+2/+1` additive arrivals (`tests/test_track_a3.gd`, `tests/test_p5_simulation.gd`, `tests/test_p5g_fair_economy.gd`). |
| Main menu & startup flow / `UI-01` | **Implemented & verified** | Real `main_scene` boot opens `MainMenuOverlay` with `_run_started == false` and zero story/HUD started; Settings/Cancel preserve MainMenu; `Play` starts clean Day 1 run + story (`tests/test_main_menu_and_display_m7.gd`, `tests/test_story_tutorial.gd`, `01_boot_main_menu.png`). |
| HUD and typing | **Implemented & verified** | Left HUD `136px`, `paper-calendar` `32px`, typing/command rects (`tests/test_hud_pause_m5c.gd`, `tests/test_dialogue_click_m5b3.gd`, `03_sidebar_planning_640.png`). |
| Sidebar Exit & Exit Confirm | **Implemented & verified** | `ExitStubButton` -> `ExitConfirmOverlay` (`"Keluar Game?"`), `MenuStubButton` -> `Cara Main`, `PauseButton` -> `PauseOverlay`; `Pause` & `Main Menu` unified (`tests/test_audio_settings_exit_m6.gd`, `tests/test_hud_pause_m5c.gd`, `tests/test_planning_m4a.gd`, `04_exit_confirm_*.png`). |
| Edit Menu, shops & 3-tile counters | **Implemented & verified** | `tests/test_edit_menu_feedback_m5e.gd`, `tests/test_shop_m4b.gd`, `tests/test_shop_ui_m5d.gd`, `tests/test_fixture_m4c.gd`, `tests/test_audio_settings_exit_m6.gd` (interactive mouse/key cooking + `LongCounterLeft01` `DishSprite` + dine-in serve). |
| Audio `A-01`/`A-02` & BGM `.ogg` | **Implemented & verified (no physical speaker check in CLI)** | `Backsound.ogg` (`193.85s`) imported and playing cleanly (`Main Menu` / `SERVING`), `Master`/`Music`/`SFX` buses + fade-only `BGMPlayer`, `191.392s` loop, `5.0s` fade, click/serve/error SFX (`tests/test_audio_settings_exit_m6.gd`, `tests/test_docs2_final.gd`). **Human speaker listening QA awaits interactive launch.** |
| Settings `A-03` & Live Display/Reset | **Implemented & verified (headless + non-headless GL)** | `SettingsOverlay` (`AUDIO`, `TAMPILAN`, `LAINNYA`) with `Master`/`Musik`/`SFX`, real `DisplayServer` Fullscreen/Windowed, `[480x270, 640x360, 1280x720, 1600x900]` bounds-clamped sizing, VSync, verified `DisplayStatusLabel`, `Reset Default`, and deferred `user://settings.cfg` startup application (`tests/test_main_menu_and_display_m7.gd`, live captures `02`–`08`). |
| Results / win / lose `R-01` | **Implemented & verified** | Days 1–6 summary, Day 7 WON (`Lanjut jualan` / `Menu utama`), Day 7 LOST (`Coba lagi` / `Menu utama`) (`tests/test_progression_m5b.gd`, `tests/test_full_run_m5f.gd`). |
| Grape Soda / 15-Section `CARA MAIN` & Modal Fix | **Implemented & verified** | `GrapeSoda.ttf` applied via `KetikUiArt`; `15`-section `CARA MAIN` fits `480x270`–`1600x900`; `Cara Main` vs `PauseOverlay` mutual exclusion + `PauseReferenceButton` round-trip (`tests/test_story_tutorial.gd`, `tests/test_tutorial_modal_typography_m9.gd`, `tests/test_hud_pause_m5c.gd`). |
| Interactive 8-Chapter Tutorial & Employee UI Typography / `M9` | **Implemented & verified** | Removed `FontVariation` from `EmployeeOverlay` (unified `KetikUiArt` cream/brown contrast); re-activated 8-chapter (`17`-step) real-action tutorial + `9` contextual tips + Skip/Replay + `GameAudio` `[tutorial]` `ConfigFile` persistence (`tests/test_tutorial_modal_typography_m9.gd`, `9` inspected GL PNGs `480x270`–`1600x900`). |
| Employee Hiring & Workforce / `M8`+`M8.1` | **Implemented & verified** | `Koki`/`Kasir`/`Pelayan` (`PLANNING`-only hire/dismiss + confirmation), stable sequence names (`Koki #1`..), standardized UI labels (`Kelola Pegawai`, `Biaya Rekrutmen`, `Gaji Harian`, `Total Gaji Harian`, zero `"Upah"`), expanded `Koki` stove cooking onto `long_counter_right_01..03` with station/slot locks, procedural `WALK`/`WORK`+pan/steam/`CLEAN`/`SERVE` animations on `pegawai.png`, `[1.0, 0.75, 0.50, 0.35]` + crowding overhead (`+20k/extra` beyond 2), and 7-day simulations (`tests/test_employees_m8.gd`: `46` PASS; `0`-hire `Rp 1,721,400` WON, `1 Cook` `Rp 1,622,800` WON, bloated 6-crew `Rp 485,400` LOST). |

---

## Validation performed

1. **Headless Resource Import & Project Main-Scene Boot:**
   - `C:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path . --import` -> Exit `0`, zero import/parse/UID errors.
   - `C:\Godot\Godot_v4.7.2-stable_win64.exe --path . --quit-after 30` -> Exit `0` (direct `project.godot` launch).
2. **Full Automated Godot Regression Suite (`27/27` suites, headless `--path . -s tests/*.gd`):**
   - Includes all `26` prior suites plus `tests/test_tutorial_modal_typography_m9.gd`, updated `tests/test_story_tutorial.gd`, and `tests/test_hud_pause_m5c.gd` — **Combined:** `27/27` suites passing (`exit=0`, `SUMMARY fails=0`).
3. **Live Non-Headless Windows GL Runtime & Visual Verification (`scratch/visual_audit_m9.gd`, `tests/test_main_menu_and_display_m7.gd`):**
   - Executed M9 tutorial, `Cara Main` vs `PauseOverlay`, and `EmployeeOverlay` typography visual audit across `480x270`, `640x360`, `1280x720`, and `1600x900` (`9` inspected GL PNGs in session scratch dir).
   - Previously verified `DisplayServer` mode/resolution/VSync transitions (`tests/test_main_menu_and_display_m7.gd`: `23/23` PASS, `SUMMARY fails=0`).
4. **Audio Listening Check:** **NOT RUN** (CLI environment without live speaker verification).

---

## Known errors, missing assets, and deviations

1. **BGM Source Transcode:** Original `assets/audio/Backsound.opus` is retained alongside transcoded `assets/audio/Backsound.ogg` (produced locally from OBS Studio's FFmpeg 7.x `libopus` -> `libvorbis` libraries at matching `48 kHz` stereo, `9,304,968` samples / `193.85s`) so Godot `4.7.2` imports it natively.
2. **Headless Audio Teardown Timing Note:** In Godot `4.7.2` `--headless` Dummy audio driver, existing tests that play `.ogg` streams immediately before calling `free(); await process_frame; quit()` may print `ObjectDB instances were leaked` (`AudioStreamPlaybackOggVorbis`) unless `2+` frames run for `AudioServer::update()` to flush stopped playbacks (`test_audio_settings_exit_m6.gd` drains `12` frames and exits cleanly with `0` node/gameplay leaks). Also inside Windows Sandbox Mode, `user://settings.cfg` is read-only unless running unsandboxed or via `set_settings_path_for_test(...)`.
3. **Asset Path & Role Implementation Notes:** Prompt-referenced `res://assets/art/npc/Pegawai.png` does not exist; existing repository asset `res://assets/art/characters/pegawai.png` (`uid://btbdutwct48ot`, `14×31` static RGBA8 sprite) is used consistently in both `WorldMap` and `EmployeeOverlay`. Equipment selling (`M4-D`) remains unimplemented/excluded and is intentionally omitted from `Cara Main`. When hiring triggers `employee_hired` while `EmployeeOverlay` is open, `FeatureTipPanel` renders behind `WorldDimmer` at top-right until dismissed or the shop closes. Because Ketik Saji credits orders atomically on `saji` without a separate cashier register queue, `Kasir` assists front-of-house online intake (`OnlineStation` at free pickup spots) and guest patience buffers without generating unbacked cash.
4. **Formatting Check:** `git diff --check` clean (`exit=0`); zero files inside `docs_2/` modified.

---

## Checks for the coordinator

1. **Audio Listening & Display QA (Windows Desktop Build):** Launch on desktop, verify BGM starts in Main Menu and Serving, loops seamlessly at `191.392s`, fades smoothly over `5.0s` into Planning/Results, responds live to `Master`/`Musik`/`SFX` sliders (`0%` mutes cleanly without affecting sibling buses), verify `Mode Layar`/`Resolusi`/`VSync` & `Reset Default`, and verify settings reload after relaunch (`user://settings.cfg`).
2. **Interactive Exit & Full Run QA:** Verify sidebar scroll icon opens `Cara Main`, `Exit` icon opens `"Keluar Game?"` confirmation (`Batal`/`Keluar`/`Escape`), `Pause` opens Pause cleanly, and run Day 1 -> Day 7 win/lose playthrough.

---

## Next work

1. Perform interactive desktop speaker QA on `Backsound.ogg`, `Master`/`Music`/`SFX` sliders, `click1..5.ogg`, error SFX, and serve SFX.
2. Perform interactive relaunch check of `user://settings.cfg` on a non-sandboxed Windows desktop session (saving settings, closing, and reopening the executable).
3. Export Windows release build (`itch.io` package) with GrapeSoda font attribution on the `itch.io` store page per `F-02`.
