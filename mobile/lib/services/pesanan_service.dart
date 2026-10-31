import '../models/pesanan.dart';
import 'api_client.dart';

/// Alamat pengiriman milik pengguna yang login (`/api/alamat`).
class AlamatService {
  AlamatService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<Alamat>> daftar() async {
    final data = await _client.getJson('/api/alamat', auth: true);
    return (data as List).cast<Map<String, dynamic>>().map(Alamat.fromJson).toList();
  }

  Future<Alamat> tambah({
    required String label,
    required String namaPenerima,
    required String telepon,
    required String alamatLengkap,
    required String kota,
    required String kodePos,
  }) async {
    final data = await _client.postJson('/api/alamat', {
      'label': label,
      'nama_penerima': namaPenerima,
      'telepon': telepon,
      'alamat_lengkap': alamatLengkap,
      'kota': kota,
      'kode_pos': kodePos,
    }, auth: true);
    return Alamat.fromJson(data as Map<String, dynamic>);
  }

  Future<void> hapus(String id) => _client.delete('/api/alamat/$id');

  Future<void> jadikanUtama(String id) => _client.postJson('/api/alamat/$id/utama', const {}, auth: true);
}

/// Pesanan (checkout) kolektor dan pesanan masuk seniman (`/api/pesanan`).
class PesananService {
  PesananService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Pesanan _p(dynamic d) => Pesanan.fromJson(d as Map<String, dynamic>);

  Future<Pesanan> buat({required String karyaId, required String alamatId}) async =>
      _p(await _client.postJson('/api/pesanan', {'karya_id': karyaId, 'alamat_id': alamatId}, auth: true));

  /// [penjual] = true untuk pesanan masuk seniman.
  Future<List<Pesanan>> daftar({bool penjual = false}) async {
    final data = await _client.getJson('/api/pesanan?peran=${penjual ? 'penjual' : 'pembeli'}&page_size=100', auth: true);
    return (data['items'] as List).map(_p).toList();
  }

  Future<Pesanan> detail(String id) async => _p(await _client.getJson('/api/pesanan/$id', auth: true));

  Future<Pesanan> pilihMetode(String id, String metode) async =>
      _p(await _client.postJson('/api/pesanan/$id/bayar', {'metode': metode}, auth: true));

  /// Sandbox: anggap pembayaran sudah masuk.
  Future<Pesanan> simulasiBayar(String id) async =>
      _p(await _client.postJson('/api/pesanan/$id/bayar/simulasi', const {}, auth: true));

  Future<Pesanan> batal(String id) async => _p(await _client.postJson('/api/pesanan/$id/batal', const {}, auth: true));

  Future<Pesanan> konfirmasi(String id) async =>
      _p(await _client.postJson('/api/pesanan/$id/konfirmasi', const {}, auth: true));

  Future<Pesanan> kirim(String id, {required String kurir, required String noResi}) async =>
      _p(await _client.postJson('/api/pesanan/$id/kirim', {'kurir': kurir, 'no_resi': noResi}, auth: true));

  Future<Pesanan> terima(String id) async => _p(await _client.postJson('/api/pesanan/$id/terima', const {}, auth: true));
}
