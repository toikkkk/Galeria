import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Indikator langkah dipakai bersama di 3 layar wizard "Buat Event"
/// (lihat lib/screens/event/buat_event_step*_screen.dart).
class EventStepper extends StatelessWidget {
  const EventStepper({super.key, required this.currentStep});

  final int currentStep; // 1, 2, atau 3

  static const _labels = ['Detail', 'Jadwal & Lokasi', 'Tiket'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var step = 1; step <= 3; step++) ...[
          _buildStep(step),
          if (step != 3)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: step < currentStep ? AppColors.primary : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStep(int step) {
    final done = step < currentStep;
    final active = step == currentStep;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? AppColors.primary : AppColors.surfaceContainerHigh,
            border: active ? Border.all(color: AppColors.accent, width: 2) : null,
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$step',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.onSurfaceVariant,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          _labels[step - 1],
          style: AppTextStyles.labelSm.copyWith(
            color: active ? AppColors.onSurface : AppColors.muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
