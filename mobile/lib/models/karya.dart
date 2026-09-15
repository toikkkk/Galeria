/// Model data karya seni + data contoh (sample) dari katalog WikiArt
/// (ml-visual-search/data/processed/) -- dipakai sementara untuk UI/demo
/// sebelum backend & endpoint /api/katalog tersedia.
///
/// TODO(backend): ganti [sampleKarya] dengan fetch nyata ke
/// `GET /api/katalog` begitu backend/services/visual_search_service.dart
/// selesai diimplementasi.
class Karya {
  const Karya({
    required this.assetPath,
    required this.title,
    required this.artistName,
    required this.styleName,
    required this.priceIdr,
  });

  final String assetPath;
  final String title;
  final String artistName;
  final String styleName;

  /// Harga contoh (bebas/placeholder) -- BUKAN harga nyata, belum ada data
  /// transaksi/harga aktual di platform.
  final int priceIdr;

  String get priceFormatted {
    final s = priceIdr.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }
}

/// Data contoh diambil dari 8 style berbeda di katalog WikiArt kita
/// (data/processed/, sudah di-SquarePad). Artist asli (bukan fiksi), judul
/// & harga adalah placeholder (metadata WikiArt tidak menyediakan judul).
const sampleKarya = <Karya>[
  Karya(
    assetPath: 'assets/images/catalog/impressionism_01.jpg',
    title: 'Tanpa Judul (Impresionisme)',
    artistName: 'Pierre-Auguste Renoir',
    styleName: 'Impressionism',
    priceIdr: 185000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/post_impressionism_01.jpg',
    title: 'Tanpa Judul (Pasca-Impresionisme)',
    artistName: 'Vincent van Gogh',
    styleName: 'Post Impressionism',
    priceIdr: 420000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/romanticism_01.jpg',
    title: 'Tanpa Judul (Romantisisme)',
    artistName: 'Ivan Aivazovsky',
    styleName: 'Romanticism',
    priceIdr: 95000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/baroque_01.jpg',
    title: 'Tanpa Judul (Barok)',
    artistName: 'Rembrandt',
    styleName: 'Baroque',
    priceIdr: 610000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/cubism_01.jpg',
    title: 'Tanpa Judul (Kubisme)',
    artistName: 'Pablo Picasso',
    styleName: 'Cubism',
    priceIdr: 980000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/art_nouveau_01.jpg',
    title: 'Tanpa Judul (Art Nouveau)',
    artistName: 'Boris Kustodiev',
    styleName: 'Art Nouveau',
    priceIdr: 72000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/expressionism_01.jpg',
    title: 'Tanpa Judul (Ekspresionisme)',
    artistName: 'Pyotr Konchalovsky',
    styleName: 'Expressionism',
    priceIdr: 138000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/symbolism_01.jpg',
    title: 'Tanpa Judul (Simbolisme)',
    artistName: 'Martiros Saryan',
    styleName: 'Symbolism',
    priceIdr: 64000000,
  ),
];
