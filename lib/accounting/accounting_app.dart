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
  const AccountingApp({super.key, required this.database});
  final AccountingDatabase database;

  @override
  State<AccountingApp> createState() => _AccountingAppState();
}

class _AccountingAppState extends State<AccountingApp> {
  late final AccountingToolsService _tools;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _tools = AccountingToolsService(widget.database.db);
    _authenticate();
  }

  Future<void> _authenticate() async {
    final auth = LocalAuthentication();
    try {
      final canCheck = await auth.canCheckBiometrics;
      final supported = await auth.isDeviceSupported();
      if (!canCheck && !supported) {
        setState(() => _locked = false);
        return;
      }
      final result = await auth.authenticate(
        localizedReason: 'تأكد من هويتك للوصول إلى تطبيق المحاسبة',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (!mounted) return;
      setState(() => _locked = !result);
    } catch (_) {
      if (mounted) setState(() => _locked = false);
    }
  }

  int tab = 0;
  int revision = 0;
  bool dark = false;
  void refresh() => setState(() => revision++);

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return MaterialApp(
        title: 'قفل التطبيق',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: _ink,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fingerprint, size: 82, color: Colors.white),
                  const SizedBox(height: 18),
                  const Text('تطبيق المحاسبة محمي', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('استخدم البصمة أو PIN لفتح التطبيق', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('فتح التطبيق'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final light = ThemeData(
      useMaterial3: true,
      fontFamily: 'DejaVuSans',
      colorScheme: ColorScheme.fromSeed(seedColor: _green),
      scaffoldBackgroundColor: _background,
      cardTheme: const CardThemeData(color: Colors.white, elevation: 0),
    );
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'DejaVuSans',
      colorScheme: ColorScheme.fromSeed(seedColor: _green, brightness: Brightness.dark),
    );
    final pages = <Widget>[
      DashboardPage(database: widget.database, revision: revision, onOpenJournal: () => setState(() => tab = 1)),
      JournalPage(database: widget.database, revision: revision, onSaved: refresh),
      BusinessPage(database: widget.database, revision: revision, onSaved: refresh),
      AdvancedReportsPage(database: widget.database),
      SettingsPage(database: widget.database, tools: _tools, dark: dark, onDarkChanged: (value) => setState(() => dark = value)),
    ];

    return MaterialApp(
      title: 'دفتر المحاسبة',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: light,
      darkTheme: darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: IndexedStack(index: tab, children: pages),
        floatingActionButton: tab == 1 ? null : FloatingActionButton.extended(
          onPressed: () => _quickAdd(context),
          backgroundColor: _green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('إضافة'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'القيود'),
            NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'الأعمال'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'التقارير'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.edit_note), title: const Text('قيد يومية'), onTap: () => Navigator.pop(context, 'journal')),
            ListTile(leading: const Icon(Icons.person_add_alt_1), title: const Text('عميل أو مورد'), onTap: () => Navigator.pop(context, 'party')),
            ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('صنف مخزون'), onTap: () => Navigator.pop(context, 'product')),
          ],
        ),
      ),
    );
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
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<Map<String, int>>(
      key: ValueKey(revision),
      future: database.totals(),
      builder: (context, snapshot) {
        final values = snapshot.data ?? const <String, int>{};
        final income = -(values['income'] ?? 0);
        final expense = values['expense'] ?? 0;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('مساحة عملك', style: TextStyle(color: Colors.grey)),
            const Text('دفتر المحاسبة', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [_ink, _green], begin: Alignment.topRight, end: Alignment.bottomLeft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('صافي الإيرادات', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Text(_money(income - expense), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _metric('الإيرادات', income, Icons.trending_up)),
                      const SizedBox(width: 12),
                      Expanded(child: _metric('المصروفات', expense, Icons.trending_down)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(child: Text('الوصول السريع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                TextButton(onPressed: onOpenJournal, child: const Text('القيود')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _Shortcut(icon: Icons.edit_note, label: 'قيد يومية', onTap: onOpenJournal)),
                const SizedBox(width: 10),
                Expanded(child: _Shortcut(icon: Icons.bar_chart, label: 'تقارير', onTap: () {})),
              ],
            ),
            const SizedBox(height: 20),
            const Text('آخر القيود', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, Object?>>>(
              future: database.latestEntries(limit: 5),
              builder: (context, journal) {
                final entries = journal.data ?? [];
                if (entries.isEmpty) return const _Empty('سجّل أول قيد لبدء متابعة حساب��تك.');
                return Column(
                  children: entries
                      .map(
                        (entry) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xFFE9F5EF), child: Icon(Icons.receipt_long, color: _green)),
                            title: Text('${entry['description']}'),
                            subtitle: Text('${entry['entry_date']}'),
                            trailing: Text(_minor((entry['total_minor'] as int?) ?? 0)),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, required this.database, required this.revision, required this.onSaved});
  final AccountingDatabase database;
  final int revision;
  final VoidCallback onSaved;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  String _side = 'expense';
  int? _accountId;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(List<Map<String, Object?>> accounts) async {
    final amount = _parseMinor(_amount.text);
    if (_description.text.trim().isEmpty || amount <= 0) {
      _message(context, 'أدخل وصفًا ومبلغًا صحيحًا.');
      return;
    }
    final income = _side == 'income';
    final debitId = _accountId ?? (int.tryParse('${accounts.first['id']}') ?? 1);
    final lines = income
        ? [
            JournalLineData(accountId: debitId, debitMinor: amount),
            JournalLineData(accountId: 7, creditMinor: amount),
          ]
        : [
            JournalLineData(accountId: 8, debitMinor: amount),
            JournalLineData(accountId: debitId, creditMinor: amount),
          ];
    try {
      await widget.database.postJournal(
        date: DateTime.now().toIso8601String().substring(0, 10),
        description: _description.text,
        lines: lines,
      );
      _description.clear();
      _amount.clear();
      widget.onSaved();
      if (mounted) _message(context, 'تم ترحيل القيد المتوازن.');
    } catch (error) {
      if (mounted) _message(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('القيود اليومية', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('مصروف')),
                    ButtonSegment(value: 'income', label: Text('إيراد')),
                  ],
                  selected: {_side},
                  onSelectionChanged: (value) => setState(() => _side = value.first),
                ),
                const SizedBox(height: 12),
                TextField(controller: _description, decoration: const InputDecoration(labelText: 'وصف القيد')),
                const SizedBox(height: 10),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ', suffixText: 'SAR'),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, Object?>>>(
                  future: widget.database.accounts(),
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? [];
                    final candidates = accounts.where((account) => account['type'] == (_side == 'income' ? 'asset' : 'liability')).toList();
                    if (candidates.isEmpty) return const SizedBox.shrink();
                    final selected = candidates.any((a) => a['id'] == _accountId) ? _accountId : candidates.first['id'] as int;
                    return Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: selected,
                          decoration: const InputDecoration(labelText: 'الحساب المقابل'),
                          items: candidates
                              .map((a) => DropdownMenuItem(value: a['id'] as int, child: Text('${a['code']} • ${a['name']}')))
                              .toList(),
                          onChanged: (id) => setState(() => _accountId = id),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _save(accounts),
                            icon: const Icon(Icons.check),
                            label: const Text('حفظ وترحيل'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('سجل القيود', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        FutureBuilder<List<Map<String, Object?>>>(
          key: ValueKey(widget.revision),
          future: widget.database.journal(),
          builder: (context, snapshot) {
            final rows = snapshot.data ?? [];
            return Column(
              children: rows
                  .map((row) => Card(
                        child: ListTile(
                          title: Text('${row['description']}'),
                          subtitle: Text('${row['entry_date']} • ${row['reference'] ?? 'قيد يدوي'}'),
                          trailing: Text(_minor((row['total_minor'] as int?) ?? 0)),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}

class BusinessPage extends StatefulWidget {
  const BusinessPage({super.key, required this.database, required this.revision, required this.onSaved});
  final AccountingDatabase database;
  final int revision;
  final VoidCallback onSaved;

  @override
  State<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends State<BusinessPage> {
  int section = 0;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('إدارة الأعمال', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('العملاء والموردون')),
            ButtonSegment(value: 1, label: Text('المخزون')),
            ButtonSegment(value: 2, label: Text('الفواتير')),
          ],
          selected: {section},
          onSelectionChanged: (value) => setState(() => section = value.first),
        ),
        const SizedBox(height: 14),
        if (section == 0) _PartiesPanel(database: widget.database, revision: widget.revision, onSaved: widget.onSaved),
        if (section == 1) _ProductsPanel(database: widget.database, revision: widget.revision, onSaved: widget.onSaved),
        if (section == 2) _InvoicesPanel(database: widget.database, revision: widget.revision, onSaved: widget.onSaved),
      ],
    ),
  );
}

class _PartiesPanel extends StatefulWidget {
  const _PartiesPanel({required this.database, required this.revision, required this.onSaved});
  final AccountingDatabase database;
  final int revision;
  final VoidCallback onSaved;

  @override
  State<_PartiesPanel> createState() => _PartiesPanelState();
}

class _PartiesPanelState extends State<_PartiesPanel> {
  final name = TextEditingController();
  final phone = TextEditingController();
  String kind = 'customer';

  Future<void> add() async {
    if (name.text.trim().isEmpty) return;
    await widget.database.addParty(name: name.text, kind: kind, phone: phone.text);
    name.clear();
    phone.clear();
    widget.onSaved();
    setState(() {});
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم العميل أو المورد')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('عميل')),
                  DropdownMenuItem(value: 'supplier', child: Text('مورد')),
                  DropdownMenuItem(value: 'both', child: Text('كلاهما')),
                ],
                onChanged: (value) => setState(() => kind = value ?? kind),
              ),
              const SizedBox(height: 10),
              FilledButton(onPressed: add, child: const Text('إضافة طرف')),
            ],
          ),
        ),
      ),
      FutureBuilder<List<Map<String, Object?>>>(
        key: ValueKey(widget.revision),
        future: widget.database.parties(),
        builder: (context, snapshot) => Column(
          children: (snapshot.data ?? [])
              .map((party) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text('${party['name']}'),
                      subtitle: Text('${party['kind']} • ${party['phone'] ?? ''}'),
                    ),
                  ))
              .toList(),
        ),
      ),
    ],
  );
}

class _ProductsPanel extends StatefulWidget {
  const _ProductsPanel({required this.database, required this.revision, required this.onSaved});
  final AccountingDatabase database;
  final int revision;
  final VoidCallback onSaved;

  @override
  State<_ProductsPanel> createState() => _ProductsPanelState();
}

class _ProductsPanelState extends State<_ProductsPanel> {
  final sku = TextEditingController();
  final name = TextEditingController();
  final sale = TextEditingController();
  final stock = TextEditingController();

  Future<void> add() async {
    final value = _parseMinor(sale.text);
    final qty = _parseMilli(stock.text);
    if (sku.text.trim().isEmpty || name.text.trim().isEmpty || value < 0) return;
    try {
      await widget.database.addProduct(
        sku: sku.text,
        name: name.text,
        purchasePriceMinor: value,
        salePriceMinor: value,
        openingStockMilli: qty,
        reorderMilli: 0,
      );
      sku.clear();
      name.clear();
      sale.clear();
      stock.clear();
      widget.onSaved();
      setState(() {});
    } catch (e) {
      if (mounted) _message(context, '$e');
    }
  }

  @override
  void dispose() {
    sku.dispose();
    name.dispose();
    sale.dispose();
    stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              TextField(controller: sku, decoration: const InputDecoration(labelText: 'رمز الصنف')),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الصنف')),
              TextField(controller: sale, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع', suffixText: 'SAR')),
              TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي')),
              const SizedBox(height: 10),
              FilledButton(onPressed: add, child: const Text('إضافة صنف')),
            ],
          ),
        ),
      ),
      FutureBuilder<List<Map<String, Object?>>>(
        key: ValueKey(widget.revision),
        future: widget.database.products(),
        builder: (context, snapshot) => Column(
          children: (snapshot.data ?? [])
              .map((product) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                      title: Text('${product['name']}'),
                      subtitle: Text('${product['sku']} • الرصيد ${((product['stock_milli'] as int? ?? 0) / 1000).toStringAsFixed(3)}'),
                      trailing: Text(_minor(product['sale_price_minor'] as int? ?? 0)),
                    ),
                  ))
              .toList(),
        ),
      ),
    ],
  );
}

