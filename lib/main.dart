import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const orange = Color(0xFFD97706);
const green = Color(0xFF16A34A);
const ink = Color(0xFF17212B);
const cream = Color(0xFFFFFBF5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = LivestockDb();
  await db.open();
  runApp(LivestockApp(db: db));
}

class LivestockApp extends StatelessWidget {
  const LivestockApp({super.key, required this.db});
  final LivestockDb db;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: orange, brightness: Brightness.light);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مقاني',
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: cream,
        fontFamily: 'DejaVuSans',
        appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: ink, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.black12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: orange, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
      home: SplashScreen(db: db),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.db});
  final LivestockDb db;
  @override State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() { super.initState(); Future.delayed(const Duration(milliseconds: 1400), () { if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeShell(db: widget.db))); }); }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: orange, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const AnimalLogo(size: 105, light: true), const SizedBox(height: 18),
    const Text('مقاني', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white)),
    const SizedBox(height: 10), const Text('اهلا بك في مقاني', style: TextStyle(fontSize: 18, color: Colors.white70)),
  ])));
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.db});
  final LivestockDb db;
  @override State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final refresh = ValueNotifier<int>(0);
  @override Widget build(BuildContext context) {
    final pages = [HomeScreen(db: widget.db, refresh: refresh, onAdd: () => setState(() => index = 1)), VaccinationScreen(db: widget.db), TagsScreen(db: widget.db, refresh: refresh), AddAnimalScreen(db: widget.db, onSaved: () { refresh.value++; setState(() => index = 0); })];
    return Scaffold(body: IndexedStack(index: index, children: pages), bottomNavigationBar: NavigationBar(
      selectedIndex: index > 3 ? 0 : index, onDestinationSelected: (i) => setState(() => index = i), backgroundColor: Colors.white,
      indicatorColor: orange.withOpacity(.14), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: orange), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.vaccines_outlined), selectedIcon: Icon(Icons.vaccines, color: green), label: 'التطعيم'),
        NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number, color: orange), label: 'الأرقام'),
        NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle, color: green), label: 'إضافة رأس'),
      ],
    ));
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.db, required this.refresh, required this.onAdd});
  final LivestockDb db; final ValueNotifier<int> refresh; final VoidCallback onAdd;
  @override State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> animals = []; String query = ''; String filter = 'الكل';
  @override void initState() { super.initState(); load(); widget.refresh.addListener(load); }
  @override void dispose() { widget.refresh.removeListener(load); super.dispose(); }
  Future<void> load() async { final rows = await widget.db.animals(); if (mounted) setState(() => animals = rows); }
  List<Map<String, dynamic>> get shown => animals.where((a) { final matchesQuery = query.isEmpty || '${a['number']}'.contains(query) || '${a['animal_type']}'.contains(query); final matchesFilter = filter == 'الكل' || (filter == 'الذكور' && a['gender'] == 'ذكر') || (filter == 'الاناث' && a['gender'] == 'انثى') || a['animal_type'] == filter || (filter == 'الدافع' && a['tag_color'] == 'أخضر'); return matchesQuery && matchesFilter; }).toList();
  @override Widget build(BuildContext context) => SafeArea(child: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [
    Row(children: [const AnimalLogo(size: 46), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('اهلا بك', style: TextStyle(color: Colors.grey.shade600)), const Text('السارحات بارك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink))])), IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: orange))]),
    const SizedBox(height: 20), Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: orange.withOpacity(.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: orange.withOpacity(.22))), child: const Row(children: [Icon(Icons.info_outline, color: orange), SizedBox(width: 10), Expanded(child: Text('يرجي اضافة ايصال التحويل ليتم تفعيل الحساب', style: TextStyle(color: ink, fontWeight: FontWeight.w600)))])),
    const SizedBox(height: 18), const Text('التصنيف', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 10), StatsCard(animals: animals),
    const SizedBox(height: 14), SizedBox(height: 52, child: FilledButton.icon(onPressed: widget.onAdd, style: FilledButton.styleFrom(backgroundColor: green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), icon: const Icon(Icons.add), label: const Text('اضافة رأس', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
    const SizedBox(height: 14), Row(children: [QuickAction(icon: Icons.vaccines_outlined, label: 'التطعيم', color: green, onTap: () {}), const SizedBox(width: 10), QuickAction(icon: Icons.medical_information_outlined, label: 'السجل المرضي', color: orange, onTap: () {}), const SizedBox(width: 10), QuickAction(icon: Icons.payments_outlined, label: 'الدافع', color: Colors.blueGrey, onTap: () {})]),
    const SizedBox(height: 20), TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: 'ابحث عن ...', prefixIcon: Icon(Icons.search))),
    const SizedBox(height: 12), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['الكل', 'نجدي', 'حري', 'الذكور', 'الاناث', 'الدافع'].map((f) => Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(f), selected: filter == f, selectedColor: orange.withOpacity(.18), onSelected: (_) => setState(() => filter = f))).toList())),
    const SizedBox(height: 18), if (shown.isEmpty) const EmptyState() else GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: shown.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.25), itemBuilder: (_, i) => AnimalCard(animal: shown[i])),
  ])));
}

