import '../models/langganan.dart';
import 'api_client.dart';

/// Langganan (Seniman PRO, Akses AR), promosi karya, dan tagihannya (`/api/langganan`, `/api/promosi`, `/api/tagihan`).
/// Harga dan manfaat ditentukan server; aplikasi hanya menampilkannya.
class LanggananService {
  LanggananService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Status langganan terakhir yang diketahui di perangkat ini (diperbarui tiap [saya] dipanggil).
  static LanggananSaya terakhir = LanggananSaya.kosong;

  Future<KatalogPaket> paket() async => KatalogPaket.fromJson(await _client.getJson('/api/langganan/paket') as Map<String, dynamic>);

  Future<LanggananSaya> saya() async {
    final s = LanggananSaya.fromJson(await _client.getJson('/api/langganan/saya', auth: true) as Map<String, dynamic>);
    return terakhir = s;
  }

  Tagihan _t(dynamic d) => Tagihan.fromJson(d as Map<String, dynamic>);

  Future<Tagihan> beli(String plan) async => _t(await _client.postJson('/api/langganan/beli', {'plan': plan}, auth: true));

  Future<Tagihan> beliPromosi({required String karyaId, required int durasiHari, required bool diBeranda, required bool diLelang}) async => _t(
      await _client.postJson('/api/promosi', {'karya_id': karyaId, 'durasi_hari': durasiHari, 'di_beranda': diBeranda, 'di_lelang': diLelang}, auth: true));

  Future<List<PromosiKarya>> promosiSaya() async {
    final d = await _client.getJson('/api/promosi/saya', auth: true);
    return (d['items'] as List).cast<Map<String, dynamic>>().map(PromosiKarya.fromJson).toList();
  }

  Future<Tagihan> pilihMetode(String id, String metode) async => _t(await _client.postJson('/api/tagihan/$id/bayar', {'metode': metode}, auth: true));

  /// Sandbox: anggap pembayaran sudah masuk.
  Future<Tagihan> simulasiBayar(String id) async => _t(await _client.postJson('/api/tagihan/$id/bayar/simulasi', const {}, auth: true));

  Future<Tagihan> batal(String id) async => _t(await _client.postJson('/api/tagihan/$id/batal', const {}, auth: true));
}
