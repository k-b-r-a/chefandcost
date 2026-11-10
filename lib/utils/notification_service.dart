import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'audio_alarm_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId == 'stop_alarm_action') {
    AudioAlarmService().stopAlarm();
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Convenience alias for initialize() for uniform deferred init calling
  Future<void> init() => initialize();

  Future<void> initialize() async {
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        _initialized = true;
        return;
      }
    } catch (_) {}
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.actionId == 'stop_alarm_action' || response.id != null) {
            AudioAlarmService().stopAlarm();
            if (response.id != null) {
              _notificationsPlugin.cancel(response.id!);
            }
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Requests notification permission on supported mobile platforms (Android 13+ and iOS).
  /// Safe to call anywhere after the UI has loaded without freezing or showing a black screen.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    try {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final darwinImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (darwinImplementation != null) {
        final granted = await darwinImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
    return false;
  }

  /// Alias for [requestPermission] for backward compatibility.
  Future<bool?> requestNotificationsPermission() => requestPermission();

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
  }

  Future<void> showTimerFinishedNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      'kitchen_timer_alarm_v4',
      'Kitchen Timer Alarm',
      channelDescription: 'Notifications for finished kitchen timers with alarm sound',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'stop_alarm_action',
          '⏹️ DETENER ALARMA',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    if (kIsWeb) return;
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing timer notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }
}
