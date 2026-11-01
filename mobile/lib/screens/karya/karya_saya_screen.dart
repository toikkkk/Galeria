import 'package:flutter/material.dart';

import 'ubah_karya_screen.dart';
import '../../models/karya.dart';
import '../../services/katalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/karya_image.dart';

/// Tujuan tombol "Karya" di bottom nav Seniman (index 1).
///
/// Menampilkan SEMUA karya milik seniman yang sedang login (`GET /api/karya-saya`), apa pun
/// status verifikasinya: menunggu, terverifikasi, perlu ditinjau, atau ditolak. Karya yang
/// belum terverifikasi hanya terlihat olehmu, belum tampil di katalog kolektor.
class KaryaSayaScreen extends StatefulWidget {
  const KaryaSayaScreen({
    super.key,
    required this.onBack,
    this.onUploadKarya,
    this.onKaryaTap,
    KatalogService? service,
  }) : _service = service;

  final VoidCallback onBack;
  final VoidCallback? onUploadKarya;
  final void Function(Karya karya)? onKaryaTap;
  final KatalogService? _service;

  @override
  State<KaryaSayaScreen> createState() => _KaryaSayaScreenState();
}

class _KaryaSayaScreenState extends State<KaryaSayaScreen> {
  late final KatalogService _service = widget._service ?? KatalogService();
  final _searchCtrl = TextEditingController();
  List<Karya> _karya = [];
  bool _loading = true;
  String? _error;
  String _filter = 'semua';

  static const _filters = <(String, String)>[
    ('semua', 'Semua'),
    ('terverifikasi', 'Terverifikasi'),
    ('menunggu', 'Menunggu'),
    ('perlu_ditinjau', 'Perlu ditinjau'),
    ('ditolak', 'Ditolak'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasil = await _service.fetchKaryaSaya();
      if (!mounted) return;
      setState(() => _karya = hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat karya: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Karya> get _tampil {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _karya.where((k) {
      if (_filter != 'semua' && k.statusVerifikasi != _filter) return false;
      return q.isEmpty || k.title.toLowerCase().contains(q) || k.styleName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _ubah(Karya karya) async {
    if (karya.terjual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Karya yang sudah terjual atau sedang dipesan tidak bisa diubah.')),
      );
      return;
    }
    final baru = await Navigator.of(context).push<Karya>(MaterialPageRoute(builder: (_) => UbahKaryaScreen(karya: karya)));
    if (baru == null || !mounted) return;
    setState(() => _karya = [for (final k in _karya) k.id == baru.id ? baru : k]);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perubahan disimpan.')));
  }

  Future<void> _hapus(Karya karya) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus karya?'),
        content: Text('"${karya.title}" akan dihapus dari daftarmu. Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ya != true || !mounted) return;
    try {
      await _service.hapusKarya(karya.id);
      if (!mounted) return;
      setState(() => _karya = _karya.where((k) => k.id != karya.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Karya dihapus.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tampil = _tampil;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Karya Saya', style: AppTextStyles.headlineSm),
        actions: [
          IconButton(onPressed: widget.onUploadKarya, icon: const Icon(Icons.add), tooltip: 'Unggah karya'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari judul atau aliran',
                prefixIcon: const Icon(Icons.search),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: _filter == f.$1,
                        onSelected: (_) => setState(() => _filter = f.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_error != null)
              _pesan(
                _error!,
                warna: AppColors.error,
                aksi: OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Coba Lagi'),
                ),
              )
            else if (_loading && _karya.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_karya.isEmpty)
              _pesan(
                'Kamu belum mengunggah karya. Unggah karya pertamamu, lalu karya akan diperiksa keaslian dan tampil di katalog kolektor setelah terverifikasi.',
                aksi: FilledButton.icon(
                  onPressed: widget.onUploadKarya,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Unggah karya'),
                ),
              )
            else if (tampil.isEmpty)
              _pesan('Tidak ada karya yang cocok dengan filter ini.')
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tampil.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.58,
                ),
                itemBuilder: (context, i) {
                  final k = tampil[i];
                  return _KaryaSayaCard(
                    karya: k,
                    onTap: k.statusVerifikasi == 'terverifikasi' && widget.onKaryaTap != null
                        ? () => widget.onKaryaTap!(k)
                        : null,
                    onHapus: () => _hapus(k),
                    onUbah: () => _ubah(k),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _pesan(String teks, {Color? warna, Widget? aksi}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Text(
              teks,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: warna ?? AppColors.muted),
            ),
            if (aksi != null) ...[const SizedBox(height: AppSpacing.sm), aksi],
          ],
        ),
      );
}

({String label, Color warna, IconData ikon}) _infoStatus(String? status) => switch (status) {
      'terverifikasi' => (label: 'Terverifikasi', warna: AppColors.accent, ikon: Icons.verified),
      'perlu_ditinjau' => (label: 'Perlu ditinjau', warna: const Color(0xFFB26A00), ikon: Icons.hourglass_top),
      'ditolak' => (label: 'Ditolak', warna: AppColors.error, ikon: Icons.block),
      _ => (label: 'Menunggu', warna: AppColors.muted, ikon: Icons.schedule),
    };

class _KaryaSayaCard extends StatelessWidget {
  const _KaryaSayaCard({required this.karya, this.onTap, this.onHapus, this.onUbah});

  final Karya karya;
  final VoidCallback? onTap;
  final VoidCallback? onHapus;
  final VoidCallback? onUbah;

  @override
  Widget build(BuildContext context) {
    final ai = karya.aiGeneratedProbability;
    final info = _infoStatus(karya.statusVerifikasi);
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
                      decoration: BoxDecoration(color: info.warna, borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(info.ikon, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            info.label,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (karya.isPromoted)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: const Text(
                          'Dipromosikan',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('ubah_${karya.id}'),
                          onPressed: onUbah,
                          tooltip: 'Ubah karya',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(backgroundColor: Colors.black38),
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: onHapus,
                          tooltip: 'Hapus karya',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(backgroundColor: Colors.black38),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                        ),
                      ],
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
                    karya.styleName,
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
                    ai == null ? 'Belum dicek engine' : 'Skor AI-generated ${(ai * 100).round()}%',
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
