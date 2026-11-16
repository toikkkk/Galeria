import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../services/katalog_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/commerce_widgets.dart';
import '../../../widgets/kolektor/karya_grid_card.dart';

/// Profil toko seorang seniman: identitas + semua karya terverifikasinya (`GET /api/katalog?seniman_id=`).
///
/// Semua isi nyata. Angka yang tidak punya sumber data (pengikut, jumlah terjual, rating toko) sengaja
/// TIDAK ditampilkan, dan klaim yang tidak ada di sistem (mis. "escrow") dihapus.
class ProfilTokoScreen extends StatefulWidget {
  const ProfilTokoScreen({
    super.key,
    required this.onBack,
    this.onKaryaTap,
    this.senimanId,
    this.nama = 'Seniman',
    this.galeri,
    KatalogService? service,
  }) : _service = service;

  final VoidCallback onBack;
  final ValueChanged<Karya>? onKaryaTap;

  /// Pemilik toko. Tanpa id, layar menampilkan keadaan kosong yang jujur.
  final String? senimanId;
  final String nama;
  final String? galeri;
  final KatalogService? _service;

  @override
  State<ProfilTokoScreen> createState() => _ProfilTokoScreenState();
}

class _ProfilTokoScreenState extends State<ProfilTokoScreen> {
  late final KatalogService _service = widget._service ?? KatalogService();
  List<Karya> _karya = [];
  int _total = 0;
  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final id = widget.senimanId;
    if (id == null || id.isEmpty) {
      setState(() => _memuat = false);
      return;
    }
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final h = await _service.fetchKatalogTerverifikasi(pageSize: 60, senimanId: id);
      if (mounted) {
        setState(() {
          _karya = h.items;
          _total = h.total;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat karya: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nama = widget.nama.trim().isEmpty ? 'Seniman' : widget.nama.trim();
    final inisial = nama.length >= 2 ? nama.substring(0, 2).toUpperCase() : nama.toUpperCase();
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Profil Toko', style: AppTextStyles.headlineSm),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1C1C1C), Color(0xFF3A3326)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Text(inisial, style: AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nama, style: AppTextStyles.headlineMd.copyWith(color: Colors.white, fontSize: 21)),
                          if (widget.galeri != null && widget.galeri!.isNotEmpty && widget.galeri != nama)
                            Text(widget.galeri!, style: AppTextStyles.bodySm.copyWith(color: Colors.white70)),
                          const SizedBox(height: 6),
                          const LencanaKecil('Seniman di GALERIA', ikon: Icons.brush_outlined, warna: AppColors.accentSoft),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: KartuBagian(
                  margin: EdgeInsets.zero,
                  child: Row(
                    children: [
                      Expanded(child: _stat('$_total', 'Karya terverifikasi')),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const Expanded(child: _Jaminan()),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
                child: Text('Karya Tersedia', style: AppTextStyles.headlineSm),
              ),
            ),
            if (_memuat)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator())))
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                      OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
                    ],
                  ),
                ),
              )
            else if (_karya.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text('Belum ada karya terverifikasi dari seniman ini.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.66,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => KaryaGridCard(karya: _karya[i], overline: null, onTap: () => widget.onKaryaTap?.call(_karya[i])),
                    childCount: _karya.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: AppTextStyles.headlineSm.copyWith(fontSize: 18)),
          Text(label, style: AppTextStyles.bodySm.copyWith(fontSize: 10.5)),
        ],
      );
}

class _Jaminan extends StatelessWidget {
  const _Jaminan();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.accent),
          const SizedBox(width: 6),
          Expanded(child: Text('Setiap karya lolos pemeriksaan keaslian digital', style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.onSurface))),
        ],
      ),
    );
  }
}
