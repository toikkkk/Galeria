import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../services/katalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/karya_image.dart';

/// Tujuan tombol "Karya" di bottom nav Seniman (index 1).
///
/// Menampilkan SEMUA karya terverifikasi di platform (`GET /api/katalog`) --
/// yaitu karya yang sudah lolos verification engine Digital Art Identity
/// (Art-to-Art: bukan duplikat; Art-to-AI: bukan AI-generated). Tiap kartu
/// menampilkan skor Art-to-AI dari engine kalau ada.
///
/// Filter "Milik saya" SENGAJA terkunci: butuh Auth (belum dibangun, lihat
/// CLAUDE.md). Begitu Login tersedia, isi [senimanId] dari sesi login dan
/// filter ini otomatis aktif (backend sudah mendukung `?seniman_id=`).
class KaryaSayaScreen extends StatefulWidget {
  const KaryaSayaScreen({
    super.key,
    required this.onBack,
    this.onUploadKarya,
    this.onKaryaTap,
    this.senimanId,
  });

  final VoidCallback onBack;
  final VoidCallback? onUploadKarya;
  final void Function(Karya karya)? onKaryaTap;

  /// ID seniman yang sedang login. `null` = belum login -> "Milik saya"
  /// terkunci.
  final String? senimanId;

  @override
  State<KaryaSayaScreen> createState() => _KaryaSayaScreenState();
}

class _KaryaSayaScreenState extends State<KaryaSayaScreen> {
  static const _pageSize = 20;

  final _service = KatalogService();
  final _searchCtrl = TextEditingController();
  final List<Karya> _karya = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  bool _milikSaya = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _karya.clear();
        _page = 0;
        _total = 0;
      }
    });
    try {
      final res = await _service.fetchKatalogTerverifikasi(
        page: _page + 1,
        pageSize: _pageSize,
        q: _searchCtrl.text,
        senimanId: _milikSaya ? widget.senimanId : null,
      );
      if (!mounted) return;
      setState(() {
        _karya.addAll(res.items);
        _page = res.page;
        _total = res.total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat karya: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pilihFilter(bool milikSaya) {
    if (milikSaya && widget.senimanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Filter "Milik saya" aktif setelah Anda login sebagai seniman.'),
        ),
      );
      return;
    }
    if (_milikSaya == milikSaya) return;
    setState(() => _milikSaya = milikSaya);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final bisaMuatLagi = _karya.length < _total;
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
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          children: [
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(reset: true),
              decoration: InputDecoration(
                hintText: 'Cari judul, seniman, atau galeri',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load(reset: true);
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('Semua terverifikasi'),
                  selected: !_milikSaya,
                  onSelected: (_) => _pilihFilter(false),
                ),
                ChoiceChip(
                  avatar: widget.senimanId == null
                      ? const Icon(Icons.lock_outline, size: 14)
                      : null,
                  label: const Text('Milik saya'),
                  selected: _milikSaya,
                  onSelected: (_) => _pilihFilter(true),
                ),
              ],
            ),
            if (widget.senimanId == null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Filter "Milik saya" akan aktif setelah fitur Login tersedia.',
                style: AppTextStyles.bodySm.copyWith(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (_total > 0)
              Text(
                '$_total karya terverifikasi',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.muted),
              ),
            const SizedBox(height: AppSpacing.xs),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => _load(reset: _karya.isEmpty),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            else if (_karya.isEmpty && _loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_karya.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(
                  child: Text(
                    'Belum ada karya terverifikasi.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _karya.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.58,
                ),
                itemBuilder: (context, i) => _KaryaSayaCard(
                  karya: _karya[i],
                  onTap: widget.onKaryaTap == null ? null : () => widget.onKaryaTap!(_karya[i]),
                ),
              ),
            if (_error == null && bisaMuatLagi)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          onPressed: _load,
                          child: const Text('Muat lebih banyak'),
                        ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _KaryaSayaCard extends StatelessWidget {
  const _KaryaSayaCard({required this.karya, this.onTap});

  final Karya karya;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ai = karya.aiGeneratedProbability;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  KaryaImage(karya: karya),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 11, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'Terverifikasi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    karya.title,
                    style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    karya.artistName,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    karya.priceFormatted,
                    style: AppTextStyles.bodySm.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ai == null
                        ? 'Belum dicek engine'
                        : 'Skor AI-generated ${(ai * 100).round()}%',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
