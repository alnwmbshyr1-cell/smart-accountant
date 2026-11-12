import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import 'accounting_database.dart';
import 'accounting_tools_service.dart';

const _green = Color(0xFF167D62);
const _ink = Color(0xFF17362E);
const _background = Color(0xFFF5F8F6);

class AccountingApp extends StatefulWidget {
  const AccountingApp({
    super.key,
    required this.database,
    required this.tools,
  });

  final AccountingDatabase database;
  final AccountingToolsService tools;

  @override
  State<AccountingApp> createState() => _AccountingAppState();
}

class _AccountingAppState extends State<AccountingApp> {
  late final AccountingToolsService _tools;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _tools = widget.tools;
    _authenticate();
  }
