# دليل Smart Accountant v3.2.0

## 1. محلل الأرقام اليمنية المركبة

### الفكرة

لا يكفي البحث داخل `yemeniNumberWords` عن أول كلمة؛ فهذا يحوّل `مليون` إلى 1,000,000 لكنه لا يفهم أن `مليونين وخمسمية` تعني:

```text
2 × 1,000,000 + 500 = 2,000,500
```

الحل هو تنفيذ محلل مستقل يمر على الكلمات بالترتيب، ويفصل بين:

- قيم صغيرة: الوحدات والعشرات والمئات.
- المقاييس الكبيرة: ألف، مليون، مليار.
- القيم المركبة المباشرة: مليونين، ألفين، خمسمية.
- حرف العطف `و` عندما يكون ملتصقاً بالكلمة، مثل `وخمسمية`.

### الملف المقترح: `lib/yemeni_number_parser.dart`

```dart
class YemeniNumberParser {
  static const Map<String, double> _smallValues = {
    'صفر': 0,
    'واحد': 1,
    'واحدة': 1,
    'اثنين': 2,
    'اثنان': 2,
    'اثنتين': 2,
    'اثنتان': 2,
    'ثلاث': 3,
    'ثلاثة': 3,
    'أربع': 4,
    'أربعة': 4,
    'خمس': 5,
    'خمسة': 5,
    'ست': 6,
    'ستة': 6,
    'سبع': 7,
    'سبعة': 7,
    'ثمان': 8,
    'ثمانية': 8,
    'تسع': 9,
    'تسعة': 9,
    'عشر': 10,
    'عشرة': 10,
    'عشرين': 20,
    'عشرون': 20,
    'ثلاثين': 30,
    'ثلاثون': 30,
    'أربعين': 40,
    'أربعون': 40,
    'خمسين': 50,
    'خمسون': 50,
    'ستين': 60,
    'ستون': 60,
    'سبعين': 70,
    'سبعون': 70,
    'ثمانين': 80,
    'ثمانون': 80,
    'تسعين': 90,
    'تسعون': 90,
    'مئة': 100,
    'مائة': 100,
    'مئه': 100,
    'مائه': 100,
    'مية': 100,
    'ميه': 100,
    'مئتين': 200,
    'مائتين': 200,
    'ميتين': 200,
    // صيغ يمنية دارجة
    'خمسمية': 500,
    'خمسماية': 500,
    'خمسمائه': 500,
    'خمسمائة': 500,
    'ستمية': 600,
    'سبعمية': 700,
    'ثمانمية': 800,
    'تسعمية': 900,
  };

  static const Map<String, double> _directValues = {
    'ألفين': 2000,
    'الفين': 2000,
    'مليونين': 2000000,
    'مليونان': 2000000,
    'مليارين': 2000000000,
    'ملياران': 2000000000,
  };

  static const Map<String, double> _scales = {
    'ألف': 1000,
    'الف': 1000,
    'مليون': 1000000,
    'مليار': 1000000000,
  };

  static const Set<String> _knownWords = {
    ..._smallValues.keys,
    ..._directValues.keys,
    ..._scales.keys,
    'نصف',
  };

  static double? tryParse(String input) {
    var text = _normalize(input);
    if (text.isEmpty) return null;

    // دعم الأعداد المركبة من 11 إلى 19 قبل تقسيمها إلى كلمات منفصلة.
    const compoundPhrases = <String, String>{
      'أحد عشر': '11',
      'احد عشر': '11',
      'اثنا عشر': '12',
      'اثني عشر': '12',
      'ثلاثة عشر': '13',
      'أربعة عشر': '14',
      'خمسة عشر': '15',
      'ستة عشر': '16',
      'سبعة عشر': '17',
      'ثمانية عشر': '18',
      'تسعة عشر': '19',
    };
    compoundPhrases.forEach((phrase, value) {
      text = text.replaceAll(phrase, value);
    });

    final tokens = text
        .split(RegExp(r'\s+'))
        .map(_canonicalToken)
        .where((token) => token.isNotEmpty && token != 'و')
        .toList();

    double total = 0;
    double group = 0;
    double? lastScale;
    bool foundNumber = false;

    for (final token in tokens) {
      final numeric = _parseDigits(token);
      if (numeric != null) {
        group += numeric;
        foundNumber = true;
        continue;
      }

      final direct = _directValues[token];
      if (direct != null) {
        total += direct;
        group = 0;
        // يسمح هذا بصيغة: مليونين ونصف.
        lastScale = direct >= 1000000000 ? 1000000000 : 1000000;
        foundNumber = true;
        continue;
      }

      final small = _smallValues[token];
      if (small != null) {
        // ثلاث مئة = 300، أما عشرين وخمسة = 25.
        if (small >= 100 && group > 0 && group < 100) {
          group *= small;
        } else {
          group += small;
        }
        foundNumber = true;
        continue;
      }

      final scale = _scales[token];
      if (scale != null) {
        final coefficient = group == 0 ? 1 : group;
        total += coefficient * scale;
        group = 0;
        lastScale = scale;
        foundNumber = true;
        continue;
      }

      if (token == 'نصف' && lastScale != null) {
        total += lastScale / 2;
        foundNumber = true;
      }
    }

    if (!foundNumber) return null;
    return total + group;
  }

  static String _normalize(String input) {
    var text = input.trim();

    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < arabicDigits.length; i++) {
      text = text.replaceAll(arabicDigits[i], '$i');
    }

    text = text
        .replaceAll('٬', '')
        .replaceAll('،', ',')
        .replaceAll(RegExp(r'(?<=\d),(?=\d)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text;
  }

  static String _canonicalToken(String raw) {
    var token = raw.replaceAll(RegExp(r'^[,،.]+|[,،.]+$'), '');
    if (_knownWords.contains(token)) return token;

    // يدعم: وخمسمية، ومليونين، وتسعة، وألف.
    if (token.startsWith('و')) {
      final withoutWaw = token.substring(1);
      if (_knownWords.contains(withoutWaw)) return withoutWaw;
    }

    return token;
  }

  static double? _parseDigits(String token) {
    final cleaned = token.replaceAll(',', '');
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(cleaned)) return null;
    return double.tryParse(cleaned);
  }
}
```

