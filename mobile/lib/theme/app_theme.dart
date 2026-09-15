// Design token diextract dari export Stitch (docs/design/role_seniman_1 & 2,
// file DESIGN.md "Haute Enchere" + tailwind.config di tiap code.html).
//
// Catatan: 2 sumber desain (welcome_screen vs splash_screen dkk) punya sedikit
// drift warna (beda sesi generate Stitch) -- di-satukan di sini jadi SATU
// palet konsisten: skala netral (surface/on-surface/outline) dari sistem M3
// "Haute Enchere" (DESIGN.md), warna aksen emas dinormalisasi ke #C9A227
// (dipakai paling konsisten & paling representatif utk brand "kurasi karya
// seni" -- lihat logo splash & aksen welcome screen).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const surface = Color(0xFFFBF9F6);
  static const surfaceDim = Color(0xFFDBDAD7);
  static const surfaceBright = Color(0xFFFBF9F6);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF5F3F0);
  static const surfaceContainer = Color(0xFFEFEEEB);
  static const surfaceContainerHigh = Color(0xFFEAE8E5);
  static const surfaceContainerHighest = Color(0xFFE4E2DF);

  static const onSurface = Color(0xFF1B1C1A);
  static const onSurfaceVariant = Color(0xFF444748);
  static const inverseSurface = Color(0xFF30312F);
  static const inverseOnSurface = Color(0xFFF2F0ED);

  static const outline = Color(0xFF747878);
  static const outlineVariant = Color(0xFFC4C7C7);
  static const border = Color(0xFFE8E4DF);

  static const primary = Color(0xFF1C1C1C); // "brand.primary" / primary-container
  static const onPrimary = Color(0xFFFFFFFF);

  // Aksen emas -- warna khas GALERIA (kurasi/lelang karya seni).
  static const accent = Color(0xFFC9A227);
  static const accentSoft = Color(0xFFF3E3B6);

  static const muted = Color(0xFF8A8580);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Dipakai utk status "terverifikasi"/sukses (mis. karya_terverifikasi_asli).
  static const success = Color(0xFF45926F);
  static const successContainer = Color(0xFF002113);
}

class AppRadius {
  AppRadius._();

  static const xs = 2.0;
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0; // "rounded-xl" di sebagian besar layar
  static const full = 999.0;
}

class AppSpacing {
  AppSpacing._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0; // = margin-edge / gutter-screen
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 64.0;

  static const screenGutter = 24.0;
  static const cardInner = 20.0;
  static const touchTarget = 48.0;
  static const bottomNavHeight = 72.0;
}

/// Text style ala design token Stitch (headline-*, body-*, label-*, overline).
/// Font serif (EB Garamond) utk judul/headline, sans (Plus Jakarta Sans) utk
/// body/label -- sesuai konvensi tiap layar Stitch.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _serif => GoogleFonts.ebGaramond();
  static TextStyle get _sans => GoogleFonts.plusJakartaSans();

  static TextStyle get displayLg => _serif.copyWith(
        fontSize: 36,
        height: 44 / 36,
        letterSpacing: -0.02 * 36,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get displayMd => _serif.copyWith(
        fontSize: 30,
        height: 38 / 30,
        letterSpacing: -0.015 * 30,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLg => _serif.copyWith(
        fontSize: 26,
        height: 34 / 26,
        letterSpacing: -0.01 * 26,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => _serif.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineSm => _serif.copyWith(
        fontSize: 18,
        height: 24 / 18,
        letterSpacing: 0.01 * 18,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLg => _sans.copyWith(
        fontSize: 16,
        height: 26 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyMd => _sans.copyWith(
        fontSize: 14,
        height: 22 / 14,
        letterSpacing: 0.01 * 14,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get bodySm => _sans.copyWith(
        fontSize: 12,
        height: 18 / 12,
        letterSpacing: 0.015 * 12,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get labelMd => _sans.copyWith(
        fontSize: 13,
        height: 18 / 13,
        letterSpacing: 0.02 * 13,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get labelSm => _sans.copyWith(
        fontSize: 11,
        height: 16 / 11,
        letterSpacing: 0.06 * 11,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get overline => _sans.copyWith(
        fontSize: 10,
        height: 14 / 10,
        letterSpacing: 0.12 * 10,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.accent,
      onSecondary: AppColors.onPrimary,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLg,
        displayMedium: AppTextStyles.displayMd,
        headlineLarge: AppTextStyles.headlineLg,
        headlineMedium: AppTextStyles.headlineMd,
        headlineSmall: AppTextStyles.headlineSm,
        bodyLarge: AppTextStyles.bodyLg,
        bodyMedium: AppTextStyles.bodyMd,
        bodySmall: AppTextStyles.bodySm,
        labelMedium: AppTextStyles.labelMd,
        labelSmall: AppTextStyles.labelSm,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.labelMd.copyWith(
            color: AppColors.onPrimary,
            fontSize: 15,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          side: BorderSide(color: AppColors.onSurface.withValues(alpha: 0.25)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: AppTextStyles.labelMd.copyWith(fontSize: 15),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineSm,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }
}
