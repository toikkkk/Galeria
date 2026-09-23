/// Model notifikasi + data contoh -- dipakai sementara untuk UI/demo
/// sebelum ada sistem notifikasi nyata (push notification/backend event).
///
/// TODO(backend): ganti [sampleNotifikasi] dengan fetch nyata begitu ada
/// endpoint notifikasi (mis. lewat FCM/websocket) -- termasuk status
/// dibaca/belum yang sinkron ke server, bukan cuma state lokal layar.
enum NotifikasiKategori { pesanan, lelang, event, rekomendasi, sertifikat }

class NotifikasiItem {
  const NotifikasiItem({
    required this.kategori,
    required this.title,
    required this.subtitle,
    required this.waktuLabel,
    this.dibaca = false,
    this.mendesak = false,
  });

  final NotifikasiKategori kategori;
  final String title;
  final String subtitle;
  final String waktuLabel;
  final bool dibaca;

  /// Contoh: batas waktu pembayaran hampir habis -- ditandai warna beda.
  final bool mendesak;
}

final sampleNotifikasi = <NotifikasiItem>[
  NotifikasiItem(
    kategori: NotifikasiKategori.pesanan,
    title: 'Batas Waktu Pembayaran Hampir Habis',
    subtitle:
        'Selesaikan pembayaran Lot #104 sebelum 23:47:10 agar pesanan tidak dibatalkan otomatis.',
    waktuLabel: '5 menit lalu',
    mendesak: true,
  ),
  NotifikasiItem(
    kategori: NotifikasiKategori.lelang,
    title: 'Tawaran Anda Telah Terlampaui',
    subtitle:
        'Lot #08 "Komposisi Emas & Lapis Lazuli" kini di Rp 68.000.000. Ajukan tawaran baru?',
    waktuLabel: '2 jam lalu',
  ),
  NotifikasiItem(
    kategori: NotifikasiKategori.pesanan,
    title: 'Pesanan Anda Sedang Dikirim',
    subtitle:
        'Karya Anda dalam perjalanan via JNE Art Cargo, estimasi tiba besok.',
    waktuLabel: '3 jam lalu',
  ),
  NotifikasiItem(
    kategori: NotifikasiKategori.lelang,
    title: 'Ajakan Ikut Lelang: Karya Baru dari Sanggar Rupa Nusantara',
    subtitle: 'Lot eksklusif segera dibuka -- jadilah penawar pertama.',
    waktuLabel: 'Kemarin',
    dibaca: true,
  ),
  NotifikasiItem(
    kategori: NotifikasiKategori.event,
    title: 'Event Dipromosikan: Grand Vernissage 2026',
    subtitle:
        'Pameran eksklusif Masterpiece Nusantara & Eropa, 34 karya terpilih.',
    waktuLabel: 'Kemarin',
    dibaca: true,
  ),
  NotifikasiItem(
    kategori: NotifikasiKategori.event,
    title: 'Pengingat Kunjungan Pameran',
    subtitle:
        'Sesi 2 (Kurator Talk) besok pukul 14:00 WIB di Galeri Nasional Indonesia.',
    waktuLabel: '2 hari lalu',
    dibaca: true,
  ),
  NotifikasiItem(
    kategori: NotifikasiKategori.rekomendasi,
    title: 'Karya Baru Sesuai Preferensi Anda',
    subtitle:
        'Beberapa karya beraliran Barok & Kubisme baru saja diunggah kurator terakreditasi.',
    waktuLabel: '3 hari lalu',
    dibaca: true,
  ),
  NotifikasiItem(
    kategori: NotifikasiKategori.sertifikat,
    title: 'Sertifikat Digital Keaslian Diterbitkan',
    subtitle:
        'Bukti registrasi kepemilikan digital untuk koleksi terbaru Anda telah terbit.',
    waktuLabel: '4 hari lalu',
    dibaca: true,
  ),
];
