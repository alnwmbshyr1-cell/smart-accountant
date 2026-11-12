import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'accounting_database.dart';

const _green = Color(0xFF167D62);
const _ink = Color(0xFF17362E);
const _background = Color(0xFFF5F8F6);

class AccountingApp extends StatefulWidget {
  const AccountingApp({super.key, required this.database});
  final AccountingDatabase database;
  @override
  State<AccountingApp> createState() => _AccountingAppState();
}

class _AccountingAppState extends State<AccountingApp> {
  int tab = 0;
  int revision = 0;
  bool dark = false;
  void refresh() => setState(() => revision++);

  @override
  Widget build(BuildContext context) {
    final light = ThemeData(useMaterial3: true, fontFamily: 'DejaVuSans', colorScheme: ColorScheme.fromSeed(seedColor: _green), scaffoldBackgroundColor: _background, cardTheme: const CardThemeData(color: Colors.white, elevation: 0));
    final night = ThemeData(useMaterial3: true, brightness: Brightness.dark, fontFamily: 'DejaVuSans', colorScheme: ColorScheme.fromSeed(seedColor: _green, brightness: Brightness.dark));
    final pages = <Widget>[
      DashboardPage(database: widget.database, revision: revision, onOpenJournal: () => setState(() => tab = 1)),
      JournalPage(database: widget.database, revision: revision, onSaved: refresh),
      BusinessPage(database: widget.database, revision: revision, onSaved: refresh),
      ReportsPage(database: widget.database, revision: revision),
      SettingsPage(dark: dark, onDarkChanged: (value) => setState(() => dark = value)),
    ];
    return MaterialApp(
      title: 'دفتر المحاسبة', debugShowCheckedModeBanner: false,
      locale: const Locale('ar'), supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: light, darkTheme: night, themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: IndexedStack(index: tab, children: pages),
        floatingActionButton: tab == 1 ? null : FloatingActionButton.extended(onPressed: () => _quickAdd(context), backgroundColor: _green, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('إضافة')),
        bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'القيود'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'الأعمال'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ]),
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(context: context, builder: (context) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.edit_note), title: const Text('قيد يومية'), onTap: () => Navigator.pop(context, 'journal')),
      ListTile(leading: const Icon(Icons.person_add_alt_1), title: const Text('عميل أو مورد'), onTap: () => Navigator.pop(context, 'party')),
      ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('صنف مخزون'), onTap: () => Navigator.pop(context, 'product')),
    ])));
    if (!mounted || choice == null) return;
    if (choice == 'journal') setState(() => tab = 1);
    if (choice == 'party' || choice == 'product') setState(() => tab = 2);
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.database, required this.revision, required this.onOpenJournal});
  final AccountingDatabase database;
  final int revision;
  final VoidCallback onOpenJournal;
  @override
  Widget build(BuildContext context) => SafeArea(child: FutureBuilder<Map<String, int>>(key: ValueKey(revision), future: database.totals(), builder: (context, snapshot) {
    final values = snapshot.data ?? const <String, int>{};
    final income = -(values['income'] ?? 0);
    final expense = values['expense'] ?? 0;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('مساحة عملك', style: TextStyle(color: Colors.grey)),
      const Text('دفتر المحاسبة', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: _ink)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [_ink, _green], begin: Alignment.topRight, end: Alignment.bottomLeft)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('صافي الإيرادات', style: TextStyle(color: Colors.white70)), const SizedBox(height: 10),
        Text(_money(income - expense), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 20),
        Row(children: [Expanded(child: _metric('الإيرادات', income, Icons.trending_up)), const SizedBox(width: 12), Expanded(child: _metric('المصروفات', expense, Icons.trending_down))]),
      ])),
      const SizedBox(height: 22),
      Row(children: [const Expanded(child: Text('الوصول السريع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), TextButton(onPressed: onOpenJournal, child: const Text('القيود'))]),
      Row(children: [Expanded(child: _Shortcut(icon: Icons.edit_note, label: 'قيد يومية', onTap: onOpenJournal)), const SizedBox(width: 10), Expanded(child: _Shortcut(icon: Icons.bar_chart, label: 'ميزان المراجعة', onTap: () {}))]),
      const SizedBox(height: 20), const Text('آخر القيود', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
      FutureBuilder<List<Map<String, Object?>>>(future: database.journal(), builder: (context, journal) {
        final entries = journal.data ?? [];
        if (entries.isEmpty) return const _Empty('سجّل أول قيد لبدء متابعة حساباتك.');
        return Column(children: entries.take(5).map((entry) => Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE9F5EF), child: Icon(Icons.receipt_long, color: _green)), title: Text('${entry['description']}'), subtitle: Text('${entry['entry_date']}'), trailing: Text(_minor(entry['total_minor'] as int? ?? 0)))).toList());
      }),
    ]);
  }));
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, required this.database, required this.revision, required this.onSaved});
  final AccountingDatabase database; final int revision; final VoidCallback onSaved;
  @override State<JournalPage> createState() => _JournalPageState();
}
class _JournalPageState extends State<JournalPage> {
  final _description = TextEditingController(); final _amount = TextEditingController();
  String _side = 'expense'; int? _accountId;
  @override void dispose() { _description.dispose(); _amount.dispose(); super.dispose(); }
  Future<void> _save(List<Map<String, Object?>> accounts) async {
    final amount = _parseMinor(_amount.text);
    if (_description.text.trim().isEmpty || amount <= 0) { _message(context, 'أدخل وصفًا ومبلغًا صحيحًا.'); return; }
    final debitId = _accountId ?? (int.tryParse('${accounts.first['id']}') ?? 1);
    final income = _side == 'income';
    final creditId = income ? 7 : 1;
    final lines = income
      ? [JournalLineData(accountId: debitId, debitMinor: amount), JournalLineData(accountId: 7, creditMinor: amount)]
      : [JournalLineData(accountId: 8, debitMinor: amount), JournalLineData(accountId: debitId, creditMinor: amount)];
    try {
      await widget.database.postJournal(date: DateTime.now().toIso8601String().substring(0, 10), description: _description.text, lines: lines);
      _description.clear(); _amount.clear(); widget.onSaved(); if (mounted) _message(context, 'تم ترحيل القيد المتوازن.');
    } catch (error) { if (mounted) _message(context, '$error'); }
  }
  @override Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
    const Text('القيود اليومية', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'expense', label: Text('مصروف')), ButtonSegment(value: 'income', label: Text('إيراد'))], selected: {_side}, onSelectionChanged: (set) => setState(() => _side = set.first)),
      const SizedBox(height: 12), TextField(controller: _description, decoration: const InputDecoration(labelText: 'وصف القيد')),
      const SizedBox(height: 10), TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ', suffixText: 'SAR')),
      const SizedBox(height: 12), FutureBuilder<List<Map<String, Object?>>>(future: widget.database.accounts(), builder: (context, snapshot) {
        final accounts = snapshot.data ?? [];
        final candidates = accounts.where((account) => account['type'] == (_side == 'income' ? 'asset' : 'liability')).toList();
        if (candidates.isEmpty) return const SizedBox.shrink();
        final selected = candidates.any((a) => a['id'] == _accountId) ? _accountId : candidates.first['id'] as int;
        return Column(children: [DropdownButtonFormField<int>(value: selected, decoration: const InputDecoration(labelText: 'الحساب المقابل'), items: candidates.map((a) => DropdownMenuItem(value: a['id'] as int, child: Text('${a['code']} • ${a['name']}'))).toList(), onChanged: (id) => setState(() => _accountId = id)), const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _save(accounts), icon: const Icon(Icons.check), label: const Text('حفظ وترحيل')))]);
      })
    ]))),
    const SizedBox(height: 18), const Text('سجل القيود', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
    FutureBuilder<List<Map<String, Object?>>>(key: ValueKey(widget.revision), future: widget.database.journal(), builder: (context, snapshot) { final rows = snapshot.data ?? []; return Column(children: rows.map((row) => Card(child: ListTile(title: Text('${row['description']}'), subtitle: Text('${row['entry_date']} • ${row['reference'] ?? 'قيد يدوي'}'), trailing: Text(_minor(row['total_minor'] as int? ?? 0)))).toList()); }),
  ]));
}

