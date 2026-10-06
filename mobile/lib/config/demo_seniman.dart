import '../services/api_client.dart';
import '../services/dashboard_service.dart';

/// Seniman demo untuk dashboard -- pengganti login sampai Auth selesai.
///
/// Override dengan `--dart-define=DEMO_SENIMAN_ID=<uuid>`; tanpa itu dipakai
/// seniman pertama dari `GET /api/dashboard/demo-seniman` (terbanyak terjual).
const _kDemoSenimanId = String.fromEnvironment('DEMO_SENIMAN_ID');

Future<String> resolveDemoSenimanId(DashboardService service) async {
  if (_kDemoSenimanId.isNotEmpty) return _kDemoSenimanId;
  final daftar = await service.fetchSenimanDemo();
  if (daftar.isEmpty) throw ApiException('Belum ada seniman contoh di database.');
  return daftar.first.id;
}
