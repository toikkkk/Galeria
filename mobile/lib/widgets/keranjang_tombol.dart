import 'package:flutter/material.dart';

import '../models/karya.dart';
import '../services/auth_service.dart';
import '../services/keranjang_service.dart';
import '../theme/app_theme.dart';

/// Tombol "masukkan ke keranjang" di detail karya. Terisi bila karya sudah ada di keranjang; ketuk lagi untuk mengeluarkan.
/// Tamu diminta masuk; akun seniman tidak punya keranjang.
class KeranjangTombol extends StatelessWidget {
  const KeranjangTombol({super.key, required this.karya, this.onMasuk});

  final Karya karya;

  /// Dipanggil bila tamu mengetuk (mis. membuka layar masuk).
  final VoidCallback? onMasuk;

  Future<void> _ketuk(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = AuthService.instance;
    if (!auth.loggedIn) {
      messenger.showSnackBar(const SnackBar(content: Text('Masuk dulu untuk memakai keranjang.')));
      onMasuk?.call();
      return;
    }
    if (auth.user?.isSeniman ?? false) {
      messenger.showSnackBar(const SnackBar(content: Text('Akun seniman tidak punya keranjang. Daftar sebagai kolektor untuk membeli.')));
      return;
    }
    if (karya.id.isEmpty) return;
    final sudah = KeranjangStore.instance.punya(karya.id);
    final err = await KeranjangStore.instance.ubah(karya.id);
    messenger.showSnackBar(SnackBar(content: Text(err ?? (sudah ? 'Dikeluarkan dari keranjang.' : 'Masuk ke keranjang.'))));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KeranjangStore.instance,
      builder: (context, _) {
        final ada = KeranjangStore.instance.punya(karya.id);
        return IconButton.outlined(
          key: const Key('tombol_keranjang'),
          onPressed: karya.terjual ? null : () => _ketuk(context),
          tooltip: ada ? 'Keluarkan dari keranjang' : 'Masukkan ke keranjang',
          icon: Icon(ada ? Icons.shopping_cart : Icons.add_shopping_cart_outlined, color: AppColors.accent),
        );
      },
    );
  }
}

/// Ikon keranjang dengan lencana jumlah (untuk app bar kolektor).
class KeranjangIkon extends StatelessWidget {
  const KeranjangIkon({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KeranjangStore.instance,
      builder: (context, _) {
        final n = KeranjangStore.instance.jumlah;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(key: const Key('ikon_keranjang'), onPressed: onTap, tooltip: 'Keranjang', icon: const Icon(Icons.shopping_cart_outlined)),
            if (n > 0)
              Positioned(
                top: 6,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                  child: Text(n > 99 ? '99+' : '$n', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        );
      },
    );
  }
}
