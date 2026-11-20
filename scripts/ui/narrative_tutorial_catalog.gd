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


static func get_tutorial_chapters() -> Array[Dictionary]:
	return [
		{
			"id": &"ch1_intro",
			"number": 1,
			"title": "Kenalan dengan Warung",
			"step_ids": [&"ch1_objective", &"ch1_move"],
		},
		{
			"id": &"ch2_planning",
			"number": 2,
			"title": "Persiapan Warung",
			"step_ids": [&"ch2_edit_menu", &"ch2_buy_ingredients", &"ch2_open_service"],
		},
		{
			"id": &"ch3_cooking",
			"number": 3,
			"title": "Mulai Memasak",
			"step_ids": [&"ch3_take_rice", &"ch3_wash_rice", &"ch3_cook_rice", &"ch3_cook_egg"],
		},
		{
			"id": &"ch4_dine_in",
			"number": 4,
			"title": "Layani Pelanggan",
			"step_ids": [&"ch4_assemble", &"ch4_serve_dinein", &"ch4_clean_and_wash"],
		},
		{
			"id": &"ch5_online",
			"number": 5,
			"title": "Pesanan Online",
			"step_ids": [&"ch5_accept_online", &"ch5_serve_online"],
		},
		{
			"id": &"ch6_employees",
			"number": 6,
			"title": "Kelola Pegawai",
			"step_ids": [&"ch6_employee_overview"],
		},
		{
			"id": &"ch7_finances",
			"number": 7,
			"title": "Atur Keuangan",
			"step_ids": [&"ch7_review_results"],
		},
		{
			"id": &"ch8_challenge",
			"number": 8,
			"title": "Selesaikan Tantangan",
			"step_ids": [&"ch8_ready"],
		},
	]


