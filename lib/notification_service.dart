import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// خدمة إشعارات محلية تعمل دون خادم أو اتصال بالإنترنت.
class MaqaniNotificationService {
  MaqaniNotificationService._();
  static final instance = MaqaniNotificationService._();

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings: settings);
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> scheduleVaccinationReminder({required int id, required String animalNumber, required DateTime date}) async {
    await _schedule(
      id: id,
      title: 'موعد تطعيم في مقاني',
      body: 'حان موعد تطعيم الرأس رقم $animalNumber',
      date: date,
      channelId: 'vaccinations',
      channelName: 'مواعيد التطعيمات',
    );
  }

  Future<void> scheduleHealthFollowUp({required int id, required String animalNumber, required String condition, required DateTime date}) async {
    await _schedule(
      id: id,
      title: 'متابعة صحية في مقاني',
      body: 'تذكير بمتابعة حالة الرأس رقم $animalNumber: $condition',
      date: date,
      channelId: 'health_records',
      channelName: 'السجل المرضي',
    );
  }

  Future<void> _schedule({required int id, required String title, required String body, required DateTime date, required String channelId, required String channelName}) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(channelId, channelName, channelDescription: 'تنبيهات تطبيق مقاني', importance: Importance.high, priority: Priority.high),
    );
    final scheduled = tz.TZDateTime.from(date, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    await plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'maqani://$channelId/$id',
    );
  }

  Future<void> cancel(int id) => plugin.cancel(id: id);
  Future<void> cancelAll() => plugin.cancelAll();
}
