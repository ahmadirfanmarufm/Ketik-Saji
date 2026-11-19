class_name NarrativeTutorialCatalog
extends RefCounted
## Static copy and metadata catalog for Ketik Saji opening story, daily
## narratives (Days 1-7), Day 1 progressive tutorial, feature tips, and
## quick reference guide. Holds no mutable gameplay or session state.

const DAY_1_OPENING_ID: StringName = &"day_1_opening"
const DAY_7_EPILOGUE_ID: StringName = &"day_7_epilogue"


static func get_opening_story() -> Dictionary:
	return {
		"id": DAY_1_OPENING_ID,
		"day_index": 1,
		"title": "Hari 1: Warisan Terakhir",
		"lines": [
			{
				"speaker": "Narasi",
				"portrait_path": "",
				"text": "Kamu mewarisi warung kecil dari orang tuamu: modal awal Rp 100k, resep Nasi Telor, kotak bahan, penanak nasi, kompor, wastafel, dan 2 meja.",
			},
			{
				"speaker": "Orang Tua",
				"portrait_path": "",
				"text": "Kelola warung ini baik-baik. Tidak harus besar, yang penting cukup dan berjalan dengan baik.",
			},
			{
				"speaker": "Kamu",
				"portrait_path": "res://assets/art/characters/player.png",
				"text": "Warung ini masih terlalu kecil. Kalau aku tambah banyak menu, banyak alat, dan banyak pelanggan, pasti aku bakal jadi jauh lebih sukses!",
			},
		],
	}


static func get_day_intro_story(day_index: int) -> Dictionary:
	if day_index <= 1:
		return get_opening_story()
	match day_index:
		2:
			return {
				"id": &"day_2_intro",
				"day_index": 2,
				"title": "Hari 2: Ramai Mulai Berdatangan",
				"lines": [
					{
						"speaker": "Narasi",
						"portrait_path": "",
						"text": "Pelanggan mulai berdatangan dan resep baru perlahan terbuka. Semangatmu membara untuk memperluas menu dan mengejar omzet lebih besar.",
					},
					{
						"speaker": "Kamu",
						"portrait_path": "res://assets/art/characters/player.png",
						"text": "Bagus, makin ramai! Kalau menu makin lengkap dan stok selalu penuh, pasti cuannya langsung melonjak.",
					},
				],
			}
		3:
			return {
				"id": &"day_3_intro",
				"day_index": 3,
				"title": "Hari 3: Warung Mulai Sibuk",
				"lines": [
					{
						"speaker": "Narasi",
						"portrait_path": "",
						"text": "Warung mulai sibuk dan sifat pelanggan makin beragam—bahkan ada yang duduk lama katanya \"lagi bikin skripsi\". Tanpa prioritas, meja dan dapur cepat kewalahan.",
					},
					{
						"speaker": "Kamu",
						"portrait_path": "res://assets/art/characters/player.png",
						"text": "Aneh-aneh saja pelanggannya... Aku harus pintar membagi fokus supaya dapur tidak macet.",
					},
				],
			}
		4:
			return {
				"id": &"day_4_intro",
				"day_index": 4,
				"title": "Hari 4: Ekspansi atau Fokus?",
				"lines": [
					{
						"speaker": "Narasi",
						"portrait_path": "",
						"text": "Semakin banyak menu aktif dan kulkas yang dibeli, semakin rumit stok bahan serta biaya listrik harianmu. Pesanan kecil yang tuntas tepat waktu sering jauh lebih menguntungkan.",
					},
				],
			}
		5:
			return {
				"id": &"day_5_intro",
				"day_index": 5,
				"title": "Hari 5: Harga dari Keramaian",
				"lines": [
					{
						"speaker": "Narasi",
						"portrait_path": "",
						"text": "Order online dan pelanggan langsung terus silih berganti. Mengaktifkan terlalu banyak menu justru membuat dapur kewalahan dan piring kotor menumpuk.",
					},
				],
			}
		6:
			return {
				"id": &"day_6_intro",
				"day_index": 6,
				"title": "Hari 6: Menjaga Ritme",
				"lines": [
					{
						"speaker": "Narasi",
						"portrait_path": "",
						"text": "Menjelang hari terakhir, ritme kerja dan menu yang ramping jauh lebih menentukan daripada ukuran warung. Layani apa yang benar-benar sanggup kamu selesaikan.",
					},
				],
			}
		7:
			return {
				"id": &"day_7_intro",
				"day_index": 7,
				"title": "Hari 7: Penentuan Warung",
				"lines": [
					{
						"speaker": "Narasi",
						"portrait_path": "",
						"text": "Hari ketujuh tiba! Buktikan bagaimana caramu memimpin warung warisan ini sampai akhir minggu.",
					},
				],
			}
		_:
			return {}


