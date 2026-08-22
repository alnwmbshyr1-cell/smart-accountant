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
}
