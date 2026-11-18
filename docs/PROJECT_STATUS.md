# Ketik Saji | Status pengembangan

**Untuk developer/Claude Code.** Isi laporan ini dari branch dan build yang sedang dikerjakan. Perbarui snapshot sebelum push berikutnya, lalu segarkan dan sertakan file ini pada **setiap push pengembangan** agar koordinator dapat memeriksa kondisi kode, error, dan hasil validasi langsung di `/docs/PROJECT_STATUS.md`. Gunakan `docs/PROGRESS.md` untuk histori milestone yang lebih panjang.

## Snapshot terbaru

| Field | Nilai aktual saat ini |
| --- | --- |
| Tanggal/jam, WIB | 18 November 2026 · 22:08 WIB |
| Branch dan commit sumber yang diuji | `main` @ `489f15d` (`feat: implement M5-A1 world layout`) + implementasi lokal **M5-A2 (Customer Seating)** (belum di-stage/commit) |
| Lingkungan yang diuji | Godot `4.7.2.stable.official.ed1daf0bf` · Windows · headless (`10/10` suite, `935/935` cek) & GUI (`640×360` / `1280×720` window & `480×270`) |
| Status lokal sebelum push | Milestone **M5-A (M5-A1 World Layout `12×9` + M5-A2 Customer Seating)** selesai diimplementasikan dan lulus seluruh `10` suite headless (`935/935` PASS, exit `0`) serta verifikasi GUI di `640×360` dan `480×270`. Permukaan meja makan masih memakai placeholder sementara `TabletopPlaceholder` sambil menunggu sprite meja khusus dari tim artist; loop 7 hari (`M5-B+`) masih pending. |
| Ringkasan | Meja makan starter (`dining_table_01..02`) dan dinamis M4-C (`dining_table_03+` via `WorldMap.spawn_placed_fixture()`) kini memakai scene bersama `scenes/world/dining_table.tscn` (`TabletopPlaceholder`, `ChairVisual` `Sprite2D` di sisi selatan memakai `Rect2(416, 160, 32, 32)`, `SeatAnchor` `Marker2D` di `(0, 16)`, `TableHitbox` `28×28`, dan `ChairHitbox` `22×12` di `(0, 18)`). Pelanggan `SEATED_WAITING` dan `EATING` menempati `SeatAnchor.global_position` (bukan di atas permukaan meja), klik kursi memilih meja induk, dan sel lantai selatan tetap walkable serta dapat diklik untuk teleport. |

Saat mengisi, catat branch, SHA **kode yang benar-benar diuji**, dan apakah perubahan lokal ikut diuji. Jika suite belum dijalankan lagi setelah perubahan terakhir, beri tanggal/SHA hasil lama dan tandai hasil build sekarang sebagai **BELUM DIUJI**.

### Yang berubah dan dapat dimainkan

