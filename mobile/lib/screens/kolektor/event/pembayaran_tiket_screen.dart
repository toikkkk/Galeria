import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../models/event.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../widgets/commerce_widgets.dart';
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
  const PembayaranTiketScreen({
    super.key,
    required this.pesanan,
    required this.onBack,
    required this.onSelesai,
    EventService? service,
  }) : _service = service;

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

  Future<void> _jalankan(
    Future<PesananTiket> Function() kerja, {
    bool selesai = false,
  }) async {
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

  Future<void> _salin(String teks) async {
    await Clipboard.setData(ClipboardData(text: teks));
    if (mounted) tampilkanPesan(context, 'Nomor disalin.');
  }

  @override
  Widget build(BuildContext context) {
    final ins = _p.instruksi;
    final batas = _p.batasBayarAt;
    return Scaffold(
      backgroundColor: kLatarMarketplace,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Bayar Tiket', style: AppTextStyles.headlineSm),
      ),
      body: Column(
        children: [
          const IndikatorLangkah(
            aktif: 1,
            label: ['Pilih tiket', 'Pembayaran', 'Selesai'],
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: [
                BannerStatus(
                  warna: AppColors.primary,
                  ikon: Icons.schedule,
                  judul: batas != null ? 'Bayar dalam' : 'Menunggu pembayaran',
                  subjudul:
                      '${_p.event.judul} · ${_p.jumlah} × ${_p.tiketNama}',
                  trailing: batas == null
                      ? null
                      : HitungMundurBatas(
                          batas: batas,
                          gaya: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.accentSoft,
                            fontSize: 18,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.xs),
                KartuBagian(
                  judul: 'Metode Pembayaran',
                  ikon: Icons.account_balance_wallet_outlined,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xxs,
                    AppSpacing.md,
                    AppSpacing.xxs,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _metode.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        InkWell(
                          onTap: _sibuk
                              ? null
                              : () => _jalankan(
                                  () => _service.pilihMetode(
                                    _p.id,
                                    _metode[i].$1,
                                  ),
                                ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs + 2,
                            ),
                            child: Row(
                              children: [
                                Icon(_metode[i].$3, color: AppColors.primary),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    _metode[i].$2,
                                    style: AppTextStyles.labelMd.copyWith(
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                Icon(
                                  ins?.metode == _metode[i].$1
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: ins?.metode == _metode[i].$1
                                      ? AppColors.accent
                                      : AppColors.outlineVariant,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (ins != null)
                  KartuBagian(
                    judul: ins.metode == 'qris'
                        ? 'Pindai Kode QRIS'
                        : 'Nomor ${ins.namaMetode}',
                    ikon: ins.metode == 'qris'
                        ? Icons.qr_code_2
                        : Icons.pin_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ins.metode == 'qris') ...[
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: QrImageView(
                                data: ins.nomor,
                                size: 170,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                ins.nomor,
                                style: AppTextStyles.headlineSm.copyWith(
                                  letterSpacing: ins.metode == 'qris'
                                      ? 0.2
                                      : 1.2,
                                  fontSize: ins.metode == 'qris' ? 13 : 19,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _salin(ins.nomor),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Salin'),
                            ),
                          ],
                        ),
                        if (ins.sandbox)
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs + 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              'Mode sandbox: nomor ini contoh, tanpa uang sungguhan. Pakai tombol di bawah untuk mensimulasikan pembayaran masuk.',
                              style: AppTextStyles.bodySm.copyWith(
                                fontSize: 11,
                                color: const Color(0xFF584400),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                KartuBagian(
                  judul: 'Rincian',
                  ikon: Icons.receipt_long_outlined,
                  child: Column(
                    children: [
                      BarisHarga(
                        '${_p.tiketNama} × ${_p.jumlah}',
                        formatRupiah(_p.totalIdr),
                      ),
                      const Divider(height: AppSpacing.md),
                      BarisHarga(
                        'Total Pembayaran',
                        formatRupiah(_p.totalIdr),
                        tebal: true,
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Text(
                      _error!,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                Center(
                  child: TextButton(
                    onPressed: _sibuk
                        ? null
                        : () => _jalankan(
                            () => _service.batalPesanan(_p.id),
                            selesai: true,
                          ),
                    child: const Text(
                      'Batalkan pesanan',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BarBawah(
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: AppTextStyles.bodySm.copyWith(fontSize: 11),
                ),
                Text(
                  formatRupiah(_p.totalIdr),
                  style: AppTextStyles.headlineMd.copyWith(fontSize: 19),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_sibuk || ins == null || !ins.sandbox)
                    ? null
                    : () => _jalankan(
                        () => _service.simulasiBayar(_p.id),
                        selesai: true,
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onSurface,
                ),
                icon: _sibuk
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  ins == null
                      ? 'Pilih metode dulu'
                      : 'Simulasikan bayar (sandbox)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
