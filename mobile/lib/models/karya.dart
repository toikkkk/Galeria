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
    required this.galleryName,
    this.isPromoted = false,
  });

  final String assetPath;
  final String title;
  final String artistName;
  final String styleName;

  /// Nama galeri/sanggar penjual -- dipakai jg utk pencarian di beranda
  /// ("cari lukisan, seniman, galeri").
  final String galleryName;

  /// Harga contoh (bebas/placeholder) -- BUKAN harga nyata, belum ada data
  /// transaksi/harga aktual di platform.
  final int priceIdr;

  /// Apakah seniman membayar utk mempromosikan karya ini (tampil lebih
  /// dulu di katalog) -- placeholder, belum ada mekanisme promosi nyata
  /// di backend.
  final bool isPromoted;

  String get priceFormatted {
    final s = priceIdr.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  String get _slug => title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Link demo (placeholder) -- belum ada halaman detail karya publik di
  /// web/deep link asli, backend belum expose URL per karya.
  ///
  /// TODO(backend): ganti dengan URL nyata (mis. deep link `galeria://karya/{id}`
  /// atau halaman web publik) begitu tersedia.
  String get shareUrl => 'https://galeria.app/karya/$_slug';

  /// Dipakai search bar Beranda -- cocok kalau [query] ada di judul, nama
  /// seniman, ATAU nama galeri (tidak peka besar-kecil huruf).
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    return title.toLowerCase().contains(q) ||
        artistName.toLowerCase().contains(q) ||
        galleryName.toLowerCase().contains(q);
  }
}

/// Data contoh diambil dari 8 style berbeda di katalog WikiArt kita
/// (data/processed/, sudah di-SquarePad). Artist asli (bukan fiksi), judul
/// & harga adalah placeholder (metadata WikiArt tidak menyediakan judul).
/// Nama galeri juga contoh -- beberapa dipakai berulang dari mockup asli
/// (docs/KOLEKTOR FITUR UTAMA/.../galeria_beranda_kolektor).
const sampleKarya = <Karya>[
  Karya(
    assetPath: 'assets/images/catalog/impressionism_01.jpg',
    title: 'Tanpa Judul (Impresionisme)',
    artistName: 'Pierre-Auguste Renoir',
    styleName: 'Impressionism',
    galleryName: 'Galeri Hadiprana, Jakarta',
    priceIdr: 185000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/post_impressionism_01.jpg',
    title: 'Tanpa Judul (Pasca-Impresionisme)',
    artistName: 'Vincent van Gogh',
    styleName: 'Post Impressionism',
    galleryName: "D'Gallerie Jakarta",
    priceIdr: 420000000,
    isPromoted: true,
  ),
  Karya(
    assetPath: 'assets/images/catalog/romanticism_01.jpg',
    title: 'Tanpa Judul (Romantisisme)',
    artistName: 'Ivan Aivazovsky',
    styleName: 'Romanticism',
    galleryName: 'Artemis Art Gallery',
    priceIdr: 95000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/baroque_01.jpg',
    title: 'Tanpa Judul (Barok)',
    artistName: 'Rembrandt',
    styleName: 'Baroque',
    galleryName: 'Sanggar Rupa Nusantara',
    priceIdr: 610000000,
    isPromoted: true,
  ),
  Karya(
    assetPath: 'assets/images/catalog/cubism_01.jpg',
    title: 'Tanpa Judul (Kubisme)',
    artistName: 'Pablo Picasso',
    styleName: 'Cubism',
    galleryName: 'Studio Bentang Alam',
    priceIdr: 980000000,
    isPromoted: true,
  ),
  Karya(
    assetPath: 'assets/images/catalog/art_nouveau_01.jpg',
    title: 'Tanpa Judul (Art Nouveau)',
    artistName: 'Boris Kustodiev',
    styleName: 'Art Nouveau',
    galleryName: 'Selasar Sunaryo Art Space',
    priceIdr: 72000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/expressionism_01.jpg',
    title: 'Tanpa Judul (Ekspresionisme)',
    artistName: 'Pyotr Konchalovsky',
    styleName: 'Expressionism',
    galleryName: 'Studio Bimo Setiawan',
    priceIdr: 138000000,
  ),
  Karya(
    assetPath: 'assets/images/catalog/symbolism_01.jpg',
    title: 'Tanpa Judul (Simbolisme)',
    artistName: 'Martiros Saryan',
    styleName: 'Symbolism',
    galleryName: 'Komunitas Alam Tropis',
    priceIdr: 64000000,
  ),
];
