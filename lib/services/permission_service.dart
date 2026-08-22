import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Handles runtime permissions required by the voice assistant.
///
/// Android still requires the user to approve dangerous permissions. This
/// service requests them automatically at the correct point in the flow and
/// exposes a safe way to open system settings after a permanent denial.
class PermissionService {
  const PermissionService();

  Future<PermissionResult> requestForVoiceAssistant() async {
    final microphone = await Permission.microphone.request();

    PermissionStatus? notifications;
    if (Platform.isAndroid) {
      notifications = await Permission.notification.request();
    }

    return PermissionResult(
      microphone: microphone,
      notifications: notifications,
    );
  }

  Future<PermissionResult> requestMicrophone() async {
    final microphone = await Permission.microphone.request();
    return PermissionResult(microphone: microphone);
  }

  Future<bool> openSettings() => openAppSettings();
}

class PermissionResult {
  const PermissionResult({required this.microphone, this.notifications});

  final PermissionStatus microphone;
  final PermissionStatus? notifications;

  bool get microphoneGranted => microphone.isGranted || microphone.isLimited;
  bool get microphonePermanentlyDenied => microphone.isPermanentlyDenied;
  bool get notificationsGranted =>
      notifications == null ||
      notifications!.isGranted ||
      notifications!.isLimited;
  bool get hasRequiredPermissions => microphoneGranted;
}