class BusinessPage extends StatefulWidget {
  const BusinessPage({super.key, required this.database, required this.revision, required this.onSaved});
  final AccountingDatabase database; final int revision; final VoidCallback onSaved;
  @override State<BusinessPage> createState() => _BusinessPageState();
}
class _BusinessPageState extends State<BusinessPage> {
  int section = 0;
  @override Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
    const Text('إدارة الأعمال', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 12),
    SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('العملاء والموردون')), ButtonSegment(value: 1, label: Text('المخزون')), ButtonSegment(value: 2, label: Text('الفواتير'))], selected: {section}, onSelectionChanged: (v) => setState(() => section = v.first)),
    const SizedBox(height: 14),
    if (section == 0) _PartiesPanel(database: widget.database, revision: widget.revision, onSaved: widget.onSaved),
    if (section == 1) _ProductsPanel(database: widget.database, revision: widget.revision, onSaved: widget.onSaved),
    if (section == 2) _InvoicesPanel(database: widget.database, revision: widget.revision, onSaved: widget.onSaved),
  ]));
}

class _PartiesPanel extends StatefulWidget {
  const _PartiesPanel({required this.database, required this.revision, required this.onSaved}); final AccountingDatabase database; final int revision; final VoidCallback onSaved;
  @override State<_PartiesPanel> createState() => _PartiesPanelState();
}
class _PartiesPanelState extends State<_PartiesPanel> {
  final name = TextEditingController(); final phone = TextEditingController(); String kind = 'customer';
  Future<void> add() async { if (name.text.trim().isEmpty) return; await widget.database.addParty(name: name.text, kind: kind, phone: phone.text); name.clear(); phone.clear(); widget.onSaved(); setState(() {}); }
  @override void dispose() { name.dispose(); phone.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Column(children: [Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم العميل أو المورد')), TextField(controller: phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')), DropdownButtonFormField<String>(value: kind, decoration: const InputDecoration(labelText: 'التصنيف'), items: const [DropdownMenuItem(value: 'customer', child: Text('عميل')), DropdownMenuItem(value: 'supplier', child: Text('مورد')), DropdownMenuItem(value: 'both', child: Text('كلاهما'))], onChanged: (value) => setState(() => kind = value ?? kind)), const SizedBox(height: 10), FilledButton(onPressed: add, child: const Text('إضافة طرف'))]))), FutureBuilder<List<Map<String, Object?>>>(key: ValueKey(widget.revision), future: widget.database.parties(), builder: (context, snapshot) => Column(children: (snapshot.data ?? []).map((p) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: Text('${p['name']}'), subtitle: Text('${p['kind']} • ${p['phone'] ?? ''}'))).toList()))]);
}

