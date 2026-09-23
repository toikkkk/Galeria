import 'package:flutter/material.dart';

import '../../../models/karya.dart';
import '../../../theme/app_theme.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR PEMBELIAN PEMBAYARAN/.../galeria_konfirmasi_pesanan/code.html
class KonfirmasiPesananScreen extends StatefulWidget {
  const KonfirmasiPesananScreen({
    super.key,
    required this.karya,
    required this.onBack,
    required this.onLanjut,
  });

  final Karya karya;
  final VoidCallback onBack;
  final VoidCallback onLanjut;

  @override
  State<KonfirmasiPesananScreen> createState() =>
      _KonfirmasiPesananScreenState();
}

class _KonfirmasiPesananScreenState extends State<KonfirmasiPesananScreen> {
  int _shipping = 1; // 0=reguler, 1=kurir seni
  bool _insurance = true;

  static const _hargaReguler = 350000;
  static const _hargaKurirSeni = 1850000;
  static const _asuransi = 725000;
  static const _biayaLayanan = 50000;

  int get _ongkir => _shipping == 0 ? _hargaReguler : _hargaKurirSeni;
  int get _total =>
      widget.karya.priceIdr +
      _ongkir +
      (_insurance ? _asuransi : 0) +
      _biayaLayanan;

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
        title: Text('Konfirmasi Pesanan', style: AppTextStyles.headlineSm),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        children: [
          _stepper(step: 1),
          const SizedBox(height: AppSpacing.md),
          _card(
            title: 'Alamat Pengiriman',
            trailing: TextButton(onPressed: () {}, child: const Text('Ubah')),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Rani Paramita', style: AppTextStyles.labelMd),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'UTAMA',
                          style: AppTextStyles.overline.copyWith(fontSize: 8),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '+62 812-3456-7890',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jl. Teuku Cik Ditiro No. 42, Menteng, Jakarta Pusat, DKI Jakarta 10310',
                    style: AppTextStyles.bodyMd,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _card(
            title: 'Karya Yang Dipesan',
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.asset(
                    widget.karya.assetPath,
                    width: 72,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.karya.title,
                        style: AppTextStyles.headlineSm.copyWith(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        widget.karya.artistName,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        widget.karya.styleName,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.outline,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.karya.priceFormatted,
                        style: AppTextStyles.labelMd.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _card(
            title: 'Metode Pengiriman',
            child: Column(
              children: [
                _shippingOption(
                  0,
                  'Reguler (5–7 hari)',
                  'Pengiriman standar tanpa penanganan termal',
                  _hargaReguler,
                ),
                const SizedBox(height: AppSpacing.xs),
                _shippingOption(
                  1,
                  'Kurir Karya Seni + Packing Kayu (3–5 hari)',
                  'Peti kayu bersertifikasi museum & armada beriklim khusus',
                  _hargaKurirSeni,
                  badge: 'Rekomendasi Kurator',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asuransi Transit & Kurasi Penuh',
                        style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                      ),
                      Text(
                        '+${_rupiah(_asuransi)}',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.accent,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _insurance,
                  onChanged: (v) => setState(() => _insurance = v),
                  activeThumbColor: AppColors.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _card(
            title: 'Rincian Pembayaran',
            child: Column(
              children: [
                _rincianRow('Harga Karya', widget.karya.priceIdr),
                _rincianRow('Ongkos Kirim', _ongkir),
                if (_insurance)
                  _rincianRow('Asuransi Transit (All-Risk)', _asuransi),
                _rincianRow(
                  'Biaya Layanan & Sertifikasi Digital',
                  _biayaLayanan,
                ),
                const Divider(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Pembayaran',
                      style: AppTextStyles.headlineSm.copyWith(fontSize: 15),
                    ),
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
              onPressed: widget.onLanjut,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
              child: const Text('Pilih Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepper({required int step}) => Row(
    children: [
      _stepDot('1', 'Konfirmasi', step >= 1),
      Expanded(
        child: Container(
          height: 2,
          color: step >= 2 ? AppColors.primary : AppColors.border,
        ),
      ),
      _stepDot('2', 'Pembayaran', step >= 2),
      Expanded(
        child: Container(
          height: 2,
          color: step >= 3 ? AppColors.primary : AppColors.border,
        ),
      ),
      _stepDot('3', 'Selesai', step >= 3),
    ],
  );

  Widget _stepDot(String n, String label, bool active) => Column(
    children: [
      CircleAvatar(
        radius: 12,
        backgroundColor: active
            ? AppColors.primary
            : AppColors.surfaceContainerHighest,
        child: Text(
          n,
          style: TextStyle(
            fontSize: 11,
            color: active ? Colors.white : AppColors.muted,
          ),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          fontSize: 9,
          color: active ? AppColors.primary : AppColors.muted,
        ),
      ),
    ],
  );

  Widget _card({
    required String title,
    Widget? trailing,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTextStyles.headlineSm.copyWith(fontSize: 15)),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    ),
  );

  Widget _shippingOption(
    int id,
    String title,
    String desc,
    int price, {
    String? badge,
  }) {
    final selected = _shipping == id;
    return InkWell(
      onTap: () => setState(() => _shipping = id),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceContainerLow : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.primary : AppColors.border,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
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
                        style: AppTextStyles.overline.copyWith(fontSize: 7.5),
                      ),
                    ),
                  Text(
                    title,
                    style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                  ),
                  Text(
                    desc,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _rupiah(price),
              style: AppTextStyles.labelMd.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rincianRow(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.muted),
        ),
        Text(
          _rupiah(value),
          style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
