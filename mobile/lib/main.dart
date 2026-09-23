import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/karya.dart';
import 'models/lelang.dart';
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
import 'screens/kolektor/auth/daftar_kolektor_screen.dart';
import 'screens/kolektor/auth/preferensi_genre_screen.dart';
import 'screens/kolektor/beranda/beranda_kolektor_screen.dart';
import 'screens/kolektor/event/e_tiket_screen.dart';
import 'screens/kolektor/event/event_screen.dart';
import 'screens/kolektor/event/tiket_checkout_screen.dart';
import 'screens/kolektor/karya/detail_karya_screen.dart';
import 'screens/kolektor/karya/profil_toko_screen.dart';
import 'screens/kolektor/karya/semua_karya_screen.dart';
import 'screens/kolektor/koleksi/koleksi_saya_screen.dart';
import 'screens/kolektor/lelang/detail_lelang_screen.dart';
import 'screens/kolektor/lelang/lelang_screen.dart';
import 'screens/kolektor/notifikasi/notifikasi_screen.dart';
import 'screens/kolektor/pesanan/daftar_pesanan_screen.dart';
import 'screens/kolektor/pesanan/konfirmasi_pesanan_screen.dart';
import 'screens/kolektor/pesanan/pesanan_selesai_screen.dart';
import 'screens/kolektor/pesanan/selesaikan_pembayaran_screen.dart';
import 'screens/kolektor/profile/profil_kolektor_screen.dart';
import 'screens/kolektor/scan/ar_ruangan_screen.dart';
import 'screens/kolektor/scan/visual_search_camera_screen.dart';
import 'screens/onboarding/role_selection_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/profile/profil_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GaleriaApp());
}