static func get_day_closing_caption(day_index: int, goal_outcome: int) -> String:
	if day_index >= 7:
		if goal_outcome == SharedTypes.DayOutcome.WON:
			return "Warisan tetap terjaga! Sedikit menu yang dikelola rapi membawa hasil terbaik."
		return "Minggu ini menjadi pelajaran berharga tentang batas fokus, stok, dan biaya."
	match day_index:
		1:
			return "Hari pertama selesai. Langkah awal menentukan ritme dapur besok."
		2:
			return "Makin banyak menu terasa menarik, tetapi bahan dan waktunya ikut menuntut."
		3:
			return "Di tengah meja yang penuh dan pelanggan skripsi, fokus adalah kuncinya."
		4:
			return "Menu yang terlalu lebar membebani dapur; efisiensi menjaga untung tetap bersih."
		5:
			return "Kecepatan merakit dan cuci piring lebih berharga daripada daftar menu yang panjang."
		6:
			return "Satu hari lagi menuju penentuan akhir warung warisanmu."
		_:
			return ""


static func get_day_7_epilogue(goal_outcome: int) -> Dictionary:
	if goal_outcome == SharedTypes.DayOutcome.WON:
		return {
			"id": DAY_7_EPILOGUE_ID,
			"day_index": 7,
			"title": "Hari 7 Selesai: Warung Bertahan",
			"lines": [
				{
					"speaker": "Kamu",
					"portrait_path": "res://assets/art/characters/player.png",
					"text": "Akhirnya tembus target! Ternyata kuncinya bukan memaksa semua menu dan alat, melainkan tahu batas yang bisa kulayani dengan rapi.",
				},
				{
					"speaker": "Narasi",
					"portrait_path": "",
					"text": "Memiliki lebih banyak belum tentu membuat kita lebih sukses. Mengelola apa yang kita punya dengan bijak jauh lebih penting.",
				},
			],
		}
	return {
		"id": DAY_7_EPILOGUE_ID,
		"day_index": 7,
		"title": "Hari 7 Selesai: Pelajaran Warung Kebablasan",
		"lines": [
			{
				"speaker": "Kamu",
				"portrait_path": "res://assets/art/characters/player.png",
				"text": "Warung terasa berat saat aku terlalu banyak mengejar ekspansi tanpa menjaga ritme dapur...",
			},
			{
				"speaker": "Narasi",
				"portrait_path": "",
				"text": "Memiliki lebih banyak belum tentu membuat kita lebih sukses. Mengelola apa yang kita punya dengan bijak jauh lebih penting.",
			},
		],
	}


static func get_tutorial_steps() -> Array[Dictionary]:
	return [
		{
			"id": &"step_01_objective",
			"title": "1/9 — Pahami Tujuan Warung",
			"body": "Kamu mewarisi warung kecil (Rp 100k, menu Nasi Telor). Kelola stok, waktu, dan fokus untuk bertahan hingga Hari 7. Klik Lanjut untuk menyiapkan bahan!",
			"allow_next": true,
			"next_label": "Lanjut",
		},
		{
			"id": &"step_02_prepare_ingredients",
			"title": "2/9 — Siapkan Bahan",
			"body": "Pertama, kita butuh bahan untuk memasak. Klik Kotak Bahan untuk belanja (`beli` beras & telur), buka warung (`buka`), lalu ketik 'beras' untuk mengambil beras (nanti ambil 'telur' dengan cara yang sama).",
			"allow_next": false,
			"next_label": "Lanjut",
		},
		{
			"id": &"step_03_wash_rice",
			"title": "3/9 — Cuci Beras",
			"body": "Beras harus dicuci terlebih dahulu. Klik Wastafel, lalu ketik 'cuci'.",
			"allow_next": false,
			"next_label": "Lanjut",
		},
		{
			"id": &"step_04_cook_rice",
			"title": "4/9 — Masak Nasi",
			"body": "Masukkan beras yang sudah dicuci ke Penanak Nasi. Klik Penanak Nasi lalu ketik 'masak' (1x masak = 5 porsi nasi!).",
			"allow_next": false,
			"next_label": "Lanjut",
		},
		{
			"id": &"step_05_cook_egg",
			"title": "5/9 — Goreng Telur",
			"body": "Satu kali memasak menghasilkan 5 porsi nasi! Sekarang ambil 'telur' di Kotak Bahan, lalu bawa ke Kompor dan ketik 'goreng' hingga matang.",
			"allow_next": false,
			"next_label": "Lanjut",
		},
		{
			"id": &"step_06_assemble_dish",
			"title": "6/9 — Rakit Nasi Telor",
			"body": "Gabungkan nasi matang dan telur matang di atas piring bersih (klik Rak Piring / Meja Kerja dan ambil 'nasi' di Penanak Nasi—urutan boleh dibalik!) sampai menjadi Nasi Telor.",
			"allow_next": false,
			"next_label": "Lanjut",
		},
		{
			"id": &"step_07_serve_customer",
			"title": "7/9 — Sajikan Pelanggan",
			"body": "Pesanan sudah siap! Pilih meja pelanggan yang memesan, lalu ketik 'saji' untuk menyajikan makanan.",
			"allow_next": false,
			"next_label": "Lanjut",
		},
		{
			"id": &"step_08_clean_and_wash",
			"title": "8/9 — Bersihkan Meja & Cuci Piring",
			"body": "Setelah pelanggan selesai makan, klik meja kotor -> ketik 'bersihkan'. Lalu dengan tangan kosong, klik Wastafel -> ketik 'cuci' untuk mencuci piring kotor.",
			"allow_next": false,
			"next_label": "Lanjut",
		},
		{
			"id": &"step_09_finish_day",
			"title": "9/9 — Akhiri Hari Pertama",
			"body": "Lanjutkan pelayanan hingga tutup hari, lalu tinjau Pendapatan, Belanja, Listrik, Penalti Permintaan, dan Kas Akhir. Semakin banyak menu belum tentu semakin banyak keuntungan. Kelola bahan, waktu, dan pelayanan dengan baik.",
			"allow_next": true,
			"next_label": "Selesai",
		},
	]


