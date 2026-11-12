import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'accounting/accounting_app.dart';
import 'accounting/accounting_database.dart';
import 'accounting/accounting_tools_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AccountingDatabase.open();
  final tools = AccountingToolsService(database.db);
  await tools.initialize();

  // Configure only with the public Supabase URL and publishable/anon key.
  // Never ship a service-role key in a mobile application.
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    tools.configureCloud(Supabase.instance.client);
  }

  runApp(AccountingApp(database: database, tools: tools));
}
