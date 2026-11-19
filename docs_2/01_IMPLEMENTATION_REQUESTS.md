# Ketik Saji | Permintaan integrasi terkumpul FINAL v006

19 November 2026 (WIB)

Dokumen ini merapikan permintaan koordinator menjadi instruksi untuk developer/agent. [Catatan sumber](02_COORDINATOR_REQUEST_LOG.md) mempertahankan kalimat asli dan urutannya. Versi ini adalah snapshot kumulatif final untuk fase integrasi terakhir. Setiap pembaruan berikutnya menghasilkan ZIP baru yang memuat seluruh permintaan aktif beserta koreksinya.

Implementasi berjalan menjadi baseline. Fokus fase ini adalah integrasi UI berdasarkan aset yang tersedia, audio yang telah tersedia, dan penyederhanaan tutorial yang diminta tepat sebelum pencatatan dimulai. Aset UI dan lima target visual sudah tersedia. Baca 03_UI_VISUAL_IMPLEMENTATION.md, 04_UI_ASSET_CATALOG.md, dan 05_DECISIONS_AND_ACCEPTANCE.md untuk integrasi visual terperinci.

## A. Tutorial satu panel — instruksi final

Permintaan terbaru mengganti rangkaian tutorial terpandu dengan satu panel berisi teks CARA MAIN persis dari koordinator. Ikuti [09_TUTORIAL_PANEL_FINAL.md](09_TUTORIAL_PANEL_FINAL.md). Hapus urutan langkah, panah/highlight, popup bertahap, dan gate progres tutorial. Agent wajib memverifikasi fit dan keterbacaan di panel sebenarnya dengan Grape Soda, termasuk tombol tutup, pada ukuran normal dan ukuran kecil yang didukung. Jangan mengganti kata-kata koordinator agar muat.

## B. Pemetaan audio

Sumber A-01. Seluruh file audio disediakan dalam SFX.zip. Path di arsip memakai awalan to use/. Hubungkan file ke aksi yang sudah ada pada proyek.

| Pemicu | File | Perilaku |
| --- | --- | --- |
| Setiap penekanan keyboard | click1.ogg sampai click5.ogg | Pilih acak dan hindari file yang sama pada dua pemutaran berurutan. |
| Setiap penekanan tombol UI | Pool click yang sama | Acak dengan aturan tanpa pengulangan berturut-turut. |
| Input ketik yang tidak valid | impactGlass_heavy_000.ogg | Putar saat validator menolak input salah. |
| Hidangan benar berhasil disajikan melalui saji | impactMining_000.ogg | Putar setelah transaksi serving berhasil. |
| Main menu dan Serving | Backsound.opus | Mainkan BGM berulang sesuai titik loop. |
| Planning | BGM diam setelah fade selesai | Planning dapat menerima sisa fade transisi dari Serving. |

**Interpretasi implementasi.** Gunakan satu riwayat click terakhir untuk keyboard dan tombol UI agar keduanya berbagi aturan tanpa pengulangan berurutan. Sound error dan sound sukses melengkapi click dari keyboard. Ini menjelaskan penggabungan event, sementara koordinator menetapkan masing-masing pemicunya.

Kelola pemutaran dari satu jalur input yang jelas. Event keyboard fisik yang sampai ke beberapa handler cukup dicatat sekali sebagai penekanan. Auto-repeat dan tombol UI yang diaktifkan lewat keyboard belum diberi aturan campuran. Usulan minimal adalah satu click untuk satu penekanan fisik, termasuk jika penekanan itu mengaktifkan tombol UI. Gunakan callback sukses serving yang sudah tervalidasi agar input ditolak atau callback berulang tidak menghasilkan sound sukses tambahan.

## C. Loop tepat pada 03:11.392

Sumber A-01. BGM mengulang tepat pada **191.392 detik**.

**Interpretasi titik awal.** Ulang ke awal file pada 00:00.000. Koordinator menetapkan titik akhir, sementara titik awal ini merupakan pembacaan langsung atas permintaan.

Pemeriksaan file mendapati Backsound.opus berupa stereo Opus 48 kHz dengan durasi container sekitar **193.8675 detik**. Titik loop mendahului akhir file sekitar 2.4755 detik. Gunakan batas 191.392 detik dan dengarkan hasil loop. Periksa offset import/decoder jika format runtime memerlukannya.

Periksa dukungan import file pada engine yang dipakai. Jika perlu derivative format yang kompatibel, pertahankan materi audio serta waktu loop sumber. Hindari perubahan tempo atau durasi saat konversi.

## D. Fade lintas stage dan scene

Sumber A-02. Saat scene atau stage berubah, BGM keluar dengan fade **5 detik**. Serving ke Planning merupakan contoh eksplisit, dan koordinator menerapkannya pada kasus transisi lainnya.

- Jalur fade tetap hidup ketika scene asal dibongkar.
- Transisi ke Planning menurunkan volume yang sedang terdengar hingga diam selama 5 detik. Setelah itu Planning diam.
- Jika batas loop tercapai saat fade berjalan, fade terus berjalan menuju diam.
- Transisi cepat dan berulang memakai tujuan terbaru dan satu kepemilikan playback yang jelas.
- Kurva fade dapat memakai implementasi sederhana yang tersedia. Koordinator menetapkan durasinya.