static func get_tutorial_steps() -> Array[Dictionary]:
	return [
		{
			"id": &"ch1_objective",
			"chapter": 1,
			"chapter_title": "Kenalan dengan Warung",
			"title": "Bab 1/8 · Selamat Datang!",
			"body": (
				"Kelola warungmu selama 7 hari & capai kas Rp 700.000 di Hari ke-7! "
				+ "Santai saja, semua langkahnya kita pelajari satu per satu."
			),
			"allow_next": true,
			"next_label": "Lanjut",
		},
		{
			"id": &"ch1_move",
			"chapter": 1,
			"chapter_title": "Kenalan dengan Warung",
			"title": "Bab 1/8 · Pindah & Arahkan",
			"body": (
				"Klik petak lantai kosong untuk berpindah. Saat berjualan nanti, klik objek "
				+ "akan langsung membawamu ke sebelah objek tersebut."
			),
			"allow_next": false,
		},
		{
			"id": &"ch2_edit_menu",
			"chapter": 2,
			"chapter_title": "Persiapan Warung",
			"title": "Bab 2/8 · Atur Menu Warung",
			"body": (
				"Yuk, siapkan warungmu! Klik 'Edit menu' untuk cek hidangan aktif & resepnya, "
				+ "lalu klik 'Simpan'."
			),
			"allow_next": false,
		},
		{
			"id": &"ch2_buy_ingredients",
			"chapter": 2,
			"chapter_title": "Persiapan Warung",
			"title": "Bab 2/8 · Beli Bahan Pokok",
			"body": (
				"Klik Kotak Bahan, lalu ketik 'beli' (tanpa Enter!). Beli minimal 1 Beras "
				+ "& 1 Telur agar siap memasak."
			),
			"allow_next": false,
		},
		{
			"id": &"ch2_open_service",
			"chapter": 2,
			"chapter_title": "Persiapan Warung",
			"title": "Bab 2/8 · Buka Warung",
			"body": (
				"Bahan siap! Jika objek terpilih, klik lantai/ESC dulu, lalu ketik 'buka' "
				+ "untuk mulai menerima pelanggan."
			),
			"allow_next": false,
		},
		{
			"id": &"ch3_take_rice",
			"chapter": 3,
			"chapter_title": "Mulai Memasak",
			"title": "Bab 3/8 · Ambil Beras",
			"body": (
				"Klik Kotak Bahan di dapur lalu ketik 'beras' (atau klik kata perintahnya) "
				+ "untuk mengambil beras mentah."
			),
			"allow_next": false,
		},
		{
			"id": &"ch3_wash_rice",
			"chapter": 3,
			"chapter_title": "Mulai Memasak",
			"title": "Bab 3/8 · Cuci Beras",
			"body": (
				"Beras mentah harus dicuci dulu! Klik Wastafel, lalu ketik 'cuci'."
			),
			"allow_next": false,
		},
		{
			"id": &"ch3_cook_rice",
			"chapter": 3,
			"chapter_title": "Mulai Memasak",
			"title": "Bab 3/8 · Masak Nasi",
			"body": (
				"Klik Penanak Nasi lalu ketik 'masak'. Sekali masak menghasilkan 5 porsi "
				+ "nasi matang!"
			),
			"allow_next": false,
		},
		{
			"id": &"ch3_cook_egg",
			"chapter": 3,
			"chapter_title": "Mulai Memasak",
			"title": "Bab 3/8 · Goreng Telur",
			"body": (
				"Ambil telur di Kotak Bahan ('telur'), lalu klik Kompor dan ketik 'goreng'."
			),
			"allow_next": false,
		},
		{
			"id": &"ch4_assemble",
			"chapter": 4,
			"chapter_title": "Layani Pelanggan",
			"title": "Bab 4/8 · Rakit Nasi Telor",
			"body": (
				"Ambil piring di Rak Piring, ambil nasi di Penanak Nasi ('nasi'), lalu "
				+ "gabung dengan telur di tangan/Meja Kerja!"
			),
			"allow_next": false,
		},
		{
			"id": &"ch4_serve_dinein",
			"chapter": 4,
			"chapter_title": "Layani Pelanggan",
			"title": "Bab 4/8 · Sajikan ke Meja",
			"body": (
				"Pesanan sudah siap! Klik meja pelanggan yang menunggu di area makan, "
				+ "lalu ketik 'saji'."
			),
			"allow_next": false,
		},
		{
			"id": &"ch4_clean_and_wash",
			"chapter": 4,
			"chapter_title": "Layani Pelanggan",
			"title": "Bab 4/8 · Bereskan & Cuci",
			"body": (
				"Setelah tamu selesai makan (~20 dtk), klik meja kotor → 'bersihkan', "
				+ "lalu kosongkan tangan & 'cuci' piring di Wastafel."
			),
			"allow_next": false,
		},
		{
			"id": &"ch7_review_results",
			"chapter": 7,
			"chapter_title": "Atur Keuangan",
			"title": "Bab 7/8 · Atur Keuangan",
			"body": (
				"Warung yang ramai belum tentu untung besar. Setiap bahan, alat, dan pegawai "
				+ "butuh uang! Cek laporan lalu klik 'Lanjut'."
			),
			"allow_next": true,
			"next_label": "Lanjut",
		},
		{
			"id": &"ch6_employee_overview",
			"chapter": 6,
			"chapter_title": "Kelola Pegawai",
			"title": "Bab 6/8 · Kenali Pegawai",
			"body": (
				"Buka tombol 'Pegawai'! Pegawai membantu tugas tertentu (bukan merakit "
				+ "piring), namun terlalu banyak pegawai (>2) justru bikin sesak & boros gaji."
			),
			"allow_next": false,
			"next_label": "Mengerti",
		},
		{
			"id": &"ch5_accept_online",
			"chapter": 5,
			"chapter_title": "Pesanan Online",
			"title": "Bab 5/8 · Terima Order Online",
			"body": (
				"Tawaran online muncul berkala di Meja Online! Klik Meja Online saat "
				+ "aktif lalu ketik 'terima' (batas 60 dtk)."
			),
			"allow_next": false,
			"next_label": "Lewati Bab",
		},
		{
			"id": &"ch5_serve_online",
			"chapter": 5,
			"chapter_title": "Pesanan Online",
			"title": "Bab 5/8 · Serahkan ke Pengantar",
			"body": (
				"Masak pesanannya, lalu klik pengantar di spot pickup kanan (bukan di "
				+ "antrean jalan) & ketik 'saji'."
			),
			"allow_next": false,
			"next_label": "Lewati Bab",
		},
		{
			"id": &"ch8_ready",
			"chapter": 8,
			"chapter_title": "Selesaikan Tantangan",
			"title": "Bab 8/8 · Siap Berjualan!",
			"body": (
				"Kamu siap menjalankan warung! Tambah alat lewat 'Beli alat' (+Alat/+Meja) "
				+ "seperlunya, jaga ritme, & capai Rp 700k di Hari ke-7."
			),
			"allow_next": true,
			"next_label": "Selesai",
		},
	]


