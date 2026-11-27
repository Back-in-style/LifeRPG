import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferpg/app/app.dart';
import 'package:liferpg/app/providers.dart';
import 'package:liferpg/app/reminder.dart';
import 'package:liferpg/data/in_memory_game_repository.dart';
import 'package:liferpg/domain/domain.dart';

/// 위젯 테스트 고정 시각.
final DateTime fixedNow = DateTime(2026, 11, 26, 9);

/// 알림 플러그인을 쓰지 않는 가짜 리마인더.
class FakeReminderService implements ReminderService {
  ReminderSettings saved = const ReminderSettings();

  @override
  Future<ReminderSettings> load() async => saved;

  @override
  Future<bool> apply(ReminderSettings settings) async {
    saved = settings;
    return true;
  }
}

/// [extra]: 추가 override (예: 디자인 안).
Widget testApp(InMemoryGameRepository repo,
        {List<Override> extra = const []}) =>
    ProviderScope(
      overrides: [
        ...extra,
        clockProvider.overrideWithValue(() => fixedNow),
        gameRepositoryProvider.overrideWith((ref) async => repo),
        reminderServiceProvider.overrideWithValue(FakeReminderService()),
      ],
      child: const LifeRpgApp(),
    );

InMemoryGameRepository newRepo([GameState? initial]) =>
    InMemoryGameRepository(initial: initial, clock: () => fixedNow);
