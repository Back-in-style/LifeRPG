import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reminder_service_native.dart'
    if (dart.library.js_interop) 'reminder_service_web.dart';

/// Daily 리마인더 설정.
class ReminderSettings {
  const ReminderSettings(
      {this.enabled = false, this.hour = 21, this.minute = 0});

  final bool enabled;
  final int hour;
  final int minute;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, Object?> toJson() =>
      {'enabled': enabled, 'hour': hour, 'minute': minute};

  factory ReminderSettings.fromJson(Map<String, Object?> j) => ReminderSettings(
        enabled: j['enabled'] == true,
        hour: (j['hour'] as num?)?.toInt() ?? 21,
        minute: (j['minute'] as num?)?.toInt() ?? 0,
      );

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// 알림 예약·설정 저장 계약 (테스트에서 가짜로 override).
abstract interface class ReminderService {
  Future<ReminderSettings> load();

  /// 설정을 저장하고 알림을 예약/취소한다. 권한이 거부되면 false.
  Future<bool> apply(ReminderSettings settings);
}

final reminderServiceProvider =
    Provider<ReminderService>((_) => createReminderService());

/// 현재 리마인더 설정.
final reminderSettingsProvider = FutureProvider<ReminderSettings>(
    (ref) => ref.watch(reminderServiceProvider).load());
