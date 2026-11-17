# Ketik Saji | Status pengembangan

**Untuk developer/Claude Code.** Isi laporan ini dari branch dan build yang sedang dikerjakan. Perbarui snapshot sebelum push berikutnya, lalu segarkan dan sertakan file ini pada **setiap push pengembangan** agar koordinator dapat memeriksa kondisi kode, error, dan hasil validasi langsung di `/docs/PROJECT_STATUS.md`. Gunakan `docs/PROGRESS.md` untuk histori milestone yang lebih panjang.

## Snapshot terbaru

| Field | Nilai aktual saat ini |
| --- | --- |
| Tanggal/jam, WIB | 17 November 2026 · 22:28 WIB |
| Branch dan commit sumber yang diuji | `main` @ `fecb2cc` + perubahan lokal M4-A (belum di-commit) |
| Lingkungan yang diuji | Godot `4.7.2.stable.official.ed1daf0bf` · Windows · headless |
| Status lokal sebelum push | Milestone M4-A (Planning HUD, Edit Menu popup, dan perintah ketik `buka`) selesai dan lulus seluruh suite repo di headless; belum di-stage/commit. |
| Ringkasan | M1 Dapur, M2 Dine-in, M3 Online Delivery, dan M4-A Planning HUD / Edit Menu / `buka` teruji lulus di headless (`656/656` total across 8 suite di `tests/`). M4-B (`Belanja Bahan` popup), M4-C (`PlacementSlots` & pembelian peralatan), penutup hasil minimal, aset PNG UI/font final, dan Audio masih menunggu. |

Saat mengisi, catat branch, SHA **kode yang benar-benar diuji**, dan apakah perubahan lokal ikut diuji. Jika suite belum dijalankan lagi setelah perubahan terakhir, beri tanggal/SHA hasil lama dan tandai hasil build sekarang sebagai **BELUM DIUJI**.

### Yang berubah dan dapat dimainkan

| Area | Status | Bukti atau langkah verifikasi |
| --- | --- | --- |
| Boot, interaksi dapur (M1), dine-in (M2) | **SELESAI & LULUS HEADLESS** | Boot ke Planning, seluruh alur bahan/cuci/masak/potong/rak/meja/sampah (`106/106` di `tests/test_game_ui_m1.gd`), serta spawn, FIFO, patience `100s`, makan `20s`, `saji`, dan `bersihkan` (`41/41` di `tests/test_service_m2.gd`). |
| Online delivery (M3) | **SELESAI & LULUS HEADLESS** | Preview offer di `OnlineStation`, `terima`, cutoff kuota `<= 2`, cap `day_queue_initial`, 3 pickup spot + overflow FIFO, deadline `60s`, `saji` driver, dan penutupan drain otomatis teruji penuh (`98/98` di `tests/test_service_m3.gd`). |
| Planning HUD, Edit Menu, `buka` (M4-A) | **SELESAI & LULUS HEADLESS** | HUD `persiapan sebelum buka`, `Hari X/7`, persentase target Hari 7, tombol stub `Menu`/`Exit`, modal `Edit Menu` dengan `RunController.select_daily_menu()` + validasi/guard ganda, dan `buka` tanpa Enter menggantikan `StartServiceButton` (`26/26` di `tests/test_planning_m4a.gd`). |
| Belanja bahan & peralatan (M4-B, M4-C), Results minimal | **MENUNGGU (PENDING)** | Popup belanja box/fridge (M4-B), `PlacementSlots` / `request_fixture_purchase` + refactor ID stasiun dinamis (M4-C), redesain Serving HUD, auto-advance Hari 1–6, dan layar akhir Hari 7 `main menu` belum diimplementasikan. |
| Aset grafis, font, Audio, dan GUI ekspor | **BELUM DIUJI SECARA GRAFIS / TERBLOKIR ASET** | Tile, player, NPC, gojek, dan sebagian bahan terpasang. PNG UI (`assets/ui/`), font pilihan (`font pake yg kemaren aja`), resep Hari 4–7, dan spesifikasi/aset Audio belum tersedia di repo (UI M4-A memakai fallback Godot `Control`). Playtest grafis & ekspor desktop belum dijalankan. |

Pada setiap update, tulis 1–3 perubahan yang masuk push, jalur pemain yang bisa dicoba, serta bagian parsial/placeholder dan dependensinya. Sertakan path scene, fungsi, atau tes yang relevan.

### Tes yang benar-benar dijalankan