static func get_feature_discovery_tip(tip_id: StringName) -> Dictionary:
	match tip_id:
		&"online_offer":
			return {
				"id": &"online_offer",
				"title": "Tip · Order Online",
				"body": (
					"Ada tawaran online di Meja Online! Klik Meja Online → 'terima' jika "
					+ "sanggup mengejar batas waktu 60 detik."
				),
			}
		&"first_driver_pickup":
			return {
				"id": &"first_driver_pickup",
				"title": "Tip · Spot Pickup",
				"body": (
					"Pengantar sudah di spot! Siapkan hidangan, klik pengantarnya, lalu "
					+ "ketik 'saji'. Piring langsung kembali bersih."
				),
			}
		&"driver_overflow":
			return {
				"id": &"driver_overflow",
				"title": "Tip · Antrean Jalan",
				"body": (
					"3 spot pickup penuh sehingga pengantar menunggu di jalan. Antarkan "
					+ "dulu yang ada di spot pickup!"
				),
			}
		&"potong_veggie":
			return {
				"id": &"potong_veggie",
				"title": "Tip · Potong Sayur",
				"body": (
					"Resep baru memakai sayur! Ambil sayur mentah lalu bawa ke talenan "
					+ "Meja Kerja dan ketik 'potong'."
				),
			}
		&"serving_belanja":
			return {
				"id": &"serving_belanja",
				"title": "Tip · Pengiriman 100 dtk",
				"body": (
					"Belanja bahan saat warung buka akan tiba 100 detik lagi. Jika hari "
					+ "tutup duluan, uang dikembalikan penuh!"
				),
			}
		&"recipe_unlock":
			return {
				"id": &"recipe_unlock",
				"title": "Tip · Resep Baru",
				"body": (
					"Resep baru terbuka di 'Edit menu'! Tapi ingat: terlalu banyak menu "
					+ "aktif membuat stok & piring lebih cepat kewalahan."
				),
			}
		&"demand_and_debt":
			return {
				"id": &"demand_and_debt",
				"title": "Tip · Pelanggan Berkurang",
				"body": (
					"Ada pesanan terlewat kemarin sehingga tamu hari ini berkurang. "
					+ "Hari sempurna tanpa gagal akan memulihkannya!"
				),
			}
		&"fixture_shop_tip":
			return {
				"id": &"fixture_shop_tip",
				"title": "Tip · Tambah Alat & Ruang",
				"body": (
					"Pertimbangkan ruang dapur & biaya listrik harian! Kulkas & Penanak "
					+ "Nasi menambah listrik tiap malam."
				),
			}
		&"employee_hired":
			return {
				"id": &"employee_hired",
				"title": "Tip · Komitmen Pegawai",
				"body": (
					"Pegawai membantumu sesuai perannya, tetapi Gaji Harian dipotong tiap "
					+ "malam & lebih dari 2 pegawai membuat dapur semakin sesak!"
				),
			}
		_:
			return {}


static func get_cara_main_sections() -> Array[Dictionary]:
	return [
		{
			"heading": "KLIK & KETIK",
			"bullets": [
				"Klik lantai untuk berpindah, klik objek untuk berinteraksi.",
				"Ketik perintah yang muncul. Tidak perlu tekan Enter!",
			],
		},
		{
			"heading": "SEBELUM BUKA",
			"bullets": [
				"Pilih menu, beli bahan, dan tambah peralatan.",
				"Ketik [color=#9e2508]buka[/color] untuk mulai berjualan!",
			],
		},
		{
			"heading": "SAAT BERJUALAN",
			"bullets": [
				"Siapkan bahan, masak, lalu sajikan pesanan sebelum pelanggan kehabisan kesabaran!",
				"Ketik [color=#9e2508]saji[/color] untuk mengantar makanan.",
				"Ketik [color=#9e2508]bersihkan[/color] untuk membereskan meja, lalu [color=#9e2508]cuci[/color] untuk mencuci piring.",
				"Pesanan online bisa diterima dengan mengetik [color=#9e2508]terima[/color]. Awas, ada batas waktunya!",
			],
		},
		{
			"heading": "TARGETMU",
			"plain_body": true,
			"bullets": [
				"Kumpulkan cukup uang sebelum hari ke-7 berakhir!",
			],
		},
	]


static func get_cara_main_bbcode() -> String:
	var parts: PackedStringArray = []
	for sec: Dictionary in get_cara_main_sections():
		parts.append("[color=#6e220b]%s[/color]" % str(sec.get("heading", "")))
		for b: String in sec.get("bullets", []):
			parts.append("- " + b)
		parts.append("")
	parts.append("[color=#5a1e09]Selamat berjualan, semoga nggak ikut matang![/color]")
	return "\n".join(parts)


static func get_reference_summary_text() -> String:
	var lines: PackedStringArray = ["CARA MAIN", ""]
	var tag_strip := RegEx.new()
	tag_strip.compile("\\[/?color[^\\]]*\\]")
	for sec: Dictionary in get_cara_main_sections():
		lines.append(str(sec.get("heading", "")))
		for b: String in sec.get("bullets", []):
			lines.append("- " + tag_strip.sub(b, "", true))
		lines.append("")
	lines.append("Selamat berjualan, semoga nggak ikut matang!")
	return "\n".join(lines)
