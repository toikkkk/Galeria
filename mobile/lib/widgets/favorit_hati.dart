import 'package:flutter/material.dart';

import '../models/karya.dart';
import '../services/auth_service.dart';
import '../services/favorit_service.dart';
import '../theme/app_theme.dart';

/// Ikon hati favorit. Terisi bila karya ada di favoritmu (data server). Tamu diminta masuk dulu.
class FavoritHati extends StatelessWidget {
  const FavoritHati({super.key, required this.karya, this.bulat = true, this.ukuran = 14});

  final Karya karya;

  /// true = tombol bulat putih kecil (di atas gambar kartu); false = IconButton biasa (app bar).
  final bool bulat;
  final double ukuran;

  Future<void> _ketuk(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!AuthService.instance.loggedIn) {
      messenger.showSnackBar(const SnackBar(content: Text('Masuk dulu untuk menyimpan favorit.')));
      return;
    }
    if (karya.id.isEmpty) return;
    final err = await FavoritStore.instance.ubah(karya.id);
    if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavoritStore.instance,
      builder: (context, _) {
        final fav = FavoritStore.instance.punya(karya.id);
        final ikon = Icon(fav ? Icons.favorite : Icons.favorite_border, size: ukuran, color: fav ? AppColors.error : AppColors.onSurface);
        if (!bulat) {
          return IconButton(key: const Key('hati_favorit'), onPressed: () => _ketuk(context), icon: ikon, tooltip: fav ? 'Hapus dari favorit' : 'Simpan ke favorit');
        }
        return Material(
          color: Colors.white.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          child: InkWell(customBorder: const CircleBorder(), onTap: () => _ketuk(context), child: Padding(padding: const EdgeInsets.all(5), child: ikon)),
        );
      },
    );
  }
}
