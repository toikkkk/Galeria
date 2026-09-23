import 'package:flutter/material.dart';

import '../../../models/lelang.dart';
import '../../../theme/app_theme.dart';

/// Konversi dari
/// docs/KOLEKTOR FITUR UTAMA/.../galeria_pasang_bid_bottom_sheet/code.html
///
/// TODO(backend): submit bid ke endpoint lelang nyata -- saat ini hanya
/// menutup sheet & memanggil callback tanpa validasi lelang berjalan.
Future<void> showPasangBidSheet(BuildContext context, LelangLot lot) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PasangBidSheet(lot: lot),
  );
}

class _PasangBidSheet extends StatefulWidget {
  const _PasangBidSheet({required this.lot});

  final LelangLot lot;

  @override
  State<_PasangBidSheet> createState() => _PasangBidSheetState();
}

class _PasangBidSheetState extends State<_PasangBidSheet> {
  static const _increment = 1000000;
  late int _bidValue = widget.lot.currentBidIdr + _increment;
  bool _autoBid = true;
  bool _submitting = false;

  String _formatRupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.sm,
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                  ),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pasang Bid', style: AppTextStyles.headlineLg),
                            Text(
                              'Bid tertinggi: ${widget.lot.currentBidFormatted}',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Image.asset(
                              widget.lot.karya.assetPath,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LOT NO. ${widget.lot.lotNumber}',
                                  style: AppTextStyles.overline.copyWith(
                                    fontSize: 9,
                                  ),
                                ),
                                Text(
                                  widget.lot.karya.title,
                                  style: AppTextStyles.headlineSm.copyWith(
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'NOMINAL TAWARAN ANDA',
                            style: AppTextStyles.overline.copyWith(fontSize: 9),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton.filled(
                                onPressed: () => setState(
                                  () => _bidValue = (_bidValue - _increment)
                                      .clamp(
                                        widget.lot.currentBidIdr + _increment,
                                        1 << 31,
                                      ),
                                ),
                                icon: const Icon(Icons.remove),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      AppColors.surfaceContainerLow,
                                  foregroundColor: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                'Rp ${_formatRupiah(_bidValue)}',
                                style: AppTextStyles.displayMd.copyWith(
                                  fontSize: 24,
                                ),
                              ),
                              IconButton.filled(
                                onPressed: () =>
                                    setState(() => _bidValue += _increment),
                                icon: const Icon(Icons.add),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              'Memenuhi kelipatan sah (+Rp 1.000.000)',
                              style: AppTextStyles.bodySm.copyWith(
                                fontSize: 11,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        for (final v in [1000000, 2500000, 5000000]) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(
                                () => _bidValue = widget.lot.currentBidIdr + v,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                side: const BorderSide(color: AppColors.accent),
                              ),
                              child: Text(
                                '+Rp ${_formatRupiah(v)}',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                          if (v != 5000000) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.smart_toy_outlined,
                                      size: 18,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Aktifkan Auto-Bid',
                                        style: AppTextStyles.labelMd.copyWith(
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _autoBid,
                                onChanged: (v) => setState(() => _autoBid = v),
                                activeThumbColor: AppColors.accent,
                              ),
                            ],
                          ),
                          Text(
                            'Kelipatan tawaran otomatis dinaikkan sistem sampai batas maksimum yang Anda tentukan.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          if (_autoBid) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Batas Maksimum',
                                  style: AppTextStyles.bodySm.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  'Rp ${_formatRupiah(widget.lot.currentBidIdr + 15 * _increment)}',
                                  style: AppTextStyles.labelSm.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tawaran tidak dapat dibatalkan sesuai ketentuan Balai Lelang GALERIA.',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
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
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          setState(() => _submitting = true);
                          await Future.delayed(
                            const Duration(milliseconds: 700),
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.gavel, size: 16),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Konfirmasi Bid Rp ${_formatRupiah(_bidValue)}',
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
