import 'dart:math';
import 'database_service.dart';

class SeedDatabase {
  static final DatabaseService _db = DatabaseService();

  static const List<String> _namesList = [
    "أحمد",
    "محمد",
    "خالد",
    "علي",
    "سالم",
    "فهد",
    "عبدالله",
    "عمر",
    "إبراهيم",
    "يوسف",
    "ناصر",
    "صالح",
    "حسن",
    "حسين",
    "معاذ",
    "بلال",
    "عارف",
    "سامي",
    "نبيل",
    "منصور",
    "جمال",
    "رائد",
    "زياد",
    "باسل",
    "هيثم",
    "طارق",
    "واصف",
    "أمين",
    "محسن",
    "عادل"
  ];

  static const List<String> _notesList = [
    "بضاعة",
    "بنزين",
    "إيجار",
    "رواتب",
    "مواد غذائية",
    "قطع غيار",
    "صيانة",
    "كهرباء ومياه",
    "نقل وتوصيل",
    "أمشاج"
  ];

  static const List<String> _typesList = [
    "مبيعات",
    "مشتريات",
    "مصروف",
    "دين لك",
    "دين عليك"
  ];

  /// توليد 10 مليون سجل موزعة على دفعات 50,000 لتجنب تعليق الهاتف
  static Future<void> generateMassiveData({
    required Function(int current, int total, String status) onProgress,
  }) async {
    const int totalRecords = 10000000;
    const int batchSize = 50000;
    final Random random = Random();

    // توزيع الملايين حسب الطلب:
    // مبيعات: 3,000,000 | مشتريات: 2,000,000 | مصروفات: 2,000,000 | دين لي: 1,500,000 | دين علي: 1,500,000

    int createdCount = 0;

    for (int batchStart = 0;
        batchStart < totalRecords;
        batchStart += batchSize) {
      int currentBatchCount = (batchStart + batchSize > totalRecords)
          ? (totalRecords - batchStart)
          : batchSize;
      List<Map<String, dynamic>> batchList = [];

      for (int i = 0; i < currentBatchCount; i++) {
        // تحديد النوع بتوزيع واقعي
        String type = _typesList[random.nextInt(_typesList.length)];
        double amount = (random.nextInt(10000) + 1) *
            1000.0; // مبالغ من 1000 إلى 10,000,000
        String name = _namesList[random.nextInt(_namesList.length)];
        String note = _notesList[random.nextInt(_notesList.length)];

        // تاريخ عشوائي خلال آخر 3 سنوات
        int daysAgo = random.nextInt(365 * 3);
        String dateStr =
            DateTime.now().subtract(Duration(days: daysAgo)).toIso8601String();

        batchList.add({
          'type': type,
          'amount': amount,
          'description': '$note (تجريبي - $name)',
          'date': dateStr,
          'is_seed': 1, // علامة مميزة لتمييز البيانات التجريبية وحذفها بأمان
        });
      }

      // إدخال الدفعة في قاعدة البيانات SQLite
      await _db.insertBatchTransactions(batchList);
      createdCount += currentBatchCount;

      onProgress(createdCount, totalRecords,
          "جاري حقن الدفعة: $createdCount من $totalRecords سجل...");

      // إتاحة فرصة للمعالج لكي لا يتجمد التطبيق
      await Future.delayed(const Duration(milliseconds: 10));
    }

    onProgress(totalRecords, totalRecords, "تم إنشاء 10,000,000 عملية بنجاح!");
  }

  /// مسح البيانات التجريبية فقط مع الحفاظ على البيانات الحقيقية للمستخدم
  static Future<int> clearSeedData() async {
    return await _db.deleteSeedTransactions();
  }
}
