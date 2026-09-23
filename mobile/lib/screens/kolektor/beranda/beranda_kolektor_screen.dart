import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../models/notifikasi.dart';
import '../../../services/katalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/karya_grid_card.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_beranda_kolektor/code.html
///
/// Karya diambil dari `GET /api/katalog` (backend/routers/katalog.py).
/// Mulai dengan [sampleKarya] (lokal) supaya UI langsung render tanpa
/// nunggu network, lalu diganti diam-diam begitu fetch API berhasil. Kalau
/// fetch gagal (backend mati/tidak ada koneksi), tetap pakai [sampleKarya]
/// -- app tidak boleh crash/kosong cuma gara-gara backend tidak nyala
/// (penting utk demo).
class BerandaKolektorScreen extends StatefulWidget {
  const BerandaKolektorScreen({
    super.key,
    this.onNavTap,
    this.onPindai,
    this.onLelangTap,
    this.onEventTap,
    this.onKoleksiTap,
    this.onKaryaTap,
    this.onLihatSemuaTap,
    this.onProfilTap,
    this.onNotifikasiTap,
  });

  final ValueChanged<int>? onNavTap;
  final VoidCallback? onPindai;
  final VoidCallback? onLelangTap;
  final VoidCallback? onEventTap;
  final VoidCallback? onKoleksiTap;
  final ValueChanged<Karya>? onKaryaTap;
  final VoidCallback? onLihatSemuaTap;
  final VoidCallback? onProfilTap;
  final VoidCallback? onNotifikasiTap;

  @override
  State<BerandaKolektorScreen> createState() => _BerandaKolektorScreenState();
}

class _BerandaKolektorScreenState extends State<BerandaKolektorScreen> {
  int _filterIndex = 0;
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Mulai dari [sampleKarya] (lokal), diganti begitu fetch API sukses.
  List<Karya> _karya = sampleKarya;

  static const _filters = ['Semua', 'Impresionisme', 'Barok', 'Kubisme'];

  @override
  void initState() {
    super.initState();
    _loadKatalog();
  }

  Future<void> _loadKatalog() async {
    try {
      final karya = await KatalogService().fetchKatalog();
      if (!mounted || karya.isEmpty) return;
      setState(() => _karya = karya);
    } catch (_) {
      // Diam-diam tetap pakai sampleKarya -- lihat komentar kelas di atas.
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = _query.isEmpty
        ? const <Karya>[]
        : _karya.where((k) => k.matchesQuery(_query)).toList();
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.diamond_outlined,
              size: 20,
              color: AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('GALERIA', style: AppTextStyles.headlineMd),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: widget.onNotifikasiTap,
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (sampleNotifikasi.any((n) => !n.dibaca))
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              onTap: widget.onProfilTap,
              customBorder: const CircleBorder(),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenGutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Halo, Rani', style: AppTextStyles.headlineLg),
                  Text(
                    'KOLEKTOR TERDAFTAR',
                    style: AppTextStyles.overline.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 18,
                          color: AppColors.outline,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v),
                            style: AppTextStyles.bodySm,
                            decoration: InputDecoration(
                              hintText: 'Cari lukisan, seniman, galeri',
                              hintStyle: AppTextStyles.bodySm.copyWith(
                                color: AppColors.outline,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          InkWell(
                            onTap: () => setState(() {
                              _searchCtrl.clear();
                              _query = '';
                            }),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: AppColors.muted,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.tune,
                            size: 18,
                            color: AppColors.muted,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_query.isNotEmpty)
              ..._buildSearchResults(searchResults)
            else ...[
              // Banner pameran
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                child: InkWell(
                  onTap: widget.onEventTap,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.asset(
                            _karya[0].assetPath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                              stops: const [0.3, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'EKSKLUSIF PEKAN INI',
                            style: AppTextStyles.overline.copyWith(
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grand Vernissage 2026: Masterpiece Nusantara & Eropa',
                              style: AppTextStyles.headlineSm.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '34 Karya Terpilih',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    'Lihat Kurasi',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Quick actions
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _quickAction(
                      Icons.gavel_outlined,
                      'Lelang',
                      widget.onLelangTap,
                    ),
                    _quickAction(
                      Icons.confirmation_number_outlined,
                      'Event',
                      widget.onEventTap,
                    ),
                    _quickAction(
                      Icons.bookmarks_outlined,
                      'Koleksi Saya',
                      widget.onKoleksiTap,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Filter chips (gaya WikiArt asli, konsisten dgn preferensi genre)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenGutter,
                  ),
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final active = i == _filterIndex;
                    return ChoiceChip(
                      label: Text(_filters[i]),
                      selected: active,
                      onSelected: (_) => setState(() => _filterIndex = i),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: AppTextStyles.labelMd.copyWith(
                        color: active
                            ? Colors.white
                            : AppColors.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: active ? AppColors.primary : AppColors.border,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rekomendasi untukmu',
                          style: AppTextStyles.headlineMd,
                        ),
                        Text(
                          'Berdasarkan preferensimu',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: widget.onLihatSemuaTap,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Row(
                        children: [
                          Text(
                            'Lihat Semua',
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _karya.length < 4 ? _karya.length : 4,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.66,
                  ),
                  itemBuilder: (context, i) {
                    const overlines = [
                      'Lelang Langsung',
                      'Tawaran Terakhir',
                      'Beli Langsung',
                      'Tawaran Terbuka',
                    ];
                    const priceLabels = [
                      'Tawaran Saat Ini',
                      'Estimasi Palu',
                      'Harga Koleksi',
                      'Tawaran Terkini',
                    ];
                    return KaryaGridCard(
                      karya: _karya[i],
                      overline: overlines[i],
                      priceLabel: priceLabels[i],
                      onTap: () => widget.onKaryaTap?.call(_karya[i]),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.accentSoft,
                        child: const Icon(
                          Icons.support_agent,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Konsultasi Kurator Pribadi',
                              style: AppTextStyles.labelMd,
                            ),
                            Text(
                              'Dapatkan ulasan autentikasi & pasar',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Hubungi'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
      bottomNavigationBar: KolektorBottomNav(
        currentIndex: 0,
        onTap: (i) => widget.onNavTap?.call(i),
        onPindai: widget.onPindai ?? () {},
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surfaceContainerLow,
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.labelSm),
        ],
      ),
    );
  }

  List<Widget> _buildSearchResults(List<Karya> results) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
        ),
        child: Text(
          results.isEmpty
              ? 'Tidak ada hasil untuk "$_query"'
              : '${results.length} hasil untuk "$_query"',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (results.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              const Icon(Icons.search_off, size: 40, color: AppColors.muted),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Coba kata kunci lain, mis. nama seniman atau galeri.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
          ),
          child: Column(
            children: [
              for (final k in results) ...[
                _SearchResultTile(
                  karya: k,
                  onTap: () => widget.onKaryaTap?.call(k),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.karya, this.onTap});

  final Karya karya;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.asset(
                karya.assetPath,
                width: 56,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    karya.title,
                    style: AppTextStyles.headlineSm.copyWith(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    karya.artistName,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 11,
                        color: AppColors.outline,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          karya.galleryName,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.outline,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    karya.priceFormatted,
                    style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
