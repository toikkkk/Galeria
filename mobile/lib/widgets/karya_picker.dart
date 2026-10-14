import 'package:flutter/material.dart';

import '../models/karya.dart';
import '../services/katalog_service.dart';
import '../theme/app_theme.dart';
import 'karya_image.dart';

/// Pilih karya terverifikasi (dari `GET /api/katalog`).
///
/// [multi] = true -> boleh pilih banyak (mis. karya untuk event).
/// [onUnggahBaru] -> tombol "Unggah baru" (mis. membuka alur unggah karya).
/// Mengembalikan daftar karya terpilih, atau null kalau dibatalkan.
Future<List<Karya>?> showKaryaPicker(
  BuildContext context, {
  bool multi = false,
  List<Karya> awal = const [],
  VoidCallback? onUnggahBaru,
}) {
  return showModalBottomSheet<List<Karya>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _KaryaPicker(multi: multi, awal: awal, onUnggahBaru: onUnggahBaru),
  );
}

class _KaryaPicker extends StatefulWidget {
  const _KaryaPicker({required this.multi, required this.awal, this.onUnggahBaru});

  final bool multi;
  final List<Karya> awal;
  final VoidCallback? onUnggahBaru;

  @override
  State<_KaryaPicker> createState() => _KaryaPickerState();
}

class _KaryaPickerState extends State<_KaryaPicker> {
  List<Karya>? _items;
  String? _error;
  late final List<Karya> _terpilih = [...widget.awal];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final res = await KatalogService().fetchKatalogTerverifikasi(pageSize: 50);
      if (!mounted) return;
      setState(() => _items = res.items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat karya: $e');
    }
  }

  bool _dipilih(Karya k) => _terpilih.any((t) => t.id == k.id);

  void _tap(Karya k) {
    if (!widget.multi) {
      Navigator.of(context).pop([k]);
      return;
    }
    setState(() {
      if (_dipilih(k)) {
        _terpilih.removeWhere((t) => t.id == k.id);
      } else {
        _terpilih.add(k);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tinggi = MediaQuery.of(context).size.height * 0.8;
    return Container(
      height: tinggi,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.multi ? 'Pilih Karya' : 'Pilih Karya Terverifikasi',
                    style: AppTextStyles.headlineMd,
                  ),
                ),
                if (widget.onUnggahBaru != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onUnggahBaru!();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Unggah baru'),
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
          if (widget.multi)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenGutter),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_terpilih),
                  child: Text('Pilih ${_terpilih.length} karya'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Belum ada karya terverifikasi. Unggah karya dulu, lalu tunggu hasil verifikasinya.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) {
        final k = items[i];
        final dipilih = _dipilih(k);
        return InkWell(
          onTap: () => _tap(k),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: dipilih ? AppColors.accentSoft.withValues(alpha: 0.4) : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: dipilih ? AppColors.accent : AppColors.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(width: 56, height: 56, child: KaryaImage(karya: k)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.title,
                        style: AppTextStyles.labelMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${k.styleName} · ${k.priceFormatted}',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (widget.multi)
                  Icon(
                    dipilih ? Icons.check_circle : Icons.circle_outlined,
                    color: dipilih ? AppColors.accent : AppColors.muted,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
