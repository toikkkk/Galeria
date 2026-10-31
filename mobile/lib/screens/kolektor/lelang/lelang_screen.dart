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
    if (l.sayaPemenang) return Text('Kamu pemenangnya', style: AppTextStyles.labelSm.copyWith(color: AppColors.accent, fontSize: 11));
    if (l.berlangsung && l.sayaTertinggi) return Text('Kamu penawar tertinggi', style: AppTextStyles.labelSm.copyWith(color: AppColors.accent, fontSize: 11));
    if (_aktif == 'ikut' && l.berlangsung) return Text('Tawaranmu terlampaui', style: AppTextStyles.labelSm.copyWith(color: AppColors.error, fontSize: 11));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Lelang Karya', style: AppTextStyles.headlineMd),
        actions: [IconButton(onPressed: _memuat ? null : _muat, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: AppSpacing.xs),
              itemCount: _filter.length,
              separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                final aktif = _filter[i].$1 == _aktif;
                return ChoiceChip(
                  label: Text(_filter[i].$2),
                  selected: aktif,
                  onSelected: (_) => _pilih(_filter[i].$1),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  labelStyle: AppTextStyles.labelMd.copyWith(color: aktif ? Colors.white : AppColors.onSurfaceVariant, fontSize: 12.5),
                  shape: StadiumBorder(side: BorderSide(color: aktif ? AppColors.primary : AppColors.border)),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.sm, AppSpacing.screenGutter, AppSpacing.lg),
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
                  else
                    for (final l in _data) LelangKartu(lelang: l, catatan: _catatan(l), onTap: () => widget.onDetailTap?.call(l)),
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