class StatsCard extends StatelessWidget { const StatsCard({super.key, required this.animals}); final List<Map<String, dynamic>> animals;
  @override Widget build(BuildContext context) { final types = ['معز', 'حري', 'نجدي']; return Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: orange.withOpacity(.08), borderRadius: BorderRadius.circular(10)), child: const Row(children: [Expanded(child: Text('النوع', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Text('ذكور', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Text('اناث', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))])), ...types.map((type) { final males = animals.where((a) => a['animal_type'] == type && a['gender'] == 'ذكر').length; final females = animals.where((a) => a['animal_type'] == type && a['gender'] == 'انثى').length; return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text(type, textAlign: TextAlign.center)), Expanded(child: Text('$males', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Text('$females', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)))])); })]))); }
}

class QuickAction extends StatelessWidget { const QuickAction({super.key, required this.icon, required this.label, required this.color, required this.onTap}); final IconData icon; final String label; final Color color; final VoidCallback onTap; @override Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)), child: Column(children: [Icon(icon, color: color), const SizedBox(height: 5), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]))); }

class AnimalCard extends StatelessWidget { const AnimalCard({super.key, required this.animal}); final Map<String, dynamic> animal; @override Widget build(BuildContext context) { final isMale = animal['gender'] == 'ذكر'; final color = animal['tag_color'] == 'أخضر' ? green : animal['tag_color'] == 'أزرق' ? Colors.blue : orange; return Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const Spacer(), Icon(isMale ? Icons.male : Icons.female, color: isMale ? Colors.blue : Colors.pink, size: 20)]), const Spacer(), Text('${animal['number']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink)), Text('${animal['animal_type']} • ${animal['gender']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),]))); }
}

class AddAnimalScreen extends StatefulWidget { const AddAnimalScreen({super.key, required this.db, this.onSaved}); final LivestockDb db; final VoidCallback? onSaved; @override State<AddAnimalScreen> createState() => _AddAnimalScreenState(); }
class _AddAnimalScreenState extends State<AddAnimalScreen> { final form = GlobalKey<FormState>(); final number = TextEditingController(); final mother = TextEditingController(); final father = TextEditingController(); String type = 'معز', gender = 'انثى', color = 'برتقالي'; DateTime? birth;
  Future<void> save() async { if (!form.currentState!.validate()) return; await widget.db.addAnimal({'number': number.text.trim(), 'tag_color': color, 'animal_type': type, 'gender': gender, 'birth_date': birth?.toIso8601String()}); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الرأس بنجاح'), backgroundColor: green)); number.clear(); setState(() => birth = null); widget.onSaved?.call(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('اضافة رأس', style: TextStyle(fontWeight: FontWeight.w900))), body: Form(key: form, child: ListView(padding: const EdgeInsets.all(18), children: [const Text('بيانات الرأس', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 18), Row(children: [Expanded(child: DropdownButtonFormField<String>(value: color, decoration: const InputDecoration(labelText: 'اختر اللون'), items: ['برتقالي', 'أخضر', 'أزرق'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => color = v!))), const SizedBox(width: 10), Expanded(child: TextFormField(controller: number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرقم'), validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null))]), const SizedBox(height: 14), DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'النوع'), items: ['معز', 'حري', 'نجدي'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => type = v!)), const SizedBox(height: 14), DropdownButtonFormField<String>(value: gender, decoration: const InputDecoration(labelText: 'الجنس'), items: ['ذكر', 'انثى'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => gender = v!)), const SizedBox(height: 14), InkWell(onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDate: DateTime.now(), locale: const Locale('ar', 'SA')); if (d != null) setState(() => birth = d); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'تاريخ الولادة', suffixIcon: Icon(Icons.calendar_month)), child: Text(birth == null ? 'DD/MM/YYYY' : DateFormat('dd/MM/yyyy').format(birth!)))), const SizedBox(height: 14), TextFormField(controller: mother, decoration: const InputDecoration(labelText: 'الام (اختياري)', hintText: 'اختر اللون + الرقم')), const SizedBox(height: 14), TextFormField(controller: father, decoration: const InputDecoration(labelText: 'الاب (اختياري)', hintText: 'اختر اللون + الرقم')), const SizedBox(height: 28), SizedBox(height: 54, child: FilledButton(onPressed: save, style: FilledButton.styleFrom(backgroundColor: green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text('حفظ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))])));
}

class TagsScreen extends StatefulWidget { const TagsScreen({super.key, required this.db, required this.refresh}); final LivestockDb db; final ValueNotifier<int> refresh; @override State<TagsScreen> createState() => _TagsScreenState(); }
class _TagsScreenState extends State<TagsScreen> { String color = 'برتقالي', query = ''; int count = 1; List<Map<String, dynamic>> tags = []; @override void initState() { super.initState(); load(); } Future<void> load() async { final x = await widget.db.tags(); if (mounted) setState(() => tags = x); } Future<void> add() async { final max = tags.length + 1; for (var i = 0; i < count; i++) await widget.db.addTag('$color-${max + i}', color); await load(); widget.refresh.value++; } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('اضف ارقام', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(18), children: [Row(children: [Expanded(child: DropdownButtonFormField<String>(value: color, decoration: const InputDecoration(labelText: 'اختر اللون'), items: ['برتقالي', 'أخضر', 'أزرق'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => color = v!))), const SizedBox(width: 10), SizedBox(width: 90, child: TextFormField(initialValue: '1', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العدد'), onChanged: (v) => count = int.tryParse(v) ?? 1)), const SizedBox(width: 10), IconButton.filled(onPressed: add, style: IconButton.styleFrom(backgroundColor: green), icon: const Icon(Icons.add))]), const SizedBox(height: 24), const Text('الارقام المتاحة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 12), TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: 'ابحث عن رقم', prefixIcon: Icon(Icons.search))), const SizedBox(height: 15), Wrap(spacing: 10, runSpacing: 10, children: tags.where((t) => '${t['number']}'.contains(query)).map((t) { final c = t['color'] == 'أخضر' ? green : t['color'] == 'أزرق' ? Colors.blue : orange; return Container(width: 105, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(14)), child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 7), Expanded(child: Text('${t['number']}', style: const TextStyle(fontWeight: FontWeight.bold))), InkWell(onTap: () async { await widget.db.deleteTag(t['id'] as int); load(); }, child: const Icon(Icons.delete_outline, size: 18, color: Colors.grey))])); }).toList())])); }
}

