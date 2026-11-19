# Ketik Saji | Handoff implementasi UI MVP

**17 November 2026 (WIB) · Untuk developer dan Claude Code**
**Dasar perubahan** [`main` · `6da401eb452e4788644bfbb56ad33669b5b1e752`][head]. Audit sebelumnya [`531d1c7bff4c0a335b1c70287bfc0474e5999fc2`][old].

Mulai dengan `git status` dan `git diff` pada branch lokal. Cocokkan setiap delta di bawah dengan implementasi yang sudah ada dan gabungkan perubahan secara bertahap ke `game_ui.tscn`, `game_ui.gd` dan controller terkait. WIP yang belum di-push belum diketahui. Pertahankan referensi aset lokal, hasil milestone yang sudah berjalan, dan histori `docs/PROGRESS.md`. Isi snapshot awal di [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) dari kondisi lokal, lalu segarkan dan sertakan file itu pada setiap push pengembangan.

## Keputusan yang berlaku

- Buka layanan dengan mengetik `buka` sampai lengkap. Ganti aksi `Mulai Layanan` yang saat ini tampil. Peralatan hanya dibeli di slot saat Planning, dengan `beli` sebagai konfirmasi final. Penjualan peralatan keluar dari MVP.
- Settlement tetap otomatis dengan seluruh aturan penghasilan, refund, listrik, dan utang permintaan. Hilangkan tampilan breakdown harian. Hari 1–6 tetap lanjut ke Planning berikutnya. Hari 7 berakhir dengan `kamu menang` atau `kamu kalah` dan tombol `main menu`.
- **Audio — PLANNED, SPECS/ASSETS PENDING COORDINATOR.** Integrasi dijadwalkan menyusul setelah file, routing dan pemicu ditetapkan. Pakai aksi dan sinyal yang sudah ada untuk UI saat ini.

### Aset UI yang disetujui

| Kelompok | Aset |
| --- | --- |
| 10 ikon/ilustrasi | `judul`, `small dialog bubble popup`, `meja kotor`, `makanan blm jadi`, `customer yang blm datang`, `money`, `harga listrik`, `icon customer nunggu`, `icon customer makan`, `icon ada notif pesanan online` |
| 3 aset pakai ulang | Strip HUD kiri besar, satu gaya tombol dengan keadaan **unclicked** dan **clicked**, satu latar popup persegi panjang yang berbeda dari strip |
| Font | `font pake yg kemaren aja`. Pakai font terpilih jika file sudah tersedia, dengan font bawaan yang terbaca sebagai fallback sementara. |

Developer merakit tampilan dari PNG individual, sprite game yang sudah ditangani, dan elemen Godot. Gunakan `Control`/`Container` dan tekstur opsional dengan fallback warna, ikon sementara atau teks. Ikat aset berdasarkan peran dan ID game. Pertahankan referensi yang sudah terpasang dan isi referensi PNG saat aset datang. Pilih margin menurut ukuran gambar sebenarnya dan `NinePatchRect` jika gambar cocok untuk 9-slice. Karakter, tile, utilitas, bahan dan resep tetap mengikuti jalur aset yang sudah ada. [Referensi Godot 4.7: CanvasLayer][godot_canvas] · [Control][godot_control] · [InputEvent][godot_input] · [NinePatchRect][godot_nine].

## Baseline GitHub dan delta

