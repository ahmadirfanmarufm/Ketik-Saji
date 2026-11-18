# Ketik Saji | Status pengembangan

**Untuk developer/Claude Code.** Isi laporan ini dari branch dan build yang sedang dikerjakan. Perbarui snapshot sebelum push berikutnya, lalu segarkan dan sertakan file ini pada **setiap push pengembangan** agar koordinator dapat memeriksa kondisi kode, error, dan hasil validasi langsung di `/docs/PROJECT_STATUS.md`. Gunakan `docs/PROGRESS.md` untuk histori milestone yang lebih panjang.

## Snapshot terbaru

| Field | Nilai aktual saat ini |
| --- | --- |
| Tanggal/jam, WIB | 18 November 2026 · 07:31 WIB |
| Branch dan commit sumber yang diuji | `main` @ `bca99ad` + perubahan lokal M4-B, Usability Fixes, dan M4-C (belum di-commit) |
| Lingkungan yang diuji | Godot `4.7.2.stable.official.ed1daf0bf` · Windows · headless |
| Status lokal sebelum push | Milestone M4-A, M4-B, Usability Fixes (WorkTable, Smooth Movement, Day Result UI), dan M4-C (Fixture Upgrade & Placement System + Responsive Shop UI) selesai serta lulus 10 suite di headless (`826/826`) & verifikasi GUI; belum di-stage/commit. |
| Ringkasan | M1 Dapur, M2 Dine-in, M3 Online Delivery, M4-A, M4-B, dan M4-C teruji penuh di headless (`826/826` across 10 suite di `tests/`). Pemain kini dapat membeli & memasang peralatan dapur/meja (`Belanja Peralatan`) di `PLANNING` pada layout yang responsif di `640x360` (`1280x720` window) maupun ukuran lebih kecil (`480x270`), melihat konsekuensi Complexity Debt (biaya listrik harian & tekanan operasional), berinteraksi penuh dengan alat tambahan (`stove_01`, `rice_cooker_01`, `fridge_01`, `plate_rack_01`, `dining_table_03`), dan melanjutkan antar hari dengan peralatan & stok kulkas yang persisten. |

Saat mengisi, catat branch, SHA **kode yang benar-benar diuji**, dan apakah perubahan lokal ikut diuji. Jika suite belum dijalankan lagi setelah perubahan terakhir, beri tanggal/SHA hasil lama dan tandai hasil build sekarang sebagai **BELUM DIUJI**.

### Yang berubah dan dapat dimainkan

| Area | Status | Bukti atau langkah verifikasi |
| --- | --- | --- |
| Boot, interaksi dapur (M1), dine-in (M2) | **SELESAI & LULUS HEADLESS** | Boot ke Planning, seluruh alur ambil bahan/cuci/masak/potong/rak/meja/sampah (`114/114` di `tests/test_game_ui_m1.gd`), serta spawn, FIFO, patience `100s`, makan `20s`, `saji`, dan `bersihkan` (`46/46` di `tests/test_service_m2.gd`). |
| Online delivery (M3) | **SELESAI & LULUS HEADLESS** | Preview offer di `OnlineStation`, `terima`, cutoff kuota `<= 2`, cap `day_queue_initial`, 3 pickup spot + overflow FIFO, deadline `60s`, `saji` driver, dan drain otomatis (`98/98` di `tests/test_service_m3.gd`). |
| Planning HUD, Edit Menu, `buka` (M4-A) | **SELESAI & LULUS HEADLESS** | HUD `persiapan sebelum buka`, `Hari X/7`, persentase target Hari 7, tombol `Edit Menu` & `Beli Alat`, stub `Menu`/`Exit`, modal `Edit Menu` dengan `RunController.select_daily_menu()` + guard ganda, dan `buka` tanpa Enter (`26/26` di `tests/test_planning_m4a.gd`). |
| Belanja Bahan UI, Hardening Transaksi & Usability (M4-B) | **SELESAI & LULUS HEADLESS** | Klik penyimpanan (`storage_box` / `fridge_01`) di `PLANNING`/`SERVING` membuka `Belanja Bahan`, tombol `Ambil Bahan` & `ESC` di `SERVING`, pemisahan hitbox `WorkTable` (`StagingTarget` vs `ChoppingTarget`), pergerakan halus (`PlayerVisual` & NPC/driver tween), dan `DayResultSidePanel` dengan `ResultSummaryScroll` + `ResultFooter` (`55/55` di `tests/test_shop_m4b.gd`). |
| Belanja Peralatan & Placement System (M4-C) | **SELESAI & LULUS HEADLESS + GUI** | Klik tombol `Beli Alat` atau klik `PlacementSlots` kosong di `PLANNING` membuka `Belanja Peralatan` yang responsif di `640x360` (`1280x720`) maupun `480x270` (nama, kategori, harga, manfaat, beban Complexity Debt listrik/slot, kompatibilitas slot); `RunController.request_fixture_purchase()` memvalidasi kas, fase, kompatibilitas `FixtureKind`, footprint kosong, dan akses kardinal; `KitchenController` mendispatch berdasarkan `FixtureKind` sehingga alat tambahan berfungsi penuh di `SERVING` dan persisten lintas hari (`102/102` di `tests/test_fixture_m4c.gd`). |
| Aset grafis, font, Audio, dan GUI ekspor | **BELUM DIUJI SECARA GRAFIS / TERBLOKIR ASET** | Tile, player, NPC, gojek, dan sebagian bahan terpasang (`sapi.tres` memakai fallback warna di UI). PNG UI (`assets/ui/`), font pilihan, resep Hari 4–7, dan Audio belum tersedia di repo. |

