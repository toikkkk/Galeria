import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Komponen kecil yang dipakai bersama 3 langkah wizard "Buat Event".

Widget eventLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: AppTextStyles.labelMd),
    );

InputDecoration eventDekor(String hint, {String? prefix}) => InputDecoration(
      hintText: hint,
      prefixText: prefix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );

class EventSectionCard extends StatelessWidget {
  const EventSectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.cardInner),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headlineSm),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Bar bawah wizard: tombol kembali/simpan + lanjut.
class EventBottomBar extends StatelessWidget {
  const EventBottomBar({
    super.key,
    required this.lanjutLabel,
    required this.onLanjut,
    this.onKembali,
  });

  final String lanjutLabel;
  final VoidCallback? onLanjut;
  final VoidCallback? onKembali;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          children: [
            if (onKembali != null) ...[
              Expanded(
                child: OutlinedButton(onPressed: onKembali, child: const Text('Kembali')),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(onPressed: onLanjut, child: Text(lanjutLabel)),
            ),
          ],
        ),
      ),
    );
  }
}
