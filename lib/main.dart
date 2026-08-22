import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'ai_agent_service.dart';
import 'database_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartAccountantApp());
}

class SmartAccountantApp extends StatelessWidget {
  const SmartAccountantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'عاقل المحاسبة الخارق v2.4.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // Deep Blue
          primary: const Color(0xFF0D47A1),
          secondary: const Color(0xFFFFC107), // Gold
          surface: const Color(0xFFF8F9FA),
        ),
        useMaterial3: true,
        fontFamily: 'Cairo',
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
        fontFamily: 'Cairo',
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
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const MainDashboardScreen(),
    );
  }
}

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 0;
  final AiAgentService _aiAgent = AiAgentService();
  final DatabaseService _db = DatabaseService();
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = "";
  String _assistantStatus = "أهلاً بك يا شيخ، اضغط الميكروفون أو تحدث وسأقوم بالتنفيذ فوراً";
  
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _inventory = [];
  double _balance = 0.0;
  double _todayExpenses = 0.0;
  double _todaySales = 0.0;

  @override
  void initState() {
    super.initState();
    _initSpeechAndAgent();
    _loadData();
  }

  Future<void> _initSpeechAndAgent() async {
    await _aiAgent.init();
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' && _isListening) {
          _stopListeningAndProcess();
        }
      },
      onError: (error) => setState(() => _isListening = false),
    );
    if (!available) {
      setState(() => _assistantStatus = "الميكروفون غير متوفر في هذا الجهاز");
    }
  }

  Future<void> _loadData() async {
    final txs = await _db.getTransactions();
    final bal = await _db.getBalance();
    final exp = await _db.getTodayTotal('مصروف');
    final sales = await _db.getTodayTotal('مبيعات');
    setState(() {
      _transactions = txs;
      _inventory = []; // مخزن محلي تجريبي
      _balance = bal;
      _todayExpenses = exp;
      _todaySales = sales;
    });
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _lastWords = "";
          _assistantStatus = "جاري الاستماع... (تكلم بخصوص المصروفات أو المبيعات أو الديون)";
        });
        
        await _aiAgent.speakYemeni("تفضل يا شيخ، أنا أسمعك...");

        _speech.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords;
            });
            if (result.finalResult) {
              _stopListeningAndProcess();
            }
          },
          localeId: 'ar_SA',
        );
      }
    }
  }

  void _stopListeningAndProcess() async {
    _speech.stop();
    setState(() {
      _isListening = false;
    });

    if (_lastWords.isNotEmpty) {
      setState(() => _assistantStatus = "جاري تحليل الأمر الصوتي: '$_lastWords'...");
      
      var res = await _aiAgent.processVoiceCommandText(_lastWords, (reply) {
        setState(() {
          _assistantStatus = reply;
        });
      });

      if (res.containsKey("targetTab")) {
        setState(() {
          _currentIndex = res["targetTab"];
        });
      }

      await _loadData();
    } else {
      setState(() => _assistantStatus = "لم أسمع شيئاً يا شيخ، حاول مرة أخرى.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final List<Widget> screens = [
      _buildHomeScreen(colorScheme),
      _buildSalesPurchasesScreen(colorScheme),
      _buildDebtsScreen(colorScheme),
      _buildInventoryScreen(colorScheme),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('عاقل المحاسبة الخارق v2.4.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: _loadData,
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
                  colors: [colorScheme.primary.withValues(alpha: 0.08), colorScheme.secondary.withValues(alpha: 0.12)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.5)),
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
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
        onPressed: () {
          if (_isListening) {
            _stopListeningAndProcess();
          } else {
            _startListening();
          }
        },
        backgroundColor: _isListening ? Colors.red : colorScheme.secondary,
        child: Icon(
          _isListening ? Icons.stop : Icons.mic,
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
              colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: colorScheme.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إجمالي الخزنة الرصيد', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                '${_balance.toStringAsFixed(0)} ر.ي',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryBadge('مبيعات اليوم', '${_todaySales.toStringAsFixed(0)} ر.ي', Colors.greenAccent),
                  _summaryBadge('مصروفات اليوم', '${_todayExpenses.toStringAsFixed(0)} ر.ي', Colors.orangeAccent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        const Text('تجربة الأوامر الصوتية الفورية:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

        const Text('آخر العمليات المسجلة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _transactions.isEmpty
            ? const Center(child: Text('لا توجد عمليات مسجلة بعد. استخدم الميكروفون وسجل أول عملية!'))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length > 5 ? 5 : _transactions.length,
                itemBuilder: (context, index) {
                  final tx = _transactions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: tx['type'] == 'مبيعات' ? Colors.green.shade100 : Colors.red.shade100,
                        child: Icon(
                          tx['type'] == 'مبيعات' ? Icons.arrow_downward : Icons.arrow_upward,
                          color: tx['type'] == 'مبيعات' ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(tx['title'] ?? tx['description'] ?? 'عملية محاسبية', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${tx['type']} • ${tx['date']}'),
                      trailing: Text(
                        '${tx['amount']} ر.ي',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: tx['type'] == 'مبيعات' ? Colors.green : Colors.red,
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
    final salesAndPurchases = _transactions.where((t) => t['type'] == 'مبيعات' || t['type'] == 'مشتريات').toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل المبيعات والمشتريات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: salesAndPurchases.isEmpty
                ? const Center(child: Text('لا توجد مبيعات أو مشتريات مسجلة'))
                : ListView.builder(
                    itemCount: salesAndPurchases.length,
                    itemBuilder: (context, index) {
                      final item = salesAndPurchases[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item['title'] ?? item['description']),
                          subtitle: Text('${item['type']} - ${item['date']}'),
                          trailing: Text('${item['amount']} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtsScreen(ColorScheme colorScheme) {
    final debts = _transactions.where((t) => t['type'] == 'دين لك' || t['type'] == 'دين عليك').toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل الديون والحسابات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          trailing: Text('${item['amount']} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
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
          const Text('إدارة المخزن والبضائع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: _inventory.isEmpty
                ? const Center(child: Text('المخزن فارغ. أضف بضائع جديدة أو استخدم الأمر الصوتي'))
                : ListView.builder(
                    itemCount: _inventory.length,
                    itemBuilder: (context, index) {
                      final inv = _inventory[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(inv['name']),
                          subtitle: Text('الكمية: ${inv['quantity']} - السعر: ${inv['price']} ر.ي'),
                          trailing: const Icon(Icons.inventory, color: Colors.amber),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBadge(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _quickCommandChip(String commandText) {
    return ActionChip(
      label: Text(commandText, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.blue.shade50,
      onPressed: () async {
        setState(() => _assistantStatus = "جاري تنفيذ الأمر التجريبي: '$commandText'");
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
