import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_1/.../galeria_verifikasi_identitas/code.html
///
/// TODO(backend): sambungkan tombol "Ganti"/"Unggah Swafoto" ke image
/// picker + endpoint upload dokumen identitas asli. Saat ini murni UI.
class VerifikasiIdentitasScreen extends StatelessWidget {
  const VerifikasiIdentitasScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                  AppSpacing.sm, AppSpacing.screenGutter, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(
                                radius: 3, backgroundColor: AppColors.accent),
                            const SizedBox(width: 6),
                            Text('KOLEKTIF SENIMAN',
                                style: AppTextStyles.overline
                                    .copyWith(color: AppColors.accent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 8,
                            backgroundColor: AppColors.accentSoft,
                            child: Icon(Icons.check,
                                size: 10, color: AppColors.accent),
                          ),
                          const SizedBox(width: 6),
                          Text('Data Diri',
                              style: AppTextStyles.labelSm.copyWith(
                                  decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: 'LANGKAH 2/3: ',
                              style: AppTextStyles.labelSm
                                  .copyWith(color: AppColors.accent)),
                          TextSpan(
                              text: 'Verifikasi',
                              style: AppTextStyles.labelSm
                                  .copyWith(color: AppColors.onSurface)),
                        ]),
                      ),
                      Text('3. Galeri',
                          style: AppTextStyles.labelSm
                              .copyWith(color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _stepBar(true)),
                      const SizedBox(width: 8),
                      Expanded(child: _stepBar(true)),
                      const SizedBox(width: 8),
                      Expanded(child: _stepBar(false)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Verifikasi Identitas', style: AppTextStyles.displayMd
                      .copyWith(fontSize: 32)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sesuai regulasi kurasi karya seni resmi, unggah identitas sah untuk mengamankan sertifikasi hak cipta dan royalti karya Anda.',
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Security banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 18, color: AppColors.accent),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Dokumen dienkripsi standar perbankan 256-bit dan hanya ditinjau oleh Dewan Kurator GALERIA secara tertutup.',
                            style: AppTextStyles.bodySm.copyWith(
                                fontSize: 11.5, color: const Color(0xFF6E5812)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Card 1: Foto KTP (filled state)
                  _KtpCard(),
                  const SizedBox(height: AppSpacing.md),
                  // Card 2: Swafoto (empty state)
                  _SwafotoCard(),
                  const SizedBox(height: AppSpacing.lg),
                  // Requirements
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text('KETENTUAN FOTO DOKUMEN',
                                style: AppTextStyles.overline
                                    .copyWith(color: AppColors.onSurface)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final t in const [
                          'Foto asli berwarna langsung dari kamera fisik, bukan hasil tangkapan layar atau fotokopi.',
                          'Seluruh teks, NIK, dan pasfoto di KTP harus terbaca tajam tanpa pantulan kilat lampu (glare).',
                          'Format file didukung: JPG, PNG, atau HEIC dengan ukuran maksimal 10 MB per berkas.',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('•  ',
                                    style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.bold)),
                                Expanded(
                                    child: Text(t,
                                        style: AppTextStyles.bodySm
                                            .copyWith(fontSize: 11.5))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Sticky bottom CTA
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                    AppSpacing.sm, AppSpacing.screenGutter, AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.95),
                  border: const Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: onContinue,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('Lanjut'),
                          SizedBox(width: AppSpacing.xs),
                          Icon(Icons.arrow_forward, size: 16, color: AppColors.accent),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onSkip,
                      child: Text('Lewati untuk sekarang',
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBar(bool active) => Container(
        height: 4,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      );
}

class _KtpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.badge_outlined,
                    size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Foto KTP',
                        style: AppTextStyles.labelMd.copyWith(fontSize: 14)),
                    Row(
                      children: [
                        const Icon(Icons.check, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text('Siap diverifikasi',
                            style: AppTextStyles.bodySm.copyWith(
                                fontSize: 11, color: Colors.green.shade700)),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Ganti'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  backgroundColor: AppColors.accentSoft.withValues(alpha: 0.6),
                  textStyle: AppTextStyles.labelSm.copyWith(fontSize: 11),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A5F), Color(0xFF0F2038)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      CircleAvatar(radius: 5, backgroundColor: Color(0xFFDC2626)),
                      SizedBox(width: 6),
                      Text('REPUBLIK INDONESIA',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.white38, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('317101•••••••02',
                                style: TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            Text('NIRMALA SARI KUSUMA',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                            Text('JAKARTA, 14-08-1992',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 8)),
                            Text('SENIMAN LUKIS REALISME',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BERLAKU SEUMUR HIDUP',
                          style: TextStyle(color: Colors.white38, fontSize: 8)),
                      Text('✓ Terbaca Jelas',
                          style: TextStyle(
                              color: Colors.greenAccent, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 13, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pastikan seluruh bagian KTP terlihat jelas dan tidak buram.',
                  style: AppTextStyles.bodySm.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwafotoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFDCD6CC), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.sentiment_satisfied_outlined,
                    size: 16, color: AppColors.onSurface),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Swafoto dengan KTP',
                        style: AppTextStyles.labelMd.copyWith(fontSize: 14)),
                    Text('Selfie memegang kartu identitas',
                        style: AppTextStyles.bodySm.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.face_retouching_natural,
                size: 28, color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pegang KTP di samping wajah. Pastikan wajah dan data kartu tidak tertutup jari atau bayangan.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.upload_outlined, size: 16, color: AppColors.accent),
            label: const Text('Unggah Swafoto'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              textStyle: AppTextStyles.labelSm.copyWith(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}