| Bagian | Kondisi pada `6da401e` |
| --- | --- |
| Dapur dan dine-in | **Sudah terpasang.** Perintah memproses bahan, rak dan meja kerja menangani piring, `saji` melayani meja, pelanggan punya spawn/FIFO/patience, makan, dan meja kotor bisa dibersihkan. Pertahankan input, stok dan alur pemakaian ulang piring. [Dapur][kitchen_cmd] · [Dine-in][service_main] |
| Hari pertama | **Parsial dari sudut pemain.** Box awal kosong. Tes memasok bahan lewat `RunController`. Pemain bisa membiarkan pelanggan habis dan mencapai RESULTS. Jalur normal untuk mendapat bahan masih menunggu UI belanja. [Registrasi awal][starter] · [Setup tes][test_seed] |
| UI yang berbeda dari MVP | `LeftHUDRegion`, dialog ketik, input gate, held visuals, badge resep berupa teks dan bar pelanggan sudah tersedia. Tombol start lama dan `DayResultSidePanel` masih terhubung. Gunakan data dan node yang ada untuk mengganti penyajian. [Scene][ui_scene] · [GameUI][ui_hud] · [Badge pelanggan][world_badge] |
| Edit Menu, belanja dan slot | **Backend belanja/menu parsial.** `select_daily_menu` dan pembelian satu jenis bahan berfungsi di controller. Popup, input `buka`, dan menu keluar belum ada. Slot peralatan masih `Marker2D` dan `request_fixture_purchase` masih selalu menolak. Stub resale dan baris `Jual Alat` adalah legacy. [RunController][run_shop] · [Slot scene][world_slots] · [Results UI lama][ui_results] |
| Pesanan online | **Parsial.** Preview ID, aturan kelayakan, tiga pickup spot, anchor overflow dan jalur render driver sudah ada. `try_accept_online_offer` dan `try_serve_driver` belum menyelesaikan transaksi. Parser saat ini menolak aksi online setelah pencocokan. [Online controller][online] · [Render driver][world_drivers] · [Dispatch][kitchen_cmd] |
| Art | Player, NPC, gojek, tile dan sebagian bahan sudah terhubung ke scene/Resource. Font pilihan, ikon resep akhir dan paket UI yang disetujui belum terlihat dalam commit. Tampilan grafis dan WIP lokal belum diverifikasi. [Scene dunia][world_art] · [Resource tekstur][ingredient_art] |

Di snapshot ini, Godot **4.7.2.stable.official.ed1daf0bf**, Linux x86_64, lulus import, boot headless dan keenam suite repo. `test_game_ui_m1.gd` menguji input/dapur, `test_service_m2.gd` menguji dine-in dengan stok yang disiapkan via API, deadline, dan penutupan. Satu pesan `credit_order_once failed` sengaja dipicu oleh test double pada tes diagnostik. Kelulusan ini belum mencakup UI MVP, art final atau playtest grafis. [Tes M1][test_m1] · [Tes M2][test_m2] · [Tes diagnostik][test_diagnostic].

## A. Planning dan Edit Menu

1. Boot langsung ke Planning. Di strip kiri tampilkan `persiapan sebelum buka`, `Hari X/7`, kas, persentase target kas Hari 7, `Edit Menu`, perkiraan pelanggan dine-in hari ini, `Menu`/`Exit` kecil, dan hint `Ketik: buka`. Dunia dan jalur tunggu tetap tampak. Gunakan `RunController.get_run_view()` untuk hari, kas, target, menu dan `planned_dinein_quota`.
2. `Edit Menu` memakai latar persegi panjang yang sama dengan popup lain. Dari ID resep yang unlocked, baca nama/ikon atau fallback, beri highlight terhadap pilihan yang aktif, dan kirim pilihan saat dikonfirmasi lewat `select_daily_menu(recipe_ids)`. Tolak pilihan kosong, duplikat atau ID terkunci dengan pesan singkat. Setelah sukses, refresh forecast dari Run. Hari 4–7 menunggu resep yang disetujui.
3. **Opsi input minimal:** masukkan `buka` sebagai konteks Planning pada parser milik `KitchenController`, dengan `GameUI._unhandled_key_input` tetap sebagai jalur forwarding. Ketik tanpa target dunia bila tidak ada popup atau fokus pengeditan, abaikan huruf yang tidak memperpanjang prefix, dukung Backspace/Escape, reset prefix saat konteks hilang, dan panggil `GameRoot.start_service_requested()` sekali saat kata lengkap. `finalize_plan()` tetap menjadi validasi. Jika ditolak, tampilkan `Tidak bisa mulai layanan` atau pesan validasi yang spesifik. Gunakan jalur lokal yang setara jika sudah tersedia. [Input UI][ui_input] · [Parser][parser] · [Transisi Service][root_start] · [Rencana Run][plan].

