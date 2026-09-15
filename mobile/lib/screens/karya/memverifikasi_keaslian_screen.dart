import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/karya.dart';
import '../../theme/app_theme.dart';

/// Konversi dari
/// docs/design/role_seniman_2/.../galeria_memverifikasi_keaslian_karya/code.html
///
/// UI murni -- logic sesungguhnya (deteksi duplikasi + deteksi AI-generated)
/// adalah scope `ml-digital-art-identity/` (anggota tim lain, lihat
/// CLAUDE.md). Di sini cuma simulasi timer lalu panggil [onDone].
///
/// TODO(ml-digital-art-identity): ganti simulasi timer dengan polling status
/// verifikasi asli dari backend begitu endpointnya ada.
class MemverifikasiKeaslianScreen extends StatefulWidget {
  const MemverifikasiKeaslianScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<MemverifikasiKeaslianScreen> createState() => _MemverifikasiKeaslianScreenState();
}

class _MemverifikasiKeaslianScreenState extends State<MemverifikasiKeaslianScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), widget.onDone);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter, vertical: AppSpacing.lg),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(radius: 3, backgroundColor: AppColors.accent),
                    const SizedBox(width: 6),
                    Text('AUDIT PROVENANSI DIGITAL',
                        style: AppTextStyles.overline.copyWith(color: AppColors.accent)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Memverifikasi Keaslian Karya',
                  textAlign: TextAlign.center, style: AppTextStyles.displayMd.copyWith(fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                'Sistem kecerdasan kuratorial GALERIA sedang menganalisis keaslian fisik dan digital mahakarya Anda.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _spin,
                      child: CustomPaint(
                        size: const Size(200, 200),
                        painter: _ScannerRingsPainter(),
                      ),
                    ),
                    Container(
                      width: 110,
                      height: 130,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.asset(sampleKarya[3].assetPath, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.biotech, size: 12, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text('ANALISIS SPEKTROSKOPI AI',
                                style: AppTextStyles.overline.copyWith(color: Colors.white, fontSize: 8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Column(
                  children: [
                    _stepRow(
                        icon: Icons.check,
                        iconBg: AppColors.success,
                        title: 'Menganalisis kemiripan dengan karya lainnya',
                        subtitle: 'Mendeteksi kemiripan visual, komposisi, & palet karya lain',
                        status: 'Selesai',
                        statusColor: AppColors.success),
                    const SizedBox(height: AppSpacing.xs),
                    _stepRow(
                        loading: true,
                        iconBg: AppColors.accentSoft,
                        title: 'Menganalisis kemungkinan dibuat oleh AI',
                        subtitle: 'Mendeteksi artefak sintetis dan pola piksel generatif AI',
                        status: 'Memindai...',
                        statusColor: AppColors.accent,
                        active: true),
                    const SizedBox(height: AppSpacing.xs),
                    _stepRow(
                        icon: Icons.hourglass_empty,
                        iconBg: AppColors.surfaceContainerHigh,
                        iconColor: AppColors.muted,
                        title: 'Menyusun hasil verifikasi',
                        subtitle: 'Mengagregasi laporan kurasi dan kesimpulan orisinalitas',
                        status: 'Menunggu',
                        statusColor: AppColors.muted,
                        dim: true),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule, size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('Proses ini biasanya memakan waktu kurang dari 30 detik.',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Harap jangan menutup aplikasi selama enkripsi sertifikat berlangsung.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.overline.copyWith(color: AppColors.muted, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepRow({
    IconData? icon,
    bool loading = false,
    required Color iconBg,
    Color iconColor = Colors.white,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    bool active = false,
    bool dim = false,
  }) {
    return Opacity(
      opacity: dim ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceContainerHigh.withValues(alpha: 0.6) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: iconBg,
              child: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(title,
                              style: AppTextStyles.labelMd.copyWith(fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                      Text(status.toUpperCase(),
                          style: AppTextStyles.overline.copyWith(fontSize: 9, color: statusColor)),
                    ],
                  ),
                  Text(subtitle,
                      style: AppTextStyles.bodySm.copyWith(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.accent.withValues(alpha: 0.35);
    canvas.drawCircle(center, size.width / 2, paint);
    canvas.drawCircle(center, size.width / 2.3,
        paint..color = AppColors.accent.withValues(alpha: 0.2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
