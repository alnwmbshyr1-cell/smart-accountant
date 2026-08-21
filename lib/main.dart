import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartAccountantApp());
}

class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final String type; // 'مبيعات', 'مشتريات', 'دين لك', 'دين عليك'
  final String date;

  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type,
        'date': date,
      };

  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        type: json['type'],
        date: json['date'],
      );
}

class InventoryItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final int minLimit;

  InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.minLimit,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'price': price,
        'minLimit': minLimit,
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'],
        name: json['name'],
        quantity: json['quantity'],
        price: (json['price'] as num).toDouble(),
        minLimit: json['minLimit'],
      );
}

class SmartAccountantApp extends StatelessWidget {
  const SmartAccountantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Accountant - المحاسب الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B0000), // Royal Red
          primary: const Color(0xFF8B0000),
          secondary: const Color(0xFFD4AF37), // Gold
        ),
        useMaterial3: true,
      ),
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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<TransactionItem> _transactions = [];
  List<InventoryItem> _inventory = [];
  bool _isLoading = true;
  
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  String _lastSpokenText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
    _loadData();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('ar-SA');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _startListening(BuildContext ctx) async {
    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'notListening' || val == 'done') {
          setState(() => _isListening = false);
        }
      },
      onError: (val) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('خطأ في التعرف الصوتي: ${val.errorMsg}')),
        );
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() {
            _lastSpokenText = val.recognizedWords;
          });
          if (val.finalResult && _lastSpokenText.isNotEmpty) {
            _processVoiceCommand(_lastSpokenText);
          }
        },
        localeId: 'ar_SA',
      );
    } else {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('خدمة التعرف الصوتي غير متاحة على هذا الجهاز')),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? txData = prefs.getString('smart_transactions');
    final String? invData = prefs.getString('smart_inventory');

    setState(() {
      if (txData != null) {
        final List decoded = jsonDecode(txData);
        _transactions = decoded.map((e) => TransactionItem.fromJson(e)).toList();
      } else {
        _transactions = [
          TransactionItem(id: '1', title: 'مبيعات بضاعة عامة', amount: 15000, type: 'مبيعات', date: '2026-08-21'),
          TransactionItem(id: '2', title: 'شراء مواد ومستلزمات', amount: 8000, type: 'مشتريات', date: '2026-08-21'),
          TransactionItem(id: '3', title: 'دين على الزبون محمد', amount: 3000, type: 'دين لك', date: '2026-08-20'),
          TransactionItem(id: '4', title: 'دين للمورد الرئيسي', amount: 5000, type: 'دين عليك', date: '2026-08-19'),
        ];
      }

      if (invData != null) {
        final List decodedInv = jsonDecode(invData);
        _inventory = decodedInv.map((e) => InventoryItem.fromJson(e)).toList();
      } else {
        _inventory = [
          InventoryItem(id: '101', name: 'أرز بسمتي فاخر', quantity: 45, price: 2500, minLimit: 10),
          InventoryItem(id: '102', name: 'لحم حنيذ بلدي', quantity: 8, price: 6000, minLimit: 5),
          InventoryItem(id: '103', name: 'بهارات يمنية خاصة', quantity: 120, price: 500, minLimit: 20),
        ];
      }
      _isLoading = false;
    });
    _saveData();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smart_transactions', jsonEncode(_transactions.map((e) => e.toJson()).toList()));
    await prefs.setString('smart_inventory', jsonEncode(_inventory.map((e) => e.toJson()).toList()));
  }

  void _addTransaction(String title, double amount, String type) {
    setState(() {
      _transactions.insert(
        0,
        TransactionItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amount: amount,
          type: type,
          date: DateTime.now().toString().substring(0, 10),
        ),
      );
    });
    _saveData();
    _speak('تم حفظ العملية');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إضافة المعاملة بنجاح وحفظها محلياً')),
    );
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((element) => element.id == id);
    });
    _saveData();
  }

  void _addInventoryItem(String name, int qty, double price, int limit) {
    setState(() {
      _inventory.add(InventoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        quantity: qty,
        price: price,
        minLimit: limit,
      ));
    });
    _saveData();
  }

  void _updateInventoryQty(String id, int delta) {
    setState(() {
      final index = _inventory.indexWhere((element) => element.id == id);
      if (index != -1) {
        final item = _inventory[index];
        final newQty = item.quantity + delta;
        if (newQty >= 0) {
          _inventory[index] = InventoryItem(
            id: item.id,
            name: item.name,
            quantity: newQty,
            price: item.price,
            minLimit: item.minLimit,
          );
        }
      }
    });
    _saveData();
  }

  // المحاسب الصوتي الذكي مع دعم الميكروفون الحقيقي والرد الصوتي
  void _openVoiceAssistantModal() {
    final TextEditingController voiceInputCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.mic, color: Color(0xFF8B0000)),
              SizedBox(width: 8),
              Text('المحاسب الصوتي الذكي'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اضغط على زر الميكروفون وتحدث بصوتك (مثال: "سجل مبيعات بخمسة آلاف") أو اكتب الأمر:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    if (_isListening) {
                      _stopListening();
                      setStateModal(() {});
                    } else {
                      await _startListening(context);
                      setStateModal(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red.shade100 : const Color(0xFF8B0000).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: 40,
                      color: const Color(0xFF8B0000),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _isListening ? 'جارٍ الاستماع الآن... تحدث بوضوح' : 'اضغط للتحدث بالميكروفون',
                  style: TextStyle(fontSize: 12, color: _isListening ? Colors.red : Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: voiceInputCtrl,
                decoration: const InputDecoration(
                  labelText: 'النص المنطوق أو المكتوب...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.record_voice_over),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              const Text('أوامر تجريبية سريعة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chipCommand(voiceInputCtrl, 'سجل مبيعات بخمسة آلاف'),
                  _chipCommand(voiceInputCtrl, 'شراء بضاعة بألفين'),
                  _chipCommand(voiceInputCtrl, 'دين لك بثلاثة آلاف'),
                  _chipCommand(voiceInputCtrl, 'دين عليك بألف وخمسمائة'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
              onPressed: () {
                final text = voiceInputCtrl.text.trim();
                Navigator.pop(context);
                if (text.isNotEmpty) {
                  _processVoiceCommand(text);
                }
              },
              child: const Text('تنفيذ الأمر'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipCommand(TextEditingController controller, String cmd) {
    return ActionChip(
      label: Text(cmd, style: const TextStyle(fontSize: 11)),
      onPressed: () => controller.text = cmd,
    );
  }

  void _processVoiceCommand(String rawText) {
    String lower = rawText.toLowerCase();
    String type = 'مبيعات';
    if (lower.contains('مشتريات') || lower.contains('شراء')) {
      type = 'مشتريات';
    } else if (lower.contains('دين لك') || lower.contains('على الزبون') || lower.contains('لنا')) {
      type = 'دين لك';
    } else if (lower.contains('دين عليك') || lower.contains('للمورد') || lower.contains('علينا')) {
      type = 'دين عليك';
    } else if (lower.contains('مبيعات') || lower.contains('بيع')) {
      type = 'مبيعات';
    }

    // استخراج رقم بسيط أو تقديري افتراضي
    double amount = 1000.0;
    if (lower.contains('خمسة آلاف') || lower.contains('5000')) {
      amount = 5000.0;
    } else if (lower.contains('أربعة آلاف') || lower.contains('4000')) {
      amount = 4000.0;
    } else if (lower.contains('ثلاثة آلاف') || lower.contains('3000')) {
      amount = 3000.0;
    } else if (lower.contains('ألفين') || lower.contains('2000')) {
      amount = 2000.0;
    } else if (lower.contains('ألف وخمسمائة') || lower.contains('1500')) {
      amount = 1500.0;
    } else if (lower.contains('ألف') || lower.contains('1000')) {
      amount = 1000.0;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد العملية الصوتية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الأمر المنطوق: "$rawText"'),
            const SizedBox(height: 10),
            Text('نوع المعاملة: $type', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('المبلغ المستخرج: $amount ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _addTransaction('أمر صوتي: $rawText', amount, type);
            },
            child: const Text('اعتماد الحفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardTab(transactions: _transactions, inventory: _inventory, onAdd: _addTransaction),
      InventoryTab(inventory: _inventory, onAdd: _addInventoryItem, onUpdateQty: _updateInventoryQty),
      CalculatorTab(onAddTransaction: _addTransaction),
      ChartsTab(transactions: _transactions),
      HistoryTab(transactions: _transactions, onDelete: _deleteTransaction),
      ReportsTab(transactions: _transactions),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Accountant - المحاسب الذكي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF8B0000),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: Color(0xFFD4AF37)),
            tooltip: 'الأوامر الصوتية',
            onPressed: _openVoiceAssistantModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF8B0000),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'المخزن'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'الحاسبة'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'الرسوم'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'السجل'),
          BottomNavigationBarItem(icon: Icon(Icons.picture_as_pdf), label: 'التقارير'),
        ],
      ),
    );
  }
}

// 1. لوحة التحكم الرئيسية
class DashboardTab extends StatelessWidget {
  final List<TransactionItem> transactions;
  final List<InventoryItem> inventory;
  final Function(String, double, String) onAdd;

  const DashboardTab({super.key, required this.transactions, required this.inventory, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    double totalSales = transactions.where((e) => e.type == 'مبيعات').fold(0, (sum, item) => sum + item.amount);
    double totalPurchases = transactions.where((e) => e.type == 'مشتريات').fold(0, (sum, item) => sum + item.amount);
    double totalReceivable = transactions.where((e) => e.type == 'دين لك').fold(0, (sum, item) => sum + item.amount);
    double totalPayable = transactions.where((e) => e.type == 'دين عليك').fold(0, (sum, item) => sum + item.amount);
    int lowStockCount = inventory.where((e) => e.quantity <= e.minLimit).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8B0000), Color(0xFF5A0000)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مرحباً بك، المحاسب الذكي', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('صافي الأرباح التشغيلية', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(
                  '${(totalSales - totalPurchases).toStringAsFixed(0)} ر.ي',
                  style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (lowStockCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('تنبيه: يوجد $lowStockCount أصناف قاربت على النفاد في المخزن!', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text('ملخص الحسابات المالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildCard('إجمالي المبيعات', '$totalSales ر.ي', Icons.trending_up, Colors.green),
              _buildCard('إجمالي المشتريات', '$totalPurchases ر.ي', Icons.shopping_bag, Colors.orange),
              _buildCard('ديون لك (لنا)', '$totalReceivable ر.ي', Icons.arrow_downward, Colors.blue),
              _buildCard('ديون عليك (علينا)', '$totalPayable ر.ي', Icons.arrow_upward, Colors.red),
            ],
          ),
          const SizedBox(height: 20),
          const Text('آخر المعاملات المسجلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          transactions.isEmpty
              ? const Center(child: Text('لا توجد معاملات مسجلة بعد'))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length > 5 ? 5 : transactions.length,
                  itemBuilder: (context, index) {
                    final item = transactions[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorForType(item.type).withOpacity(0.2),
                          child: Icon(_getIconForType(item.type), color: _getColorForType(item.type)),
                        ),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item.type} • ${item.date}'),
                        trailing: Text('${item.amount} ر.ي', style: TextStyle(fontWeight: FontWeight.bold, color: _getColorForType(item.type))),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'مبيعات': return Colors.green;
      case 'مشتريات': return Colors.orange;
      case 'دين لك': return Colors.blue;
      case 'دين عليك': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'مبيعات': return Icons.trending_up;
      case 'مشتريات': return Icons.shopping_bag;
      case 'دين لك': return Icons.arrow_downward;
      case 'دين عليك': return Icons.arrow_upward;
      default: return Icons.receipt;
    }
  }
}

// 2. إدارة المخزن (Inventory Tab)
class InventoryTab extends StatelessWidget {
  final List<InventoryItem> inventory;
  final Function(String, int, double, int) onAdd;
  final Function(String, int) onUpdateQty;

  const InventoryTab({super.key, required this.inventory, required this.onAdd, required this.onUpdateQty});

  void _showAddItemDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final limitCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة صنف جديد للمخزن'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الصنف')),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية الأولية')),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الوحدة (ر.ي)')),
              TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد التنبيه الأدنى')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && qtyCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                onAdd(
                  nameCtrl.text.trim(),
                  int.tryParse(qtyCtrl.text) ?? 0,
                  double.tryParse(priceCtrl.text) ?? 0,
                  int.tryParse(limitCtrl.text) ?? 5,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: inventory.isEmpty
          ? const Center(child: Text('المخزن فارغ. أضف أصناف جديدة.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                final item = inventory[index];
                bool isLow = item.quantity <= item.minLimit;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('السعر: ${item.price} ر.ي • الحد الأدنى: ${item.minLimit}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${item.quantity} وحدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLow ? Colors.red : Colors.green)),
                            if (isLow) const Text('منخفض!', style: TextStyle(fontSize: 10, color: Colors.red)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.orange),
                          onPressed: () => onUpdateQty(item.id, -1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () => onUpdateQty(item.id, 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(context),
        backgroundColor: const Color(0xFF8B0000),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// 3. الحاسبة الذكية (Calculator Tab)
class CalculatorTab extends StatefulWidget {
  final Function(String, double, String) onAddTransaction;

  const CalculatorTab({super.key, required this.onAddTransaction});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  String _output = '0';
  String _expression = '';
  double num1 = 0;
  double num2 = 0;
  String operand = '';
  final TextEditingController _titleController = TextEditingController();
  String _selectedType = 'مبيعات';

  void _buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == 'C') {
        _output = '0';
        _expression = '';
        num1 = 0;
        num2 = 0;
        operand = '';
      } else if (buttonText == '+' || buttonText == '-' || buttonText == '×' || buttonText == '÷') {
        num1 = double.tryParse(_output) ?? 0;
        operand = buttonText;
        _expression = '$_output $operand ';
        _output = '0';
      } else if (buttonText == '=') {
        num2 = double.tryParse(_output) ?? 0;
        if (operand == '+') _output = (num1 + num2).toString();
        if (operand == '-') _output = (num1 - num2).toString();
        if (operand == '×') _output = (num1 * num2).toString();
        if (operand == '÷') _output = num2 != 0 ? (num1 / num2).toString() : 'خطأ';
        _expression = '';
        operand = '';
      } else {
        if (_output == '0') {
          _output = buttonText;
        } else {
          _output += buttonText;
        }
      }
    });
  }

  void _saveFromCalculator() {
    final double? amount = double.tryParse(_output);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح')));
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء كتابة وصف العملية')));
      return;
    }

    widget.onAddTransaction(_titleController.text.trim(), amount, _selectedType);
    _titleController.clear();
    setState(() {
      _output = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_expression, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text(_output, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              'C', '÷', '×', '-',
              '7', '8', '9', '+',
              '4', '5', '6', '=',
              '1', '2', '3', '0',
            ].map((text) => ElevatedButton(
                  onPressed: () => _buttonPressed(text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: text == '=' || text == '+' || text == '-' || text == '×' || text == '÷'
                        ? const Color(0xFFD4AF37)
                        : Colors.grey.shade200,
                    foregroundColor: text == '=' || text == '+' || text == '-' || text == '×' || text == '÷'
                        ? Colors.white
                        : Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                )).toList(),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const Text('ترحيل الناتج إلى سجل العمليات المحاسبية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'وصف العملية (مثال: بيع بضاعة، شراء مستلزمات)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'نوع العملية'),
            items: ['مبيعات', 'مشتريات', 'دين لك', 'دين عليك']
                .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                .toList(),
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveFromCalculator,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('حفظ العملية في السجل', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000)),
            ),
          ),
        ],
      ),
    );
  }
}

