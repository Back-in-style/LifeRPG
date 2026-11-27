import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/reminder.dart';
import '../../app/theme.dart';
import '../common/async_view.dart';

/// 설정 — 매일 대화 리마인더.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _apply(ReminderSettings next) async {
    setState(() => _busy = true);
    bool granted;
    String? failure;
    try {
      granted = await ref.read(reminderServiceProvider).apply(next);
    } catch (e) {
      granted = false;
      failure = '알림 설정 실패: $e';
    }
    ref.invalidate(reminderSettingsProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      showSnack(context, failure);
    } else if (!granted) {
      showSnack(context, '알림 권한이 없어 리마인더를 켤 수 없어요.');
    } else if (next.enabled) {
      showSnack(context, '매일 ${next.timeLabel}에 알려 드릴게요.');
    } else {
      showSnack(context, '리마인더를 껐어요.');
    }
  }

  Future<void> _pickTime(ReminderSettings s) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
    );
    if (t == null || !mounted) return;
    await _apply(s.copyWith(hour: t.hour, minute: t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final reminder = ref.watch(reminderSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const _Header('디자인 (비교용 · 앱을 껐다 켜면 묵향으로 돌아감)'),
          const _StylePicker(),
          const _Header('알림'),
          AsyncView<ReminderSettings>(
            value: reminder,
            builder: (context, s) => Column(
              children: [
                SwitchListTile(
                  key: const Key('reminder_switch'),
                  secondary: const Icon(Icons.notifications_active),
                  title: const Text('매일 대화 리마인더'),
                  subtitle: const Text('매일 정해진 시각에 Claude와 하루 대화를 하라고 알려 줘요'),
                  value: s.enabled,
                  onChanged:
                      _busy ? null : (v) => _apply(s.copyWith(enabled: v)),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('알림 시각'),
                  trailing: Text(s.timeLabel,
                      style: Theme.of(context).textTheme.titleMedium),
                  enabled: !_busy,
                  onTap: () => _pickTime(s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.secondary)),
      );
}

class _StylePicker extends ConsumerWidget {
  const _StylePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appStyleProvider);
    return Column(
      children: [
        for (final s in AppStyle.values)
          ListTile(
            key: Key('style_${s.name}'),
            leading: Icon(s == current
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked),
            title: Text(s.label),
            subtitle: Text(s.desc),
            onTap: () => ref.read(appStyleProvider.notifier).state = s,
          ),
      ],
    );
  }
}
