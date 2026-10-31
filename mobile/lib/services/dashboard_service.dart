import '../models/dashboard_seniman.dart';
import 'api_client.dart';

/// Dashboard seniman yang login: `GET /api/dashboard/saya/...` (data nyata dari transaksi, lihat
/// backend/services/dashboard_nyata.py). Semua request ber-auth; tidak ada id seniman yang dikirim.
class DashboardService {
  DashboardService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  List<Map<String, dynamic>> _list(dynamic data) => (data as List).cast<Map<String, dynamic>>();

  Future<RingkasanSeniman> fetchRingkasan({int periode = 30}) async {
    final data = await _client.getJson('/api/dashboard/saya/ringkasan?periode=$periode', auth: true);
    return RingkasanSeniman.fromJson(data as Map<String, dynamic>);
  }

  Future<List<PenjualanBulan>> fetchPenjualanBulanan({int bulan = 12}) async {
    final data = await _client.getJson('/api/dashboard/saya/penjualan-bulanan?bulan=$bulan', auth: true);
    return _list(data).map(PenjualanBulan.fromJson).toList();
  }

  Future<List<AliranSeniman>> fetchAliran() async {
    final data = await _client.getJson('/api/dashboard/saya/aliran', auth: true);
    return _list(data).map(AliranSeniman.fromJson).toList();
  }

  Future<SegmenPembeliHasil> fetchSegmenPembeli() async {
    final data = await _client.getJson('/api/dashboard/saya/segmen-pembeli', auth: true);
    return SegmenPembeliHasil.fromJson(data as Map<String, dynamic>);
  }

  Future<RiwayatPenarikan> fetchRiwayatPenarikan() async {
    final data = await _client.getJson('/api/dashboard/saya/penarikan', auth: true);
    return RiwayatPenarikan.fromJson(data as Map<String, dynamic>);
  }

  Future<List<NotifikasiSeniman>> fetchNotifikasi() async {
    final data = await _client.getJson('/api/dashboard/saya/notifikasi', auth: true);
    return _list(data).map(NotifikasiSeniman.fromJson).toList();
  }
}
