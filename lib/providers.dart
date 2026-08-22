import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_agent_service.dart';
import 'database_service.dart';
import 'services/gemini_service.dart';

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

final geminiServiceProvider = Provider<GeminiService>(
  (ref) => GeminiService(),
);

final aiAgentServiceProvider = Provider<AiAgentService>(
  (ref) => AiAgentService(gemini: ref.watch(geminiServiceProvider)),
);

final selectedReportMonthsProvider = StateProvider<int>((ref) => 6);

final monthlyProfitReportProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, months) async {
  final database = ref.watch(databaseServiceProvider);
  return database.getMonthlyProfitSummary(months: months);
});