### دمج المحلل مع `AiAgentParser`

أضف الاستيراد:

```dart
import 'yemeni_number_parser.dart';
```

ثم استبدل بداية `parseArabicNumber` بهذا الشكل، مع إبقاء البحث الرقمي كحل احتياطي:

```dart
static double parseArabicNumber(String text) {
  final compound = YemeniNumberParser.tryParse(text);
  if (compound != null) return compound;

  final match = RegExp(r'(\d[\d,\.]*)').firstMatch(text);
  if (match == null) return 0.0;

  final number = match.group(1)!.replaceAll(',', '');
  return double.tryParse(number) ?? 0.0;
}
```

### اختبارات الوحدة المطلوبة

```dart
test('يفهم الأرقام اليمنية المركبة', () {
  expect(YemeniNumberParser.tryParse('مليونين وخمسمية'), 2000500);
  expect(YemeniNumberParser.tryParse('تسعة مليار'), 9000000000);
  expect(YemeniNumberParser.tryParse('مئة ألف'), 100000);
  expect(YemeniNumberParser.tryParse('عشرين ألف'), 20000);
  expect(YemeniNumberParser.tryParse('وخمسمية'), 500);
  expect(YemeniNumberParser.tryParse('1,250,000'), 1250000);
});
```

يفضل جعل المحلل يعيد `null` عند عدم وجود رقم، بدلاً من إعادة صفر مباشرة؛ حتى لا تتحول جملة غير مالية إلى عملية بقيمة صفر دون تنبيه.

## 2. ربط `getTransactionsPage` مع `ScrollController`

### حقول الحالة داخل `_MainDashboardScreenState`

أضف هذه الحقول بجانب `_transactions`:

```dart
final ScrollController _transactionsController = ScrollController();
static const int _pageSize = 50;

bool _isPageLoading = false;
bool _hasMorePages = true;
String? _lastTransactionDate;
String? _lastTransactionId;
int _pageGeneration = 0;
```

### التسجيل والإلغاء

```dart
@override
void initState() {
  super.initState();
  _transactionsController.addListener(_onTransactionsScroll);
  _initSpeechAndAgent();
  _loadData();
}

@override
void dispose() {
  _transactionsController.dispose();
  super.dispose();
}

void _onTransactionsScroll() {
  if (!_transactionsController.hasClients) return;

  // ابدأ الجلب قبل نهاية القائمة بحوالي 600 بكسل حتى لا يظهر فراغ للمستخدم.
  if (_transactionsController.position.extentAfter < 600) {
    _loadNextTransactionsPage();
  }
}
```

### تحميل الصفحة الأولى والصفحات التالية