| Area | Status | Bukti atau langkah verifikasi |
| --- | --- | --- |
| Boot, interaksi dapur (M1), dine-in (M2) | **SELESAI & LULUS HEADLESS** | Boot ke Planning, seluruh alur ambil bahan/cuci/masak/potong/rak/meja/sampah (`114/114` di `tests/test_game_ui_m1.gd`), serta spawn, FIFO, patience `100s`, makan `20s`, `saji`, dan `bersihkan` (`51/51` di `tests/test_service_m2.gd`). |
| Online delivery (M3) | **SELESAI & LULUS HEADLESS** | Preview offer di `OnlineStation`, `terima`, cutoff kuota `<= 2`, cap `day_queue_initial`, 3 pickup spot + overflow FIFO, deadline `60s`, `saji` driver, dan drain otomatis (`98/98` di `tests/test_service_m3.gd`). |
| Planning HUD, Edit Menu, `buka` (M4-A) | **SELESAI & LULUS HEADLESS** | HUD `persiapan sebelum buka`, `Hari X/7`, persentase target Hari 7, tombol `Edit Menu` & `Beli Alat`, stub `Menu`/`Exit`, modal `Edit Menu` dengan `RunController.select_daily_menu()` + guard ganda, dan `buka` tanpa Enter (`26/26` di `tests/test_planning_m4a.gd`). |
| Belanja Bahan UI, Hardening Transaksi & Usability (M4-B) | **SELESAI & LULUS HEADLESS** | Klik penyimpanan (`storage_box` / `fridge_01`) di `PLANNING`/`SERVING` membuka `Belanja Bahan`, tombol `Ambil Bahan` & `ESC` di `SERVING`, pemisahan hitbox `WorkTable` (`StagingTarget` vs `ChoppingTarget`), pergerakan halus (`PlayerVisual` & NPC/driver tween), dan `DayResultSidePanel` dengan `ResultSummaryScroll` + `ResultFooter` (`55/55` di `tests/test_shop_m4b.gd`). |
| Belanja Peralatan & Placement System (M4-C) | **SELESAI & LULUS HEADLESS + GUI** | Klik tombol `Beli Alat` atau klik `PlacementSlots` kosong di `PLANNING` membuka `Belanja Peralatan` yang responsif di `640x360` (`1280x720`) maupun `480x270` dengan ke-`11` tombol slot (`slot_utility_01..05`, `slot_table_01..06`) muat di dalam popup (`104/104` di `tests/test_fixture_m4c.gd`). |
| World Layout `12×9` (M5-A1) | **SELESAI & LULUS HEADLESS + GUI (`640×360` & `480×270`)** | Grid `12×9` (`32×32` px, `108` sel `FloorTiles`), posisi starter fixture sesuai spesifikasi, `5` slot utilitas + `6` slot meja (`8` total meja), antrean dine-in di kolom `9` (`4` anchor), pickup spot non-walkable di `(7,5)..(7,7)`, `driver_overflow` di `(11,7)`, dekorasi pasif meja panjang (`(0..5,4)`) & dinding (`(8,0..4 & 8)`), pintu `(8,5..7)`, posisi awal pemain `(6,3)`, serta verifikasi keterjangkauan kardinal saat ke-11 slot penuh (`208/208` di `tests/test_world_hierarchy.gd`, total `913/913` di 10 suite). |
| Customer Seating (M5-A2: `ChairVisual`, `SeatAnchor` & Placeholder Meja) | **SELESAI & LULUS HEADLESS + GUI (`640×360` & `480×270`)** | Scene bersama `scenes/world/dining_table.tscn` dipakai oleh `dining_table_01..02` dan `dining_table_03+` (`WorldMap.spawn_placed_fixture()`). `ChairVisual` (`Rect2(416,160,32,32)`) dan `SeatAnchor` (`(0, 16)`) tidak terdaftar di `WorldRegistry`/`WorldGrid`; `WorldMap._resolve_customer_visual_position()` memakai `SeatAnchor.global_position`; klik `ChairHitbox` memilih meja untuk `saji`/`bersihkan` tanpa mengganggu klik lantai sel selatan (`219/219` di `test_world_hierarchy.gd`, `51/51` di `test_service_m2.gd`, `110/110` di `test_fixture_m4c.gd`). |
| Loop 7 Hari (`M5-B+`), `M4-D` Resale & Backlog Playtest | **BELUM DIIMPLEMENTASIKAN (PENDING)** | Loop transisi otomatis 7 hari + Mode Ekstra penuh, pipeline resep `nasi_komplit` / Hari 4–7 (`M5-B+`), fitur jual peralatan (`M4-D`), serta item non-layout dari catatan playtest belum dikerjakan. |
| Aset grafis, font, Audio, dan GUI ekspor | **PARSIAL / TERBLOKIR ASET LANJUTAN** | Tile lantai/jalur/dinding/meja-panjang, kursi meja makan (`416,160,32,32`), player, NPC, gojek, dan sebagian bahan terpasang (`sapi.tres` memakai fallback warna UI; permukaan meja makan memakai `TabletopPlaceholder` sampai sprite meja khusus tersedia). PNG UI (`assets/ui/`), font pilihan, resep Hari 4–7, dan Audio belum tersedia di repo. |

Pada setiap update, tulis 1–3 perubahan yang masuk push, jalur pemain yang bisa dicoba, serta bagian parsial/placeholder dan dependensinya. Sertakan path scene, fungsi, atau tes yang relevan.

### Tes yang benar-benar dijalankan

