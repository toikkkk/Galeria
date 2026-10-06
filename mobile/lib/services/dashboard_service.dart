import '../models/dashboard_seniman.dart';
import 'api_client.dart';

/// Wrapper tipis ke `GET /api/dashboard/...` (lihat backend/routers/dashboard_seniman.py).
class DashboardService {
  DashboardService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  List<Map<String, dynamic>> _list(dynamic data) => (data as List).cast<Map<String, dynamic>>();

  Future<List<SenimanDemo>> fetchSenimanDemo() async {
    final data = await _client.getJson('/api/dashboard/demo-seniman');
    return _list(data).map(SenimanDemo.fromJson).toList();
  }

  Future<RingkasanSeniman> fetchRingkasan(String senimanId, {int periode = 30}) async {
    final data = await _client.getJson('/api/dashboard/seniman/$senimanId/ringkasan?periode=$periode');
    return RingkasanSeniman.fromJson(data as Map<String, dynamic>);
  }

  Future<List<PenjualanBulan>> fetchPenjualanBulanan(String senimanId, {int bulan = 12}) async {
    final data = await _client.getJson('/api/dashboard/seniman/$senimanId/penjualan-bulanan?bulan=$bulan');
    return _list(data).map(PenjualanBulan.fromJson).toList();
  }

  Future<List<AliranSeniman>> fetchAliran(String senimanId) async {
    final data = await _client.getJson('/api/dashboard/seniman/$senimanId/aliran');
    return _list(data).map(AliranSeniman.fromJson).toList();
  }

  Future<SegmenPembeliHasil> fetchSegmenPembeli(String senimanId) async {
    final data = await _client.getJson('/api/dashboard/seniman/$senimanId/segmen-pembeli');
    return SegmenPembeliHasil.fromJson(data as Map<String, dynamic>);
  }

  Future<TrenPasar> fetchTrenPasar() async {
    final data = await _client.getJson('/api/dashboard/pasar/tren');
    return TrenPasar.fromJson(data as Map<String, dynamic>);
  }
}