class _ProductsPanel extends StatefulWidget {
  const _ProductsPanel({required this.database, required this.revision, required this.onSaved}); final AccountingDatabase database; final int revision; final VoidCallback onSaved;
  @override State<_ProductsPanel> createState() => _ProductsPanelState();
}
class _ProductsPanelState extends State<_ProductsPanel> {
  final sku = TextEditingController(); final name = TextEditingController(); final price = TextEditingController(); final stock = TextEditingController();
  Future<void> add() async { final value = _parseMinor(price.text); final qty = _parseMilli(stock.text); if (sku.text.trim().isEmpty || name.text.trim().isEmpty || value < 0) return; try { await widget.database.addProduct(sku: sku.text, name: name.text, purchasePriceMinor: value, salePriceMinor: value, openingStockMilli: qty, reorderMilli: 0); sku.clear(); name.clear(); price.clear(); stock.clear(); widget.onSaved(); setState(() {}); } catch (e) { if (mounted) _message(context, '$e'); } }
  @override void dispose() { sku.dispose(); name.dispose(); price.dispose(); stock.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Column(children: [Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [TextField(controller: sku, decoration: const InputDecoration(labelText: 'رمز الصنف')), TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الصنف')), TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر', suffixText: 'SAR')), TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رصيد افتتاحي')), const SizedBox(height: 10), FilledButton(onPressed: add, child: const Text('إضافة صنف'))]))), FutureBuilder<List<Map<String, Object?>>>(key: ValueKey(widget.revision), future: widget.database.products(), builder: (context, snapshot) => Column(children: (snapshot.data ?? []).map((p) { final qty = (p['stock_milli'] as int) / 1000; return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)), title: Text('${p['name']}'), subtitle: Text('${p['sku']} • الرصيد ${qty.toStringAsFixed(3)}'), trailing: Text(_minor(p['sale_price_minor'] as int))); }).toList()))]);
}

class _InvoicesPanel extends StatefulWidget {
  const _InvoicesPanel({required this.database, required this.revision, required this.onSaved}); final AccountingDatabase database; final int revision; final VoidCallback onSaved;
  @override State<_InvoicesPanel> createState() => _InvoicesPanelState();
}
class _InvoicesPanelState extends State<_InvoicesPanel> {
  final number = TextEditingController(); int? partyId; int? productId; String kind = 'sale'; final qty = TextEditingController(text: '1');
  Future<void> create(List<Map<String, Object?>> parties, List<Map<String, Object?>> products) async {
    if (partyId == null || productId == null || number.text.trim().isEmpty) { _message(context, 'أكمل رقم الفاتورة والعميل/المورد والصنف.'); return; }
    final product = products.firstWhere((p) => p['id'] == productId); final quantity = _parseMilli(qty.text); if (quantity <= 0) { _message(context, 'الكمية غير صحيحة.'); return; }
    try { await widget.database.createInvoice(number: number.text, kind: kind, partyId: partyId!, date: DateTime.now(), lines: [InvoiceLineData(productId: productId!, description: '${product['name']}', quantityMilli: quantity, unitPriceMinor: product[kind == 'sale' ? 'sale_price_minor' : 'purchase_price_minor'] as int)]); number.clear(); widget.onSaved(); setState(() {}); _message(context, 'تم حفظ الفاتورة وترحيلها وتحديث المخزون.'); } catch (e) { if (mounted) _message(context, '$e'); }
  }
  @override void dispose() { number.dispose(); qty.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Column(children: [Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [SegmentedButton<String>(segments: const [ButtonSegment(value: 'sale', label: Text('بيع')), ButtonSegment(value: 'purchase', label: Text('شراء'))], selected: {kind}, onSelectionChanged: (v) => setState(() => kind = v.first)), TextField(controller: number, decoration: const InputDecoration(labelText: 'رقم الفاتورة')), FutureBuilder<List<Map<String, Object?>>>(future: widget.database.parties(), builder: (context, snap) { final rows = snap.data ?? []; if (rows.isEmpty) return const Text('أضف عميلًا أو موردًا أولاً.'); final valid = rows.where((p) => p['kind'] == kind || p['kind'] == 'both').toList(); if (valid.isEmpty) return Text(kind == 'sale' ? 'أضف عميلًا أولاً.' : 'أضف موردًا أولاً.'); final id = valid.any((p) => p['id'] == partyId) ? partyId : valid.first['id'] as int; return DropdownButtonFormField<int>(value: id, decoration: InputDecoration(labelText: kind == 'sale' ? 'العميل' : 'المورد'), items: valid.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']}'))).toList(), onChanged: (v) => setState(() => partyId = v)); }), FutureBuilder<List<Map<String, Object?>>>(future: widget.database.products(), builder: (context, snap) { final rows = snap.data ?? []; if (rows.isEmpty) return const Text('أضف صنفًا للمخزون أولاً.'); final id = rows.any((p) => p['id'] == productId) ? productId : rows.first['id'] as int; return DropdownButtonFormField<int>(value: id, decoration: const InputDecoration(labelText: 'الصنف'), items: rows.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']} • ${_minor(p['sale_price_minor'] as int)}'))).toList(), onChanged: (v) => setState(() => productId = v)); }), TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية')), const SizedBox(height: 10), FutureBuilder<List<Map<String, Object?>>>(future: Future.wait([widget.database.parties(), widget.database.products()]).then((v) => <Map<String, Object?>>[]), builder: (context, _) => const SizedBox.shrink()), FutureBuilder<List<Map<String, Object?>>>(future: widget.database.parties(), builder: (context, partySnapshot) => FutureBuilder<List<Map<String, Object?>>>(future: widget.database.products(), builder: (context, productSnapshot) => FilledButton(onPressed: () => create(partySnapshot.data ?? [], productSnapshot.data ?? []), child: const Text('إنشاء الفاتورة'))))]))), FutureBuilder<List<Map<String, Object?>>>(key: ValueKey(widget.revision), future: widget.database.invoices(), builder: (context, snapshot) => Column(children: (snapshot.data ?? []).map((i) => Card(child: ListTile(title: Text('${i['number']} • ${i['party_name']}'), subtitle: Text('${i['kind']} • ${i['invoice_date']}'), trailing: Text(_minor(i['total_minor'] as int)))).toList()))]);
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.database, required this.revision}); final AccountingDatabase database; final int revision;
  @override Widget build(BuildContext context) => SafeArea(child: FutureBuilder<List<Map<String, Object?>>>(key: ValueKey(revision), future: database.trialBalance(), builder: (context, snapshot) {
    final rows = snapshot.data ?? []; final debit = rows.fold<int>(0, (sum, row) => sum + (row['debit_minor'] as int? ?? 0)); final credit = rows.fold<int>(0, (sum, row) => sum + (row['credit_minor'] as int? ?? 0));
    return ListView(padding: const EdgeInsets.all(18), children: [const Text('التقارير المالية', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 14), Card(child: ListTile(title: const Text('ميزان المراجعة'), subtitle: Text('المدين ${_minor(debit)} • الدائن ${_minor(credit)}'), trailing: Icon(debit == credit ? Icons.check_circle : Icons.error_outline, color: debit == credit ? _green : Colors.red))), const SizedBox(height: 12), ...rows.map((row) => Card(child: ListTile(title: Text('${row['code']} • ${row['name']}'), subtitle: Text('${_accountType(row['type'] as String)}'), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('مدين ${_minor(row['debit_minor'] as int)}', style: const TextStyle(fontSize: 11)), Text('دائن ${_minor(row['credit_minor'] as int)}', style: const TextStyle(fontSize: 11))]))))]);
  }));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.dark, required this.onDarkChanged}); final bool dark; final ValueChanged<bool> onDarkChanged;
  @override Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [const Text('الإعدادات', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), SwitchListTile(title: const Text('الوضع الداكن'), value: dark, onChanged: onDarkChanged), const Card(child: ListTile(leading: Icon(Icons.offline_bolt_outlined), title: Text('يعمل دون اتصال'), subtitle: Text('تُحفظ البيانات في قاعدة SQLite على الجهاز.'))), const Card(child: ListTile(leading: Icon(Icons.security_outlined), title: Text('الأمان'), subtitle: Text('يلزم تفعيل تشفير قاعدة البيانات والنسخ المشفرة قبل استخدام بيانات مالية حقيقية.'))), const Card(child: ListTile(leading: Icon(Icons.cloud_sync_outlined), title: Text('المزامنة والنسخ الاحتياطي'), subtitle: Text('غير مفعّلين بعد؛ يتطلبان خادمًا موثوقًا وإعدادًا آمنًا للمفاتيح.')))]));
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap}); final IconData icon; final String label; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Icon(icon, color: _green), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center)]))));
}
class _Empty extends StatelessWidget { const _Empty(this.message); final String message; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)))); }
int _parseMinor(String text) { final normalized = text.trim().replaceAll(',', '.'); final value = double.tryParse(normalized); return value == null ? -1 : (value * 100).round(); }
int _parseMilli(String text) { final normalized = text.trim().replaceAll(',', '.'); final value = double.tryParse(normalized); return value == null ? 0 : (value * 1000).round(); }
String _minor(int amount) => '${NumberFormat('#,##0.00', 'en').format(amount / 100)} SAR';
String _money(int amount) => _minor(amount);
String _accountType(String type) => switch (type) {'asset' => 'أصول', 'liability' => 'خصوم', 'equity' => 'حقوق ملكية', 'income' => 'إيرادات', 'expense' => 'مصروفات', _ => type};
Widget _metric(String label, int amount, IconData icon) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(icon, color: Colors.white70), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(_money(amount), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))]));
void _message(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
