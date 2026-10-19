import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../services/api_client.dart';
import '../../../services/katalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/karya_grid_card.dart';

/// Layar "Semua Karya" -- tujuan tombol "Lihat Semua" di sebelah
/// "Rekomendasi untukmu" pada BerandaKolektorScreen.
///
/// Dengan [kPakaiDataDummy] (default): katalog 2.000 karya dummy dari
/// `GET /api/katalog-dummy` -- dimuat per halaman saat scroll mendekati
/// akhir, dengan filter aliran, rentang harga, dan urutan di server.
/// Backend tidak terjangkau -> diam-diam jatuh ke [sampleKarya] (app tidak
/// boleh kosong/crash cuma karena backend mati).
///
/// Tanpa flag itu: tampilan lama (karya [Karya.isPromoted] di section
/// terpisah paling atas, sisanya di bawah) dari [sampleKarya].
class SemuaKaryaScreen extends StatefulWidget {
  const SemuaKaryaScreen({super.key, required this.onBack, this.onKaryaTap});

  final VoidCallback onBack;
  final ValueChanged<Karya>? onKaryaTap;

  @override
  State<SemuaKaryaScreen> createState() => _SemuaKaryaScreenState();
}

class _RentangHarga {
  const _RentangHarga(this.label, this.min, this.maks);

  final String label;
  final int? min;
  final int? maks;
}

const _rentangHarga = [
  _RentangHarga('Semua harga', null, null),
  _RentangHarga('< Rp10 jt', null, 10000000),
  _RentangHarga('Rp10–50 jt', 10000000, 50000000),
  _RentangHarga('Rp50–200 jt', 50000000, 200000000),
  _RentangHarga('> Rp200 jt', 200000000, null),
];

const _urutan = {
  'terbaru': 'Terbaru',
  'harga_asc': 'Harga terendah',
  'harga_desc': 'Harga tertinggi',
};

/// 11 aliran katalog dummy (nilai = `style_name` di backend).
const _gayaKatalog = [
  'Impressionism',
  'Realism',
  'Post_Impressionism',
  'Romanticism',
  'Art_Nouveau',
  'Symbolism',
  'Naive_Art_Primitivism',
  'Northern_Renaissance',
  'Expressionism',
  'Baroque',
  'Cubism',
];

String _labelGaya(String g) => g.replaceAll('_', ' ');

class _SemuaKaryaScreenState extends State<SemuaKaryaScreen> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final _service = KatalogService();

  final List<Karya> _items = [];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _gagal = false;

  String? _gaya;
  int _hargaIdx = 0;
  String _urut = 'terbaru';

  @override
  void initState() {
    super.initState();
    if (kPakaiDataDummy) {
      _scroll.addListener(_onScroll);
      _muat(reset: true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _muat();
    }
  }

  bool get _adaHalamanLagi => _items.length < _total;

  Future<void> _muat({bool reset = false}) async {
    if (_loading || (!reset && (_gagal || !_adaHalamanLagi))) return;
    setState(() {
      _loading = true;
      if (reset) {
        _items.clear();
        _page = 0;
        _total = 0;
        _gagal = false;
      }
    });
    final rentang = _rentangHarga[_hargaIdx];
    try {
      final hasil = await _service.fetchKatalogDummy(
        page: _page + 1,
        pageSize: _pageSize,
        gaya: _gaya,
        hargaMin: rentang.min,
        hargaMaks: rentang.maks,
        urut: _urut,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(hasil.items);
        _page = hasil.page;
        _total = hasil.total;
      });
    } catch (_) {
      // Backend tidak terjangkau: halaman pertama -> jatuh ke sampleKarya,
      // halaman berikutnya -> berhenti memuat (daftar yang ada tetap tampil).
      if (mounted) setState(() => _gagal = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Semua Karya', style: AppTextStyles.headlineSm),
      ),
      body: kPakaiDataDummy ? _bodyDummy() : _bodyLokal(),
    );
  }

  // ---------- katalog dummy (server) ----------

  Widget _bodyDummy() {
    final fallbackLokal = _gagal && _items.isEmpty;
    final daftar = fallbackLokal ? sampleKarya : _items;
    return Column(
      children: [
        _filterBar(),
        Expanded(
          child: daftar.isEmpty && _loading
              ? const Center(child: CircularProgressIndicator())
              : daftar.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada karya yang cocok dengan filter ini.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                  ),
                )
              : CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenGutter,
                        vertical: AppSpacing.xs,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          fallbackLokal
                              ? 'Backend tidak terjangkau — menampilkan karya contoh.'
                              : '$_total karya · Data contoh',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenGutter,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 0.66,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => KaryaGridCard(
                            karya: daftar[i],
                            overline: null,
                            onTap: () => widget.onKaryaTap?.call(daftar[i]),
                          ),
                          childCount: daftar.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : _gagal && !fallbackLokal
                              ? TextButton(
                                  onPressed: () {
                                    setState(() => _gagal = false);
                                    _muat();
                                  },
                                  child: const Text('Gagal memuat — coba lagi'),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _filterBar() {
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            children: [
              for (final g in <String?>[null, ..._gayaKatalog]) ...[
                _gayaChip(g),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
          ),
          child: Row(
            children: [
              _menu<int>(
                icon: Icons.payments_outlined,
                label: _rentangHarga[_hargaIdx].label,
                items: {
                  for (var i = 0; i < _rentangHarga.length; i++)
                    i: _rentangHarga[i].label,
                },
                onSelected: (i) {
                  setState(() => _hargaIdx = i);
                  _muat(reset: true);
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              _menu<String>(
                icon: Icons.sort,
                label: _urutan[_urut]!,
                items: _urutan,
                onSelected: (u) {
                  setState(() => _urut = u);
                  _muat(reset: true);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gayaChip(String? g) {
    final active = g == _gaya;
    return ChoiceChip(
      label: Text(g == null ? 'Semua' : _labelGaya(g)),
      selected: active,
      onSelected: (_) {
        setState(() => _gaya = g);
        _muat(reset: true);
      },
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: AppTextStyles.labelMd.copyWith(
        color: active ? Colors.white : AppColors.onSurfaceVariant,
        fontSize: 12.5,
      ),
      shape: StadiumBorder(
        side: BorderSide(color: active ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _menu<T>({
    required IconData icon,
    required String label,
    required Map<T, String> items,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final e in items.entries)
          PopupMenuItem<T>(value: e.key, child: Text(e.value)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.labelMd.copyWith(fontSize: 12)),
            const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  // ---------- tampilan lama (sampleKarya) ----------

  Widget _bodyLokal() {
    final promoted = sampleKarya.where((k) => k.isPromoted).toList();
    final lainnya = sampleKarya.where((k) => !k.isPromoted).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.sm,
      ),
      children: [
        if (promoted.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('Dipromosikan Seniman', style: AppTextStyles.headlineSm),
            ],
          ),
          Text(
            'Karya pilihan yang ditampilkan lebih dulu oleh senimannya',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          _grid(promoted),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('Karya Lainnya', style: AppTextStyles.headlineSm),
        const SizedBox(height: AppSpacing.sm),
        _grid(lainnya),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _grid(List<Karya> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (context, i) => KaryaGridCard(
        karya: items[i],
        overline: null,
        onTap: () => widget.onKaryaTap?.call(items[i]),
      ),
    );
  }
}
