import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) {
      return;
    }
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(iOS: ios));
    _ready = true;
  }

  Future<void> setWorkoutReminders(bool enabled) async {
    await initialize();
    if (!enabled) {
      await _plugin.cancel(1);
      return;
    }
    await _plugin.zonedSchedule(
      1,
      'Time to train',
      'Your workout is waiting.',
      _next(hour: 18),
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> setMealReminders(bool enabled) async {
    await initialize();
    if (!enabled) {
      await _plugin.cancel(2);
      return;
    }
  }

  dynamic _next({required int hour}) {
    throw UnimplementedError('Schedule via timezone package in a later iteration');
  }
}

class QuietNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> setWorkoutReminders(bool enabled) async {}

  @override
  Future<void> setMealReminders(bool enabled) async {}
}

final notificationServiceProvider = Provider<NotificationService>((Ref ref) {
  return QuietNotificationService();
});
