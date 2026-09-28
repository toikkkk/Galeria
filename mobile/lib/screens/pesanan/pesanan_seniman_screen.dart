import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Konversi dari 3 layar terpisah di docs/design/role_seniman_2/... yang
/// sebenarnya satu layar dengan 3 status tab (screenshot Stitch diekspor
/// terpisah per state aktif):
/// - galeria_pesanan_masuk_manajemen_pesanan_seniman (tab "Perlu Dikemas")
/// - galeria_pesanan_dikirim_manajemen_pesanan_seniman (tab "Dikirim")
/// - galeria_pesanan_selesai_manajemen_pesanan_seniman (tab "Selesai")
class PesananSenimanScreen extends StatelessWidget {
  const PesananSenimanScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          leading: IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          title: Text('Pesanan Masuk', style: AppTextStyles.headlineSm),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.accent,
            labelStyle: AppTextStyles.labelMd,
            tabs: const [
              Tab(text: 'Perlu Dikemas (2)'),
              Tab(text: 'Dikirim (1)'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PerluDikemasTab(),
            _DikirimTab(),
            _SelesaiTab(),
          ],
        ),
      ),
    );
  }
}

class _PerluDikemasTab extends StatelessWidget {
  const _PerluDikemasTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
              color: AppColors.accentSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(
            children: [
              const Icon(Icons.verified_user, color: AppColors.accent, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Karya bernilai di atas Rp 20.000.000 wajib menggunakan peti kayu tersegel dan segel hologram GALERIA sebelum diserahkan ke kurir.',
                  style: AppTextStyles.bodySm,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _OrderCard(
          kode: '#GLR-2025-8821',
          waktu: 'Hari Ini, 10:45 WIB',
          judul: 'Sang Putri Mahkota Renaisans',
          detail: '120 × 90 cm • Cat Minyak di Atas Kanvas',
          harga: 'Rp 120.000.000',
          pembeli: 'Raden Aditya Nugroho',
          lokasi: 'Jakarta Selatan, DKI Jakarta',
          badge: 'Kirim dalam 1 hari 4 jam',
          badgeColor: AppColors.accent,
          actions: [
            _outlinedAction(context, Icons.visibility_outlined, 'Lihat Detail'),
            _filledAction(context, Icons.local_shipping_outlined, 'Input Resi'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _OrderCard(
          kode: '#GLR-2025-8794',
          waktu: 'Kemarin, 16:30 WIB',
          judul: 'Komposisi Emas & Lapis Lazuli',
          detail: '80 × 60 cm • Akrilik & Daun Emas',
          harga: 'Rp 45.000.000',
          pembeli: 'Clarissa Halim',
          lokasi: 'Surabaya, Jawa Timur',
          badge: 'Menunggu Pengemasan Khusus',
          badgeColor: AppColors.muted,
          actions: [
            _outlinedAction(context, Icons.visibility_outlined, 'Lihat Detail'),
            _filledAction(context, Icons.local_shipping_outlined, 'Input Resi'),
          ],
        ),
      ],
    );
  }
}

class _DikirimTab extends StatelessWidget {
  const _DikirimTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        _ShippingCard(
          kode: '#GLR-2025-8821',
          judul: 'Sang Putri Mahkota Renaisans',
          detail: 'Cat Minyak di Atas Kanvas · 120 x 90 cm',
          harga: 'Rp 120.000.000',
          pembeli: 'Raden Aditya Nugroho · Jakarta Selatan',
          kurir: 'JNE Art Cargo',
          resi: '0088123456789',
        ),
        const SizedBox(height: AppSpacing.md),
        _ShippingCard(
          kode: '#GLR-2025-8794',
          judul: 'Kabut Pagi di Ranu Kumbolo',
          detail: 'Cat Air di Atas Kertas · 60 x 40 cm',
          harga: 'Rp 18.500.000',
          pembeli: 'Clarissa Halim · Surabaya',
          kurir: 'JNE Art Cargo',
          resi: '0088987654321',
        ),
      ],
    );
  }
}

class _SelesaiTab extends StatelessWidget {
  const _SelesaiTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
              color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(
            children: [
              Expanded(child: _statBlock('8', 'Karya Terjual')),
              Expanded(child: _statBlock('Rp 214,5jt', 'Pendapatan Bulan Ini')),
              Expanded(child: _statBlock('4.9 ★', 'Rating')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _CompletedCard(
          kode: '#GLR-2025-8654',
          selesai: 'Selesai 12 Sep 2026',
          judul: 'Komposisi Emas & Lapis Lazuli',
          detail: 'Akrilik & Daun Emas · 80 x 60 cm',
          harga: 'Rp 45.000.000',
          dana: 'Rp 42.750.000',
          reviewer: 'Clarissa Halim',
          ulasan:
              'Karya tiba dalam peti kayu yang sangat kokoh. Kualitas cat dan tekstur aslinya luar biasa memukau!',
        ),
        const SizedBox(height: AppSpacing.md),
        _CompletedCard(
          kode: '#GLR-2025-8590',
          selesai: 'Selesai 05 Sep 2026',
          judul: 'Senja di Teluk Benoa',
          detail: 'Cat Minyak di Atas Kanvas · 100 x 70 cm',
          harga: 'Rp 28.000.000',
          dana: 'Rp 26.600.000',
          reviewer: 'Bagus Pratama',
          ulasan:
              'Gradasi warna senja sangat hidup di ruang tamu. Sertifikat digital langsung terverifikasi di profil.',
        ),
      ],
    );
  }

