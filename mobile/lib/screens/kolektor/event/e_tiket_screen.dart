import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../models/event.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format_waktu.dart';
import '../../../widgets/event_widgets.dart';

/// Argumen rute `/event/e-tiket`.
class ETiketArgs {
  const ETiketArgs({required this.event, required this.tiketNama, required this.etiket, this.linkOnline});

  final EventRingkas event;
  final String tiketNama;
  final List<ETiket> etiket;
  final String? linkOnline;
}

/// E-tiket dengan QR sungguhan (isi QR = kode tiket, dipindai/diketik penyelenggara di check-in).
/// Bila ada beberapa tiket dalam satu pesanan, geser untuk berganti.
class ETiketScreen extends StatefulWidget {
  const ETiketScreen({super.key, required this.event, required this.tiketNama, required this.etiket, required this.onDone, this.linkOnline});

  final EventRingkas event;
  final String tiketNama;
  final List<ETiket> etiket;
  final VoidCallback onDone;
  final String? linkOnline;

  @override
  State<ETiketScreen> createState() => _ETiketScreenState();
}

class _ETiketScreenState extends State<ETiketScreen> {
  final _ctrl = PageController();
  int _hal = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onDone, icon: const Icon(Icons.arrow_back)),
        title: Text('E-Tiket', style: AppTextStyles.headlineSm),
      ),
      body: widget.etiket.isEmpty
          ? Center(child: Text('Belum ada e-tiket.', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)))
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    itemCount: widget.etiket.length,
                    onPageChanged: (i) => setState(() => _hal = i),
                    itemBuilder: (context, i) {
                      final t = widget.etiket[i];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.screenGutter),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                          child: Column(
                            children: [
                              StatusEventChip(status: e.status),
                              const SizedBox(height: 6),
                              Text(e.judul, textAlign: TextAlign.center, style: AppTextStyles.headlineMd),
                              Text('${formatTanggal(e.mulai)} · ${jamMenit(e.mulai)}', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                              Text(e.lokasi, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                              const SizedBox(height: AppSpacing.md),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(opacity: t.terpakai ? 0.25 : 1, child: QrImageView(data: t.kode, size: 210, padding: EdgeInsets.zero)),
                                  if (t.terpakai)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                      child: Text('SUDAH DIGUNAKAN', style: AppTextStyles.labelMd.copyWith(color: Colors.white)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              SelectableText(t.kode, style: AppTextStyles.headlineSm.copyWith(letterSpacing: 2, fontFamily: 'monospace')),
                              const Divider(height: AppSpacing.lg),
                              _baris('Pemegang', t.namaPemegang ?? '-'),
                              _baris('Jenis tiket', widget.tiketNama),
                              _baris('Status', t.terpakai ? 'Digunakan${t.checkinAt != null ? ' pukul ${jamMenit(t.checkinAt!)}' : ''}' : 'Aktif'),
                              if (widget.linkOnline != null) _baris('Tautan event', widget.linkOnline!),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.etiket.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text('Tiket ${_hal + 1} dari ${widget.etiket.length} · geser untuk berganti', style: AppTextStyles.bodySm.copyWith(color: AppColors.muted)),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, 0, AppSpacing.screenGutter, AppSpacing.sm),
                    child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: widget.onDone, child: const Text('Selesai'))),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _baris(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(l, style: AppTextStyles.bodySm.copyWith(color: AppColors.muted))),
          Expanded(child: Text(v, style: AppTextStyles.labelMd)),
        ]),
      );
}
