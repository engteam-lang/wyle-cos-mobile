import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A single notification captured from another app on the device.
class DeviceNotification {
  final String   appName;
  final String   packageName;
  final String   title;
  final String   body;
  final DateTime timestamp;

  const DeviceNotification({
    required this.appName,
    required this.packageName,
    required this.title,
    required this.body,
    required this.timestamp,
  });
}

/// Flutter-side bridge for [WyleNotificationListenerService].
///
/// Usage:
///   // Check permission
///   final granted = await DeviceNotificationService.instance.isAccessGranted();
///
///   // Open system settings if not granted
///   await DeviceNotificationService.instance.openSettings();
///
///   // Listen for incoming notifications
///   DeviceNotificationService.instance.stream.listen((n) { ... });
class DeviceNotificationService {
  DeviceNotificationService._();
  static final DeviceNotificationService instance = DeviceNotificationService._();

  static const _eventChannel  =
      EventChannel('com.wyle.wylecosapp/device_notifications');
  static const _methodChannel =
      MethodChannel('com.wyle.wylecosapp/notification_permission');

  Stream<DeviceNotification>? _stream;

  // Callback invoked when the stream errors so the caller can resubscribe.
  VoidCallback? onStreamError;

  /// Broadcast stream of notifications from other apps.
  /// Empty/no-op on web.
  Stream<DeviceNotification> get stream {
    if (kIsWeb) return const Stream.empty();
    _stream ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event != null)
        .map((dynamic event) {
          final m = Map<String, dynamic>.from(event as Map);
          return DeviceNotification(
            appName:     m['appName']     as String? ?? 'Unknown',
            packageName: m['packageName'] as String? ?? '',
            title:       m['title']       as String? ?? '',
            body:        m['body']        as String? ?? '',
            timestamp:   DateTime.fromMillisecondsSinceEpoch(
                (m['timestamp'] as num?)?.toInt() ?? 0),
          );
        })
        .handleError((dynamic e) {
          debugPrint('[DeviceNotif] Stream error: $e — will resubscribe');
          // Reset so the stream is recreated on the next subscription attempt.
          _stream = null;
          // Notify caller so it can resubscribe without waiting for a lifecycle event.
          onStreamError?.call();
        });
    return _stream!;
  }

  /// Returns true if Wyle appears in Android's notification-listener list.
  /// Always false on web.
  Future<bool> isAccessGranted() async {
    if (kIsWeb) return false;
    try {
      return await _methodChannel
              .invokeMethod<bool>('isNotificationAccessGranted') ??
          false;
    } catch (e) {
      debugPrint('[DeviceNotif] isAccessGranted error: $e');
      return false;
    }
  }

  /// Opens Android's Notification Listener Settings page so the user can
  /// toggle Wyle on.  No-op on web.
  Future<void> openSettings() async {
    if (kIsWeb) return;
    try {
      await _methodChannel.invokeMethod('openNotificationAccessSettings');
    } catch (e) {
      debugPrint('[DeviceNotif] openSettings error: $e');
    }
  }
}