static func get_feature_discovery_tip(tip_id: StringName) -> Dictionary:
	match tip_id:
		&"online_offer":
			return {
				"id": &"online_offer",
				"title": "Tip: Tawaran Online",
				"body": "Tawaran ojol muncul berkala di Stasiun Online. Klik Stasiun Online lalu ketik 'terima' untuk mengambilnya (berhenti saat antrean datang <= 2 atau batas order penuh).",
			}
		&"first_driver_pickup":
			return {
				"id": &"first_driver_pickup",
				"title": "Tip: Antar ke Driver",
				"body": "Driver online sudah di spot pickup! Masak pesanannya, pegang hidangan, klik driver tersebut, lalu ketik 'saji'. Piring langsung kembali bersih!",
			}
		&"driver_overflow":
			return {
				"id": &"driver_overflow",
				"title": "Tip: Antrean Driver Penuh",
				"body": "Hanya ada 3 spot pickup aktif! Driver di luar antrean belum bisa menerima 'saji' sampai salah satu spot di dalam kosong.",
			}
		&"recipe_unlock":
			return {
				"id": &"recipe_unlock",
				"title": "Tip: Resep Baru Terbuka",
				"body": "Resep baru terbuka, tetapi baru muncul di pesanan jika kamu memilihnya di Edit Menu. Terlalu banyak menu aktif justru memperberat dapur!",
			}
		&"potong_veggie":
			return {
				"id": &"potong_veggie",
				"title": "Tip: Potong Sayur",
				"body": "Sayur segar perlu dibawa ke Talenan (Meja Kerja) lalu ketik 'potong' sebelum digoreng atau dirakit ke piring.",
			}
		&"serving_belanja":
			return {
				"id": &"serving_belanja",
				"title": "Tip: Belanja Saat Buka",
				"body": "Belanja saat jam buka dikirim ~100 detik ke tempat penyimpanan terpilih tanpa menghentikan waktu layanan; kiriman tertunda saat tutup hari di-refund penuh.",
			}
		&"fridge_and_power":
			return {
				"id": &"fridge_and_power",
				"title": "Tip: Kulkas & Listrik",
				"body": "Kulkas (+Rp 4k listrik/hari) menyimpan stok bahan mentah melewati malam, berbeda dengan Kotak Bahan yang stoknya habis saat tutup hari.",
			}
		&"demand_and_debt":
			return {
				"id": &"demand_and_debt",
				"title": "Tip: Penalti Permintaan",
				"body": "Pesanan yang gagal/kedaluwarsa meninggalkan utang reputasi yang langsung mengurangi kuota pelanggan pada hari berikutnya.",
			}
		_:
			return {}


static func get_reference_summary_text() -> String:
	return (
		"ALUR HARIAN:\n"
		+ "- PLANNING: Pilih menu (Edit Menu), cek/beli bahan & kulkas, masak nasi lebih awal, lalu klik Buka Warung.\n"
		+ "- SERVING: Masak, potong, rakit, saji pesanan meja & ojol, lalu bersihkan meja dan cuci piring kotor.\n"
		+ "- RESULTS: Tinjau omzet, biaya belanja, listrik, dan lanjut ke hari berikutnya.\n\n"
		+ "PERINTAH KETIK INTI:\n"
		+ "- Kotak Bahan / Kulkas: ketik 'beras', 'telur', 'ayam', 'tempe', 'sapi', 'sayur'\n"
		+ "- Wastafel: bawa beras -> 'cuci' | tangan kosong -> 'cuci' piring kotor (piring bersih kembali ke tangan)\n"
		+ "- Penanak Nasi: bawa beras cuci -> 'masak' (5 porsi) | ambil porsi -> 'nasi'\n"
		+ "- Kompor: bawa bahan mentah/sayur potong -> 'goreng'\n"
		+ "- Talenan & Meja Kerja: bawa sayur -> 'potong' | klik Rak Piring & Meja Kerja untuk merakit hidangan\n"
		+ "- Sajikan & Bersihkan: klik meja/driver -> 'saji'; meja kotor -> 'bersihkan'\n"
		+ "- Stasiun Online: 'terima' | Tempat Sampah: 'buang'\n\n"
		+ "PRINSIP WARUNG:\n"
		+ "Less is More, More is Worse — lebih banyak menu atau alat berarti lebih banyak kebutuhan bahan, kerja dapur, dan tagihan listrik."
	)