class VaccinationScreen extends StatelessWidget { const VaccinationScreen({super.key, required this.db}); final LivestockDb db; @override Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: db.animals(), builder: (_, snap) { final animals = snap.data ?? []; return Scaffold(appBar: AppBar(title: const Text('التطعيم', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.all(18), children: [Container(height: 92, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: green.withOpacity(.1), borderRadius: BorderRadius.circular(18)), child: Row(children: [const Icon(Icons.calendar_month, color: green, size: 34), const SizedBox(width: 12), Expanded(child: Text(DateFormat('MMMM yyyy', 'ar').format(DateTime.now()), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))), IconButton(onPressed: () {}, icon: const Icon(Icons.edit_calendar, color: green))])), const SizedBox(height: 18), SizedBox(height: 52, child: FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), icon: const Icon(Icons.add), label: Text('تطعيمات يوم ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'))), const SizedBox(height: 22), const Text('رؤوس اليوم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 10), ...animals.take(8).map((a) => Card(elevation: 0, color: Colors.white, child: ListTile(leading: CircleAvatar(backgroundColor: a['tag_color'] == 'أخضر' ? green : orange, radius: 8), title: Text('${a['number']}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${a['animal_type']} • ${a['gender']}'), trailing: Checkbox(value: false, onChanged: (_) {}))))])); }); }

class EmptyState extends StatelessWidget { const EmptyState({super.key}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(30), child: Column(children: [Icon(Icons.pets_outlined, size: 55, color: orange.withOpacity(.5)), const SizedBox(height: 8), const Text('لا توجد رؤوس مطابقة للبحث', style: TextStyle(color: Colors.grey))])); }
class AnimalLogo extends StatelessWidget { const AnimalLogo({super.key, this.size = 60, this.light = false}); final double size; final bool light; @override Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(color: light ? Colors.white.withOpacity(.2) : orange.withOpacity(.12), shape: BoxShape.circle), child: Icon(Icons.pets, size: size * .58, color: light ? Colors.white : orange)); }

class LivestockDb { Database? _db; Future<void> open() async { final path = p.join(await getDatabasesPath(), 'maqani.db'); _db = await openDatabase(path, version: 1, onCreate: (db, _) async { await db.execute('CREATE TABLE animals (id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL, tag_color TEXT NOT NULL, animal_type TEXT NOT NULL, gender TEXT NOT NULL, birth_date TEXT)'); await db.execute('CREATE TABLE tags (id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL, color TEXT NOT NULL)'); final batch = db.batch(); final seed = [{'number':'101','tag_color':'برتقالي','animal_type':'نجدي','gender':'انثى'},{'number':'102','tag_color':'أخضر','animal_type':'حري','gender':'ذكر'},{'number':'103','tag_color':'أزرق','animal_type':'معز','gender':'انثى'},{'number':'104','tag_color':'برتقالي','animal_type':'نجدي','gender':'ذكر'}]; for (final a in seed) { batch.insert('animals', a); } await batch.commit(); }); }
  Future<List<Map<String, dynamic>>> animals() async => _db!.query('animals', orderBy: 'id DESC'); Future<void> addAnimal(Map<String, dynamic> a) async => _db!.insert('animals', a); Future<List<Map<String, dynamic>>> tags() async => _db!.query('tags', orderBy: 'id DESC'); Future<void> addTag(String n, String c) async => _db!.insert('tags', {'number': n, 'color': c}); Future<void> deleteTag(int id) async => _db!.delete('tags', where: 'id = ?', whereArgs: [id]); }