class _InvoicesPanel extends StatefulWidget {
  const _InvoicesPanel({required this.database, required this.revision, required this.onSaved});
  final AccountingDatabase database;
  final int revision;
  final VoidCallback onSaved;

  @override
  State<_InvoicesPanel> createState() => _InvoicesPanelState();
}

class _InvoicesPanelState extends State<_InvoicesPanel> {
  final number = TextEditingController();
  int? partyId;
  int? productId;
  String kind = 'sale';
  final qty = TextEditingController(text: '1');

  Future<void> create(List<Map<String, Object?>> parties, List<Map<String, Object?>> products) async {
    if (partyId == null || productId == null || number.text.trim().isEmpty) {
      _message(context, 'أكمل رقم الفاتورة والعميل/المورد والصنف.');
      return;
    }
    final product = products.firstWhere((p) => p['id'] == productId);
    final quantity = _parseMilli(qty.text);
    if (quantity <= 0) {
      _message(context, 'الكمية غير صحيحة.');
      return;
    }
    try {
      await widget.database.createInvoice(
        number: number.text,
        kind: kind,
        partyId: partyId!,
        date: DateTime.now(),
        lines: [
          InvoiceLineData(
            productId: productId!,
            description: '${product['name']}',
            quantityMilli: quantity,
            unitPriceMinor: product[kind == 'sale' ? 'sale_price_minor' : 'purchase_price_minor'] as int? ?? 0,
          )
        ],
      );
      number.clear();
      widget.onSaved();
      setState(() {});
      _message(context, 'تم حفظ الفاتورة وترحيلها وتحديث المخزون.');
    } catch (e) {
      if (mounted) _message(context, '$e');
    }
  }

