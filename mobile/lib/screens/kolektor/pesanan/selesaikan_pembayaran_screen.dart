import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR PEMBELIAN PEMBAYARAN/.../galeria_selesaikan_pembayaran/code.html
///
/// TODO(backend): sambungkan ke payment gateway nyata + polling status VA --
/// saat ini tombol "Saya Sudah Bayar" langsung lanjut tanpa verifikasi.
class SelesaikanPembayaranScreen extends StatelessWidget {
  const SelesaikanPembayaranScreen({
    super.key,
    required this.totalIdr,
    required this.onBack,
    required this.onSudahBayar,
  });

  final int totalIdr;
  final VoidCallback onBack;
  final VoidCallback onSudahBayar;

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
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Selesaikan Pembayaran', style: AppTextStyles.headlineSm),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Chip(
              avatar: const Icon(Icons.lock, size: 14, color: AppColors.accent),
              label: const Text('Aman'),
              labelStyle: AppTextStyles.labelSm.copyWith(fontSize: 10),
              backgroundColor: AppColors.surfaceContainer,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: AppColors.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'BATAS WAKTU PELUNASAN',
                            style: AppTextStyles.overline.copyWith(
                              fontSize: 9,
                              color: AppColors.error,
                            ),
                          ),
                          Text(
                            '23:47:10',
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Jatuh tempo besok, pukul 11:30 WIB',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL TAGIHAN KURASI',
                      style: AppTextStyles.overline.copyWith(fontSize: 9),
                    ),
                    Text(
                      _rupiah(totalIdr),
                      style: AppTextStyles.displayMd.copyWith(fontSize: 22),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.content_copy, size: 18),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00529C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'BCA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Virtual Account BCA',
                            style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                          ),
                          Text(
                            'Pembayaran Otomatis',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOMOR VIRTUAL ACCOUNT',
                            style: AppTextStyles.overline.copyWith(fontSize: 8),
                          ),
                          Text(
                            '8801 2940 1827 4920',
                            style: AppTextStyles.labelMd.copyWith(
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.content_copy, size: 14),
                        label: const Text('Salin'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Atas nama rekening penampung: GALERIA ESCROW',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Petunjuk Pelunasan', style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.xs),
          _accordion(context, 'm-BCA (BCA Mobile)', [
            'Buka aplikasi BCA Mobile, pilih menu m-Transfer.',
            'Pilih BCA Virtual Account, input nomor VA.',
            'Verifikasi nama & nominal tagihan penuh.',
            'Masukkan PIN m-BCA untuk konfirmasi.',
          ], initiallyExpanded: true),
          _accordion(context, 'KlikBCA / Internet Banking', [
            'Masuk ke KlikBCA Individual, login akun Anda.',
            'Pilih Transfer Dana → Transfer ke BCA Virtual Account.',
            'Masukkan kode VA dan verifikasi token KeyBCA.',
          ]),
          _accordion(context, 'ATM BCA', [
            'Masukkan Kartu ATM BCA & PIN.',
            'Pilih Transaksi Lainnya → Transfer → Ke Rekening BCA Virtual Account.',
            'Input nomor VA dan konfirmasi data transaksi.',
          ]),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pesanan otomatis dibatalkan jika transfer tidak terkonfirmasi sebelum batas waktu berakhir.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: onSudahBayar,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Saya Sudah Bayar'),
            ),
            TextButton(
              onPressed: onBack,
              child: const Text('Ganti Metode Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accordion(
    BuildContext context,
    String title,
    List<String> steps, {
    bool initiallyExpanded = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(title, style: AppTextStyles.labelMd.copyWith(fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: AppColors.surfaceContainer,
                          child: Text(
                            '${i + 1}',
                            style: AppTextStyles.overline.copyWith(fontSize: 9),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(steps[i], style: AppTextStyles.bodySm),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
