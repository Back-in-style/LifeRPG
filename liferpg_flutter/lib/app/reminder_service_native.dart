import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder.dart';

ReminderService createReminderService() => LocalReminderService();

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
        '심기체연',
        '오늘 하루를 Claude와 정리하고 퀘스트를 확인하세요!',
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
