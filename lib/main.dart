import 'package:flutter/material.dart';
import 'accounting/accounting_app.dart';
import 'accounting/accounting_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AccountingDatabase.open();
  runApp(AccountingApp(database: database));
}
