import 'models/picked_image.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'services/digital_art_identity_service.dart';

import 'models/karya.dart';
import 'models/lelang.dart';
import 'screens/auth/daftar_seniman_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/verifikasi_identitas_screen.dart';
import 'screens/community/community_detail_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/event/buat_event_step1_screen.dart';
import 'screens/event/buat_event_step2_screen.dart';
import 'screens/event/buat_event_step3_screen.dart';
import 'screens/event/event_berhasil_screen.dart';
import 'screens/community/komunitas_seniman_screen.dart';
import 'screens/lelang/buat_lelang_screen.dart';
import 'state/studio_store.dart';
import 'widgets/pro_gate.dart';
import 'screens/dashboard/notifikasi_seniman_screen.dart';
import 'screens/dashboard/riwayat_penarikan_screen.dart';
import 'screens/karya/karya_ditolak_screen.dart';
import 'screens/karya/karya_perlu_ditinjau_screen.dart';
import 'screens/karya/karya_saya_screen.dart';
import 'screens/karya/karya_terverifikasi_screen.dart';
import 'screens/karya/memverifikasi_keaslian_screen.dart';
import 'screens/karya/promosikan_karya_screen.dart';
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
import 'screens/pesanan/pesanan_seniman_screen.dart';
import 'screens/profile/profil_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GaleriaApp());
}

/// Routing hasil verifikasi Digital Art Identity (Art-to-Art + Art-to-AI)
/// berdasarkan `rekomendasi_status` ASLI dari backend -- lihat
/// DigitalArtIdentityService._decide_status (backend/services/
/// digital_art_identity_service.py) untuk aturan lengkapnya.
void _goToHasilVerifikasi(BuildContext context, VerificationResult result) {
  switch (result.rekomendasiStatus) {
    case 'ditolak':
      context.go('/karya-ditolak', extra: result);
    case 'perlu_ditinjau':
      context.go('/karya-perlu-ditinjau', extra: result);
    default: // 'terverifikasi'
      context.go('/karya-terverifikasi', extra: result);
  }
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

/// Bottom nav 5-slot role Seniman (DashboardScreen & ProfilScreen) --
/// SEBELUMNYA index 1 ("Karya") tidak punya tujuan SAMA SEKALI di seluruh
/// app (gap sistemik, bukan cuma lupa isi callback). Disatukan jadi 1
/// fungsi (pola sama dgn [_goKolektorTab]) supaya kedua layar konsisten.
/// Lihat audit navigasi role Seniman, 2026-10.
///
/// Index 0/1/4 (Dasbor/Karya Saya/Profil) TETAP pakai `go()` -- 3 layar ini
/// tidak pernah bergantung pada `context.pop()` utk tombol kembalinya
/// (Dasbor & Profil malah tidak punya tombol kembali sama sekali, Karya
/// Saya eksplisit `go('/dashboard')`), jadi aman jadi tab-switch murni
/// tanpa riwayat numpuk -- pola standar bottom nav.
///
/// Index 2 (FAB tengah, "+") pakai `push()` -- /unggah-karya PUNYA tombol
/// kembali yang pakai `context.pop()`, jadi WAJIB ada riwayat navigasi
/// supaya kembali ke tab manapun yang sedang aktif saat FAB ditekan
/// (bukan selalu balik ke Dasbor). Lihat perbaikan navigasi "kembali"
/// role Seniman, 2026-10.
void _goSenimanTab(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go('/dashboard');
    case 1:
      context.go('/karya-saya');
    case 2:
      context.push('/unggah-karya');
    case 3:
      context.go('/pesanan-seniman');
    case 4:
      context.go('/profil');
  }
}

// ---------------------------------------------------------------------------
// Navigasi "kembali" yang aman + perilaku tombol back Android
// ---------------------------------------------------------------------------

const _berandaKolektor = '/beranda-kolektor';
const _dasborSeniman = '/dashboard';

const _prefixSeniman = [
  '/dashboard', '/notifikasi-seniman', '/riwayat-penarikan', '/profil', '/karya-saya', '/komunitas',
  '/buat-lelang', '/unggah-karya', '/memverifikasi-keaslian', '/karya-terverifikasi', '/karya-ditolak',
  '/karya-perlu-ditinjau', '/pesanan-seniman', '/promosikan-karya', '/buat-event', '/event-berhasil',
  '/daftar-seniman', '/verifikasi-identitas',
];
const _prefixKolektor = [
  '/beranda-kolektor', '/notifikasi', '/karya/', '/lelang', '/koleksi-saya', '/event', '/toko', '/pesanan',
  '/pindai', '/profil-kolektor', '/preferensi-genre', '/daftar-kolektor',
];

