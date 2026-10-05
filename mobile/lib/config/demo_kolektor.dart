import '../services/api_client.dart';
import '../services/rekomendasi_service.dart';

/// Kolektor demo untuk rekomendasi -- pengganti login sampai Auth selesai.
///
/// Override dengan `--dart-define=DEMO_KOLEKTOR_ID=<uuid>`; tanpa itu dipakai
/// kolektor pertama dari `GET /api/rekomendasi/demo-kolektor`, diambil sekali
/// lalu disimpan di memori.
const _kDemoKolektorId = String.fromEnvironment('DEMO_KOLEKTOR_ID');

String? _cache;

Future<String> resolveDemoKolektorId(RekomendasiService service) async {
  if (_kDemoKolektorId.isNotEmpty) return _kDemoKolektorId;
  final cached = _cache;
  if (cached != null) return cached;
  final daftar = await service.fetchDemoKolektor();
  if (daftar.isEmpty) throw ApiException('Belum ada kolektor contoh di database.');
  return _cache = daftar.first.id;
}