## B. Belanja bahan dan peralatan

### Bahan di box/fridge

- Klik **box/fridge fisik** yang valid melalui jalur world yang ada. Pertahankan teleport kardinal dan pemilihan satu klik. Buka popup di Planning dan Serving. Redupkan **hanya area map**, biarkan HUD kiri terbaca, dan pusatkan panel di area yang dapat dipakai.
- Tampilkan sprite box/fridge terpilih di kiri atas. Di bawahnya tampilkan 3 slot fisik box (maksimal 5 per slot) atau 2 slot fridge (maksimal 3 per slot) dari `get_storage_unit_view(storage_unit_id)`. Ikon isi dan jumlah berada di setiap slot. Beri hover/highlight pilihan. Untuk sementara, gunakan pilihan slot untuk inspeksi visual. Transaksi tetap menuju container yang diklik.
- Susun ikon bahan horizontal dengan counter di atas serta tombol kecil `−` dan `+` di bawah. Batasi counter mulai dari nol. Gunakan harga yang dibaca dari Run dan tampilkan satu total di tengah. Tombol besar bawah `ga jadi` menutup tanpa perubahan dan `beli` melakukan satu commit. Kunci tombol selama commit dan kosongkan/tutup transaksi sesudah sukses. Tampilkan alasan singkat ketika kas, kapasitas atau target tidak valid. Tambahkan stok Planning langsung dan jadwalkan stok Serving pada 100 detik service. Tampilkan indikator kiriman dari `get_pending_delivery_views()` di container, menggunakan waktu GameRoot dan `due_at` dari data owner.
- API saat ini adalah `RunController.request_ingredient_purchase(ingredient_id, quantity, storage_unit_id)`. Jalur basket, jika dipilih, perlu memeriksa total kas dan simulasi **kapasitas gabungan** termasuk reservasi pada container yang sama, lalu meng-commit semua atau batal seluruhnya. Hindari loop panggilan per bahan yang bisa berhenti di tengah. Jika commit atomik belum aman, pakai **kompromi sementara** satu bahan dengan jumlah nonnol per checkout. Tampilkan batasnya dan total riil. Catat kompromi di laporan status.
- Modal menangkap klik dan ketikan melalui `set_modal_blocking` dan guard fokus yang sudah ada. Elemen dekoratif memakai `MOUSE_FILTER_IGNORE`. GameRoot terus berjalan selama overlay terbuka. [UI input][ui_input] · [Guard][ui_guard] · [Stok/kiriman][stock] · [Purchase API][run_shop].

### Peralatan di slot

- Jadikan slot kosong pada `PlacementSlots` target di jalur klik yang sama, misalnya dengan hitbox untuk marker yang sudah ada. Gunakan `slot_id`, `allowed_fixture_kinds` dan footprint pada marker tersebut. Popup memakai latar sama, menampilkan opsi yang cocok dengan slot, unlock yang berlaku dan kas, dalam dua baris. Sorot pilihan dan tampilkan harga, lalu `ga jadi` / `beli`.
- Lengkapi `request_fixture_purchase(utility_id, slot_id)` pada Run. Validasi Planning, slot masih kosong dan cocok, footprint serta akses kardinal, dan kas. Pada sukses debit sekali dan pasang serta registrasikan instance fisik ke world dan owner terkait secara langsung. Hubungkan aksi fixture baru berdasarkan jenis dan ID instance. Beberapa dispatcher dapur saat ini masih memakai ID starter. Kegagalan pendaftaran tidak meninggalkan tagihan atau fixture setengah terpasang. `beli` merupakan konfirmasi final. Hilangkan aksi penjualan dari tampilan dan tinjau stub lama terpisah bila mengganggu. [Slot scene][world_slots] · [Purchase stub][run_shop] · [Registry world][world_reg].

