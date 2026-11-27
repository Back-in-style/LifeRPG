import 'reminder.dart';

ReminderService createReminderService() => WebReminderService();

/// 웹 미리보기용: 알림 없음, 설정은 메모리에만 둔다.
class WebReminderService implements ReminderService {
  ReminderSettings _settings = const ReminderSettings();

  @override
  Future<ReminderSettings> load() async => _settings;

  @override
  Future<bool> apply(ReminderSettings settings) async {
    _settings = settings;
    return true;
  }
}
