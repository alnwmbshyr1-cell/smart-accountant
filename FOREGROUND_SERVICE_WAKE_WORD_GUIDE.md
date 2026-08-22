# تشغيل Wake Word في Android Foreground Service

## الخلاصة التنفيذية

إضافة `FOREGROUND_SERVICE` إلى `AndroidManifest.xml` وحدها لا تجعل الميكروفون مستمراً في الخلفية. يجب إنشاء كائن `Service` حقيقي، وتشغيله من واجهة ظاهرة للمستخدم، واستدعاء `startForeground()` خلال المهلة النظامية، وعرض إشعار دائم يوضح أن الميكروفون فعال. في التطبيقات التي تستهدف Android 14 أو أحدث يجب تعريف نوع الخدمة `microphone` في الـ Manifest وإضافة `FOREGROUND_SERVICE_MICROPHONE`، كما يجب منح `RECORD_AUDIO` قبل تشغيل الخدمة [1] [2].

في مشروع Smart Accountant الحالي، `AiAgentService` يعتمد على `speech_to_text` و`flutter_tts` و`porcupine_flutter` داخل عملية Flutter. هذا مناسب عندما تكون عملية التطبيق حية، لكنه ليس ضماناً لتشغيل مستمر بعد إغلاق الواجهة. البنية الأكثر ثباتاً هي أن يملك Android Service التقاط الصوت وكلمة التنشيط، بينما يتولى Flutter عرض الحالة وتنفيذ العملية المحاسبية.

## البنية المقترحة

| الطبقة | المسؤولية |
|---|---|
| Android Foreground Service | إشعار دائم، إبقاء الخدمة في foreground، امتلاك الميكروفون، تشغيل محرك Porcupine الأصلي أو Voice Processor مدعوم بالخلفية. |
| Wake Word Engine | اكتشاف `يا محاسب` و`يا حسابات`. عبارة عربية مخصصة تحتاج ملف keyword بصيغة `.ppn` وAccessKey من Picovoice؛ لا تُدرّب تلقائياً داخل التطبيق. |
| Flutter Bridge | `MethodChannel` لبدء وإيقاف الخدمة و`EventChannel` لاستقبال حدث wake word وحالة الخدمة. |
| AiAgentService | الرد `نعم يا شيخ`، تسجيل الأمر 5 ثوانٍ، تحليل النص، والحفظ في SQLite. |
| الإعدادات | مفتاح صريح للتفعيل، وزر إيقاف سريع، وبيان أن الميكروفون يعمل. |

> لا ينبغي تشغيل `speech_to_text` من Service Android مستقل على أنه ASR خلفي مضمون؛ هو Plugin موجّه لعملية Flutter وقد يعتمد على محرك النظام. إذا كان المطلوب تنفيذ الأمر بعد إغلاق الواجهة وبلا إنترنت، يجب استخدام ASR محلي مثل Vosk في الخدمة أو تشغيل محرك محلي داخل Flutter headless isolate مع اختبار حقيقي على الجهاز.

## 1. AndroidManifest.xml

أضف الصلاحيات التالية داخل عنصر `manifest`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

ثم عرّف الخدمة داخل عنصر `application`:

```xml
<service
    android:name=".WakeWordForegroundService"
    android:enabled="true"
    android:exported="false"
    android:stopWithTask="false"
    android:foregroundServiceType="microphone" />
```

التعريف الصحيح للنوع مهم؛ Android قد يرمي `MissingForegroundServiceTypeException` عند `startForeground()` إذا لم يطابق نوع الخدمة ما هو مذكور في Manifest. كما أن غياب إذن النوع قد يؤدي إلى `SecurityException` [1].

## 2. خدمة Kotlin حقيقية

أنشئ الملف:

`android/app/src/main/kotlin/com/smartaccountant/app/WakeWordForegroundService.kt`

وعدّل اسم الحزمة ليتطابق مع `namespace` و`applicationId` في المشروع:

