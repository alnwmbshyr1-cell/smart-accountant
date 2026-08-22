import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_accountant/services/gemini_service.dart';
import 'package:smart_accountant/services/permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionResult', () {
    test('reports granted, limited, denied, and required states', () {
      const granted = PermissionResult(
        microphone: PermissionStatus.granted,
        notifications: PermissionStatus.granted,
      );
      expect(granted.microphoneGranted, isTrue);
      expect(granted.microphonePermanentlyDenied, isFalse);
      expect(granted.notificationsGranted, isTrue);
      expect(granted.hasRequiredPermissions, isTrue);

      const limited = PermissionResult(
        microphone: PermissionStatus.limited,
        notifications: PermissionStatus.limited,
      );
      expect(limited.microphoneGranted, isTrue);
      expect(limited.notificationsGranted, isTrue);

      const denied = PermissionResult(
        microphone: PermissionStatus.denied,
        notifications: PermissionStatus.denied,
      );
      expect(denied.microphoneGranted, isFalse);
      expect(denied.notificationsGranted, isFalse);
      expect(denied.hasRequiredPermissions, isFalse);

      const permanent = PermissionResult(
        microphone: PermissionStatus.permanentlyDenied,
      );
      expect(permanent.microphonePermanentlyDenied, isTrue);
      expect(permanent.notificationsGranted, isTrue);
    });
  });

  group('GeminiService offline and validation guards', () {
    test('returns null for blank commands without network access', () async {
      final service = GeminiService();
      expect(await service.processCommand('   '), isNull);
      expect(await service.processCommand(''), isNull);
    });

    test('returns null when no API key is available', () async {
      final service = GeminiService();
      expect(await service.readApiKey(), isNull);
      expect(await service.hasApiKey(), isFalse);
      expect(
          await service.processCommand('سجل مصروف بنزين بعشرين ألف'), isNull);
    });

    test('rejects empty API keys before touching storage', () async {
      final service = GeminiService();
      expect(
        () => service.saveApiKey('   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('GeminiService response decoding and validation', () {
    Future<GeminiService> serviceFor(String? response) async => GeminiService(
          apiKeyLoader: () async => 'test-key',
          textProvider: (prompt) async => response,
        );

    test('decodes fenced JSON and Arabic schema fields', () async {
      final service = await serviceFor(
        'قبل الرد ```json {"النوع":"دين لي","المبلغ":"100,000","الاسم":"خالد","الكمية":0} ``` بعده',
      );
      final result = await service.processCommand('سجل دين لي على خالد');
      expect(result, isNotNull);
      expect(result!['type'], 'دين_لي');
      expect(result['amount'], 100000);
      expect(result['desc'], 'خالد');
      expect(result['quantity'], 1);
    });

    test('returns null for malformed, empty, or non-map responses', () async {
      for (final response in <String?>['', 'not-json', '[1,2]', null]) {
        final result =
            await (await serviceFor(response)).processCommand('مصروف 10');
        expect(result, isNull);
      }
    });

    test('rejects unknown types, negative amounts, and empty descriptions',
        () async {
      final cases = <String>[
        '{"type":"شيء آخر","amount":10,"desc":"x"}',
        '{"type":"مصروف","amount":-1,"desc":"x"}',
        '{"type":"مصروف","amount":10,"desc":"  "}',
        '{"type":"مصروف","amount":"not-a-number","desc":"x"}',
      ];
      for (final response in cases) {
        expect(
          await (await serviceFor(response)).processCommand('اختبار'),
          isNull,
        );
      }
    });

    test('normalizes all supported types and positive quantity fallback',
        () async {
      for (final type in <String>[
        'مبيعات',
        'مشتريات',
        'دين_علي',
        'مخزون',
        'مصروف'
      ]) {
        final result = await (await serviceFor(
          '{"type":"$type","amount":12.5,"description":"بضاعة","quantity":"2"}',
        ))
            .processCommand('اختبار');
        expect(result!['type'], type);
        expect(result['amount'], 12.5);
        expect(result['quantity'], 2);
      }
    });

    test('falls back safely when API key loader or provider throws', () async {
      final keyFailure = GeminiService(apiKeyLoader: () async {
        throw StateError('secure storage unavailable');
      });
      expect(await keyFailure.processCommand('مصروف 10'), isNull);

      final providerFailure = GeminiService(
        apiKeyLoader: () async => 'key',
        textProvider: (_) async => throw StateError('network failure'),
      );
      expect(await providerFailure.processCommand('مصروف 10'), isNull);
    });
  });
}
