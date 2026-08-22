import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'ai_agent_service.dart';
import 'database_service.dart';
import 'providers.dart';
import 'profit_report_screen.dart';
import 'export_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SmartAccountantApp()));
}

class SmartAccountantApp extends StatelessWidget {
  const SmartAccountantApp({
    super.key,
    this.enableNativeServices = true,
  });

  final bool enableNativeServices;

  @override
  Widget build(BuildContext context) {
    final baseLight = ThemeData.light(useMaterial3: true);
    final baseDark = ThemeData.dark(useMaterial3: true);

    return MaterialApp(
      title: 'المحاسب الصوتي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          primary: const Color(0xFF0D47A1),
          secondary: const Color(0xFFFFC107),
          surface: const Color(0xFFF5F5F5),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(baseLight.textTheme),
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          brightness: Brightness.dark,
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFFFFC107),
          surface: const Color(0xFF121212),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.tajawalTextTheme(baseDark.textTheme),
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      locale: const Locale('ar', 'AE'),
      supportedLocales: const [
        Locale('ar', 'AE'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return ResponsiveBreakpoints.builder(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          breakpoints: const [
            Breakpoint(start: 0, end: 450, name: MOBILE),
            Breakpoint(start: 451, end: 800, name: TABLET),
            Breakpoint(start: 801, end: double.infinity, name: DESKTOP),
          ],
        );
      },
      home: MainDashboardScreen(enableNativeServices: enableNativeServices),
    );
  }
}

class MainDashboardScreen extends ConsumerStatefulWidget {
  const MainDashboardScreen({
    super.key,
    this.enableNativeServices = true,
  });

  final bool enableNativeServices;

  @override
  ConsumerState<MainDashboardScreen> createState() =>
      _MainDashboardScreenState();
}

class _MainDashboardScreenState extends ConsumerState<MainDashboardScreen> {
  int _currentIndex = 0;
  late final AiAgentService _aiAgent;
  late final DatabaseService _db;

  bool _isListening = false;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isVoiceInitializing = true;
  bool _wakeWordEnabled = true;
  String _lastWords = "";
  String _assistantStatus =
      "أهلاً بك يا شيخ، قل يا محاسب أو يا حسابات لتنفيذ أمر صوتي";

  List<Map<String, dynamic>> _transactions = [];
  final ScrollController _transactionsController = ScrollController();
  static const int _pageSize = 50;
  bool _isPageLoading = false;
  bool _hasMorePages = true;
  String? _lastTransactionDate;
  String? _lastTransactionId;
  int _paginationGeneration = 0;
  List<Map<String, dynamic>> _inventory = [];
  double _balance = 0.0;
  double _todayExpenses = 0.0;
  double _todaySales = 0.0;

  @override
  void initState() {
    super.initState();
    _aiAgent = ref.read(aiAgentServiceProvider);
    _db = ref.read(databaseServiceProvider);
    _transactionsController.addListener(_onTransactionsScroll);
    if (widget.enableNativeServices) {
      _initSpeechAndAgent();
      _loadData();
    }
  }

  @override
  void dispose() {
    _transactionsController.dispose();
    unawaited(_aiAgent.disposeVoiceResources());
    super.dispose();
  }

  void _onTransactionsScroll() {
    if (!_transactionsController.hasClients) return;
    if (_transactionsController.position.extentAfter < 600) {
      _loadNextTransactionsPage();
    }
  }

  Future<void> _initSpeechAndAgent() async {
    if (mounted) setState(() => _isVoiceInitializing = true);
    try {
      await _aiAgent.init();
      if (_wakeWordEnabled) {
        await _startWakeWordMode();
      }
    } finally {
      if (mounted) setState(() => _isVoiceInitializing = false);
    }
  }

