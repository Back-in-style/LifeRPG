import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// TODO(메인): pubspec dependencies에 `timezone: ^0.9.4`(이미 lock에 있는 전이 의존성)를
// 추가하면 아래 ignore 두 줄을 지운다.
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily 리마인더 설정.
class ReminderSettings {
  const ReminderSettings({this.enabled = false, this.hour = 21, this.minute = 0});

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

/// flutter_local_notifications 구현. 설정은 앱 문서 디렉터리의 JSON 파일에 둔다.
class LocalReminderService implements ReminderService {
  LocalReminderService();

  static const int _notificationId = 1001;
  static const String _fileName = 'reminder_settings.json';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<void> _init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    _initialized = true;
  }

  @override
  Future<ReminderSettings> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const ReminderSettings();
      final j = jsonDecode(await f.readAsString());
      if (j is Map<String, Object?>) return ReminderSettings.fromJson(j);
    } catch (_) {
      // 깨진 설정 파일은 기본값으로.
    }
    return const ReminderSettings();
  }

  @override
  Future<bool> apply(ReminderSettings s) async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    var granted = true;
    if (s.enabled) {
      // Android 13+ 알림 권한.
      granted = await android?.requestNotificationsPermission() ?? true;
    }
    await _plugin.cancel(_notificationId);
    if (s.enabled && granted) {
      await _plugin.zonedSchedule(
        _notificationId,
        'LifeRPG',
        '오늘의 Daily 퀘스트를 확인하세요!',
        _nextInstance(s.hour, s.minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Daily 리마인더',
            channelDescription: '매일 정해진 시각에 Daily 퀘스트를 알려 줍니다.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
    final saved = s.enabled && !granted ? s.copyWith(enabled: false) : s;
    final f = await _file();
    await f.writeAsString(jsonEncode(saved.toJson()));
    return granted;
  }

  /// 다음 hh:mm (로컬). 기기 시간대 이름을 얻는 패키지가 없으므로 UTC로 환산해
  /// 예약한다 → 서머타임이 없는 지역(한국)에서는 매일 같은 로컬 시각이다.
  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return tz.TZDateTime.from(at, tz.UTC);
  }
}

final reminderServiceProvider =
    Provider<ReminderService>((_) => LocalReminderService());

/// 현재 리마인더 설정.
final reminderSettingsProvider = FutureProvider<ReminderSettings>(
    (ref) => ref.watch(reminderServiceProvider).load());