Pada setiap update, tulis 1–3 perubahan yang masuk push, jalur pemain yang bisa dicoba, serta bagian parsial/placeholder dan dependensinya. Sertakan path scene, fungsi, atau tes yang relevan.

### Tes yang benar-benar dijalankan

| Jenis | Hasil aktual (exit code Godot) |
| --- | --- |
| Boot headless | `godot --headless --path . --quit-after 2` (exit `0`, `script_errors=0`) **LULUS**. |
| Suite M4-C (`tests/test_fixture_m4c.gd`) | **LULUS** — `102/102` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M4-B (`tests/test_shop_m4b.gd`) | **LULUS** — `55/55` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M4-A (`tests/test_planning_m4a.gd`) | **LULUS** — `26/26` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M3 (`tests/test_service_m3.gd`) | **LULUS** — `98/98` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M2 (`tests/test_service_m2.gd`) | **LULUS** — `46/46` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M1 (`tests/test_game_ui_m1.gd`) | **LULUS** — `114/114` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M0 (`tests/test_controllers_m0.gd`), `test_game_root.gd`, `test_world_hierarchy.gd`, `test_track_a3.gd` | **LULUS** — `106/106`, `88/88`, `123/123`, `68/68` (`SUMMARY fails=0`, masing-masing exit `0`, zero leaks). |
| Tes historis `scratch/test_world_a2.gd` | **TIDAK TERSEDIA** — direktori/file `res://scratch/test_world_a2.gd` tidak ada di workspace saat ini. |
| UID, format GDScript, `git diff --check` | `.uid` & style (`tabs`, UTF-8, LF, `<=100` kolom) & `git diff --check` **LULUS** (`0` issue). |

Untuk update berikutnya, cantumkan command atau langkah manual, hasil **LULUS / GAGAL / BELUM DIUJI / TERBLOKIR**, dan ringkas output yang relevan. Laporkan regresi GUI dan hasil ekspor terpisah dari headless.

### Masalah dan validasi untuk koordinator

| Prioritas | Gejala dan langkah reproduksi | Harapan / status |
| --- | --- | --- |
| **SELESAI di M4-C** (`KitchenController` & `PlacementSlots`) | `KitchenController` kini memakai resolusi `FixtureKind` dinamis (`register_fixture_kind`, `get_fixture_kind`) dan `PlacementSlots` dapat diklik di `PLANNING` via `WorldMap.hit_test_placement_slot()` sambil tetap bertipe `Marker2D`. | **SELESAI & TERUJI (`test_fixture_m4c.gd`)**. |
| **SELESAI di Usability Fixes** (`WorkTable`, `PlayerVisual`, `DayResultSidePanel`) | Hitbox `StagingTarget` dan `ChoppingTarget` dipisahkan tanpa overlap, pergerakan karakter/NPC/driver menggunakan tween halus, dan tombol `Lanjut` di `DayResultSidePanel` selalu terlihat di dalam viewport `640x360`. | **SELESAI & TERUJI (`test_world_hierarchy.gd` & `test_shop_m4b.gd`)**. |
| **SELESAI di M4-B** (`RunController` & `KitchenController` transaksi bahan) | Keranjang `PLANNING` atomik (`receive_stock_basket`), refund pasca-kirim dicegah, dan UX `Ambil Bahan` / `ESC` ditambahkan saat `SERVING`. | **SELESAI & TERUJI (`test_shop_m4b.gd`)**. |

Untuk error baru, catat prioritas, langkah reproduksi, hasil yang diharapkan vs yang terjadi, pesan error persis atau lokasi yang relevan, dan status perbaikan. Tandai bug yang baru muncul atau sudah selesai. Cantumkan keputusan/asset yang dibutuhkan dan maksimal tiga hal paling penting untuk koordinator cek pada push tersebut.
