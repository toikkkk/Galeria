import 'package:flutter/material.dart';

import '../../../models/lelang.dart';
import '../../../services/auth_service.dart';
import '../../../services/lelang_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/kolektor/kolektor_bottom_nav.dart';
import '../../../widgets/lelang_widgets.dart';

/// Daftar lelang dari server (`GET /api/lelang`). Tamu boleh melihat; filter "Diikuti" butuh login.
class LelangScreen extends StatefulWidget {
  const LelangScreen({
    super.key,
    required this.onBack,
    this.onNavTap,
    this.onPindai,
    this.onDetailTap,
    LelangService? service,
  }) : _service = service;

  final VoidCallback onBack;
  final ValueChanged<int>? onNavTap;
  final VoidCallback? onPindai;
  final ValueChanged<Lelang>? onDetailTap;
  final LelangService? _service;

  @override
  State<LelangScreen> createState() => _LelangScreenState();
}

class _LelangScreenState extends State<LelangScreen> {
  late final LelangService _service = widget._service ?? LelangService();
  static const _filter = [
    ('semua', 'Semua Lot'),
    ('berlangsung', 'Berlangsung'),
    ('akan_datang', 'Segera Dimulai'),
    ('selesai', 'Selesai'),
    ('ikut', 'Diikuti'),
  ];
  String _aktif = 'semua';
  List<Lelang> _data = [];
  bool _memuat = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final ikut = _aktif == 'ikut';
      final d = await _service.daftar(status: ikut ? 'semua' : _aktif, ikut: ikut);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat lelang: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  void _pilih(String f) {
    if (f == 'ikut' && !AuthService.instance.loggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masuk dulu untuk melihat lelang yang kamu ikuti.')));
      return;
    }
    setState(() => _aktif = f);
    _muat();
  }

  Widget? _catatan(Lelang l) {
    Widget pil(String teks, IconData ikon, Color latar, Color teksWarna) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: latar, borderRadius: BorderRadius.circular(AppRadius.full)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ikon, size: 12, color: teksWarna),
            const SizedBox(width: 3),
            Flexible(child: Text(teks, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelSm.copyWith(color: teksWarna, fontSize: 10.5, fontWeight: FontWeight.w800))),
          ]),
        );
    if (l.sayaPemenang) return pil('Kamu pemenangnya', Icons.emoji_events_outlined, const Color(0xFFDBA12C), const Color(0xFF3E251E));
    if (l.berlangsung && l.sayaTertinggi) return pil('Kamu penawar tertinggi', Icons.trending_up, const Color(0xFFF7E7C1), const Color(0xFF7A5410));
    if (_aktif == 'ikut' && l.berlangsung) return pil('Tawaranmu terlampaui', Icons.priority_high, AppColors.error.withValues(alpha: 0.12), AppColors.error);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Lelang Karya', style: AppTextStyles.headlineMd),
        actions: [IconButton(onPressed: _memuat ? null : _muat, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              itemCount: _filter.length,
              itemBuilder: (context, i) {
                final aktif = _filter[i].$1 == _aktif;
                return InkWell(
                  onTap: () => _pilih(_filter[i].$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: aktif ? const Color(0xFFDBA12C) : Colors.transparent, width: 3))),
                    child: Text(
                      _filter[i].$2,
                      style: AppTextStyles.labelMd.copyWith(fontSize: 13, color: aktif ? const Color(0xFF3E251E) : AppColors.muted, fontWeight: aktif ? FontWeight.w800 : FontWeight.w500),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.lg),
                children: [
                  if (_error != null)
                    Column(
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                        OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
                      ],
                    )
                  else if (_memuat && _data.isEmpty)
                    const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
                  else if (_data.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        _aktif == 'ikut' ? 'Kamu belum mengikuti lelang apa pun.' : 'Belum ada lelang pada kategori ini.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd.copyWith(color: AppColors.muted),
                      ),
                    )
                  else ...[
                    _Sorotan(data: _data),
                    for (final l in _data) LelangKartu(lelang: l, catatan: _catatan(l), onTap: () => widget.onDetailTap?.call(l)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: KolektorBottomNav(
        currentIndex: 1,
        onTap: (i) => widget.onNavTap?.call(i),
        onPindai: widget.onPindai ?? () {},
      ),
    );
  }
}

/// Banner ringkas di atas daftar: jumlah lot yang sedang berlangsung dan lot yang segera berakhir.
class _Sorotan extends StatelessWidget {
  const _Sorotan({required this.data});

  final List<Lelang> data;

  @override
  Widget build(BuildContext context) {
    final aktif = data.where((l) => l.berlangsung).toList();
    if (aktif.isEmpty) return const SizedBox.shrink();
    final segera = aktif.where((l) => l.sisa < const Duration(hours: 24)).length;
    final totalBid = aktif.fold<int>(0, (a, l) => a + l.jumlahBid);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4D2F26), Color(0xFF2F1B15)]),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: const Color(0xFFDBA12C), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: const Icon(Icons.gavel, color: Color(0xFF3E251E), size: 22),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${aktif.length} lelang sedang berlangsung', style: AppTextStyles.labelMd.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            Text(
              segera > 0 ? '$segera berakhir dalam 24 jam · $totalBid bid masuk' : '$totalBid bid masuk',
              style: AppTextStyles.bodySm.copyWith(color: const Color(0xFFF0C86A), fontSize: 11.5),
            ),
          ]),
        ),
      ]),
    );
  }
}
