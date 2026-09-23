import 'karya.dart';

/// Model data lot lelang + data contoh -- dipakai sementara untuk UI/demo
/// sebelum backend punya endpoint lelang nyata.
///
/// TODO(backend): ganti [sampleLelang] dengan fetch nyata begitu endpoint
/// `GET /api/lelang` tersedia.
enum StatusLelang { berlangsung, segeraDimulai, selesai }

class LelangLot {
  const LelangLot({
    required this.karya,
    required this.lotNumber,
    required this.galleryName,
    required this.status,
    required this.currentBidIdr,
    required this.bidCount,
    this.minutesRemaining,
  });

  final Karya karya;
  final int lotNumber;
  final String galleryName;
  final StatusLelang status;
  final int currentBidIdr;
  final int bidCount;

  /// null kalau status == selesai / segeraDimulai.
  final int? minutesRemaining;

  String get currentBidFormatted => _formatRupiah(currentBidIdr);

  static String _formatRupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  String get countdownFormatted {
    final m = minutesRemaining ?? 0;
    final h = m ~/ 60;
    final mm = m % 60;
    return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:00';
  }
}

// Bukan `const` -- entry-entry di bawah memakai index ke [sampleKarya]
// (const list lain) yang secara teknis bukan ekspresi const di Dart.
final sampleLelang = <LelangLot>[
  LelangLot(
    karya: sampleKarya[3], // Rembrandt (Baroque)
    lotNumber: 14,
    galleryName: 'Sanggar Rupa Nusantara',
    status: StatusLelang.berlangsung,
    currentBidIdr: 48000000,
    bidCount: 18,
    minutesRemaining: 133,
  ),
  LelangLot(
    karya: sampleKarya[4], // Picasso (Cubism)
    lotNumber: 8,
    galleryName: 'Studio Bentang Alam',
    status: StatusLelang.berlangsung,
    currentBidIdr: 65000000,
    bidCount: 24,
    minutesRemaining: 44,
  ),
  LelangLot(
    karya: sampleKarya[2], // Aivazovsky (Romanticism)
    lotNumber: 21,
    galleryName: 'Bimo Setiawan',
    status: StatusLelang.berlangsung,
    currentBidIdr: 38000000,
    bidCount: 11,
    minutesRemaining: 319,
  ),
  LelangLot(
    karya: sampleKarya[6], // Konchalovsky (Expressionism)
    lotNumber: 32,
    galleryName: 'Sanggar Rupa Nusantara',
    status: StatusLelang.segeraDimulai,
    currentBidIdr: 18500000,
    bidCount: 0,
  ),
];
