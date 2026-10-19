import '../models/sentimen_seniman.dart';
import 'api_client.dart';

/// Wrapper tipis ke `GET /api/dashboard/seniman/{id}/sentimen` (lihat backend/routers/sentimen.py).
class SentimenService {
  SentimenService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<SentimenSeniman> fetchSentimen(String senimanId) async {
    final data = await _client.getJson('/api/dashboard/seniman/$senimanId/sentimen');
    return SentimenSeniman.fromJson(data as Map<String, dynamic>);
  }
}
