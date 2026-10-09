import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../services/katalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/karya_image.dart';

/// Tujuan tombol "Karya" di bottom nav Seniman (DashboardScreen &
/// ProfilScreen, index 1) -- sebelumnya TIDAK ADA layar tujuan sama sekali
/// di seluruh app (lihat audit navigasi role Seniman, 2026-10), bukan cuma
/// lupa isi callback.
///
/// CATATAN JUJUR: menampilkan SEMUA karya terverifikasi di platform (lewat
/// `GET /api/katalog`, lihat [KatalogService]), BUKAN cuma karya milik
/// seniman yang sedang login -- filter per-seniman butuh Auth (belum
/// dibangun, lihat CLAUDE.md "Belum dikerjakan"). Judul & pesan di layar ini
/// sengaja menyebutkan keterbatasan itu, BUKAN diam-diam berpura-pura sudah
/// terfilter.
class KaryaSayaScreen extends StatefulWidget {
  const KaryaSayaScreen({super.key, required this.onBack, this.onUploadKarya});

  final VoidCallback onBack;
  final VoidCallback? onUploadKarya;

  @override
  State<KaryaSayaScreen> createState() => _KaryaSayaScreenState();
}

class _KaryaSayaScreenState extends State<KaryaSayaScreen> {
  List<Karya>? _karya;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _karya = null;
      _error = null;
    });
    try {
      final karya = await KatalogService().fetchKatalog(pageSize: 50);
      if (!mounted) return;
      setState(() => _karya = karya);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat katalog: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Karya', style: AppTextStyles.headlineSm),
        actions: [
          IconButton(onPressed: widget.onUploadKarya, icon: const Icon(Icons.add)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Menampilkan semua karya terverifikasi di platform. Filter '
                      'khusus "milik saya" akan aktif setelah fitur Login tersedia.',
                      style: AppTextStyles.bodySm.copyWith(fontSize: 11.5, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            else if (_karya == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_karya!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(
                  child: Text('Belum ada karya terverifikasi.',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _karya!.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (context, i) {
                  final k = _karya![i];
                  return _KaryaSayaCard(karya: k);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _KaryaSayaCard extends StatelessWidget {
  const _KaryaSayaCard({required this.karya});

  final Karya karya;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: KaryaImage(karya)),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(karya.title,
                    style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(karya.priceFormatted,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
