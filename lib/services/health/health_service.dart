import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitmate/core/networking/supabase_provider.dart';
import 'package:health/health.dart';

class HealthData {
  const HealthData({this.steps, this.sleepHours, this.activeEnergy});

  final int? steps;
  final double? sleepHours;
  final double? activeEnergy;
}

abstract class HealthService {
  Future<void> requestPermissions();
  Future<HealthData> getTodayData();
  Future<void> syncToday();
}

class StubHealthService implements HealthService {
  @override
  Future<void> requestPermissions() async {}

  @override
  Future<HealthData> getTodayData() async => const HealthData();

  @override
  Future<void> syncToday() async {}
}

class HealthKitHealthService implements HealthService {
  HealthKitHealthService({Health? health}) : _health = health ?? Health();

  final Health _health;

  static const List<HealthDataType> _types = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WEIGHT,
  ];

  @override
  Future<void> requestPermissions() async {
    final bool granted = await _health.requestAuthorization(_types);
    if (granted != true) {
      throw StateError('Apple Health permission was not granted. You can enable it in Settings.');
    }
    final String? userId = SupabaseProvider.client.auth.currentUser?.id;
    if (userId != null) {
      await SupabaseProvider.client.from('health_connections').upsert(
        <String, dynamic>{
          'user_id': userId,
          'provider': 'apple_health',
          'connected': true,
        },
        onConflict: 'user_id',
      );
    }
  }

  @override
  Future<HealthData> getTodayData() async {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    try {
      final List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: start,
        endTime: now,
      );
      int? steps;
      double? energy;
      for (final HealthDataPoint point in points) {
        if (point.type == HealthDataType.STEPS) {
          steps = (steps ?? 0) + (point.value as NumericHealthValue).numericValue.toInt();
        }
        if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          energy = (energy ?? 0) + (point.value as NumericHealthValue).numericValue.toDouble();
        }
      }
      return HealthData(steps: steps, activeEnergy: energy);
    } catch (_) {
      return const HealthData();
    }
  }

  @override
  Future<void> syncToday() async {
    final HealthData data = await getTodayData();
    final String? userId = SupabaseProvider.client.auth.currentUser?.id;
    if (userId == null || data.steps == null) {
      return;
    }
    await SupabaseProvider.client.from('health_metrics').upsert(<String, dynamic>{
      'user_id': userId,
      'metric_type': 'steps',
      'value': data.steps,
      'unit': 'count',
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'source': 'apple_health',
    });
  }
}

final healthServiceProvider = Provider<HealthService>((Ref ref) {
  if (!Platform.isIOS) {
    return StubHealthService();
  }
  return HealthKitHealthService();
});

final todayHealthProvider = FutureProvider<HealthData>((Ref ref) {
  return ref.watch(healthServiceProvider).getTodayData();
});