// 4. الرسوم البيانية التفاعلية (Charts Tab)
class ChartsTab extends StatelessWidget {
  final List<TransactionItem> transactions;

  const ChartsTab({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    double totalSales = transactions.where((e) => e.type == 'مبيعات').fold(0, (sum, i) => sum + i.amount);
    double totalPurchases = transactions.where((e) => e.type == 'مشتريات').fold(0, (sum, i) => sum + i.amount);
    double totalReceivable = transactions.where((e) => e.type == 'دين لك').fold(0, (sum, i) => sum + i.amount);
    double totalPayable = transactions.where((e) => e.type == 'دين عليك').fold(0, (sum, i) => sum + i.amount);

    double maxVal = [totalSales, totalPurchases, totalReceivable, totalPayable].reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('التحليل المالي والرسوم البيانية الشهرية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('مقارنة بصرية شاملة لأداء المبيعات والمشتريات والديون.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _buildBarItem('المبيعات', totalSales, Colors.green, maxVal),
          _buildBarItem('المشتريات', totalPurchases, Colors.orange, maxVal),
          _buildBarItem('ديون لك', totalReceivable, Colors.blue, maxVal),
          _buildBarItem('ديون عليك', totalPayable, Colors.red, maxVal),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تحليلات ذكية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Text('• حركة المبيعات مستقرة وتغطي تكاليف المشتريات بنجاح.'),
                Text('• يوصى بمتابعة تحصيل الديون المستحقة (دين لك) لتحسين السيولة النقدية.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(String label, double value, Color color, double max) {
    double pct = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('$value ر.ي', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              color: color,
              backgroundColor: Colors.grey.shade200,
              minHeight: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// 5. سجل العمليات (History Tab)
class HistoryTab extends StatelessWidget {
  final List<TransactionItem> transactions;
  final Function(String) onDelete;

  const HistoryTab({super.key, required this.transactions, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return transactions.isEmpty
        ? const Center(child: Text('لا توجد عمليات مسجلة بعد'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final item = transactions[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item.type} • التاريخ: ${item.date}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${item.amount} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => onDelete(item.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}

// 6. التقارير وتصدير PDF (Reports Tab)
class ReportsTab extends StatelessWidget {
  final List<TransactionItem> transactions;

  const ReportsTab({super.key, required this.transactions});

  Future<void> _generateAndOpenPdf(BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Smart Accountant - المحاسب الذكي', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.Text('تقرير العمليات المالية', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('تاريخ التقرير: ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['الرقم', 'الوصف', 'النوع', 'المبلغ (ر.ي)', 'التاريخ'],
                  data: transactions.map((e) => [e.id, e.title, e.type, e.amount.toString(), e.date]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerRight,
                ),
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('إجمالي المعاملات: ${transactions.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('الإجمالي العام: ${transactions.fold(0.0, (sum, i) => sum + i.amount)} ر.ي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/smart_accountant_report.pdf');
      await file.writeAsBytes(await pdf.save());

      await OpenFile.open(file.path);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ وتصدير ملف PDF بنجاح: ${file.path}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تصدير PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 80, color: Color(0xFF8B0000)),
          const SizedBox(height: 20),
          const Text('تصدير التقارير المالية كملف PDF', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('احفظ واطبع تقارير المبيعات والمشتريات والديون بتصميم احترافي متوافق مع الاتجاه العربي RTL.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _generateAndOpenPdf(context),
            icon: const Icon(Icons.download, color: Colors.white),
            label: const Text('تصدير وفتح تقرير PDF', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
