import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('smart_transactions');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _transactions = decoded.map((e) => TransactionItem.fromJson(e)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _transactions = [
          TransactionItem(id: '1', title: 'مبيعات بضاعة عامة', amount: 15000, type: 'مبيعات', date: '2026-08-21'),
          TransactionItem(id: '2', title: 'شراء مواد ومستلزمات', amount: 8000, type: 'مشتريات', date: '2026-08-21'),
          TransactionItem(id: '3', title: 'دين على الزبون محمد', amount: 3000, type: 'دين لك', date: '2026-08-20'),
          TransactionItem(id: '4', title: 'دين للمورد الرئيسي', amount: 5000, type: 'دين عليك', date: '2026-08-19'),
        ];
        _isLoading = false;
      });
      _saveTransactions();
    }
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_transactions.map((e) => e.toJson()).toList());
    await prefs.setString('smart_transactions', encoded);
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
    _saveTransactions();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إضافة المعاملة بنجاح وحفظها محلياً')),
    );
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((element) => element.id == id);
    });
    _saveTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardTab(transactions: _transactions, onAdd: _addTransaction),
      CalculatorTab(onAddTransaction: _addTransaction),
      HistoryTab(transactions: _transactions, onDelete: _deleteTransaction),
      ReportsTab(transactions: _transactions),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Accountant - المحاسب الذكي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF8B0000),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
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
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'الحاسبة الذكية'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'سجل العمليات'),
          BottomNavigationBarItem(icon: Icon(Icons.picture_as_pdf), label: 'التقارير و PDF'),
        ],
      ),
    );
  }
}

// 1. لوحة التحكم الرئيسية (Dashboard)
class DashboardTab extends StatelessWidget {
  final List<TransactionItem> transactions;
  final Function(String, double, String) onAdd;

  const DashboardTab({super.key, required this.transactions, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    double totalSales = transactions.where((e) => e.type == 'مبيعات').fold(0, (sum, item) => sum + item.amount);
    double totalPurchases = transactions.where((e) => e.type == 'مشتريات').fold(0, (sum, item) => sum + item.amount);
    double totalReceivable = transactions.where((e) => e.type == 'دين لك').fold(0, (sum, item) => sum + item.amount);
    double totalPayable = transactions.where((e) => e.type == 'دين عليك').fold(0, (sum, item) => sum + item.amount);

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

// 2. الحاسبة الذكية (Calculator Tab)
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

// 3. سجل العمليات (History Tab)
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

// 4. التقارير وتصدير PDF (Reports Tab)
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
                pw.Table.fromTextArray(
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ وتصدير ملف PDF بنجاح: ${file.path}')),
      );
    } catch (e) {
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