| Jenis | Hasil aktual (exit code Godot) |
| --- | --- |
| Import dan boot headless | `godot --headless --path . --import` (exit `0`) dan `godot --headless --path . --quit-after 2` (exit `0`, `script_errors=0`) **LULUS**. |
| Suite M4-A (`tests/test_planning_m4a.gd`) | **LULUS** — `26/26` PASS (`SUMMARY fails=0`, exit `0`, zero leaks). |
| Suite M3 (`tests/test_service_m3.gd`) | **LULUS** — `98/98` PASS (`SUMMARY fails=0`, exit `0`, zero leaks; tes diagnostik sengaja memicu 1 log `credit_order_once failed` pada test double). |
| Suite M2 (`tests/test_service_m2.gd`) | **LULUS** — `41/41` PASS (`SUMMARY fails=0`, exit `0`, zero leaks; mencakup update setup Day 2 pasca penghapusan `StartServiceButton` dan 1 log test double). |
| Suite M1 (`tests/test_game_ui_m1.gd`) | **LULUS** — `106/106` PASS (`SUMMARY fails=0`, exit `0`, zero leaks; diperbarui untuk Planning HUD baru & `buka`). |
| Suite M0 (`tests/test_controllers_m0.gd`), `test_game_root.gd`, `test_world_hierarchy.gd`, `test_track_a3.gd` | **LULUS** — `106/106`, `88/88`, `123/123`, `68/68` (`SUMMARY fails=0`, masing-masing exit `0`, zero leaks). |
| Tes historis `scratch/test_world_a2.gd` | **TIDAK TERSEDIA** — direktori/file `res://scratch/test_world_a2.gd` yang disebut di catatan lama tidak ada di workspace saat ini. |
| UID, format GDScript, `git diff --check`, GUI & ekspor | `.uid` & style (`tabs`, UTF-8, LF, `<=100` kolom) & `git diff --check` **LULUS** (`0` issue). GUI interaktif & ekspor **BELUM DIUJI**. |

Untuk update berikutnya, cantumkan command atau langkah manual, hasil **LULUS / GAGAL / BELUM DIUJI / TERBLOKIR**, dan ringkas output yang relevan. Laporkan regresi GUI dan hasil ekspor terpisah dari headless.

### Masalah dan validasi untuk koordinator

| Prioritas | Gejala dan langkah reproduksi | Harapan / status |
| --- | --- | --- |
| **Terbuka — sebelum M4-B** (`RunController.refund_canceled_deliveries_once`) | Kirim bahan di `SERVING` melalui API, majukan waktu `100s` hingga terkirim di `KitchenController`, lalu panggil `RunController.refund_canceled_deliveries_once()` dengan `purchase_id` yang sama. Kas bertambah meski stok sudah masuk karena status ledger `RunController` masih `&"PENDING"`. | Sinkronkan status kiriman ke `RunController` / tolak refund untuk kiriman sudah `DELIVERED`. **Masih terbuka di luar cakupan M4-A**. |
| **Terbuka — sebelum M4-B** (`KitchenController.receive_stock`) | Jadwalkan kiriman `PENDING` ke container A, lalu panggil `receive_stock` sebelum `due_at` dengan ID sama dan container B. Stok masuk ke B sementara reservasi kapasitas tertinggal di A. | Kunci `storage_unit_id`, `due_at`, dan ID terhadap kiriman dini atau pindah unit. **Masih terbuka di luar cakupan M4-A**. |
| **Catatan arsitektur — sebelum M4-C** (`KitchenController` & `PlacementSlots`) | `KitchenController` masih memakai ID starter statis (`stove`, `washer`, `rice_cooker`, `plate_rack`, `work_table_stage`, `work_table_chop`) dan `PlacementSlots` masih `Marker2D` non-`Area2D`. | Perlu refactor resolusi per `FixtureKind` + slot hitbox saat M4-C. |
| **Playtest berikut (pasca M4-A)** | Buka di Planning (`persiapan sebelum buka`), uji tombol `Edit Menu` dan ketik `buka` untuk masuk Serving. | Alur Planning M4-A siap dicoba di UI; jalur beli stok oleh pemain tetap menunggu M4-B. |

Untuk error baru, catat prioritas, langkah reproduksi, hasil yang diharapkan vs yang terjadi, pesan error persis atau lokasi yang relevan, dan status perbaikan. Tandai bug yang baru muncul atau sudah selesai. Cantumkan keputusan/asset yang dibutuhkan dan maksimal tiga hal paling penting untuk koordinator cek pada push tersebut.