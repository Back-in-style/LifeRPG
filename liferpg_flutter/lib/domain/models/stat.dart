import '../game_config.dart';
import 'json_helpers.dart';

/// 스탯 하나의 상태 (GAME_DESIGN §1, §6, §10.1).
class StatState {
  const StatState({
    required this.key,
    this.value = GameConfig.defaultStatValue,
    this.cap = GameConfig.defaultStatCap,
    this.peak = GameConfig.defaultStatValue,
    this.lastGainDate,
  });

  /// 기본값(10/30)으로 시작하는 스탯.
  const StatState.initial(this.key)
      : value = GameConfig.defaultStatValue,
        cap = GameConfig.defaultStatCap,
        peak = GameConfig.defaultStatValue,
        lastGainDate = null;

  /// `GameConfig.statKeys` 중 하나.
  final String key;

  /// 현재 값 (소수 3자리 반올림 저장).
  final double value;

  /// 상한. 돌파로만 상승 (R5).
  final double cap;

  /// 역대 최고값 (R3 디트레이닝 바닥 계산용).
  final double peak;

  /// 마지막 상승 날짜 `YYYY-MM-DD` (R3).
  final String? lastGainDate;

  bool get atCap => value >= cap;

  StatState copyWith({
    String? key,
    double? value,
    double? cap,
    double? peak,
    Object? lastGainDate = unset,
  }) =>
      StatState(
        key: key ?? this.key,
        value: value ?? this.value,
        cap: cap ?? this.cap,
        peak: peak ?? this.peak,
        lastGainDate: identical(lastGainDate, unset)
            ? this.lastGainDate
            : lastGainDate as String?,
      );

  Map<String, Object?> toJson() => {
        'key': key,
        'value': value,
        'cap': cap,
        'peak': peak,
        'last_gain_date': lastGainDate,
      };

  factory StatState.fromJson(Map<String, Object?> json) {
    final value = jDouble(json['value'], GameConfig.defaultStatValue);
    return StatState(
      key: jString(json['key']),
      value: value,
      cap: jDouble(json['cap'], GameConfig.defaultStatCap),
      peak: jDoubleOrNull(json['peak']) ?? value,
      lastGainDate: jStringOrNull(json['last_gain_date']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StatState &&
      other.key == key &&
      other.value == value &&
      other.cap == cap &&
      other.peak == peak &&
      other.lastGainDate == lastGainDate;

  @override
  int get hashCode => Object.hash(key, value, cap, peak, lastGainDate);

  @override
  String toString() => 'StatState($key $value/$cap)';
}