  @override
  void dispose() {
    number.dispose();
    qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'sale', label: Text('بيع')),
                  ButtonSegment(value: 'purchase', label: Text('شراء')),
                ],
                selected: {kind},
                onSelectionChanged: (value) => setState(() => kind = value.first),
              ),
              TextField(controller: number, decoration: const InputDecoration(labelText: 'رقم الفاتورة')),
              FutureBuilder<List<Map<String, Object?>>>(
                future: widget.database.parties(),
                builder: (context, snap) {
                  final rows = snap.data ?? [];
                  if (rows.isEmpty) return const Text('أضف عميلًا أو موردًا أولاً.');
                  final valid = rows.where((p) => p['kind'] == kind || p['kind'] == 'both').toList();
                  if (valid.isEmpty) return Text(kind == 'sale' ? 'أضف عميلًا أولاً.' : 'أضف موردًا أولاً.');
                  final id = valid.any((p) => p['id'] == partyId) ? partyId : valid.first['id'] as int;
                  return DropdownButtonFormField<int>(
                    value: id,
                    decoration: InputDecoration(labelText: kind == 'sale' ? 'العميل' : 'المورد'),
                    items: valid.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']}'))).toList(),
                    onChanged: (value) => setState(() => partyId = value),
                  );
                },
              ),
              FutureBuilder<List<Map<String, Object?>>>(
                future: widget.database.products(),
                builder: (context, snap) {
                  final rows = snap.data ?? [];
                  if (rows.isEmpty) return const Text('أضف صنفًا للمخزون أولاً.');
                  final id = rows.any((p) => p['id'] == productId) ? productId : rows.first['id'] as int;
                  return DropdownButtonFormField<int>(
                    value: id,
                    decoration: const InputDecoration(labelText: 'الصنف'),
                    items: rows.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']} • ${_minor(p['sale_price_minor'] as int? ?? 0)}'))).toList(),
                    onChanged: (value) => setState(() => productId = value),
                  );
                },
              ),
              TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية')),
              const SizedBox(height: 10),
              FutureBuilder<List<Map<String, Object?>>>(
                future: widget.database.parties(),
                builder: (context, partySnapshot) => FutureBuilder<List<Map<String, Object?>>>(
                  future: widget.database.products(),
                  builder: (context, productSnapshot) => FilledButton(
                    onPressed: () => create(partySnapshot.data ?? [], productSnapshot.data ?? []),
                    child: const Text('إنشاء الفاتورة'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      FutureBuilder<List<Map<String, Object?>>>(
        key: ValueKey(widget.revision),
        future: widget.database.invoices(),
        builder: (context, snapshot) => Column(
          children: (snapshot.data ?? [])
              .map((invoice) => Card(
                    child: ListTile(
                      title: Text('${invoice['number']} • ${invoice['party_name']}'),
                      subtitle: Text('${invoice['kind']} • ${invoice['invoice_date']}'),
                      trailing: Text(_minor(invoice['total_minor'] as int? ?? 0)),
                    ),
                  ))
              .toList(),
        ),
      ),
    ],
  );
}

class AdvancedReportsPage extends StatelessWidget {
  const AdvancedReportsPage({super.key, required this.database});
  final AccountingDatabase database;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<List<Map<String, Object?>>>(
      future: Future.wait([
        database.trialBalance(),
        database.incomeStatement(),
        database.cashFlow(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final trial = snapshot.data![0] as List<Map<String, Object?>>;
        final income = snapshot.data![1] as List<Map<String, Object?>>;
        final cash = snapshot.data![2] as List<Map<String, Object?>>;
        final debit = trial.fold<int>(0, (s, row) => s + (row['debit_minor'] as int? ?? 0));
        final credit = trial.fold<int>(0, (s, row) => s + (row['credit_minor'] as int? ?? 0));
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('التقارير المالية', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('ميزان المراجعة'),
                subtitle: Text('المدين ${_minor(debit)} • الدائن ${_minor(credit)}'),
                trailing: Icon(debit == credit ? Icons.check_circle : Icons.error_outline, color: debit == credit ? _green : Colors.red),
              ),
            ),
            const SizedBox(height: 12),
            const Text('قائمة الدخل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ...income.map((row) => Card(child: ListTile(title: Text('${row['label']}'), trailing: Text(_minor((row['total_minor'] as int?) ?? 0))))),
            const SizedBox(height: 12),
            const Text('التدفقات النقدية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ...cash.map((row) => Card(child: ListTile(title: Text('${row['label']}'), trailing: Text(_minor((row['total_minor'] as int?) ?? 0))))),
          ],
        );
      },
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.database, required this.tools, required this.dark, required this.onDarkChanged});
  final AccountingDatabase database;
  final AccountingToolsService tools;
  final bool dark;
  final ValueChanged<bool> onDarkChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool biometrics = true;
  final companyName = TextEditingController();
  final companyTax = TextEditingController();
  final companyAddress = TextEditingController();
  final companyPhone = TextEditingController();
  final companyEmail = TextEditingController();
  String currencyCode = 'SAR';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final company = await widget.database.companySettings();
    if (!mounted) return;
    companyName.text = '${company['name'] ?? ''}';
    companyTax.text = '${company['tax_number'] ?? ''}';
    companyAddress.text = '${company['address'] ?? ''}';
    companyPhone.text = '${company['phone'] ?? ''}';
    companyEmail.text = '${company['email'] ?? ''}';
    currencyCode = '${company['base_currency'] ?? 'SAR'}';
    setState(() {});
  }

  Future<void> _saveCompany() async {
    try {
      await widget.database.saveCompanySettings(
        name: companyName.text,
        taxNumber: companyTax.text,
        address: companyAddress.text,
        phone: companyPhone.text,
        email: companyEmail.text,
        baseCurrency: currencyCode,
        decimalPlaces: 2,
      );
      _message(context, 'تم حفظ إعدادات الشركة.');
    } catch (error) {
      _message(context, '$error');
    }
  }

  Future<void> _exportPdf() async {
    try {
      final path = await widget.tools.exportPdfReport();
      _message(context, 'تم حفظ تقرير PDF في: $path');
    } catch (error) {
      _message(context, '$error');
    }
  }

  Future<void> _exportExcel() async {
    try {
      final path = await widget.tools.exportExcelReport();
      _message(context, 'تم حفظ التقرير Excel في: $path');
    } catch (error) {
      _message(context, '$error');
    }
  }

  Future<void> _createBackup() async {
    try {
      final path = await widget.tools.createBackup();
      _message(context, 'تم إنشاء النسخة الاحتياطية: $path');
    } catch (error) {
      _message(context, '$error');
    }
  }

  Future<void> _restoreBackup() async {
    final path = await widget.tools.pickBackupToRestore();
    if (path == null) return;
    try {
      await widget.tools.restoreBackup(path);
      _message(context, 'تم استعادة النسخة الاحتياطية بنجاح.');
    } catch (error) {
      _message(context, '$error');
    }
  }

  Future<void> _syncToCloud() async {
    try {
      final result = await widget.tools.generateCloudSyncBundle();
      _message(context, 'تم تجهيز حزمة المزامنة السحابية: $result');
    } catch (error) {
      _message(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('الإعدادات', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SwitchListTile(title: const Text('تفعيل قفل التطبيق بالبصمة'), value: biometrics, onChanged: (value) => setState(() => biometrics = value)),
        SwitchListTile(title: const Text('الوضع الداكن'), value: widget.dark, onChanged: widget.onDarkChanged),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إعدادات الشركة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                TextField(controller: companyName, decoration: const InputDecoration(labelText: 'اسم الشركة')),
                TextField(controller: companyTax, decoration: const InputDecoration(labelText: 'الرقم الضريبي')),
                TextField(controller: companyAddress, decoration: const InputDecoration(labelText: 'العنوان')),
                TextField(controller: companyPhone, decoration: const InputDecoration(labelText: 'الهاتف')),
                TextField(controller: companyEmail, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: currencyCode,
                  decoration: const InputDecoration(labelText: 'العملة الأساسية'),
                  items: const [
                    DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي')),
                    DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي')),
                    DropdownMenuItem(value: 'AED', child: Text('درهم إماراتي')),
                    DropdownMenuItem(value: 'YER', child: Text('ريال يمني')),
                    DropdownMenuItem(value: 'EUR', child: Text('يورو')),
                  ],
                  onChanged: (value) => setState(() => currencyCode = value ?? currencyCode),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(onPressed: _saveCompany, icon: const Icon(Icons.save), label: const Text('حفظ البيانات')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(title: const Text('العملات المتعددة'), subtitle: const Text('أسعار الصرف والعملة الأساسية'), trailing: const Icon(Icons.currency_exchange), onTap: () => _showCurrencyDialog(context)),
              ListTile(title: const Text('نسخ احتياطي'), subtitle: const Text('حفظ ملف JSON آمن محليًا'), onTap: _createBackup),
              ListTile(title: const Text('استعادة نسخة احتياطية'), subtitle: const Text('استرجاع البيانات من ملف JSON'), onTap: _restoreBackup),
              ListTile(title: const Text('تصدير PDF'), onTap: _exportPdf),
              ListTile(title: const Text('تصدير Excel'), onTap: _exportExcel),
              ListTile(title: const Text('مزامنة سحابية'), subtitle: const Text('تجهيز حزمة مزامنة احتياطية'), onTap: _syncToCloud),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _showCurrencyDialog(BuildContext context) async {
    final rates = await widget.database.currencyRates();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('أسعار الصرف'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: rates
                  .map(
                    (rate) => ListTile(
                      title: Text('${rate['code']}'),
                      subtitle: Text('${rate['name']}'),
                      trailing: Text('${rate['units_per_base']}'),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: _green),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
    ),
  );
}

int _parseMinor(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  final value = double.tryParse(normalized);
  return value == null ? -1 : (value * 100).round();
}

int _parseMilli(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  final value = double.tryParse(normalized);
  return value == null ? 0 : (value * 1000).round();
}

String _minor(int amount) => '${NumberFormat('#,##0.00', 'en').format(amount / 100)} SAR';
String _money(int amount) => _minor(amount);

Widget _metric(String label, int amount, IconData icon) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
  child: Row(
    children: [
      Icon(icon, color: Colors.white70),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(_money(amount), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ],
  ),
);

void _message(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