/// Halaman "beranda" sesuai peran pengguna di [path]; `/welcome` untuk layar masuk/onboarding.
String _berandaUntuk(String path) {
  bool cocok(List<String> daftar) => daftar.any(
    (p) => path == p || path.startsWith(p.endsWith('/') ? p : '$p/') || (p == '/profil' && path == '/profil'),
  );
  if (path == '/profil-kolektor' || cocok(_prefixKolektor)) return _berandaKolektor;
  if (cocok(_prefixSeniman)) return _dasborSeniman;
  return '/welcome';
}

String _lokasiSekarang() => _router.routeInformationProvider.value.uri.path;

/// Tombol kembali di dalam layar: kembali satu langkah bila ada riwayat; bila layar dibuka lewat
/// `go()` (tanpa riwayat) -- yang membuat `pop()` biasa tidak berbuat apa-apa -- pindah ke beranda
/// peran yang sama, kecuali sudah di beranda.
void _kembali(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final tujuan = _berandaUntuk(_lokasiSekarang());
  if (tujuan != _lokasiSekarang()) context.go(tujuan);
}

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

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
        // push (bukan go) -- /login & /role-selection pakai context.pop()
        // utk tombol kembali, butuh riwayat navigasi supaya ada tujuan.
        // Lihat perbaikan navigasi "kembali" role Seniman, 2026-10.
        onLoginTap: () => context.push('/login'),
        onRegisterTap: () => context.push('/role-selection'),
        // Sebelumnya selalu ke '/dashboard' (Seniman) -- ini penyebab utama
        // "masuk sebagai tamu langsung jadi Seniman". Tamu = pengalaman
        // Kolektor (jelajah katalog), sesuai use-case marketplace utama.
        onGuestTap: () => context.go('/beranda-kolektor'),
      ),
    ),
    GoRoute(
      path: '/role-selection',
      builder: (context, state) => RoleSelectionScreen(
        onBack: () => _kembali(context),
        onContinue: (role) {
          // push -- sama alasannya, /daftar-seniman & /daftar-kolektor
          // pakai context.pop() utk tombol kembali.
          if (role == UserRole.seniman) {
            context.push('/daftar-seniman');
          } else {
            context.push('/daftar-kolektor');
          }
        },
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(
        onBack: () => _kembali(context),
        onLoginSuccess: (role) {
          if (role == UserRole.seniman) {
            context.go('/dashboard');
          } else {
            context.go('/beranda-kolektor');
          }
        },
        // push -- sama alasan di atas.
        onRegisterTap: () => context.push('/role-selection'),
      ),
    ),

    // --- Alur Seniman (sudah ada sebelumnya, tidak diubah) ---
    GoRoute(
      path: '/daftar-seniman',
      builder: (context, state) => DaftarSenimanScreen(
        onBack: () => _kembali(context),
        // push -- /verifikasi-identitas pakai context.pop() (BUKAN cuma
        // dipanggil dari sini, lihat juga onDataDiri di /profil di bawah,
        // yang sudah push -- kalau dua entry point beda (go vs push), pop()
        // hanya benar utk salah satunya).
        onContinue: () => context.push('/verifikasi-identitas'),
        onLoginTap: () => context.push('/login'),
      ),
    ),
    GoRoute(
      path: '/verifikasi-identitas',
      builder: (context, state) => VerifikasiIdentitasScreen(
        onBack: () => _kembali(context),
        onContinue: () => context.go('/dashboard'),
        onSkip: () => context.go('/dashboard'),
      ),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => DashboardScreen(
        // push -- /unggah-karya & /komunitas pakai context.pop() utk
        // tombol kembali, butuh riwayat navigasi.
        onUploadKarya: () => context.push('/unggah-karya'),
        onNavTap: (i) => _goSenimanTab(context, i),
        onKomunitasTap: () => context.push('/komunitas'),
        onBuatLelang: () => context.push('/buat-lelang'),
        // Event & promosi = fitur Seniman PRO -- pop up upgrade dulu.
        onAdakanEvent: () async {
          if (await ensurePro(context, fitur: 'Membuat event pameran')) {
            if (context.mounted) {
              StudioStore.instance.mulaiDraftEvent();
              context.push('/buat-event/1');
            }
          }
        },
        onPromosikanKarya: () async {
          if (await ensurePro(context, fitur: 'Mempromosikan karya')) {
            if (context.mounted) context.push('/promosikan-karya');
          }
        },
        onNotifikasiTap: () => context.push('/notifikasi-seniman'),
        onRiwayatTap: () => context.push('/riwayat-penarikan'),
      ),
    ),
    GoRoute(
      path: '/notifikasi-seniman',
      builder: (context, state) =>
          NotifikasiSenimanScreen(onBack: () => _kembali(context)),
    ),
    GoRoute(
      path: '/riwayat-penarikan',
      builder: (context, state) =>
          RiwayatPenarikanScreen(onBack: () => _kembali(context)),
    ),
    GoRoute(
      path: '/profil',
      builder: (context, state) => ProfilScreen(
        onNavTap: (i) => _goSenimanTab(context, i),
        onLogout: () => context.go('/welcome'),
        onLihatProfilToko: () => context.push('/toko'),
        onDataDiri: () => context.push('/verifikasi-identitas'),
      ),
    ),
    GoRoute(
      path: '/karya-saya',
      builder: (context, state) => KaryaSayaScreen(
        onBack: () => context.go('/dashboard'),
        onUploadKarya: () => context.push('/unggah-karya'),
        onKaryaTap: (karya) => context.push('/karya/detail', extra: karya),
      ),
    ),
    GoRoute(
      path: '/komunitas',
      builder: (context, state) => KomunitasSenimanScreen(
        onBack: () => _kembali(context),
        onLihatKomunitas: () => context.push('/komunitas/detail'),
        onBuatEvent: () async {
          if (await ensurePro(context, fitur: 'Membuat event pameran')) {
            if (context.mounted) {
              StudioStore.instance.mulaiDraftEvent();
              context.push('/buat-event/1');
            }
          }
        },
      ),
    ),
    GoRoute(
      path: '/komunitas/detail',
      builder: (context, state) =>
          CommunityDetailScreen(onBack: () => _kembali(context)),
    ),
    GoRoute(
      path: '/buat-lelang',
      builder: (context, state) => BuatLelangScreen(
        onBack: () => _kembali(context),
        onUnggahKarya: () => context.push('/unggah-karya'),
      ),
    ),
    GoRoute(
      path: '/unggah-karya',
      builder: (context, state) => UnggahKaryaScreen(
        onBack: () => _kembali(context),
        onSubmitted: (data) => context.go('/memverifikasi-keaslian', extra: data),
      ),
    ),
    GoRoute(
      path: '/memverifikasi-keaslian',
      builder: (context, state) {
        final data = state.extra as ({PickedImage image, String karyaId});
        return MemverifikasiKeaslianScreen(
          image: data.image,
          karyaId: data.karyaId,
          // Branch ke layar hasil sesuai `rekomendasi_status` ASLI dari
          // backend (lihat DigitalArtIdentityService._decide_status) --
          // bukan selalu ke jalur sukses lagi.
          onDone: (result) => _goToHasilVerifikasi(context, result),
        );
      },
    ),
    GoRoute(
      path: '/karya-terverifikasi',
      builder: (context, state) => KaryaTerverifikasiScreen(
        result: state.extra as VerificationResult?,
        onClose: () => context.go('/dashboard'),
        onLihatGaleri: () => context.go('/dashboard'),
        // push -- samakan dgn 2 entry point lain ke /unggah-karya (dashboard
        // quick-action & FAB), supaya tombol kembalinya (pop()) konsisten
        // berfungsi apa pun jalur masuknya.
        onUnggahLagi: () => context.push('/unggah-karya'),
      ),
    ),
    GoRoute(
      path: '/karya-ditolak',
      builder: (context, state) => KaryaDitolakScreen(
        result: state.extra as VerificationResult?,
        onBack: () => context.go('/dashboard'),
        onAjukanBanding: () => context.go('/dashboard'),
      ),
    ),
    GoRoute(
      path: '/karya-perlu-ditinjau',
      builder: (context, state) => KaryaPerluDitinjauScreen(
        result: state.extra as VerificationResult?,
        onClose: () => context.go('/dashboard'),
        onAjukanPeninjauan: () => context.go('/dashboard'),
        onKembali: () => context.go('/dashboard'),
      ),
    ),
    GoRoute(
      path: '/pesanan-seniman',
      builder: (context, state) => PesananSenimanScreen(
        // Dituju via tab-switch (go(), lihat _goSenimanTab) -- pop() tidak
        // bisa diandalkan (bisa tidak ada riwayat). Pola sama dgn
        // /karya-saya.
        onBack: () => context.go('/dashboard'),
      ),
    ),
    GoRoute(
      path: '/promosikan-karya',
      builder: (context, state) => PromosikanKaryaScreen(
        karya: state.extra as Karya?,
        onBack: () => _kembali(context),
        onUnggahKarya: () => context.push('/unggah-karya'),
        onLanjut: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Label promosi aktif pada karya kamu.')),
          );
          _kembali(context);
        },
      ),
    ),
    GoRoute(
      path: '/buat-event/1',
      builder: (context, state) => BuatEventStep1Screen(
        onClose: () => _kembali(context),
        onLanjut: () => context.push('/buat-event/2'),
        onUnggahKarya: () => context.push('/unggah-karya'),
      ),
    ),
    GoRoute(
      path: '/buat-event/2',
      builder: (context, state) => BuatEventStep2Screen(
        onKembali: () => _kembali(context),
        onLanjut: () => context.push('/buat-event/3'),
      ),
    ),
    GoRoute(
      path: '/buat-event/3',
      builder: (context, state) => BuatEventStep3Screen(
        onKembali: () => _kembali(context),
        onTerbitkan: () => context.go('/event-berhasil'),
      ),
    ),
    GoRoute(
      path: '/event-berhasil',
      builder: (context, state) => EventBerhasilScreen(
        onKelolaEvent: () => context.go('/dashboard'),
        onKembaliDasbor: () => context.go('/dashboard'),
      ),
    ),

    // --- Alur Kolektor ---
    GoRoute(
      path: '/daftar-kolektor',
      builder: (context, state) => DaftarKolektorScreen(
        onBack: () => _kembali(context),
        // push -- /preferensi-genre pakai context.pop() utk tombol kembali.
        onContinue: () => context.push('/preferensi-genre'),
        onLoginTap: () => context.push('/login'),
      ),
    ),
    GoRoute(
      path: '/preferensi-genre',
      builder: (context, state) => PreferensiGenreScreen(
        onBack: () => _kembali(context),
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
        onBack: () => _kembali(context),
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
        onBack: () => _kembali(context),
        onKaryaTap: (karya) => context.push('/karya/detail', extra: karya),
      ),
    ),
    GoRoute(
      path: '/lelang',
      builder: (context, state) => LelangScreen(
        onBack: () => _kembali(context),
        onNavTap: (i) => _goKolektorTab(context, i),
        onPindai: () => context.push('/pindai'),
        onDetailTap: (lot) => context.push('/lelang/detail', extra: lot),
      ),
    ),
    GoRoute(
      path: '/lelang/detail',
      builder: (context, state) => DetailLelangScreen(
        lot: (state.extra as LelangLot?) ?? sampleLelang.first,
        onBack: () => _kembali(context),
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
        onBack: () => _kembali(context),
        onDaftarTap: () => context.push('/event/tiket'),
      ),
    ),
    GoRoute(
      path: '/event/tiket',
      builder: (context, state) => TiketCheckoutScreen(
        onBack: () => _kembali(context),
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
          onBack: () => _kembali(context),
          onArTap: () => context.push('/pindai/ar', extra: karya),
          onBeliTap: () => context.push('/pesanan/konfirmasi', extra: karya),
          onTokoTap: () => context.push('/toko'),
        );
      },
    ),
    GoRoute(
      path: '/toko',
      builder: (context, state) => ProfilTokoScreen(
        onBack: () => _kembali(context),
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
          onBack: () => _kembali(context),
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
        onBack: () => _kembali(context),
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
        onBack: () => _kembali(context),
        // pushReplacement: layar Scan ditutup agar kameranya dilepas -- ARCore tidak bisa berbagi
        // kamera dgn plugin `camera` (rebutan kamera => preview patah-patah lalu mati).
        onArTap: () => context.pushReplacement('/pindai/ar'),
        onKaryaTap: (karya) => context.push('/karya/detail', extra: karya),
      ),
    ),
    GoRoute(
      path: '/pindai/ar',
      builder: (context, state) => ArRuanganScreen(
        onClose: () => _kembali(context),
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

class GaleriaApp extends StatefulWidget {
  const GaleriaApp({super.key});

  @override
  State<GaleriaApp> createState() => _GaleriaAppState();
}

/// Menangani tombol back Android SETELAH router (didaftarkan di post-frame, jadi dipanggil hanya
/// kalau router sudah tidak bisa pop lagi): dari layar tingkat atas pindah ke beranda dulu, dan
/// baru keluar app dengan dua kali tekan di beranda -- bukan langsung keluar.
class _GaleriaAppState extends State<GaleriaApp> with WidgetsBindingObserver {
  DateTime? _backTerakhir;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) WidgetsBinding.instance.addObserver(this);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    final path = _lokasiSekarang();
    final beranda = _berandaUntuk(path);
    if (path != beranda && beranda != '/welcome') {
      _router.go(beranda); // dari tab/layar tingkat atas: ke beranda dulu, jangan keluar app
      return true;
    }
    if (beranda == '/welcome' && path != '/welcome' && path != '/splash') {
      _router.go('/welcome');
      return true;
    }
    // Sudah di beranda/welcome: keluar hanya bila ditekan dua kali dalam 2 detik.
    final sekarang = DateTime.now();
    if (_backTerakhir != null && sekarang.difference(_backTerakhir!) < const Duration(seconds: 2)) {
      return false; // biarkan sistem menutup app
    }
    _backTerakhir = sekarang;
    _messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Tekan sekali lagi untuk keluar'), duration: Duration(seconds: 2)));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GALERIA',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      // Animasi perpindahan halaman yang halus (fade + geser) di semua layar, termasuk pindah tab.
      theme: AppTheme.light.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      routerConfig: _router,
    );
  }
}
