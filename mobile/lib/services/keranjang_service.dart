import 'package:flutter/foundation.dart';

import '../models/karya.dart';
import '../models/pesanan.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Satu baris keranjang. [tersedia] = false bila karya sudah terjual/dipesan/dilelang/dihapus
/// (tetap tampil beserta [alasan], tidak ikut checkout).
class ItemKeranjang {
  const ItemKeranjang({required this.karya, required this.tersedia, this.alasan});

  final Karya karya;
  final bool tersedia;
  final String? alasan;

  factory ItemKeranjang.fromJson(Map<String, dynamic> j) => ItemKeranjang(
        karya: Karya.fromJson(j['karya'] as Map<String, dynamic>),
        tersedia: j['tersedia'] as bool,
        alasan: j['alasan'] as String?,
      );
}

class Keranjang {
  const Keranjang({required this.items, required this.totalIdr});

  final List<ItemKeranjang> items;

  /// Total hanya karya yang masih tersedia (dihitung server dari harga terbaru).
  final int totalIdr;

  int get jumlahTersedia => items.where((i) => i.tersedia).length;

  factory Keranjang.fromJson(Map<String, dynamic> j) => Keranjang(
        items: (j['items'] as List).cast<Map<String, dynamic>>().map(ItemKeranjang.fromJson).toList(),
        totalIdr: j['total_idr'] as int,
      );
}

class CheckoutGagal {
  const CheckoutGagal({required this.karyaId, required this.judul, required this.alasan});

  final String karyaId, judul, alasan;

  factory CheckoutGagal.fromJson(Map<String, dynamic> j) =>
      CheckoutGagal(karyaId: j['karya_id'] as String, judul: j['judul'] as String, alasan: j['alasan'] as String);
}

/// Hasil checkout: satu pesanan per karya yang berhasil, plus karya yang gagal (tetap di keranjang).
class HasilCheckout {
  const HasilCheckout({required this.pesanan, required this.gagal});

  final List<Pesanan> pesanan;
  final List<CheckoutGagal> gagal;

  factory HasilCheckout.fromJson(Map<String, dynamic> j) => HasilCheckout(
        pesanan: (j['pesanan'] as List).cast<Map<String, dynamic>>().map(Pesanan.fromJson).toList(),
        gagal: (j['gagal'] as List).cast<Map<String, dynamic>>().map(CheckoutGagal.fromJson).toList(),
      );
}

/// `/api/keranjang` (khusus kolektor).
class KeranjangService {
  KeranjangService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Keranjang> lihat() async => Keranjang.fromJson(await _client.getJson('/api/keranjang', auth: true) as Map<String, dynamic>);

  Future<Set<String>> ids() async => ((await _client.getJson('/api/keranjang/ids', auth: true))['ids'] as List).cast<String>().toSet();

  Future<void> tambah(String karyaId) => _client.postJson('/api/keranjang/$karyaId', const {}, auth: true);

  Future<void> hapus(String karyaId) => _client.delete('/api/keranjang/$karyaId');

  Future<void> kosongkan() => _client.delete('/api/keranjang');

  Future<HasilCheckout> checkout(String alamatId) async =>
      HasilCheckout.fromJson(await _client.postJson('/api/keranjang/checkout', {'alamat_id': alamatId}, auth: true) as Map<String, dynamic>);
}

/// Id karya di keranjang milik pengguna yang login (untuk tombol di detail karya dan lencana jumlah).
/// Kosong bila belum masuk atau akunnya seniman.
class KeranjangStore extends ChangeNotifier {
  KeranjangStore._();
  static KeranjangStore instance = KeranjangStore._();

  KeranjangService service = KeranjangService();
  final Set<String> _ids = {};

  int get jumlah => _ids.length;
  bool punya(String karyaId) => _ids.contains(karyaId);

  Future<void> muat() async {
    if (AuthService.instance.user?.isSeniman ?? true) return;
    try {
      final baru = await service.ids();
      _ids
        ..clear()
        ..addAll(baru);
      notifyListeners();
    } catch (_) {
      // gagal memuat: lencana tidak tampil, tidak mengganggu layar lain
    }
  }

  void kosongkan() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }

  /// Dipakai layar keranjang setelah menghapus/checkout supaya lencana ikut berubah.
  void setelahPerubahan(Iterable<String> idBaru) {
    _ids
      ..clear()
      ..addAll(idBaru);
    notifyListeners();
  }

  /// Tambah/keluarkan karya. Mengembalikan pesan error bila gagal (state dikembalikan), null bila sukses.
  Future<String?> ubah(String karyaId) async {
    final sudah = _ids.contains(karyaId);
    sudah ? _ids.remove(karyaId) : _ids.add(karyaId);
    notifyListeners();
    try {
      if (sudah) {
        await service.hapus(karyaId);
      } else {
        await service.tambah(karyaId);
      }
      return null;
    } catch (e) {
      sudah ? _ids.add(karyaId) : _ids.remove(karyaId);
      notifyListeners();
      return e.toString();
    }
  }
}