/// Handler bersama untuk bottom-nav Kolektor (0=Beranda, 1=Lelang,
/// 2=Pesanan, 3=Profil).
void _goKolektorTab(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go('/beranda-kolektor');
    case 1:
      context.go('/lelang');
    case 2:
      context.go('/pesanan');
    case 3:
      context.go('/profil-kolektor');
  }
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) =>
          SplashScreen(onFinished: () => context.go('/welcome')),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => WelcomeScreen(
        onLoginTap: () => context.go('/login'),
        onRegisterTap: () => context.go('/role-selection'),
        // Sebelumnya selalu ke '/dashboard' (Seniman) -- ini penyebab utama
        // "masuk sebagai tamu langsung jadi Seniman". Tamu = pengalaman
        // Kolektor (jelajah katalog), sesuai use-case marketplace utama.
        onGuestTap: () => context.go('/beranda-kolektor'),
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
            context.go('/daftar-kolektor');
          }
        },
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(
        onBack: () => context.pop(),
        onLoginSuccess: (role) {
          if (role == UserRole.seniman) {
            context.go('/dashboard');
          } else {
            context.go('/beranda-kolektor');
          }
        },
        onRegisterTap: () => context.go('/role-selection'),
      ),
    ),

    // --- Alur Seniman (sudah ada sebelumnya, tidak diubah) ---
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
      builder: (context, state) =>
          CommunityDetailScreen(onBack: () => context.pop()),
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

    // --- Alur Kolektor ---
    GoRoute(
      path: '/daftar-kolektor',
      builder: (context, state) => DaftarKolektorScreen(
        onBack: () => context.pop(),
        onContinue: () => context.go('/preferensi-genre'),
        onLoginTap: () => context.go('/login'),
      ),
    ),
    GoRoute(
      path: '/preferensi-genre',
      builder: (context, state) => PreferensiGenreScreen(
        onBack: () => context.pop(),
        onContinue: () => context.go('/beranda-kolektor'),
        onSkip: () => context.go('/beranda-kolektor'),
      ),
    ),
    GoRoute(
      path: '/beranda-kolektor',
      builder: (context, state) => BerandaKolektorScreen(
        onNavTap: (i) => _goKolektorTab(context, i),
        onPindai: () => context.push('/pindai'),
        onLelangTap: () => context.push('/lelang'),
        onEventTap: () => context.push('/event'),
        onKoleksiTap: () => context.push('/koleksi-saya'),
        onKaryaTap: (karya) => context.push('/karya/detail', extra: karya),
        onLihatSemuaTap: () => context.push('/karya/semua'),
        onProfilTap: () => context.push('/profil-kolektor'),
        onNotifikasiTap: () => context.push('/notifikasi'),
      ),
    ),
    GoRoute(
      path: '/notifikasi',
      builder: (context, state) => NotifikasiScreen(
        onBack: () => context.pop(),
        onPesananTap: () => context.push('/pesanan'),
        onLelangTap: () => context.push('/lelang'),
        onEventTap: () => context.push('/event'),
        onRekomendasiTap: () => context.push('/karya/semua'),
        onSertifikatTap: () => context.push('/koleksi-saya'),
      ),
    ),
    GoRoute(
      path: '/karya/semua',
      builder: (context, state) => SemuaKaryaScreen(
        onBack: () => context.pop(),
        onKaryaTap: (karya) => context.push('/karya/detail', extra: karya),
      ),
    ),
    GoRoute(
      path: '/lelang',
      builder: (context, state) => LelangScreen(
        onBack: () => context.pop(),
        onNavTap: (i) => _goKolektorTab(context, i),
        onPindai: () => context.push('/pindai'),
        onDetailTap: (lot) => context.push('/lelang/detail', extra: lot),
      ),
    ),
    GoRoute(
      path: '/lelang/detail',
      builder: (context, state) => DetailLelangScreen(
        lot: (state.extra as LelangLot?) ?? sampleLelang.first,
        onBack: () => context.pop(),
      ),
    ),
    GoRoute(
      path: '/koleksi-saya',
      builder: (context, state) => KoleksiSayaScreen(
        onNavTap: (i) => _goKolektorTab(context, i),
        onPindai: () => context.push('/pindai'),
      ),
    ),
    GoRoute(
      path: '/event',
      builder: (context, state) => EventScreen(
        onBack: () => context.pop(),
        onDaftarTap: () => context.push('/event/tiket'),
      ),
    ),
    GoRoute(
      path: '/event/tiket',
      builder: (context, state) => TiketCheckoutScreen(
        onBack: () => context.pop(),
        onPaid: () => context.push('/event/e-tiket'),
      ),
    ),
    GoRoute(
      path: '/event/e-tiket',
      builder: (context, state) =>
          ETiketScreen(onDone: () => context.go('/beranda-kolektor')),
    ),
    GoRoute(
      path: '/karya/detail',
      builder: (context, state) {
        final karya = (state.extra as Karya?) ?? sampleKarya.first;
        return DetailKaryaScreen(
          karya: karya,
          onBack: () => context.pop(),
          onArTap: () => context.push('/pindai/ar', extra: karya),
          onBeliTap: () => context.push('/pesanan/konfirmasi', extra: karya),
          onTokoTap: () => context.push('/toko'),
        );
      },
    ),
    GoRoute(
      path: '/toko',
      builder: (context, state) => ProfilTokoScreen(
        onBack: () => context.pop(),
        onKaryaTap: (karya) => context.push('/karya/detail', extra: karya),
      ),
    ),
    GoRoute(
      path: '/pesanan',
      builder: (context, state) => DaftarPesananScreen(
        onNavTap: (i) => _goKolektorTab(context, i),
        onPindai: () => context.push('/pindai'),
        onBayarTap: (total) =>
            context.push('/pesanan/pembayaran', extra: total),
        onDetailTap: (karya) => context.push('/pesanan/selesai', extra: karya),
      ),
    ),
    GoRoute(
      path: '/pesanan/konfirmasi',
      builder: (context, state) {
        final karya = (state.extra as Karya?) ?? sampleKarya.first;
        return KonfirmasiPesananScreen(
          karya: karya,
          onBack: () => context.pop(),
          // Estimasi total (kurir seni + asuransi + biaya layanan default) --
          // demo lokal, belum ada state pembayaran nyata lintas layar.
          onLanjut: () => context.push(
            '/pesanan/pembayaran',
            extra: karya.priceIdr + 2625000,
          ),
        );
      },
    ),
    GoRoute(
      path: '/pesanan/pembayaran',
      builder: (context, state) => SelesaikanPembayaranScreen(
        totalIdr: (state.extra as int?) ?? 147625000,
        onBack: () => context.pop(),
        onSudahBayar: () =>
            context.push('/pesanan/selesai', extra: sampleKarya.first),
      ),
    ),
    GoRoute(
      path: '/pesanan/selesai',
      builder: (context, state) => PesananSelesaiScreen(
        karya: (state.extra as Karya?) ?? sampleKarya.first,
        onSelesai: () => context.go('/koleksi-saya'),
      ),
    ),
    GoRoute(
      path: '/pindai',
      builder: (context, state) => VisualSearchCameraScreen(
        onBack: () => context.pop(),
        onArTap: () => context.push('/pindai/ar'),
        onKaryaTap: (karya) => context.push('/karya/detail', extra: karya),
      ),
    ),
    GoRoute(
      path: '/pindai/ar',
      builder: (context, state) => ArRuanganScreen(
        onClose: () => context.pop(),
        karya: state.extra as Karya?,
      ),
    ),
    GoRoute(
      path: '/profil-kolektor',
      builder: (context, state) => ProfilKolektorScreen(
        onNavTap: (i) => _goKolektorTab(context, i),
        onPindai: () => context.push('/pindai'),
        onLogout: () => context.go('/welcome'),
        onPesananTap: () => context.push('/pesanan'),
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
