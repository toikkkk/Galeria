import '../models/event.dart';
import 'api_client.dart';

/// Event & tiket (`/api/event`, `/api/event-pesanan`, `/api/tiket-saya`).
/// Daftar & detail terbuka untuk tamu; selebihnya butuh login.
class EventService {
  EventService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  List<EventInfo> _daftar(dynamic data) =>
      (data['items'] as List).cast<Map<String, dynamic>>().map(EventInfo.fromJson).toList();

  /// [waktu]: mendatang | selesai | semua.
  Future<List<EventInfo>> daftar({String waktu = 'mendatang', String? q}) async {
    final qs = Uri(queryParameters: {'waktu': waktu, 'page_size': '100', if (q != null && q.trim().isNotEmpty) 'q': q.trim()}).query;
    return _daftar(await _client.getJson('/api/event?$qs', auth: true));
  }

  /// Event yang kamu selenggarakan, lengkap dengan statistik.
  Future<List<EventInfo>> saya() async => _daftar(await _client.getJson('/api/event/saya', auth: true));

  Future<EventInfo> detail(String id) async =>
      EventInfo.fromJson(await _client.getJson('/api/event/$id', auth: true) as Map<String, dynamic>);

  Future<EventInfo> buat(Map<String, dynamic> body) async =>
      EventInfo.fromJson(await _client.postJson('/api/event', body, auth: true) as Map<String, dynamic>);

  Future<EventInfo> batal(String id) async =>
      EventInfo.fromJson(await _client.postJson('/api/event/$id/batal', const {}, auth: true) as Map<String, dynamic>);

  Future<List<Peserta>> peserta(String id) async {
    final data = await _client.getJson('/api/event/$id/peserta', auth: true);
    return (data['items'] as List).cast<Map<String, dynamic>>().map(Peserta.fromJson).toList();
  }

  Future<HasilCheckin> checkin(String kode) async =>
      HasilCheckin.fromJson(await _client.postJson('/api/event/checkin', {'kode': kode}, auth: true) as Map<String, dynamic>);

  PesananTiket _p(dynamic d) => PesananTiket.fromJson(d as Map<String, dynamic>);

  Future<PesananTiket> pesan(String eventId, {required String tiketId, required int jumlah, required String namaPemegang}) async =>
      _p(await _client.postJson('/api/event/$eventId/pesan', {'tiket_id': tiketId, 'jumlah': jumlah, 'nama_pemegang': namaPemegang}, auth: true));

  Future<PesananTiket> pesananDetail(String id) async => _p(await _client.getJson('/api/event-pesanan/$id', auth: true));

  Future<PesananTiket> pilihMetode(String id, String metode) async =>
      _p(await _client.postJson('/api/event-pesanan/$id/bayar', {'metode': metode}, auth: true));

  /// Sandbox: anggap pembayaran sudah masuk.
  Future<PesananTiket> simulasiBayar(String id) async =>
      _p(await _client.postJson('/api/event-pesanan/$id/bayar/simulasi', const {}, auth: true));

  Future<PesananTiket> batalPesanan(String id) async =>
      _p(await _client.postJson('/api/event-pesanan/$id/batal', const {}, auth: true));

  Future<List<TiketSaya>> tiketSaya() async {
    final data = await _client.getJson('/api/tiket-saya', auth: true);
    return (data['items'] as List).cast<Map<String, dynamic>>().map(TiketSaya.fromJson).toList();
  }
}
