import 'package:flutter/material.dart';

import '../models/langganan.dart';
import '../screens/langganan/bayar_tagihan_screen.dart';
import '../services/langganan_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Pastikan akun punya langganan Seniman PRO sebelum memakai [fitur].
/// Status dicek ke server; kalau belum, tampil penawaran (harga & manfaat dari server) lalu alur pembayaran.
/// Mengembalikan true bila sekarang sudah PRO. (Server juga menolak fitur PRO tanpa langganan: 402.)
Future<bool> ensurePro(BuildContext context, {required String fitur, LanggananService? service}) =>
    _pastikan(context, plan: 'komunitas_pro', fitur: fitur, ikon: Icons.workspace_premium, service: service);

/// Pastikan akun kolektor punya Akses AR aktif. Gerbang ini hanya di aplikasi (AR berjalan di perangkat).
Future<bool> ensureAr(BuildContext context, {LanggananService? service}) =>
    _pastikan(context, plan: 'ar_akses', fitur: 'Mencoba karya di ruanganmu (AR)', ikon: Icons.view_in_ar_outlined, service: service);

Future<bool> _pastikan(BuildContext context, {required String plan, required String fitur, required IconData ikon, LanggananService? service}) async {
  final s = service ?? LanggananService();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final saya = await s.saya();
    if (plan == 'komunitas_pro' ? saya.pro : saya.ar) return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Gagal memeriksa langganan: $e')));
    return false;
  }
  KatalogPaket katalog;
  try {
    katalog = await s.paket();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Gagal memuat paket: $e')));
    return false;
  }
  final paket = katalog.cari(plan);
  if (paket == null || !context.mounted) return false;
  final lanjut = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaketSheet(paket: paket, fitur: fitur, ikon: ikon),
  );
  if (lanjut != true) return false;
  try {
    final tagihan = await s.beli(plan);
    final lunas = await navigator.push<bool>(MaterialPageRoute(builder: (_) => BayarTagihanScreen(tagihan: tagihan, service: s)));
    if (lunas != true) return false;
    await s.saya();
    messenger.showSnackBar(SnackBar(content: Text('${paket.nama} aktif ${paket.durasiHari} hari.')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    return false;
  }
}

class _PaketSheet extends StatelessWidget {
  const _PaketSheet({required this.paket, required this.fitur, required this.ikon});

  final Paket paket;
  final String fitur;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, AppSpacing.xs, AppSpacing.screenGutter, AppSpacing.lg),
        decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(AppRadius.full)),
              ),
            ),
            Row(children: [
              Icon(ikon, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('Berlangganan ${paket.nama}', style: AppTextStyles.headlineMd)),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text('$fitur membutuhkan ${paket.nama}.', style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            for (final m in paket.manfaat)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle, size: 18, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(m, style: AppTextStyles.bodyMd)),
                ]),
              ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.accentSoft.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(children: [
                Text(formatRupiah(paket.hargaIdr), style: AppTextStyles.headlineMd),
                Text(' / ${paket.durasiHari} hari', style: AppTextStyles.bodySm),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text('Tidak otomatis diperpanjang', textAlign: TextAlign.right, style: AppTextStyles.labelSm.copyWith(color: AppColors.muted, fontSize: 10.5))),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(key: const Key('lanjut_langganan'), onPressed: () => Navigator.of(context).pop(true), child: const Text('Lanjut ke Pembayaran')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Nanti Saja', style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