| Jenis | Hasil aktual (exit code Godot) |
| --- | --- |
| Import & Boot headless | `godot --headless --path . --import` (exit `0`) & `godot --headless --path . --quit-after 2` (exit `0`) **LULUS**. |
| Suite World Hierarchy, M5-A1 & M5-A2 (`tests/test_world_hierarchy.gd`) | **LULUS** — `219/219` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M4-C (`tests/test_fixture_m4c.gd`) | **LULUS** — `110/110` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M4-B (`tests/test_shop_m4b.gd`) | **LULUS** — `55/55` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M4-A (`tests/test_planning_m4a.gd`) | **LULUS** — `26/26` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M3 (`tests/test_service_m3.gd`) | **LULUS** — `98/98` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M2 (`tests/test_service_m2.gd`) | **LULUS** — `51/51` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M1 (`tests/test_game_ui_m1.gd`) | **LULUS** — `114/114` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M0 (`tests/test_controllers_m0.gd`), `test_game_root.gd`, `test_track_a3.gd` | **LULUS** — `106/106`, `88/88`, `68/68` (`SUMMARY fails=0`, masing-masing exit `0`, zero leaks; total `935/935` cek di 10 suite). |
| Verifikasi GUI (`640×360` / `1280×720` window & `480×270`) | **LULUS** — Diuji dengan renderer non-headless Godot 4.7.2: `LeftHUDRegion` tidak menimpa `World`, klik HUD terblokir, popup `Belanja Peralatan` (11 tombol slot) muat penuh di `640×360` & `480×270`, klik `ChairHitbox` meja starter & dinamis memilih meja induk, sel lantai selatan dapat diklik normal, dan visual pelanggan duduk di `SeatAnchor` terverifikasi via render `640×360`. |
| Tes historis `scratch/test_world_a2.gd` | **TIDAK TERSEDIA** — direktori/file `res://scratch/test_world_a2.gd` tidak ada di workspace saat ini. |
| UID, format GDScript, `git diff --check` | `.uid` & style (`tabs`, UTF-8, LF, `<=100` kolom) & `git diff --check` **LULUS** (`0` issue). |

Untuk update berikutnya, cantumkan command atau langkah manual, hasil **LULUS / GAGAL / BELUM DIUJI / TERBLOKIR**, dan ringkas output yang relevan. Laporkan regresi GUI dan hasil ekspor terpisah dari headless.

### Masalah dan validasi untuk koordinator

| Prioritas | Gejala dan langkah reproduksi | Harapan / status |
| --- | --- | --- |
| **SELESAI di M5-A2** (`Customer Seating`) | `ChairVisual` (`Rect2(416,160,32,32)`) + `SeatAnchor` (`(0, 16)`) + `ChairHitbox` + `TabletopPlaceholder` terpasang lewat scene bersama `scenes/world/dining_table.tscn` pada meja starter & dinamis M4-C; pelanggan duduk di `SeatAnchor`. | **SELESAI & TERUJI (`test_world_hierarchy.gd`, `test_service_m2.gd`, `test_fixture_m4c.gd`)**. |
| **SELESAI di M5-A1** (`World Layout 12×9`) | Layout `12×9` (`108` sel), `5` slot utilitas + `6` slot meja, antrean kanan kolom `9`, pickup non-walkable `(7,5)..(7,7)`, overflow jalan kanan `(11,7)`, dekorasi pasif meja panjang & dinding, dan posisi awal pemain `(6,3)` telah diterapkan dan lulus headless + GUI. | **SELESAI & TERUJI (`test_world_hierarchy.gd` & `test_fixture_m4c.gd`)**. |
| **SELESAI di M4-C** (`KitchenController` & `PlacementSlots`) | `KitchenController` kini memakai resolusi `FixtureKind` dinamis (`register_fixture_kind`, `get_fixture_kind`) dan `PlacementSlots` dapat diklik di `PLANNING` via `WorldMap.hit_test_placement_slot()` sambil tetap bertipe `Marker2D`. | **SELESAI & TERUJI (`test_fixture_m4c.gd`)**. |
| **SELESAI di Usability Fixes** (`WorkTable`, `PlayerVisual`, `DayResultSidePanel`) | Hitbox `StagingTarget` dan `ChoppingTarget` dipisahkan tanpa overlap, pergerakan karakter/NPC/driver menggunakan tween halus, dan tombol `Lanjut` di `DayResultSidePanel` selalu terlihat di dalam viewport `640x360`. | **SELESAI & TERUJI (`test_world_hierarchy.gd` & `test_shop_m4b.gd`)**. |
| **SELESAI di M4-B** (`RunController` & `KitchenController` transaksi bahan) | Keranjang `PLANNING` atomik (`receive_stock_basket`), refund pasca-kirim dicegah, dan UX `Ambil Bahan` / `ESC` ditambahkan saat `SERVING`. | **SELESAI & TERUJI (`test_shop_m4b.gd`)**. |

Untuk error baru, catat prioritas, langkah reproduksi, hasil yang diharapkan vs yang terjadi, pesan error persis atau lokasi yang relevan, dan status perbaikan. Tandai bug yang baru muncul atau sudah selesai. Cantumkan keputusan/asset yang dibutuhkan dan maksimal tiga hal paling penting untuk koordinator cek pada push tersebut.