```dart
Future<void> _resetTransactionsPagination() async {
  if (_isPageLoading) return;

  _pageGeneration++;
  final generation = _pageGeneration;

  setState(() {
    _transactions = [];
    _lastTransactionDate = null;
    _lastTransactionId = null;
    _hasMorePages = true;
  });

  await _loadNextTransactionsPage(generation: generation);
}

Future<void> _loadNextTransactionsPage({int? generation}) async {
  if (_isPageLoading || !_hasMorePages) return;

  final requestGeneration = generation ?? _pageGeneration;
  final cursorDate = _lastTransactionDate;
  final cursorId = _lastTransactionId;

  setState(() => _isPageLoading = true);

  try {
    final page = await _db.getTransactionsPage(
      limit: _pageSize,
      lastDate: cursorDate,
      lastId: cursorId,
    );

    if (!mounted || requestGeneration != _pageGeneration) return;

    final existingIds = _transactions
        .map((row) => row['id'].toString())
        .toSet();

    final freshRows = page.where((row) {
      return existingIds.add(row['id'].toString());
    }).toList();

    setState(() {
      _transactions.addAll(freshRows);
      _hasMorePages = page.length == _pageSize;

      if (page.isNotEmpty) {
        final last = page.last;
        _lastTransactionDate = last['date']?.toString();
        _lastTransactionId = last['id']?.toString();
      }
    });
  } finally {
    if (mounted && requestGeneration == _pageGeneration) {
      setState(() => _isPageLoading = false);
    }
  }
}
```

### تعديل `_loadData`

لا تستدعِ `getTransactions()` بعد الآن لقائمة السجل؛ استخدم الصفحة الأولى، واجلب المؤشرات المالية بشكل مستقل:

```dart
Future<void> _loadData() async {
  await _resetTransactionsPagination();

  final results = await Future.wait<double>([
    _db.getBalance(),
    _db.getTodayTotal('مصروف'),
    _db.getTodayTotal('مبيعات'),
  ]);

  if (!mounted) return;
  setState(() {
    _balance = results[0];
    _todayExpenses = results[1];
    _todaySales = results[2];
  });
}
```

### استخدام القائمة الصفحية في الواجهة

في الشاشة التي تعرض السجل، استبدل `ListView.builder` الحالي بهذا النمط:

```dart
Widget _buildPagedTransactionsList() {
  final itemCount = _transactions.length + (_hasMorePages ? 1 : 0);

  return RefreshIndicator(
    onRefresh: _resetTransactionsPagination,
    child: ListView.builder(
      controller: _transactionsController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == _transactions.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final transaction = _transactions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              transaction['title'] ??
                  transaction['description'] ??
                  'عملية محاسبية',
            ),
            subtitle: Text(
              '${transaction['type']} • ${transaction['date']}',
            ),
            trailing: Text('${transaction['amount']} ر.ي'),
          ),
        );
      },
    ),
  );
}
```

لا تضع `ScrollController` على `ListView` في الشاشة الرئيسية وتستخدم قائمة أخرى في شاشة المبيعات؛ يجب ربط المتحكم بالقائمة الفعلية التي يمررها المستخدم. وإذا كانت لكل تبويبة قائمة مستقلة، استخدم متحكماً وCursor مستقلاً لكل تبويب.

## 3. تحسين قاعدة البيانات للتصفح العميق

الاستعلام الحالي صحيح منطقياً:

```sql
WHERE date < ? OR (date = ? AND id < ?)
ORDER BY date DESC, id DESC
LIMIT ?
```

ولتحسينه مع ملايين السجلات، أضف فهرساً مركباً في ترقية قاعدة البيانات:

```dart
version: 2,
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tx_date_id '
      'ON transactions(date DESC, id DESC)',
    );
  }
},
```

لا يكفي تعديل `onCreate` في جهاز يحتوي على قاعدة بيانات موجودة؛ يجب رفع رقم النسخة وإضافة `onUpgrade` حتى يصل الفهرس إلى الأجهزة القديمة.

## 4. اختبار الأداء عبر الواجهة

1. شغّل التطبيق في **Profile Mode**، وليس Debug Mode.
2. افتح شاشة توليد البيانات واضغط `توليد 10 مليون عملية في الخلفية`.
3. بعد انتهاء التوليد، افتح شاشة السجل ومرّر بسرعة إلى صفحات عميقة.
4. راقب تبويبي Performance وMemory في Flutter DevTools.
5. سجّل زمن كل جلب صفحة، وعدد الإطارات المفقودة، وحجم الذاكرة.
6. تحقق من عدم تكرار `id` وعدم رجوع القائمة إلى الصفحة الأولى أثناء التمرير.
7. نفّذ تحديثاً بالسحب وتأكد من تصفير Cursor ثم إعادة تحميل الصفحة الأولى.
8. استخدم زر مسح البيانات التجريبية في النهاية؛ يجب أن يحذف `is_seed = 1` فقط.

النسخة الحالية من `main.dart` كانت تستخدم `getTransactions()` المحدودة بـ 100 سجل، ولذلك لا يُعد اختبار التمرير الصفحي مكتملًا حتى استبدالها بالقائمة والمتحكم أعلاه.
