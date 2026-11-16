import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/galeria_logo.dart';

/// Splash minimalis: hanya logo + tulisan GALERIA, dianimasikan bertahap seperti timeline GSAP
/// (logo membesar dengan pantulan halus -> huruf muncul satu per satu -> garis emas memanjang),
/// lalu content keluar (membesar & memudar) sebelum aplikasi terbuka.
///
/// Catatan: GSAP adalah library JavaScript dan tidak bisa dipakai di Flutter; animasinya dibuat dengan
/// `AnimationController` + `Interval` (satu controller = satu timeline, tiap elemen punya jendela waktunya).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  /// Dipanggil sekali setelah animasi masuk + keluar selesai.
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _kata = 'GALERIA';

  late final AnimationController _masuk = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  // 250 ms pertama = jeda tahan (hasil akhir terbaca), sisanya animasi keluar.
  late final AnimationController _keluar = AnimationController(vsync: this, duration: const Duration(milliseconds: 730));
  bool _selesai = false;

  @override
  void initState() {
    super.initState();
    _masuk.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _keluar.forward();
    });
    _keluar.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_selesai) {
        _selesai = true;
        widget.onFinished();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _masuk.forward();
    });
  }

  @override
  void dispose() {
    _masuk.dispose();
    _keluar.dispose();
    super.dispose();
  }

  /// Nilai 0..1 untuk satu elemen pada jendela waktu [awal, akhir] dari timeline masuk.
  double _t(double awal, double akhir, Curve kurva) => Interval(awal, akhir, curve: kurva).transform(_masuk.value);

  @override
  Widget build(BuildContext context) {
    final kurangiGerak = MediaQuery.of(context).disableAnimations;
    if (kurangiGerak && !_masuk.isAnimating && _masuk.value == 0) {
      // aksesibilitas: tanpa gerak, tampilkan langsung lalu lanjut
      _masuk.duration = const Duration(milliseconds: 350);
      _keluar.duration = const Duration(milliseconds: 300);
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_masuk, _keluar]),
          builder: (context, _) {
            final k = const Interval(0.34, 1.0, curve: Curves.easeInCubic).transform(_keluar.value);
            final logoSkala = 0.55 + 0.45 * _t(0.0, 0.38, Curves.easeOutBack);
            final logoAlpha = _t(0.0, 0.2, Curves.easeOut);
            final halo = _t(0.05, 0.5, Curves.easeOutCubic);
            final garis = _t(0.62, 0.84, Curves.easeInOutCubic);
            return Opacity(
              opacity: 1 - k,
              child: Transform.translate(
                offset: Offset(0, -14 * k),
                child: Transform.scale(
                  scale: 1 + 0.12 * k,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // halo emas lembut yang melebar di belakang logo
                          Opacity(
                            opacity: (1 - halo) * 0.55,
                            child: Container(
                              width: 120 + 120 * halo,
                              height: 120 + 120 * halo,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.accent, width: 1.5),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: logoAlpha,
                            child: Transform.scale(scale: logoSkala, child: const GaleriaLogo(size: 124)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _kata.length; i++) _huruf(i),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(width: 48 * garis, height: 2, color: AppColors.accent),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Satu huruf: bergantian (stagger 70 ms), naik 18 px sambil memudar masuk.
  Widget _huruf(int i) {
    const mulai = 0.24, jeda = 0.045, lama = 0.22;
    final t = _t(mulai + i * jeda, mulai + i * jeda + lama, Curves.easeOutCubic);
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - t)),
        child: Text(_kata[i], style: AppTextStyles.displayLg.copyWith(fontSize: 38, letterSpacing: 7, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
