import 'package:flutter/material.dart';

import '../../../models/lelang.dart';
import '../../../services/lelang_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Formulir pasang tawaran. Mengembalikan [Lelang] terbaru (dari server) bila bid berhasil, atau null.
Future<Lelang?> tampilkanPasangBid(BuildContext context, Lelang lelang, {LelangService? service}) {
  return showModalBottomSheet<Lelang>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (_) => _PasangBidSheet(lelang: lelang, service: service ?? LelangService()),
  );
}

class _PasangBidSheet extends StatefulWidget {
  const _PasangBidSheet({required this.lelang, required this.service});

  final Lelang lelang;
  final LelangService service;

  @override
  State<_PasangBidSheet> createState() => _PasangBidSheetState();
}

class _PasangBidSheetState extends State<_PasangBidSheet> {
  late final _ctrl = TextEditingController(text: _titik(widget.lelang.bidMinimumIdr));
  bool _kirim = false;
  String? _error;

  static String _titik(int n) => formatRupiah(n).replaceFirst('Rp', '');

  int? get _jumlah => int.tryParse(_ctrl.text.replaceAll('.', '').trim());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(int n) => setState(() {
        _ctrl.text = _titik(n);
        _error = null;
      });

  Future<void> _submit() async {
    final j = _jumlah;
    if (j == null || j < widget.lelang.bidMinimumIdr) {
      setState(() => _error = 'Tawaran minimal ${formatRupiah(widget.lelang.bidMinimumIdr)}.');
      return;
    }
    setState(() {
      _kirim = true;
      _error = null;
    });
    try {
      final baru = await widget.service.bid(widget.lelang.id, j);
      if (mounted) Navigator.pop(context, baru);
    } catch (e) {
      if (mounted) {
        setState(() {
          _kirim = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lelang;
    final min = l.bidMinimumIdr;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.md, AppSpacing.screenGutter, MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pasang Tawaran', style: AppTextStyles.headlineMd),
            Text(l.judul, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.jumlahBid == 0 ? 'Harga awal' : 'Tawaran tertinggi saat ini', style: AppTextStyles.bodySm),
                Text(formatRupiah(l.hargaSaatIniIdr), style: AppTextStyles.labelMd),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tawaran minimal', style: AppTextStyles.bodySm),
                Text(formatRupiah(min), style: AppTextStyles.labelMd.copyWith(color: AppColors.accent)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final k in [0, 1, 2, 5])
                  ActionChip(
                    label: Text(k == 0 ? 'Minimal' : '+${formatRupiahRingkas(l.kelipatanIdr * k)}'),
                    onPressed: _kirim ? null : () => _set(min + l.kelipatanIdr * k),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              key: const Key('jumlah_bid'),
              controller: _ctrl,
              enabled: !_kirim,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(prefixText: 'Rp ', labelText: 'Tawaranmu', filled: true, fillColor: Colors.white),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(_error!, key: const Key('error_bid'), style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tawaran bersifat mengikat. Jika kamu menang, pesanan dibuat otomatis dan harus dibayar dalam 24 jam. '
              'Tawaran di 2 menit terakhir memperpanjang lelang 2 menit.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('kirim_bid'),
                onPressed: _kirim ? null : _submit,
                child: _kirim
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kirim Tawaran'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