  Widget _statBlock(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      );
}

Widget _outlinedAction(BuildContext context, IconData icon, String label) => Expanded(
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );

Widget _filledAction(BuildContext context, IconData icon, String label) => Expanded(
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.kode,
    required this.waktu,
    required this.judul,
    required this.detail,
    required this.harga,
    required this.pembeli,
    required this.lokasi,
    required this.badge,
    required this.badgeColor,
    required this.actions,
  });

  final String kode, waktu, judul, detail, harga, pembeli, lokasi, badge;
  final Color badgeColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(kode, style: AppTextStyles.labelMd),
              Text(waktu, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.full)),
            child: Text(badge, style: AppTextStyles.labelSm.copyWith(color: badgeColor)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(judul, style: AppTextStyles.headlineSm),
          Text(detail, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(harga, style: AppTextStyles.headlineSm.copyWith(fontSize: 16)),
          const Divider(height: AppSpacing.md),
          Row(children: [
            const Icon(Icons.person_outline, size: 16, color: AppColors.muted),
            const SizedBox(width: 4),
            Expanded(child: Text('$pembeli · $lokasi', style: AppTextStyles.bodySm)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: actions.expand((w) => [w, const SizedBox(width: AppSpacing.xs)]).toList()
            ..removeLast()),
        ],
      ),
    );
  }
}

class _ShippingCard extends StatelessWidget {
  const _ShippingCard({
    required this.kode,
    required this.judul,
    required this.detail,
    required this.harga,
    required this.pembeli,
    required this.kurir,
    required this.resi,
  });

  final String kode, judul, detail, harga, pembeli, kurir, resi;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(kode, style: AppTextStyles.labelMd),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.blue.shade50, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.local_shipping, size: 15, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text('Dalam Perjalanan',
                  style: AppTextStyles.labelSm.copyWith(color: Colors.blue.shade800)),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(judul, style: AppTextStyles.headlineSm),
          Text(detail, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
          Text(harga, style: AppTextStyles.headlineSm.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pembeli, style: AppTextStyles.bodySm),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(kurir, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    Text(resi, style: AppTextStyles.bodySm.copyWith(fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            const Icon(Icons.lock_outline, size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Expanded(
                child: Text('Dana ditahan escrow sampai kolektor konfirmasi penerimaan',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.accent, fontSize: 11))),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            _outlinedAction(context, Icons.location_searching, 'Lacak Kiriman'),
            const SizedBox(width: AppSpacing.xs),
            _filledAction(context, Icons.chat_bubble_outline, 'Hubungi Kolektor'),
          ]),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({
    required this.kode,
    required this.selesai,
    required this.judul,
    required this.detail,
    required this.harga,
    required this.dana,
    required this.reviewer,
    required this.ulasan,
  });

  final String kode, selesai, judul, detail, harga, dana, reviewer, ulasan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(kode, style: AppTextStyles.labelMd),
              Text(selesai, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.green.shade50, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 15, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Text('Selesai', style: AppTextStyles.labelSm.copyWith(color: Colors.green.shade800)),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(judul, style: AppTextStyles.headlineSm),
          Text(detail, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
          Text(harga, style: AppTextStyles.headlineSm.copyWith(fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text('Dana Diteruskan', style: AppTextStyles.bodySm),
                ]),
                Text(dana,
                    style:
                        AppTextStyles.labelMd.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.star, size: 14, color: AppColors.accent),
                  const Icon(Icons.star, size: 14, color: AppColors.accent),
                  const Icon(Icons.star, size: 14, color: AppColors.accent),
                  const Icon(Icons.star, size: 14, color: AppColors.accent),
                  const Icon(Icons.star, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(reviewer, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text('"$ulasan"',
                    style: AppTextStyles.bodySm.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            _outlinedAction(context, Icons.receipt_long_outlined, 'Lihat Invoice'),
            const SizedBox(width: AppSpacing.xs),
            _outlinedAction(context, Icons.download_outlined, 'Berita Acara'),
          ]),
        ],
      ),
    );
  }
}
