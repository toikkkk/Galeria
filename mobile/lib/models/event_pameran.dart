/// Model data event/pameran + data contoh -- dipakai sementara untuk UI/demo
/// sebelum backend punya endpoint event nyata.
///
/// TODO(backend): ganti [sampleEvents] dengan fetch nyata begitu endpoint
/// event tersedia (lihat rencana n8n/backend event & tiket).
class EventPameran {
  const EventPameran({
    required this.assetPath,
    required this.title,
    required this.organizerName,
    required this.location,
    required this.dateLabel,
    required this.priceLabel,
    this.isFeatured = false,
  });

  final String assetPath;
  final String title;
  final String organizerName;
  final String location;
  final String dateLabel;
  final String priceLabel;
  final bool isFeatured;
}

const sampleEvents = <EventPameran>[
  EventPameran(
    assetPath: 'assets/images/catalog/baroque_01.jpg',
    title: 'Pameran Tunggal: Jejak Cahaya Nusantara',
    organizerName: 'Sanggar Rupa Nusantara · Kurator Terakreditasi',
    location: 'Galeri Nasional Indonesia, Jakarta Pusat',
    dateLabel: '24 Okt 2026 · 14:00 - 18:00 WIB',
    priceLabel: 'Mulai Rp 50.000',
    isFeatured: true,
  ),
  EventPameran(
    assetPath: 'assets/images/catalog/romanticism_01.jpg',
    title: 'Gema Realisme Nusantara 2026',
    organizerName: 'Perupa Realis Nusantara',
    location: 'Benoa Art Space, Bali',
    dateLabel: '1 - 10 Nov 2026',
    priceLabel: 'Gratis Registrasi',
  ),
  EventPameran(
    assetPath: 'assets/images/catalog/cubism_01.jpg',
    title: 'Malam Kurasi: Simfoni Emas & Lapis Lazuli',
    organizerName: 'Galeria Salon Utama, Jakarta Selatan',
    location: 'Hotel The Dharmawangsa, Jakarta',
    dateLabel: '15 Nov 2026 · 18:30 WIB',
    priceLabel: 'Rp 250.000',
  ),
];
