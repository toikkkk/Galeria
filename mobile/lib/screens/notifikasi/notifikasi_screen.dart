import 'package:flutter/material.dart';

import '../../models/notifikasi.dart';
import '../../services/notifikasi_service.dart';
import '../../theme/app_theme.dart';
import '../../models/komunitas.dart' show waktuRelatif;

/// Notifikasi in-app (kolektor dan seniman memakai layar yang sama). Data dari server; ketuk untuk membuka tujuannya.
class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key, required this.onBack, required this.onBuka, NotifikasiService? service}) : _service = service;

  final VoidCallback onBack;

  /// Dipanggil saat notifikasi diketuk (sudah ditandai dibaca); pemanggil menentukan rute dari `tautan`.
  final ValueChanged<Notifikasi> onBuka;
  final NotifikasiService? _service;

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  late final NotifikasiService _service = widget._service ?? NotifikasiService();
  final List<Notifikasi> _items = [];
  bool _memuat = true;
  bool _adaLagi = false;
  bool _hanyaBelum = false;
  int _belum = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat({bool lagi = false}) async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final h = await _service.daftar(belum: _hanyaBelum, sebelum: lagi && _items.isNotEmpty ? _items.last.waktu : null);
      if (!mounted) return;
      setState(() {
        if (!lagi) _items.clear();
        _items.addAll(h.items);
        _adaLagi = h.adaLagi;
        _belum = h.belumDibaca;
      });
      NotifikasiStore.instance.atur(h.belumDibaca);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat notifikasi: $e');
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _ketuk(Notifikasi n) async {
    if (!n.dibaca) {
      setState(() {
        n.dibaca = true;
        _belum = (_belum - 1).clamp(0, 1 << 30);
      });
      try {
        NotifikasiStore.instance.atur(await _service.baca(n.id));
      } catch (_) {}
    }
    if (mounted) widget.onBuka(n);
  }

  Future<void> _bacaSemua() async {
    try {
      final n = await _service.bacaSemua();
      NotifikasiStore.instance.atur(n);
      if (mounted) {
        setState(() {
          for (final i in _items) {
            i.dibaca = true;
          }
          _belum = n;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  (IconData, Color) _gaya(String tipe) => switch (tipe) {
        'transaksi' => (Icons.shopping_bag_outlined, AppColors.accent),
        'lelang' => (Icons.gavel_outlined, AppColors.primary),
        'event' => (Icons.event_outlined, AppColors.primary),
        'verifikasi_karya' => (Icons.verified_outlined, AppColors.accent),
        'komunitas' => (Icons.groups_outlined, AppColors.primary),
        _ => (Icons.notifications_outlined, AppColors.muted),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Notifikasi', style: AppTextStyles.headlineSm),
        actions: [TextButton(onPressed: _belum == 0 ? null : _bacaSemua, child: const Text('Tandai semua'))],
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          children: [
            Wrap(spacing: AppSpacing.xs, children: [
              ChoiceChip(label: const Text('Semua'), selected: !_hanyaBelum, onSelected: (_) { setState(() => _hanyaBelum = false); _muat(); }),
              ChoiceChip(label: Text('Belum dibaca${_belum > 0 ? ' ($_belum)' : ''}'), selected: _hanyaBelum, onSelected: (_) { setState(() => _hanyaBelum = true); _muat(); }),
            ]),
            const SizedBox(height: AppSpacing.sm),
            if (_error != null)
              Column(children: [
                Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
                OutlinedButton.icon(onPressed: _muat, icon: const Icon(Icons.refresh, size: 16), label: const Text('Coba Lagi')),
              ])
            else if (_memuat && _items.isEmpty)
              const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(_hanyaBelum ? 'Semua notifikasi sudah dibaca.' : 'Belum ada notifikasi.', textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
              )
            else
              for (final n in _items)
                Builder(builder: (context) {
                  final (ikon, warna) = _gaya(n.tipe);
                  return GestureDetector(
                    onTap: () => _ketuk(n),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: n.dibaca ? Colors.white : AppColors.accentSoft.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CircleAvatar(radius: 18, backgroundColor: warna.withValues(alpha: 0.12), child: Icon(ikon, size: 18, color: warna)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(n.judul, style: AppTextStyles.labelMd.copyWith(fontWeight: n.dibaca ? FontWeight.w500 : FontWeight.w700))),
                              if (!n.dibaca) Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error)),
                            ]),
                            if (n.isi != null) Text(n.isi!, style: AppTextStyles.bodySm, maxLines: 3, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(waktuRelatif(n.waktu), style: AppTextStyles.bodySm.copyWith(fontSize: 10.5, color: AppColors.muted)),
                          ]),
                        ),
                      ]),
                    ),
                  );
                }),
            if (_adaLagi && !_memuat) Center(child: OutlinedButton(onPressed: () => _muat(lagi: true), child: const Text('Muat lebih banyak'))),
          ],
        ),
      ),
    );
  }
}
