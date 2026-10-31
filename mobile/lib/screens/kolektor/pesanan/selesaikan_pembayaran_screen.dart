import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/pesanan.dart';
import '../../../services/pesanan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../utils/format_waktu.dart';
import '../../../widgets/pesanan_widgets.dart';

const _metode = <(String, String, IconData)>[
  ('va_bca', 'Virtual Account BCA', Icons.account_balance_outlined),
  ('va_mandiri', 'Virtual Account Mandiri', Icons.account_balance_outlined),
  ('va_bni', 'Virtual Account BNI', Icons.account_balance_outlined),
  ('qris', 'QRIS', Icons.qr_code_2),
];

/// Pilih metode pembayaran, tampilkan instruksi, dan (mode sandbox) simulasikan pembayaran.
///
/// MODE SANDBOX: tidak ada uang sungguhan dan belum ada gateway di belakangnya. Tombol "Simulasikan
/// pembayaran" meniru notifikasi "pembayaran diterima" dari gateway, supaya seluruh alur pesanan
/// (konfirmasi seniman, pengiriman, penerimaan) bisa dicoba dari awal sampai selesai.
class SelesaikanPembayaranScreen extends StatefulWidget {
  const SelesaikanPembayaranScreen({
    super.key,
    required this.pesanan,
    required this.onBack,
    required this.onSelesai,
    PesananService? service,
  }) : _service = service;

  final Pesanan pesanan;
  final VoidCallback onBack;

  /// Dipanggil dengan pesanan terbaru setelah dibayar atau dibatalkan.
  final ValueChanged<Pesanan> onSelesai;
  final PesananService? _service;

  @override
  State<SelesaikanPembayaranScreen> createState() => _SelesaikanPembayaranScreenState();
}

class _SelesaikanPembayaranScreenState extends State<SelesaikanPembayaranScreen> {
  late final PesananService _service = widget._service ?? PesananService();
  late Pesanan _pesanan = widget.pesanan;
  bool _sibuk = false;
  String? _error;

  Future<void> _jalankan(Future<Pesanan> Function() kerja, {bool selesai = false}) async {
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
      setState(() => _pesanan = baru);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _batal() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text('Karya akan tersedia lagi untuk kolektor lain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ya == true) await _jalankan(() => _service.batal(_pesanan.id), selesai: true);
  }

  @override
  Widget build(BuildContext context) {
    final ins = _pesanan.instruksi;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: Text('Selesaikan Pembayaran', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total pembayaran', style: AppTextStyles.bodySm.copyWith(color: Colors.white70)),
                Text(formatRupiah(_pesanan.hargaIdr), style: AppTextStyles.displayMd.copyWith(color: Colors.white, fontSize: 28)),
                const SizedBox(height: 4),
                Text('${_pesanan.judul} · ${_pesanan.kode}', style: AppTextStyles.bodySm.copyWith(color: Colors.white70)),
                if (_pesanan.batasBayarAt != null)
                  Text(
                    'Bayar sebelum ${formatTanggal(_pesanan.batasBayarAt!)} '
                    '${_pesanan.batasBayarAt!.hour.toString().padLeft(2, '0')}:${_pesanan.batasBayarAt!.minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.bodySm.copyWith(color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Metode Pembayaran', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          for (final m in _metode)
            GestureDetector(
              onTap: _sibuk ? null : () => _jalankan(() => _service.pilihMetode(_pesanan.id, m.$1)),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _pesanan.metodePembayaranTerpilih == m.$1 ? AppColors.accent : AppColors.border,
                    width: _pesanan.metodePembayaranTerpilih == m.$1 ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(m.$3, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(m.$2, style: AppTextStyles.labelMd)),
                    Icon(
                      _pesanan.metodePembayaranTerpilih == m.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: _pesanan.metodePembayaranTerpilih == m.$1 ? AppColors.accent : AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          if (ins != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ins.metode == 'qris' ? 'Kode QRIS' : 'Nomor ${ins.namaMetode}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(ins.nomor, style: AppTextStyles.headlineSm.copyWith(letterSpacing: 1)),
                      ),
                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: ins.nomor));
                          if (context.mounted) tampilkanPesan(context, 'Nomor disalin.');
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Salin',
                      ),
                    ],
                  ),
                  Text('Jumlah: ${formatRupiah(ins.jumlahIdr)}', style: AppTextStyles.labelMd),
                  if (ins.sandbox) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Mode sandbox: nomor ini hanya contoh, tidak ada uang sungguhan. Gunakan tombol di bawah untuk mensimulasikan pembayaran masuk.',
                        style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: const Color(0xFF584400)),
                      ),
                    ),
                  ],
                ],
              ),
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
              onPressed: (_sibuk || ins == null || !ins.sandbox) ? null : () => _jalankan(() => _service.simulasiBayar(_pesanan.id), selesai: true),
              icon: _sibuk
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(ins == null ? 'Pilih metode pembayaran dulu' : 'Simulasikan pembayaran (sandbox)'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _sibuk ? null : _batal,
              child: const Text('Batalkan pesanan', style: TextStyle(color: AppColors.error)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

extension on Pesanan {
  /// Metode yang sedang dipilih (null bila belum memilih).
  String? get metodePembayaranTerpilih => instruksi?.metode;
}
