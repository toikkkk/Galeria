import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/daftar_seniman_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/verifikasi_identitas_screen.dart';
import 'screens/community/community_detail_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/karya/karya_ditolak_screen.dart';
import 'screens/karya/karya_perlu_ditinjau_screen.dart';
import 'screens/karya/karya_terverifikasi_screen.dart';
import 'screens/karya/memverifikasi_keaslian_screen.dart';
import 'screens/karya/unggah_karya_screen.dart';
import 'screens/onboarding/role_selection_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/profile/profil_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GaleriaApp());
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => SplashScreen(
        onFinished: () => context.go('/welcome'),
      ),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => WelcomeScreen(
        onLoginTap: () => context.go('/login'),
        onRegisterTap: () => context.go('/role-selection'),
        onGuestTap: () => context.go('/dashboard'),
      ),
    ),
    GoRoute(
      path: '/role-selection',
      builder: (context, state) => RoleSelectionScreen(
        onBack: () => context.pop(),
        onContinue: (role) {
          if (role == UserRole.seniman) {
            context.go('/daftar-seniman');
          } else {
            context.go('/login');
          }
        },
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(
        onBack: () => context.pop(),
        onLoginSuccess: () => context.go('/dashboard'),
        onRegisterTap: () => context.go('/role-selection'),
      ),
    ),
    GoRoute(
      path: '/daftar-seniman',
      builder: (context, state) => DaftarSenimanScreen(
        onBack: () => context.pop(),
        onContinue: () => context.go('/verifikasi-identitas'),
        onLoginTap: () => context.go('/login'),
      ),
    ),
    GoRoute(
      path: '/verifikasi-identitas',
      builder: (context, state) => VerifikasiIdentitasScreen(
        onBack: () => context.pop(),
        onContinue: () => context.go('/dashboard'),
        onSkip: () => context.go('/dashboard'),
      ),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => DashboardScreen(
        onUploadKarya: () => context.go('/unggah-karya'),
        onNavTap: (i) {
          if (i == 4) context.go('/profil');
        },
        onKomunitasTap: () => context.go('/komunitas'),
      ),
    ),
    GoRoute(
      path: '/profil',
      builder: (context, state) => ProfilScreen(
        onNavTap: (i) {
          if (i == 0) context.go('/dashboard');
        },
        onLogout: () => context.go('/welcome'),
      ),
    ),
    GoRoute(
      path: '/komunitas',
      builder: (context, state) => CommunityDetailScreen(
        onBack: () => context.pop(),
      ),
    ),
    GoRoute(
      path: '/unggah-karya',
      builder: (context, state) => UnggahKaryaScreen(
        onBack: () => context.pop(),
        onSubmitted: () => context.go('/memverifikasi-keaslian'),
      ),
    ),
    GoRoute(
      path: '/memverifikasi-keaslian',
      builder: (context, state) => MemverifikasiKeaslianScreen(
        // TODO(ml-digital-art-identity): harusnya branch ke
        // /karya-terverifikasi, /karya-ditolak, atau /karya-perlu-ditinjau
        // sesuai hasil verifikasi asli -- sementara selalu ke jalur sukses
        // (demo/UI-only, backend verifikasi belum ada).
        onDone: () => context.go('/karya-terverifikasi'),
      ),
    ),
    GoRoute(
      path: '/karya-terverifikasi',
      builder: (context, state) => KaryaTerverifikasiScreen(
        onClose: () => context.go('/dashboard'),
        onLihatGaleri: () => context.go('/dashboard'),
        onUnggahLagi: () => context.go('/unggah-karya'),
      ),
    ),
    GoRoute(
      path: '/karya-ditolak',
      builder: (context, state) => KaryaDitolakScreen(
        onBack: () => context.go('/dashboard'),
        onAjukanBanding: () => context.go('/dashboard'),
      ),
    ),
    GoRoute(
      path: '/karya-perlu-ditinjau',
      builder: (context, state) => KaryaPerluDitinjauScreen(
        onClose: () => context.go('/dashboard'),
        onAjukanPeninjauan: () => context.go('/dashboard'),
        onKembali: () => context.go('/dashboard'),
      ),
    ),
  ],
);

class GaleriaApp extends StatelessWidget {
  const GaleriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GALERIA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
