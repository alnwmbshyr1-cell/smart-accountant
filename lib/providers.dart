import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_agent_service.dart';
import 'database_service.dart';
import 'services/accounting_backend_client.dart';
import 'services/gemini_service.dart';
import 'export_service.dart';

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

final geminiServiceProvider = Provider<GeminiService>((ref) {
  const backendUrl = String.fromEnvironment('GEMINI_BACKEND_URL');
  if (backendUrl.isEmpty) return GeminiService();

  const storage = FlutterSecureStorage();
  return GeminiService(
    backendClient: AccountingBackendClient(
      baseUrl: backendUrl,
      accessTokenLoader: () =>
          storage.read(key: 'smart_accountant_backend_access_token'),
    ),
  );
});

final aiAgentServiceProvider = Provider<AiAgentService>(
  (ref) => AiAgentService(gemini: ref.watch(geminiServiceProvider)),
);

final exportServiceProvider = Provider<ExportService>(
  (ref) => const ExportService(),
);

final selectedReportMonthsProvider = StateProvider<int>((ref) => 6);

final monthlyProfitReportProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, months) async {
  final database = ref.watch(databaseServiceProvider);
  return database.getMonthlyProfitSummary(months: months);
});