### Regresi yang perlu ditutup saat belanja dihubungkan

Pada commit ini, probe API mengonfirmasi `refund_canceled_deliveries_once` dapat mengembalikan kas untuk kiriman yang sudah tiba jika dipanggil langsung, dan `receive_stock` menerima ID pending terlalu dini ke box lain sehingga reservasi asal tertinggal. Jalur tick/close biasa memakai target dan daftar pembatalan yang benar. Batasi UI pada permintaan pembelian dengan pilihan ID dan jumlah, sementara owner menentukan harga, ID transaksi, waktu, status dan refund. Tambahkan pengujian guard untuk pengiriman dini/salah unit, refund setelah delivery, dan duplikasi. Untuk listrik, gunakan kalkulasi Run yang sama untuk angka HUD dan settlement. `UtilityDef` juga menyimpan biaya dan dapat menyimpang dari `EconomyConfig` yang saat ini dipakai hitungan. [Receipt][receipt] · [Refund][refund] · [Hitungan listrik][power].

## C. Serving dan indikator dunia

- Di strip kiri tampilkan logo di atas, `Hari X/7`, `day_queue_remaining` dengan ikon pelanggan belum datang, kas, perkiraan listrik hari ini, jumlah pelanggan kecewa dan entri kecil `Menu`/`Exit`. Baca kas/biaya dari Run dan angka antrean dari `ServiceController.get_customer_queue_view()`. Usul untuk angka kecewa ialah satu hitungan gagal hari ini dari order dine-in dan online yang sudah diterima. Ekspos snapshot dari Service bila perlu. Tetap bedakan dengan antrean luar dan utang demand. Goal meter hanya di Planning. HUD Serving tidak memakai elapsed readout atau daftar tiket.
- Pertahankan `get_customer_views()` dan `sync_dine_in_visuals()`. Ubah badge teks/bar yang telah terpasang menjadi ikon resep di atas pelanggan OPEN, penanda tunggu dan ring 100 detik sejak spawn, termasuk di luar. Saat makan gunakan ikon makan dan ring 20 detik. Hubungkan `meja kotor` dengan state DIRTY. Pertahankan held visual dan baca `get_held_item_view()`. Pakai `makanan blm jadi` ketika plated item belum cocok dengan resep lengkap.
- Pertahankan satu bubble dekat target dengan command relevan, prefix aktual dan ghost text. Owner menjaga kelayakan command dan klaim transaksi. Saat target berubah atau hilang, buang prefix lama. Pakai transform dan clamp yang sudah ada, dan uji agar klik ke objek tetap sampai meski ikon/ring berada di atasnya.
- Pada stasiun fisik online, baca `get_online_offer_view()` dan tampilkan ikon notifikasi plus preview resep saat ada offer, termasuk saat preview belum bisa diterima. Offer belum memiliki deadline. Sambungkan `terima` ke `try_accept_online_offer` setelah M3 siap. Cutoff ketika unspawned `<= 2`, cap order aktif sama dengan kuota dine-in awal. Pesanan yang diterima menghasilkan **driver fisik** dengan resep dan ring 60 detik. Pakai tiga pickup spot dan overflow FIFO yang tetap terlihat. Hanya driver yang berada di spot dapat dipilih untuk `saji` melalui ID driver dan hidangan yang cocok. Deadline tidak di-reset saat promosi. Gunakan `sync_driver_visuals` dan view Service setelah jalur benar-benar tersedia. Gunakan placeholder untuk tata letak sementara.
- Pertahankan satu jam service. Perbarui indikator dari data waktu owner. Perubahan PNG dan penyajian hanya mengubah tampilan. [HUD dan view wiring][ui_hud] · [Views Service][views] · [Visual pelanggan][world_badge] · [Driver visual][world_drivers] · [Clock][root_start].

## D. Tutup layanan dan hasil akhir

