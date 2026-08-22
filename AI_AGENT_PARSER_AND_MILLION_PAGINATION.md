# Smart Accountant v3.2.0

## 1. محلل الأرقام اليمنية المركبة

أنشئ الملف `lib/yemeni_number_parser.dart`:

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
    // صيغ دارجة في النطق اليمني
    'خمسمية': 500,
    'خمسماية': 500,
    'خمسمائة': 500,
    'خمسمائه': 500,
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
    'مليوني': 2000000,
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
    'نص',
  };

  /// يعيد null إذا لم يجد أي قيمة رقمية، حتى لا تتحول الجملة غير المالية إلى صفر.
  static double? tryParse(String input) {
    var text = _normalize(input);
    if (text.isEmpty) return null;

    // تطبيع بعض الأعداد المركبة قبل تحليل الكلمات.
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
        lastScale = direct >= 1000000000 ? 1000000000 : 1000000;
        foundNumber = true;
        continue;
      }

      final small = _smallValues[token];
      if (small != null) {
        // ثلاث مئة = 300، و"عشرين وخمسة" = 25.
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

      if ((token == 'نصف' || token == 'نص') && lastScale != null) {
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

    return text
        .replaceAll('٬', '')
        .replaceAll('،', ',')
        .replaceAll(RegExp(r'(?<=\d),(?=\d)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _canonicalToken(String raw) {
    var token = raw.replaceAll(RegExp(r'^[,،.]+|[,،.]+$'), '');
    if (_knownWords.contains(token)) return token;

    // دعم: وخمسمية، ومليونين، وتسعة، وألف.
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

> ملاحظة: احذف تكرار المفتاح `اثنا عشر` إذا ظهر مرتين عند النسخ؛ في Dart يجب أن تكون مفاتيح الـ Map ثابتة وفريدة. النسخة الصحيحة تحتويه مرة واحدة فقط.

## 2. AiAgentParser الكامل بعد الدمج

استبدل محتوى `lib/ai_agent_parser.dart` بالآتي:

```dart
import 'yemeni_dictionary.dart';
import 'yemeni_number_parser.dart';

class AiAgentParser {
  const AiAgentParser._();

  static Map<String, dynamic> parseCommandToJson(String text) {
    final normalized = YemeniDictionary
        .normalizeYemeniText(text)
        .toLowerCase()
        .trim();

    final type = _detectType(normalized);
    final amount = parseArabicNumber(normalized);
    final name = extractName(normalized);

    return <String, dynamic>{
      'النوع': type,
      'الاسم': name,
      'المبلغ': amount,
      'النص_الاصلي': text,
    };
  }

  static String _detectType(String text) {
    // افحص الديون قبل كلمة "على" حتى لا تُصنّف الجملة بشكل غير مقصود.
    if (text.contains('دين_علي') ||
        text.contains('دين علي') ||
        text.contains('ديني') ||
        text.contains('للناس عندي') ||
        text.contains('للمورد')) {
      return 'دين_علي';
    }

    if (text.contains('دين_لي') ||
        text.contains('دين لي') ||
        text.contains('دين لك') ||
        text.contains('سلفه') ||
        text.contains('سلفة') ||
        text.contains('في ذمته') ||
        text.contains('على')) {
      return 'دين_لي';
    }

    if (text.contains('مبيعات') ||
        text.contains('بيع') ||
        text.contains('بعت') ||
        text.contains('صوّبت') ||
        text.contains('دبّرت') ||
        text.contains('كسبت') ||
        text.contains('حصلت') ||
        text.contains('ايراد') ||
        text.contains('دخل')) {
      return 'مبيعات';
    }

    if (text.contains('مشتريات') ||
        text.contains('اشتريت') ||
        text.contains('شريت') ||
        text.contains('تقضّيت') ||
        text.contains('قضّيت')) {
      return 'مشتريات';
    }

    return 'مصروف';
  }

  /// يحلل الكلمات المركبة أولاً، ثم يرجع للأرقام الرقمية كحل احتياطي.
  static double parseArabicNumber(String text) {
    final compound = YemeniNumberParser.tryParse(text);
    if (compound != null) return compound;

    final match = RegExp(r'(\d[\d,\.]*)').firstMatch(text);
    if (match == null) return 0.0;

    final numberText = match.group(1)!.replaceAll(',', '');
    return double.tryParse(numberText) ?? 0.0;
  }

  static String extractName(String text) {
    final patterns = <RegExp>[
      RegExp(r'(?:على|عند)\s+([\u0600-\u06FF]+)'),
      RegExp(r'للمورد\s+([\u0600-\u06FF]+)'),
      RegExp(r'(?:لـ|لِـ|ل)\s*([\u0600-\u06FF]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final candidate = match.group(1)!.trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }

    // حافظ على السلوك السابق للأمر الصريح "لاحمد".
    if (text.contains('لاحمد') || text.contains('لأحمد')) {
      return 'أحمد';
    }

    return 'عام';
  }
}
```

> النسخة الصحيحة تبدأ مباشرة بالاستيرادين التاليين:
>
> ```dart
> import 'yemeni_dictionary.dart';
> import 'yemeni_number_parser.dart';
> ```
>
> ثم يبدأ تعريف `class AiAgentParser`.

## 3. أمثلة اختبار محلل الأرقام

أنشئ `test/yemeni_number_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_accountant/ai_agent_parser.dart';
import 'package:smart_accountant/yemeni_number_parser.dart';

void main() {
  group('Yemeni compound number parser', () {
    test('parses millionain plus khamsmiya', () {
      expect(
        YemeniNumberParser.tryParse('مليونين وخمسمية'),
        2000500,
      );
    });

    test('parses a number before a large scale', () {
      expect(YemeniNumberParser.tryParse('تسعة مليار'), 9000000000);
      expect(YemeniNumberParser.tryParse('عشرين ألف'), 20000);
      expect(YemeniNumberParser.tryParse('مئة ألف'), 100000);
    });

    test('parses attached waw and Yemeni hundreds', () {
      expect(YemeniNumberParser.tryParse('وخمسمية'), 500);
      expect(YemeniNumberParser.tryParse('ثلاث مئة وخمسين ألف'), 350000);
    });

    test('parses compound number through AiAgentParser', () {
      final result = AiAgentParser.parseCommandToJson(
        'سجل مصروف مليونين وخمسمية ريال',
      );

      expect(result['النوع'], 'مصروف');
      expect(result['المبلغ'], 2000500);
    });

    test('returns null for a sentence without a number', () {
      expect(YemeniNumberParser.tryParse('افتح التقرير'), isNull);
    });
  });
}
```

## 4. اختبار Keyset Pagination مع مليون سجل محلياً

هذا الاختبار يستخدم قاعدة SQLite مؤقتة مستقلة، حتى لا يتداخل مع قاعدة التطبيق أو اختبارات أخرى. أنشئ `test/pagination_million_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const million = 1000000;
const pageSize = 100;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'Keyset Pagination traverses one million local records',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'smart_accountant_pagination_',
      );
      final databasePath = p.join(tempDirectory.path, 'million.db');

      final db = await databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                amount REAL NOT NULL,
                description TEXT,
                date TEXT NOT NULL,
                is_seed INTEGER NOT NULL DEFAULT 1
              )
            ''');

            await database.execute('''
              CREATE INDEX idx_transactions_date_id
              ON transactions(date DESC, id DESC)
            ''');
          },
        ),
      );

      try {
        final seedWatch = Stopwatch()..start();
        await _seedMillionRows(db);
        seedWatch.stop();

        final countResult = await db.rawQuery(
          'SELECT COUNT(*) AS count FROM transactions',
        );
        final insertedCount = (countResult.first['count'] as num).toInt();
        expect(insertedCount, million);

        String? lastDate;
        String? lastId;
        String? previousId;
        var fetchedRows = 0;
        var pages = 0;
        var slowestPageMs = 0;
        final pageSamples = <int, int>{};

        final traversalWatch = Stopwatch()..start();

        while (true) {
          final pageWatch = Stopwatch()..start();
          final page = await _getTransactionsPage(
            db,
            limit: pageSize,
            lastDate: lastDate,
            lastId: lastId,
          );
          pageWatch.stop();

          final pageTimeMs = pageWatch.elapsedMilliseconds;
          if (pageTimeMs > slowestPageMs) {
            slowestPageMs = pageTimeMs;
          }

          if (page.isEmpty) break;

          pages++;
          fetchedRows += page.length;
          pageSamples[pages] = pageTimeMs;

          for (final row in page) {
            final currentId = row['id']!.toString();

            // كل صفحة يجب أن تكون مرتبة تنازلياً، دون تكرار أو رجوع للخلف.
            if (previousId != null) {
              expect(int.parse(currentId) < int.parse(previousId!), isTrue);
            }
            previousId = currentId;
          }

          final lastRow = page.last;
          lastDate = lastRow['date']!.toString();
          lastId = lastRow['id']!.toString();

          expect(page.length, lessThanOrEqualTo(pageSize));
        }

        traversalWatch.stop();

        expect(fetchedRows, million);
        expect(pages, (million / pageSize).ceil());
        expect(lastId, '000000000001');

        // عتبة واسعة لتفادي فشل الاختبار على أجهزة CI البطيئة.
        // اضبطها لاحقاً وفق خط أساس جهازك الحقيقي.
        expect(slowestPageMs, lessThan(5000));

        // تظهر هذه القيم في سجل الاختبار للمقارنة بين الأجهزة.
        print('Seed time: ${seedWatch.elapsedMilliseconds} ms');
        print('Traversal time: ${traversalWatch.elapsedMilliseconds} ms');
        print('Pages: $pages, rows: $fetchedRows');
        print('Slowest page: $slowestPageMs ms');
        print('First page: ${pageSamples[1]} ms');
        print('Middle sample: ${pageSamples[pages ~/ 2]} ms');
        print('Last page: ${pageSamples[pages]} ms');
      } finally {
        await db.close();
        await tempDirectory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<void> _seedMillionRows(Database db) async {
  const fixedDate = '2026-08-22T00:00:00.000Z';

  for (var start = 1; start <= million; start += 50000) {
    final end = (start + 50000 - 1).clamp(1, million);

    await db.transaction((transaction) async {
      final batch = transaction.batch();

      for (var id = start; id <= end; id++) {
        batch.insert(
          'transactions',
          <String, Object?>{
            // padding يحافظ على الترتيب النصي نفسه للترتيب الرقمي.
            'id': id.toString().padLeft(12, '0'),
            'type': id % 3 == 0 ? 'مبيعات' : 'مصروف',
            'amount': (id % 100000) + 1000,
            'description': 'سجل اختبار $id',
            'date': fixedDate,
            'is_seed': 1,
          },
        );
      }

      await batch.commit(noResult: true);
    });
  }
}

Future<List<Map<String, Object?>>> _getTransactionsPage(
  Database db, {
  required int limit,
  String? lastDate,
  String? lastId,
}) {
  if (lastDate == null || lastId == null) {
    return db.query(
      'transactions',
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
  }

  return db.query(
    'transactions',
    where: 'date < ? OR (date = ? AND id < ?)',
    whereArgs: <Object?>[lastDate, lastDate, lastId],
    orderBy: 'date DESC, id DESC',
    limit: limit,
  );
}
```

## 5. تشغيل الاختبارات

شغّل اختبار المحلل أولاً:

```bash
flutter test test/yemeni_number_parser_test.dart
```

ثم شغّل اختبار المليون بشكل منفصل وبـ concurrency واحد لتجنب قفل SQLite بين الاختبارات:

```bash
flutter test --concurrency=1 test/pagination_million_test.dart
```

ولتسجيل إخراج أطول أثناء قياس الأداء:

```bash
flutter test --concurrency=1 -r expanded test/pagination_million_test.dart
```

## 6. تفسير النتائج

نجاح الاختبار يتطلب أربعة أمور: إدخال مليون سجل، إرجاع العدد نفسه أثناء المرور الصفحي، عدم تكرار أو عكس ترتيب المعرفات، وبقاء أبطأ صفحة تحت العتبة الواسعة المحددة للاختبار. لا تقارن زمن Debug Mode بزمن نسخة الإنتاج؛ استخدم Profile Mode على الهاتف أو المحاكي عند قياس تجربة المستخدم.

اختبار المليون أعلاه يختبر استعلام SQLite مباشرة باستخدام الفهرس المركب `(date, id)`. أما ربطه بواجهة Flutter فيحتاج أيضاً إلى `ScrollController` وحالة `_isPageLoading` وCursor (`lastDate`, `lastId`). لا تشغّل اختبار المليون بالتوازي مع اختبارات تفتح قاعدة `smart_accountant_v3.db` نفسها؛ قاعدة مؤقتة مستقلة و`--concurrency=1` يمنعان معظم أخطاء `database is locked`.