**Main menu ke Serving dan arah sebaliknya.** Keduanya memakai BGM, dan permintaan fade berlaku pada perubahan scene secara umum. Usulan minimal adalah fade keluar 5 detik, kemudian lanjutkan/mulai playback untuk tujuan yang masih memerlukan musik. Fade-in atau crossfade belum ditetapkan. Saran assistant sebelumnya untuk playback kontinu belum menjadi instruksi langsung koordinator. Laporkan pilihan yang dipakai.

Perilaku musik saat Pause belum ditentukan. Gunakan perilaku yang sudah konsisten di proyek dan laporkan pilihan tersebut.

## E. Slider volume di Settings

Sumber A-03 **mengganti pembatasan volume awal A-01**. Proyek memiliki Settings dan sekarang memerlukan slider volume pemain.

Dalam konteks percakapan ini slider berlaku untuk **BGM**. Hubungkan ke Settings yang sudah ada. Gunakan satu nilai volume musik dengan default yang mudah disetel programmer, terapkan perubahan secara langsung, dan izinkan mute pada nol.

Volume efektif selama fade adalah volume pilihan pemain dikalikan faktor fade. Menggeser slider saat fade berjalan menerapkan pengaturan baru tanpa menghentikan fade atau memulai ulang track. Playback setelah transisi menghormati pilihan terbaru, termasuk mute.

Persistensi slider antar-launch belum diminta. Reuse penyimpanan Settings bila tersedia. Cakupan slider SFX/master belum ditentukan.

## F. Pemeriksaan sebelum push

| Cek | Hasil yang perlu diverifikasi |
| --- | --- |
| Keyboard dan tombol UI | Click terpicu, kelima file digunakan secara acak, dan tidak ada pengulangan berturut-turut pada input campuran. |
| Input salah | Glass sound tanpa mengubah prefix atau state game. |
| saji | Sukses dine-in dan online memicu mining sound sekali. Hidangan salah, target salah, terlambat, dan duplikasi tidak memicu sound sukses. |
| Stage | Main menu dan Serving memutar BGM. Planning diam setelah fade 5 detik. |
| Loop | Pada 191.392 detik playback kembali ke awal. Dengarkan batas loop. |
| Scene dan fade | Pergantian scene tidak memotong fade. Uji batas loop selama fade, transisi cepat, dan jumlah pemutar yang terdengar. |
| Slider | Volume berubah langsung, nol mute, dan perubahan saat fade serta stage berikutnya tetap memakai pilihan terbaru. |
| Panel panduan | Kontrol sesuai game, dapat ditutup/dibuka lagi, dan tidak mengembalikan urutan tutorial bertahap. |
| UI v002 | Gunakan pemetaan aset, target visual, dan checklist pada dokumen 03–05. |

Pada push berikutnya perbarui docs/PROJECT_STATUS.md dengan integrasi yang masuk, hasil tes dan pengecekan audio aktual, serta keputusan yang masih sementara. Penyusunan paket ini belum merupakan klaim bahwa integrasi atau tes audio sudah dijalankan.

## G. Counter panjang: satu item per tile

Sumber C-01 dan klarifikasi C-02. Counter panjang yang dimaksud terdiri dari tiga tile dan harus dapat menampung tiga item sekaligus: satu item pada setiap tile, dengan tiga slot independen per counter. Baca [07_LONG_COUNTER_ITEM_SLOTS.md](07_LONG_COUNTER_ITEM_SLOTS.md) untuk screenshot, perilaku yang diminta, interpretasi teknis, dan pemeriksaannya. Ini merupakan tambahan gameplay pada paket kumulatif; seluruh permintaan UI/audio/tutorial sebelumnya tetap berlaku.

## H. Hasil harian, menang/kalah, dan font Grape Soda

Sumber R-01. Koordinator meminta rancangan menu hasil harian serta menang/kalah, dan menetapkan font Grape Soda. Font asli sudah diunduh dan disertakan pada `provided_assets/fonts/GrapeSoda.ttf`. [08_RESULTS_WIN_LOSE_DESIGN.md](08_RESULTS_WIN_LOSE_DESIGN.md) dan [preview HTML](previews/RESULT_MENUS_PREVIEW.html) memuat usulan desain konkret, binding data, navigasi, dan pemeriksaannya; detail desain ini masih merupakan proposal.

Klarifikasi F-02: atribusi sudah ditempatkan koordinator pada halaman itch.io. Jangan menambahkan atribusi atau layar kredit wajib di game. Referensi sumber/credit font disimpan dalam paket untuk developer.

## I. Menu final dan prioritas sumber

Terapkan [brief 13 resep](<sources/KETIK_SAJI_13_RECIPE_PROGRESSION_AND_DEMAND_HANDOFF(1).md>) dan [pemetaan artwork](11_DISH_ASSET_MAP.md). Ikuti [10_FINAL_OVERRIDES.md](10_FINAL_OVERRIDES.md) untuk konflik dengan spesifikasi lama: deskripsi Resep kini wajib, selling peralatan tetap di luar scope, dan instruksi audio terpisah tetap aktif. Semua 13 icon dish dan plate biasa disertakan. Baca 00_AGENT_EXECUTION_ORDER.md terlebih dahulu untuk urutan implementasi final.