```kotlin
package com.smartaccountant.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class WakeWordForegroundService : Service() {

    companion object {
        const val ACTION_START = "com.smartaccountant.action.START_WAKE_WORD"
        const val ACTION_STOP = "com.smartaccountant.action.STOP_WAKE_WORD"
        const val CHANNEL_ID = "smart_accountant_voice"
        const val NOTIFICATION_ID = 4101
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopWakeWordEngine()
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = buildNotification()
        val foregroundType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        } else {
            0
        }

        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            foregroundType,
        )

        // هنا يجب تشغيل محرك Wake Word الأصلي المدعوم بالخدمة.
        // لا تضع استدعاء speech_to_text هنا وتتوقع أنه سيبقى بعد موت Flutter.
        startWakeWordEngine()
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, WakeWordForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            4102,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
        )

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentPendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                4103,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
            )
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("المحاسب يستمع")
            .setContentText("قل: يا محاسب أو يا حسابات")
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(contentPendingIntent)
            .addAction(
                android.R.drawable.ic_media_pause,
                "إيقاف",
                stopPendingIntent,
            )
            .build()
    }

    private fun immutableFlag(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "التنشيط الصوتي",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "إشعار دائم عند تشغيل الاستماع لكلمة التنشيط"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun startWakeWordEngine() {
        // اربط هنا Picovoice Porcupine Android SDK مع ملف .ppn العربي.
        // عند اكتشاف الكلمة أرسل broadcast أو EventChannel إلى Flutter.
    }

    private fun stopWakeWordEngine() {
        // حرر AudioRecord / Porcupine resources هنا.
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        stopWakeWordEngine()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
```

هذا الهيكل مسؤول عن الإشعار ودورة حياة الخدمة فقط. يجب عدم ترك `startWakeWordEngine()` فارغة في نسخة الإنتاج؛ اربط فيها SDK Android الأصلي لـ Porcupine أو محركاً آخر يدعم foreground service. حزمة `porcupine_flutter` الموجودة في المشروع توفر واجهة Flutter، لكنها لا تعني تلقائياً أن محرك الصوت سيستمر بعد إنهاء عملية Flutter [3].

## 3. تشغيل وإيقاف الخدمة من MainActivity

في `MainActivity.kt` استخدم قناة MethodChannel. يجب بدء الخدمة بعد أن تكون Activity مرئية وبعد منح `RECORD_AUDIO`:

```kotlin
package com.smartaccountant.app

import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "smart_accountant/foreground_wake"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, WakeWordForegroundService::class.java)
                        .setAction(WakeWordForegroundService.ACTION_START)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ContextCompat.startForegroundService(this, intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    val intent = Intent(this, WakeWordForegroundService::class.java)
                        .setAction(WakeWordForegroundService.ACTION_STOP)
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
```

لا تبدأ خدمة الميكروفون تلقائياً من `BOOT_COMPLETED` أو من حالة خلفية بلا موافقة ظاهرة. قيود Android الخاصة بصلاحيات while-in-use تجعل الترتيب مهماً: اطلب `RECORD_AUDIO`، تحقق من نجاحه، ثم ابدأ الخدمة بينما التطبيق ظاهر [1] [2].

## 4. جسر Flutter

أنشئ ملفاً مثل `lib/foreground_wake_bridge.dart`:

```dart
import 'package:flutter/services.dart';

class ForegroundWakeBridge {
  static const _channel = MethodChannel('smart_accountant/foreground_wake');

  Future<void> start() async {
    await _channel.invokeMethod<void>('start');
  }

  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }
}
```

وفي الإعدادات:

```dart
final bridge = ForegroundWakeBridge();

Future<void> onWakeToggle(bool enabled) async {
  if (enabled) {
    // اطلب RECORD_AUDIO وPOST_NOTIFICATIONS قبل هذا السطر.
    await bridge.start();
  } else {
    await bridge.stop();
  }
}
```

عند اكتشاف wake word، أرسل event من الخدمة إلى Flutter عندما تكون الواجهة حية، أو احفظ الحدث في مخزن صغير ليُقرأ عند عودة Activity. لا تعتمد على EventChannel وحده إذا كان التطبيق مغلقاً؛ فلا يوجد مستمع Dart مضمون في تلك الحالة.

## 5. دورة الأمر المطلوبة

الدورة الآمنة هي:

1. المستخدم يفعّل المفتاح صراحة من الإعدادات.
2. Flutter يطلب `RECORD_AUDIO` و`POST_NOTIFICATIONS`.
3. بعد نجاح الصلاحيات يبدأ `WakeWordForegroundService` ويظهر إشعار `المحاسب يستمع...`.
4. Porcupine يكتشف `يا محاسب` أو `يا حسابات` دون إرسال الصوت إلى السحابة.
5. الخدمة توقف جلسة wake مؤقتاً حتى لا يحدث تعارض مع جلسة الأمر.
6. Flutter ينطق `نعم يا شيخ` إذا كانت العملية داخل Flutter، أو تنطقها الخدمة عبر Android Text-to-Speech إذا كان التطبيق مغلقاً.
7. يبدأ التقاط الأمر لمدة 5 ثوانٍ.
8. يحوّل ASR المحلي الأمر إلى نص، ثم يرسل النص إلى `AiAgentService`.
9. يحلل الأمر ويحفظه في SQLite؛ لا تنطق `تم` قبل نجاح `addTransaction`.
10. يعاد تشغيل wake engine، ويستمر الإشعار.
11. عند الضغط على `إيقاف` من الإشعار أو الإعدادات، يحرر المحرك والميكروفون ويتوقف الإشعار.

## 6. ما يجب تعديله في AiAgentService الحالي

الدالة الحالية `startWakeWordListening` جيدة كحل fallback عندما تكون عملية Flutter حية. في بنية foreground الحقيقية اجعلها مستقبلاً مستمعاً لحدث bridge بدلاً من محاولة امتلاك ميكروفون ثانٍ:

```dart
void attachForegroundWakeEvents() {
  // عند وصول wake event:
  // 1) speakYemeni('نعم يا شيخ')
  // 2) استدعاء capture لمدة 5 ثوانٍ
  // 3) processVoiceCommandText بعد وصول النص
}
```

يجب ألا يعمل `speech_to_text` من `AiAgentService` في الوقت نفسه الذي يعمل فيه Porcupine أو AudioRecord؛ امتلاك مصدرين للميكروفون قد يسبب `ERROR_RECOGNIZER_BUSY` أو توقفاً متقطعاً. استخدم state machine واحدة مثل:

```text
IDLE -> WAKE_LISTENING -> WAKE_DETECTED -> COMMAND_RECORDING
     -> PROCESSING -> SPEAKING -> WAKE_LISTENING
```

## 7. الاختبارات العملية على جهاز Android

اختبر على جهاز فعلي في Release أو Profile، لا على widget tests فقط. تحقّق من النقاط التالية:

```bash
adb shell pm grant com.smartaccountant.app android.permission.RECORD_AUDIO
adb shell am start -n com.smartaccountant.app/.MainActivity
adb shell dumpsys activity services com.smartaccountant.app
adb shell dumpsys notification --noredact | grep -i "المحاسب"
```

ثم اختبر بالترتيب: تفعيل المفتاح، إطفاء الشاشة، قول `يا محاسب`، انتظار `نعم يا شيخ`، قول `سجل مصروف 20 الف`، إعادة فتح التطبيق، والتحقق من وجود العملية في SQLite. كرر الاختبار مع إيقاف التنشيط من الإشعار، ومع رفض إذن الإشعارات، ومع إيقاف التطبيق من شاشة Recent Apps.

لا يمكن إثبات استمرار الميكروفون أو استهلاك البطارية باختبار `flutter test`؛ يلزم جهاز Android فعلي وقياس `dumpsys meminfo` و`dumpsys batterystats` ومراقبة إشعار النظام.

## القيود والخصوصية

لا توجد طريقة تضمن ألا يغلق النظام الخدمة في جميع الظروف. المستخدم يستطيع إيقافها من إعدادات البطارية أو زر إيقاف التطبيق، وبعض الشركات تضيف سياسات قتل عدوانية. كما أن Android يفرض إشعاراً مرئياً لخدمة الميكروفون، وGoogle Play قد يراجع مبرر استخدام foreground microphone service. لذلك اجعل التنشيط اختيارياً، وأظهر الحالة بوضوح، وأوقف الميكروفون فور إلغاء المفتاح.

## مراجع

[1]: https://developer.android.com/about/versions/14/changes/fgs-types-required "Android Developers — Foreground service types are required"

[2]: https://developer.android.com/develop/background-work/services/fgs/service-types "Android Developers — Foreground service types"

[3]: https://pub.dev/packages/porcupine_flutter "pub.dev — porcupine_flutter"