Gunakan `GameRoot.request_close_if_drained()`. Syaratnya kuota belum datang habis, antrean luar kosong, tidak ada dine-in aktif termasuk yang makan, dan tidak ada order online diterima yang masih OPEN. Pertahankan pengosongan dan settlement satu kali. Aman untuk menyembunyikan `DayResultSidePanel` setelah transisi penggantinya benar-benar terhubung. Hari 1–6 dapat lanjut otomatis **setelah settlement**, lewat jalur advance yang sudah ada dan guard sekali, atau memakai satu aksi kecil bila jalur lokal sudah aman. Toast singkat `Hari X selesai` opsional.

Hari 7 memakai latar rectangle yang sama, teks `kamu menang` / `kamu kalah` dari hasil Run setelah listrik, dan tombol `main menu`. Pakai navigasi yang sudah tersedia secara lokal bila ada. Untuk snapshot ini, fallback teknisnya menu minimal dengan logo, panel dan tombol `Main` yang memulai run baru lewat boot Planning. Tampilkan menu yang benar sebagai tujuan tombol. Pertahankan jalur backend Extra Mode bila kompatibel. [Semantik settlement dan advance][root_close] · [Saldo setelah listrik][settle] · [Presentasi lama][ui_results].

### Keputusan koordinator yang masih terbuka

| Area | Opsi kerja sementara |
| --- | --- |
| Fokus `buka`, lanjut hari | Gunakan input Planning global bebas modal, dan transisi otomatis setelah settlement, atau pertahankan padanan lokal yang aman. Ini pilihan integrasi yang dapat diganti. |
| Slot dan beberapa bahan | Sorot slot sebagai inspeksi. Beli menuju container. Gunakan satu jenis bahan per checkout jika basket atomik belum siap. |
| Angka kecewa dan menu | Usul jumlah order gagal hari ini. Pakai tujuan `main menu` minimal atau yang sudah ada. Jika perilaku pause belum disetujui, gunakan entry/overlay tanpa menghentikan waktu. Ekspos Extra Mode bila kemudian diminta. |

## E. Urutan implementasi dan verifikasi

1. Pertahankan milestone gameplay yang aktif, sambungkan strip Planning, `buka`, Edit Menu dan akses stok starter lewat alur belanja. Tambahkan overlay dan fallback asset sekarang.
2. Hubungkan ulang transisi hari dan hasil akhir dengan tes settlement. Lengkapi belanja Serving dan peralatan, termasuk guard ledger, sebagai perubahan kecil per jalur.
3. Pakai ulang indikator dine-in yang sudah hidup. Sambungkan online ketika transaksi M3 tersedia. Ganti fallback dengan PNG yang nyata dan lakukan playtest grafis.

| Cek penerimaan | Hasil yang harus diamati |
| --- | --- |
| Boot, Edit Menu, `buka` | Hari 1, kas, persentase, forecast dan peta terbaca dengan fallback. Pilihan resep unlocked mengubah forecast, pilihan kosong ditolak, ketik lengkap sekali tanpa Enter dan tanpa bocor dari modal. |
| Belanja dua fase | Slot box/fridge benar dan selectable, total berubah dengan counter, `ga jadi` bebas efek, kas/kapasitas rendah menolak secara utuh. Cek double-click dan basket atau fallback tercatat. Serving 99 detik masih pending, 100 detik tiba di target meski modal terbuka. Tidak ada refund setelah delivery. |
| Peralatan dan input | Klik slot kosong yang kompatibel, opsi dua baris, sorot dan harga. Satu debit/pemasangan. Occupied, slot salah dan Serving ditolak. Klik di HUD, kartu atau dimmer tidak menggerakkan player. Klik target dunia tetap teleport kardinal sekaligus memilih. |
| Dunia dan order | Dine-in tunggu 100 detik, makan 20 detik, DIRTY dan piring benar. HUD mencerminkan quota belum spawn, listrik dan gagal hari ini. Begitu M3 tersambung, verifikasi preview tanpa timer, cutoff/cap, empat order mengisi tiga spot plus overflow, 60 detik berjalan, dan `saji` salah/overflow ditolak. |
| Settlement dan hasil | Selesaikan satu hari dari entry pemain dengan belanja dan service nyata. Lanjut tepat sekali tanpa breakdown. Cek batas kas Hari 7 sesudah listrik dan klik `main menu` menuju destinasi yang berfungsi. |
| Art dan fit | Ulangi dengan fallback dan PNG terpasang. Periksa busy-screen, ring, prompt, klik, serta ekspor desktop bila tersedia. Catat perbedaan hasil headless, GUI dan build aktual di `docs/PROJECT_STATUS.md`. |

