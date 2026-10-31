import '../models/sentimen_seniman.dart';
import 'api_client.dart';

/// `GET /api/dashboard/saya/sentimen` (lihat backend/services/dashboard_nyata.py): ringkasan ulasan atas
/// karya seniman yang login. Sentimen diisi batch oleh model IndoBERT; ulasan yang belum dianalisis
/// tampil sebagai "menunggu analisis".
class SentimenService {
  SentimenService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<SentimenSeniman> fetchSentimen() async {
    final data = await _client.getJson('/api/dashboard/saya/sentimen', auth: true);
    return SentimenSeniman.fromJson(data as Map<String, dynamic>);
  }
}
