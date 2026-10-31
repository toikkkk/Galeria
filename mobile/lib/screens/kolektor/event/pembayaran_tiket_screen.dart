import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/event.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../widgets/event_widgets.dart';
import '../../../widgets/pesanan_widgets.dart';

const _metode = <(String, String, IconData)>[
  ('va_bca', 'Virtual Account BCA', Icons.account_balance_outlined),
  ('va_mandiri', 'Virtual Account Mandiri', Icons.account_balance_outlined),
  ('va_bni', 'Virtual Account BNI', Icons.account_balance_outlined),
  ('qris', 'QRIS', Icons.qr_code_2),
];

/// Bayar pesanan tiket. MODE SANDBOX: tidak ada uang sungguhan; tombol simulasi meniru pembayaran masuk,
/// lalu e-tiket diterbitkan. Kuota ditahan 30 menit; lewat itu pesanan batal otomatis.
class PembayaranTiketScreen extends StatefulWidget {
  const PembayaranTiketScreen({super.key, required this.pesanan, required this.onBack, required this.onSelesai, EventService? service})
      : _service = service;

  final PesananTiket pesanan;
  final VoidCallback onBack;

  /// Dipanggil dengan pesanan terbaru setelah dibayar atau dibatalkan.
  final ValueChanged<PesananTiket> onSelesai;
  final EventService? _service;

  @override
  State<PembayaranTiketScreen> createState() => _PembayaranTiketScreenState();
}

class _PembayaranTiketScreenState extends State<PembayaranTiketScreen> {
  late final EventService _service = widget._service ?? EventService();
  late PesananTiket _p = widget.pesanan;
  bool _sibuk = false;
  String? _error;

  Future<void> _jalankan(Future<PesananTiket> Function() kerja, {bool selesai = false}) async {
    setState(() {
      _sibuk = true;
      _error = null;
    });
    try {
      final baru = await kerja();
      if (!mounted) return;
      if (selesai) {
        widget.onSelesai(baru);
        return;
      }
      setState(() => _p = baru);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ins = _p.instruksi;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Bayar Tiket', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total pembayaran', style: AppTextStyles.bodySm.copyWith(color: Colors.white70)),
              Text(formatRupiah(_p.totalIdr), style: AppTextStyles.displayMd.copyWith(color: Colors.white, fontSize: 28)),
              const SizedBox(height: 4),
              Text('${_p.event.judul} · ${_p.jumlah} × ${_p.tiketNama}', style: AppTextStyles.bodySm.copyWith(color: Colors.white70)),
              if (_p.batasBayarAt != null)
                Text('Bayar sebelum ${jamMenit(_p.batasBayarAt!)} (kuota ditahan sampai saat itu)', style: AppTextStyles.bodySm.copyWith(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Metode Pembayaran', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          for (final m in _metode)
            GestureDetector(
              onTap: _sibuk ? null : () => _jalankan(() => _service.pilihMetode(_p.id, m.$1)),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: ins?.metode == m.$1 ? AppColors.accent : AppColors.border, width: ins?.metode == m.$1 ? 1.6 : 1),
                ),
                child: Row(children: [
                  Icon(m.$3, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(m.$2, style: AppTextStyles.labelMd)),
                  Icon(ins?.metode == m.$1 ? Icons.radio_button_checked : Icons.radio_button_off, color: ins?.metode == m.$1 ? AppColors.accent : AppColors.muted),
                ]),
              ),
            ),
          if (ins != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ins.metode == 'qris' ? 'Kode QRIS' : 'Nomor ${ins.namaMetode}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                Row(children: [
                  Expanded(child: SelectableText(ins.nomor, style: AppTextStyles.headlineSm.copyWith(letterSpacing: 1))),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: ins.nomor));
                      if (context.mounted) tampilkanPesan(context, 'Nomor disalin.');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ]),
                if (ins.sandbox)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Text('Mode sandbox: nomor ini contoh, tanpa uang sungguhan. Pakai tombol di bawah untuk mensimulasikan pembayaran masuk.',
                        style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: const Color(0xFF584400))),
                  ),
              ]),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_sibuk || ins == null || !ins.sandbox) ? null : () => _jalankan(() => _service.simulasiBayar(_p.id), selesai: true),
              icon: _sibuk ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
              label: Text(ins == null ? 'Pilih metode pembayaran dulu' : 'Simulasikan pembayaran (sandbox)'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _sibuk ? null : () => _jalankan(() => _service.batalPesanan(_p.id), selesai: true),
              child: const Text('Batalkan pesanan', style: TextStyle(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }
}
