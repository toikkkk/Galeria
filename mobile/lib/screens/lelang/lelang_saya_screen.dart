import 'package:flutter/material.dart';

import '../../models/lelang.dart';
import '../../services/lelang_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lelang_widgets.dart';

/// Lelang milik seniman yang login (`GET /api/lelang/saya`), semua status.
class LelangSayaScreen extends StatefulWidget {
  const LelangSayaScreen({super.key, required this.onBack, required this.onDetail, this.onBuat, LelangService? service})
      : _service = service;

  final VoidCallback onBack;
  final ValueChanged<Lelang> onDetail;
  final VoidCallback? onBuat;
  final LelangService? _service;

  @override
  State<LelangSayaScreen> createState() => _LelangSayaScreenState();
}

class _LelangSayaScreenState extends State<LelangSayaScreen> {
  late final LelangService _service = widget._service ?? LelangService();
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
      final d = await _service.saya();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat lelang: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Lelang Saya', style: AppTextStyles.headlineSm),
        actions: [IconButton(onPressed: widget.onBuat, icon: const Icon(Icons.add), tooltip: 'Buat lelang')],
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          children: [
            if (_error != null)
              Column(children: [
                Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
              ])
            else if (_memuat && _data.isEmpty)
              const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else if (_data.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Text('Kamu belum membuat lelang.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                    const SizedBox(height: AppSpacing.xs),
                    FilledButton.icon(onPressed: widget.onBuat, icon: const Icon(Icons.gavel), label: const Text('Buat lelang')),
                  ],
                ),
              )
            else
              for (final l in _data) LelangKartu(lelang: l, onTap: () => widget.onDetail(l)),
          ],
        ),
      ),
    );
  }
}
