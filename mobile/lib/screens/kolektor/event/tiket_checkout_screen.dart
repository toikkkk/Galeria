import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_pendaftaran_pembayaran_tiket_event/code.html
///
/// TODO(backend): submit ke endpoint tiket/event nyata -- saat ini simulasi
/// lokal saja.
class TiketCheckoutScreen extends StatefulWidget {
  const TiketCheckoutScreen({
    super.key,
    required this.onBack,
    required this.onPaid,
  });

  final VoidCallback onBack;
  final VoidCallback onPaid;

  @override
  State<TiketCheckoutScreen> createState() => _TiketCheckoutScreenState();
}

class _TiketCheckoutScreenState extends State<TiketCheckoutScreen> {
  int _sesi = 1;
  int _qtyReguler = 0;
  int _qtyVip = 1;
  bool _processing = false;

  static const _hargaReguler = 50000;
  static const _hargaVip = 250000;
  static const _biayaLayanan = 5000;

  int get _total =>
      _qtyReguler * _hargaReguler + _qtyVip * _hargaVip + _biayaLayanan;

  String _rupiah(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp$buf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          'Pendaftaran Event & Tiket',
          style: AppTextStyles.headlineSm,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        children: [
          Text('Pilih Sesi Kunjungan', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          _sessionTile(
            1,
            'Sesi 1',
            '10:00 – 14:00 WIB',
            'Akses Galeri & Pemandu Umum',
          ),
          const SizedBox(height: AppSpacing.xs),
          _sessionTile(
            2,
            'Sesi 2',
            '14:00 – 18:00 WIB',
            'Diskusi panel bersama kurator & seniman',
            badge: 'Kurator Talk',
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Kategori Akses Tiket', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          _ticketTile(
            'Tiket Reguler',
            'Akses masuk ruang pameran utama & katalog digital.',
            _hargaReguler,
            _qtyReguler,
            (v) => setState(() => _qtyReguler = v),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ticketTile(
            'Kurator VIP Access',
            'Katalog fisik bertanda tangan, tur privat, welcome cocktail.',
            _hargaVip,
            _qtyVip,
            (v) => setState(() => _qtyVip = v),
            featured: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Rincian Transaksi', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Column(
              children: [
                if (_qtyReguler > 0)
                  _breakdownRow(
                    '${_qtyReguler}x Tiket Reguler',
                    _qtyReguler * _hargaReguler,
                  ),
                if (_qtyVip > 0)
                  _breakdownRow(
                    '${_qtyVip}x Tiket Kurator VIP',
                    _qtyVip * _hargaVip,
                  ),
                _breakdownRow('Biaya Layanan & E-Tiket', _biayaLayanan),
                const Divider(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Pembayaran', style: AppTextStyles.labelMd),
                    Text(
                      _rupiah(_total),
                      style: AppTextStyles.displayMd.copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.sm,
          AppSpacing.screenGutter,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL',
                    style: AppTextStyles.overline.copyWith(fontSize: 9),
                  ),
                  Text(
                    _rupiah(_total),
                    style: AppTextStyles.headlineMd.copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: (_qtyReguler + _qtyVip) == 0 || _processing
                  ? null
                  : () async {
                      setState(() => _processing = true);
                      await Future.delayed(const Duration(milliseconds: 700));
                      if (context.mounted) widget.onPaid();
                    },
              child: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Bayar Tiket Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionTile(
    int id,
    String title,
    String time,
    String desc, {
    String? badge,
  }) {
    final selected = _sesi == id;
    return InkWell(
      onTap: () => setState(() => _sesi = id),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceContainerLow : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: AppTextStyles.labelMd),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            badge,
                            style: AppTextStyles.overline.copyWith(fontSize: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    desc,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketTile(
    String title,
    String desc,
    int price,
    int qty,
    ValueChanged<int> onChange, {
    bool featured = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: featured
            ? Border.all(color: AppColors.accent, width: 1.5)
            : null,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'POPULER & TERKURASI',
                  style: AppTextStyles.overline.copyWith(fontSize: 8),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelMd),
                    Text(
                      desc,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _rupiah(price),
                style: AppTextStyles.labelMd.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: qty > 0 ? () => onChange(qty - 1) : null,
                icon: const Icon(Icons.remove_circle_outline, size: 20),
              ),
              Text('$qty', style: AppTextStyles.labelMd),
              IconButton(
                onPressed: qty < 4 ? () => onChange(qty + 1) : null,
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, int amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMd),
        Text(
          _rupiah(amount),
          style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