  Future<void> _startWakeWordMode() async {
    await _aiAgent.startWakeWordListening(
      onWakeWord: () async {
        if (!mounted) return;
        setState(() {
          _isListening = true;
          _assistantStatus = "سمعتك يا شيخ، قل الأمر الآن";
        });
      },
      onCommand: (command) => _processWakeWordCommand(command),
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          _assistantStatus = status;
          _isListening = _aiAgent.isCommandMode;
        });
      },
    );
  }

  Future<void> _processWakeWordCommand(String command) async {
    if (!mounted) return;
    setState(() {
      _lastWords = command;
      _isLoading = true;
      _assistantStatus = "جاري تنفيذ الأمر: $command";
    });
    try {
      await _aiAgent.processVoiceCommandText(command, (reply) {
        if (mounted) setState(() => _assistantStatus = reply);
      });
      if (mounted) setState(() => _isListening = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleWakeWord(bool enabled) async {
    setState(() => _wakeWordEnabled = enabled);
    if (enabled) {
      await _startWakeWordMode();
    } else {
      await _aiAgent.stopWakeWordListening();
      if (mounted) setState(() => _assistantStatus = "التنشيط الصوتي متوقف");
    }
  }

  Future<void> _showVoiceSettings() async {
    if (!mounted) return;
    final gemini = ref.read(geminiServiceProvider);
    final apiKeyController =
        TextEditingController(text: await gemini.readApiKey() ?? '');
    if (!mounted) {
      apiKeyController.dispose();
      return;
    }

    var isSaving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetStateContext, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.viewInsetsOf(sheetStateContext).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'إعدادات المساعد الصوتي',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('التنشيط الصوتي'),
                    subtitle: const Text('استمع لعبارة يا محاسب أو يا حسابات'),
                    value: _wakeWordEnabled,
                    onChanged: isSaving
                        ? null
                        : (value) {
                            setSheetState(() {});
                            unawaited(_toggleWakeWord(value));
                          },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: apiKeyController,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Gemini API Key',
                      hintText: 'يُحفظ محلياً في التخزين الآمن',
                      prefixIcon: Icon(Icons.key),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setSheetState(() => isSaving = true);
                                  await gemini.clearApiKey();
                                  apiKeyController.clear();
                                  if (sheetStateContext.mounted) {
                                    setSheetState(() => isSaving = false);
                                  }
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('مسح المفتاح'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final value = apiKeyController.text.trim();
                                  if (value.isEmpty) return;
                                  setSheetState(() => isSaving = true);
                                  await gemini.saveApiKey(value);
                                  if (!mounted || !sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('تم حفظ مفتاح Gemini بأمان'),
                                    ),
                                  );
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('حفظ المفتاح'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    apiKeyController.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _transactions = [];
      _lastTransactionDate = null;
      _lastTransactionId = null;
      _hasMorePages = true;
      _paginationGeneration++;
    });

    try {
      await _loadNextTransactionsPage(force: true);
      final metrics = await Future.wait<double>([
        _db.getBalance(),
        _db.getTodayTotal('مصروف'),
        _db.getTodayTotal('مبيعات'),
      ]);
      if (!mounted) return;
      setState(() {
        _inventory = _transactions
            .where((transaction) => transaction['type'] == 'مخزون')
            .toList();
        _balance = metrics[0];
        _todayExpenses = metrics[1];
        _todaySales = metrics[2];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printInvoice() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await ExportService.printInvoice(_transactions);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الفاتورة إلى نافذة الطباعة')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذرت الطباعة: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final file = await ExportService.exportToExcel(_transactions);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تصدير Excel: ${file.path}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تصدير Excel: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNextTransactionsPage({bool force = false}) async {
    if (_isPageLoading || (!_hasMorePages && !force)) return;
    final generation = _paginationGeneration;
    final cursorDate = force ? null : _lastTransactionDate;
    final cursorId = force ? null : _lastTransactionId;

    setState(() => _isPageLoading = true);
    try {
      final page = await _db.getTransactionsPage(
        limit: _pageSize,
        lastDate: cursorDate,
        lastId: cursorId,
      );
      if (!mounted || generation != _paginationGeneration) {
        return;
      }

      final existingIds =
          _transactions.map((row) => row['id'].toString()).toSet();
      final freshRows =
          page.where((row) => existingIds.add(row['id'].toString())).toList();
      setState(() {
        if (force) {
          _transactions = freshRows;
        } else {
          _transactions.addAll(freshRows);
        }
        _hasMorePages = page.length == _pageSize;
        if (page.isNotEmpty) {
          final last = page.last;
          _lastTransactionDate = last['date']?.toString();
          _lastTransactionId = last['id']?.toString();
        }
      });
    } finally {
      if (mounted && generation == _paginationGeneration) {
        setState(() => _isPageLoading = false);
      }
    }
  }

  Future<void> _startTimedVoiceCapture() async {
    if (_isVoiceInitializing || _isListening || _isRecording) return;
    setState(() {
      _isListening = true;
      _isRecording = true;
      _lastWords = '';
      _assistantStatus = 'جاري الاستماع محلياً لمدة 10 ثوانٍ... تكلم الآن';
    });
    final text = await _aiAgent.startListening10Seconds();
    if (!mounted) return;
    setState(() {
      _lastWords = text ?? '';
      _isListening = false;
      _isRecording = false;
    });
    await _processRecognizedCommand();
  }

  Future<void> _stopListeningAndProcess() async {
    _isListening = false;
    _isRecording = false;
    await _processRecognizedCommand();
  }

  Future<void> _processRecognizedCommand() async {
    if (!mounted) return;
    if (_lastWords.isEmpty) {
      setState(() => _assistantStatus = "لم أسمع شيئاً يا شيخ، حاول مرة أخرى.");
      return;
    }
    setState(
        () => _assistantStatus = "جاري تحليل الأمر الصوتي: '$_lastWords'...");
    final res = await _aiAgent.processVoiceCommandText(_lastWords, (reply) {
      if (mounted) setState(() => _assistantStatus = reply);
    });
    if (!mounted) return;
    if (res.containsKey("targetTab")) {
      setState(() => _currentIndex = res["targetTab"] as int);
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final List<Widget> screens = [
      _buildHomeScreen(colorScheme),
      _buildSalesPurchasesScreen(colorScheme),
      _buildDebtsScreen(colorScheme),
      _buildInventoryScreen(colorScheme),
      const ProfitReportScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحاسب الصوتي',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_voice, color: Colors.amber),
            onPressed: _showVoiceSettings,
            tooltip: 'إعدادات التنشيط الصوتي',
          ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.amber),
                  )
                : const Icon(Icons.refresh, color: Colors.amber),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.08),
                    colorScheme.secondary.withValues(alpha: 0.12)
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: colorScheme.secondary.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isListening ? Icons.mic : Icons.smart_toy,
                    color: _isListening ? Colors.red : colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _assistantStatus,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: screens[_currentIndex],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _isVoiceInitializing || _isLoading
            ? null
            : () {
                if (_isListening) {
                  _stopListeningAndProcess();
                } else {
                  _startTimedVoiceCapture();
                }
              },
        backgroundColor: _isListening ? Colors.red : colorScheme.secondary,
        child: _isVoiceInitializing
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.black87,
                ),
              )
            : Icon(
                _isListening ? Symbols.stop : Symbols.mic,
                size: 36,
                color: _isListening ? Colors.white : Colors.black87,
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'مبيعات ومشتريات',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'الديون والحسابات',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'المخزن',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'الأرباح',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeScreen(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.primary.withValues(alpha: 0.8)
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إجمالي الخزنة الرصيد',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                '${_balance.toStringAsFixed(0)} ر.ي',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryBadge(
                      'مبيعات اليوم',
                      '${_todaySales.toStringAsFixed(0)} ر.ي',
                      Colors.greenAccent),
                  _summaryBadge(
                      'مصروفات اليوم',
                      '${_todayExpenses.toStringAsFixed(0)} ر.ي',
                      Colors.orangeAccent),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms),
        const SizedBox(height: 24),
        const Text('تجربة الأوامر الصوتية الفورية:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quickCommandChip('سجل مصروف بنزين بعشرين ألف'),
            _quickCommandChip('دين لي على خالد بمئة ألف'),
            _quickCommandChip('مبيعات بمليون ريال'),
            _quickCommandChip('كم صرفت اليوم'),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _isLoading ? null : _printInvoice,
              icon: const Icon(Icons.print_outlined),
              label: const Text('طباعة فاتورة'),
            ),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _exportExcel,
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('تصدير Excel'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('آخر العمليات المسجلة:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _isLoading
            ? _buildTransactionSkeletons()
            : _transactions.isEmpty
                ? const Center(
                    child: Text(
                        'لا توجد عمليات مسجلة بعد. استخدم الميكروفون وسجل أول عملية!'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount:
                        _transactions.length > 5 ? 5 : _transactions.length,
                    itemBuilder: (context, index) {
                      final tx = _transactions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tx['type'] == 'مبيعات'
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            child: Icon(
                              tx['type'] == 'مبيعات'
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: tx['type'] == 'مبيعات'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          title: Text(
                              tx['title'] ??
                                  tx['description'] ??
                                  'عملية محاسبية',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${tx['type']} • ${tx['date']}'),
                          trailing: Text(
                            '${tx['amount']} ر.ي',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: tx['type'] == 'مبيعات'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ],
    );
  }

  Widget _buildSalesPurchasesScreen(ColorScheme colorScheme) {
    final salesAndPurchases = _transactions
        .where((t) => t['type'] == 'مبيعات' || t['type'] == 'مشتريات')
        .toList();
    final listItemCount = salesAndPurchases.length + (_hasMorePages ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل المبيعات والمشتريات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                controller: _transactionsController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: listItemCount == 0 ? 1 : listItemCount,
                itemBuilder: (context, index) {
                  if (salesAndPurchases.isEmpty && listItemCount == 0) {
                    return const Center(
                        child: Text('لا توجد مبيعات أو مشتريات مسجلة'));
                  }
                  if (index == salesAndPurchases.length) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final item = salesAndPurchases[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item['title'] ?? item['description']),
                      subtitle: Text('${item['type']} - ${item['date']}'),
                      trailing: Text('${item['amount']} ر.ي',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtsScreen(ColorScheme colorScheme) {
    final debts = _transactions
        .where((t) =>
            t['type'] == 'دين لك' ||
            t['type'] == 'دين عليك' ||
            t['type'] == 'دين_لي' ||
            t['type'] == 'دين_علي')
        .toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل الديون والحسابات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: debts.isEmpty
                ? const Center(child: Text('لا توجد ديون مسجلة'))
                : ListView.builder(
                    itemCount: debts.length,
                    itemBuilder: (context, index) {
                      final item = debts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item['title'] ?? item['description']),
                          subtitle: Text('${item['type']} - ${item['date']}'),
                          trailing: Text('${item['amount']} ر.ي',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryScreen(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إدارة المخزن والبضائع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: _inventory.isEmpty
                ? const Center(
                    child: Text(
                        'المخزن فارغ. أضف بضائع جديدة أو استخدم الأمر الصوتي'))
                : ListView.builder(
                    itemCount: _inventory.length,
                    itemBuilder: (context, index) {
                      final inv = _inventory[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(inv['name']),
                          subtitle: Text(
                              'الكمية: ${inv['quantity']} - السعر: ${inv['price']} ر.ي'),
                          trailing:
                              const Icon(Icons.inventory, color: Colors.amber),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSkeletons() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: const SizedBox(
              height: 72,
              width: double.infinity,
              child: Card(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryBadge(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _quickCommandChip(String commandText) {
    return ActionChip(
      label: Text(commandText, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.blue.shade50,
      onPressed: () async {
        setState(() =>
            _assistantStatus = "جاري تنفيذ الأمر التجريبي: '$commandText'");
        var res = await _aiAgent.processVoiceCommandText(commandText, (reply) {
          setState(() => _assistantStatus = reply);
        });
        if (res.containsKey("targetTab")) {
          setState(() => _currentIndex = res["targetTab"]);
        }
        await _loadData();
      },
    );
  }
}