Jalankan `godot --headless --path . --import`, `tests/test_game_ui_m1.gd`, `tests/test_service_m2.gd`, `tests/test_controllers_m0.gd` dan suite lain yang tersentuh. Perbarui assertion untuk start/results lama ketika penggantinya sudah teruji. Beri status **BELUM DIUJI** pada jalur yang belum dijalankan dan **TERBLOKIR** bila dependensi belum ada.

[head]: https://github.com/ahmadirfanmarufm/Ketik-Saji/commit/6da401eb452e4788644bfbb56ad33669b5b1e752
[old]: https://github.com/ahmadirfanmarufm/Ketik-Saji/commit/531d1c7bff4c0a335b1c70287bfc0474e5999fc2
[godot_canvas]: https://docs.godotengine.org/en/4.7/tutorials/2d/canvas_layers.html
[godot_control]: https://docs.godotengine.org/en/4.7/classes/class_control.html
[godot_input]: https://docs.godotengine.org/en/4.7/tutorials/inputs/inputevent.html
[godot_nine]: https://docs.godotengine.org/en/4.7/classes/class_ninepatchrect.html
[kitchen_cmd]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/kitchen/kitchen_controller.gd#L653-L700
[service_main]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/service/service_controller.gd#L235-L347
[starter]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/economy/run_controller.gd#L469-L507
[test_seed]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/tests/test_service_m2.gd#L247-L264
[ui_scene]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scenes/ui/game_ui.tscn#L19-L165
[ui_hud]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/ui/game_ui.gd#L626-L682
[world_badge]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/world/world_map.gd#L652-L719
[run_shop]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/economy/run_controller.gd#L148-L263
[world_slots]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scenes/world/restaurant_world.tscn#L259-L287
[ui_results]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/ui/game_ui.gd#L844-L920
[online]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/service/service_controller.gd#L350-L383
[world_drivers]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/world/world_map.gd#L408-L521
[world_art]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scenes/world/restaurant_world.tscn#L3-L46
[ingredient_art]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/kitchen/ingredient_def.gd#L8-L27
[test_m1]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/tests/test_game_ui_m1.gd
[test_m2]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/tests/test_service_m2.gd
[test_diagnostic]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/tests/test_service_m2.gd#L783-L818
[ui_input]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/ui/game_ui.gd#L210-L278
[parser]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/kitchen/kitchen_controller.gd#L212-L291
[root_start]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/core/game_root.gd#L40-L89
[plan]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/economy/run_controller.gd#L266-L292
[ui_guard]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/ui/game_ui.gd#L993-L1019
[stock]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/kitchen/kitchen_controller.gd#L342-L382
[world_reg]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/world/world_map.gd#L125-L183
[receipt]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/kitchen/kitchen_controller.gd#L406-L444
[refund]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/economy/run_controller.gd#L342-L355
[power]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/economy/run_controller.gd#L538-L548
[views]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/service/service_controller.gd#L395-L483
[root_close]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/core/game_root.gd#L92-L187
[settle]: https://github.com/ahmadirfanmarufm/Ketik-Saji/blob/6da401eb452e4788644bfbb56ad33669b5b1e752/scripts/economy/run_controller.gd#L358-L393
