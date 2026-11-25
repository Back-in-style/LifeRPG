# GAME_DESIGN — LifeRPG 게임 규칙·밸런스

> 작성: A2 (게임 디자인/밸런스). 기준: `docs/PLAN.md` §1 R1~R7, §5 MVP, `docs/SPEC_v1.md`(레거시 실제 동작).
> **모든 수치는 `lib/domain/game_config.dart`(`GameConfig`)에 있다.** 이 문서의 숫자와 config가 다르면 config가 맞고 이 문서를 고친다.
> 검증: `dart run tool/sim/main.dart` (`--md` 표 출력, `--post-mvp` R3/R4/R6 포함). 시뮬레이터 공식(`tool/sim/sim_engine.dart`)은 이 문서의 참고 구현이다.
> 표기: `GameConfig.xxx`는 `C.xxx`로 줄인다. `trunc` = 소수점 버림, `round` = 반올림(.5는 0에서 먼 쪽, Dart `round()`).

---

## 0. 요약

| 항목 | 규칙 |
|---|---|
| 스탯 | 7종 `힘·민첩·정신력·지구력·매력·집중·커뮤니케이션`. 기본 10 / 상한 30 (레거시 그대로) |
| 트리 | 7종 `physical·swim·mobility·recovery·study·social·routine` |
| XP (R1) | 측정형: 측정치 × 단위계수 (난이도 무관) / flat: 저장된 xp(난이도 배율 포함) → 원시 XP (완료 1회 최대 200) |
| 체감 (R2) | 트리별 하루 누적 원시 XP 구간 감쇠 + 같은 트리 반복 감쇠(0.7ⁿ⁻¹, 하한 0.4) |
| 레벨 (R7) | 트리 `need(L)=round(200×1.15^(L−1))`, 메인 = 1 + Σ(트리Lv − 1) |
| 스탯 성장 | 효과 XP × 0.01 × 카테고리 가중치 × 완화(40/(40+초과분)), 상한에서 멈춤 |
| 돌파 (R5) | 개인기록(PR) 1% 이상 갱신 시에만 상한 상승, 1회 최대 +max(20, cap×0.5) |
| 스트릭 | MVP 단순 스트릭(끊기면 1부터), XP 보너스 +1%/일 최대 +10% (MVP 포함 확정) |
| MVP 이후 | R3 디트레이닝, R4 피로도, R6 유예 스트릭 — §10 초안, config에 상수 있음 |

---

## 1. 스탯

### 1.1 목록
| 키 | 아이콘 | 출처 | 주로 오르는 카테고리 |
|---|---|---|---|
| 힘 | 💪 | 레거시 | Gym |
| 민첩 | ⚡ | 레거시 | Mobility, Swim |
| 정신력 | 🧠 | 레거시 | Recovery, Study, Routine, 전 카테고리 소량 |
| 지구력 | ❤️ | 레거시 | Swim, Gym |
| 매력 | ✨ | 신규 | Social, Routine |
| 집중 | 🎯 | 신규 | Study, Routine |
| 커뮤니케이션 | 💬 | 신규 | Social |

- 옛 영문 스탯 키(`charm/focus/communication`) 값은 가져오지 않는다 (결정 §13-4). 신규 3스탯은 항상 10/30에서 시작.
- 키는 한국어 문자열 그대로 저장한다 (레거시 JSON 키와 같음). 모델 enum을 만들면 `C.statKeys` 순서·문자열과 일치시킨다.
- 기본값 `C.defaultStatValue = 10`, 기본 상한 `C.defaultStatCap = 30`. 저장은 소수 3자리 (`C.statDecimals`).

### 1.2 등급 (레거시 그대로, **상한 기준**)
`grade(cap)`: cap ≤ 30 → D, ≤ 50 → C, ≤ 100 → B, ≤ 200 → A, 그 위 S (`C.gradeBands`, `C.topGrade`). 색은 `C.gradeColorsHex`.

---

## 2. 스킬 트리와 카테고리

### 2.1 트리 목록
| 키 | 이름 | 아이콘 | 의미 |
|---|---|---|---|
| physical | Physical | 🏋️ | 근력·맨몸 운동 (레거시 트리 키) |
| swim | Swim | 🌊 | 수영·유산소 |
| mobility | Mobility | 🤸 | 스트레칭·요가·가동성 |
| recovery | Recovery | 🛌 | 수면·휴식·회복 활동 |
| study | Study | 📚 | 공부·독서·업무 집중 |
| social | Social | 🤝 | 대화·연락·발표·모임 |
| routine | Routine | 🌙 | 기상·취침·식단·정리 같은 생활 루틴 |

### 2.2 카테고리 → 트리 / 스탯 가중치 / 기본 측정치
| 카테고리 | 트리 | 스탯 가중치 (합 1.0) | 기본 측정치 |
|---|---|---|---|
| Gym | physical | 힘 0.6, 지구력 0.3, 정신력 0.1 | strength |
| Swim | swim | 지구력 0.6, 민첩 0.2, 정신력 0.2 | swim_m |
| Mobility | mobility | 민첩 0.7, 지구력 0.1, 정신력 0.2 | duration_min |
| Recovery | recovery | 정신력 0.5, 지구력 0.3, 집중 0.2 | sleep_h |
| Study | study | 집중 0.7, 정신력 0.3 | pomodoro |
| Social | social | 커뮤니케이션 0.6, 매력 0.4 | count |
| Routine | routine | 정신력 0.4, 집중 0.3, 매력 0.3 | flat |
| Other | (없음) | 없음 | flat |

- `Gym/Swim/Mobility/Recovery/Other`는 레거시 키 그대로. `Study/Social/Routine`은 신규.
- **레거시와 다른 점**: 레거시는 Swim/Mobility/Recovery를 모두 `physical`로 보냈다. 새 앱은 각자 트리로 보낸다 (기존 퀘스트도 다음 완료부터 새 트리로 감). `Other`는 레거시처럼 트리 XP 없음, 명시 보상(rewards)만 적용.
- 재배치는 결정 사항(§13-1). 레거시 physical 누적 XP는 나누지 않고 physical에 남는다.
- 기본 측정치는 퀘스트 추가 폼의 기본 선택일 뿐, 사용자는 아무 측정치나 고를 수 있다 (예: Gym + reps, Swim + duration_min).
- 고강도 카테고리(`C.highIntensityCategories`) = Gym, Swim (R4용).

### 2.3 Daily 그룹 (레거시 분류 확장)
레거시 `get_daily_group`(SPEC_v1 §4.8) 순서를 유지하고 신규 카테고리 규칙을 키워드 판정 **앞에** 끼운다:
1. desc가 `"[Day A]"`로 시작 → `grp_dayA` / `"[Day B]"` → `grp_dayB`
2. desc가 `"[수영 데이]"`로 시작하거나 category == Swim → `grp_swim`
3. category == Gym → `grp_core`
4. (신규) category == Study → `grp_study`, Routine → `grp_routine`, Social → `grp_social`
5. title에 `C.studyKeywords` 포함 → `grp_study`, `C.routineKeywords` 포함 → `grp_routine`
6. 그 밖 → `grp_etc`

그룹 표시 순서·이름은 `C.dailyGroups` (레거시 7개 + `grp_social`을 `grp_etc` 앞에 추가).

---

## 3. 측정치와 XP (R1)

### 3.1 측정치 종류
| kind | 입력 필드 | 기본 XP 공식 | 예시 |
|---|---|---|---|
| flat | – | 퀘스트에 저장된 `xp` 그대로 | 레거시 퀘스트 전부, 체크형 루틴 |
| duration_min | minutes | 1.0 × 분 | 30분 → 30 |
| distance_km | km | 10 × km | 5km → 50 |
| swim_m | meters | 0.04 × m | 1500m → 60 |
| strength | sets, reps, weight_kg | 0.015 × (세트 × 횟수 × 무게) | 16세트×10회×40kg = 6400 → 96 |
| reps | sets, reps | 0.3 × (세트 × 횟수) | 5×20 → 30 |
| pomodoro | count | 12 × 개수 | 4개 → 48 |
| sleep_h | hours | 아래 §3.2 | 7.5h → 40 |
| steps | steps | 0.003 × 걸음 | 10000 → 30 |
| count | count | 10 × 횟수 | 연락 3명 → 30 |

계수는 `C.measureXpPerUnit`, 필드 키는 `C.measureFields`. 기준점: "보통 강도로 30분 ≈ 30 XP"(레거시 폼 기본 XP 30과 맞춤), 근력 1세션 ≈ 100 XP.

### 3.2 수면 XP
```
h = clamp(hours, 0, C.sleepMaxH=14)
h < 7        → 40 × h / 7
7 ≤ h ≤ 9    → 40
h > 9        → max(0, 40 − (h − 9) × 10)
```
예: 6h → 34.28, 8h → 40, 10h → 30, 13h → 0. (과수면은 보상하지 않는다.)

### 3.3 원시 XP
```
rawXp(kind, m, difficulty, {flatXp}):
  kind == flat : raw = min(200, max(1, flatXp))            # flatXp = quest.xp (추가할 때 난이도 배율 적용됨)
  그 밖(측정형): raw = min(C.maxRawXpPerCompletion=200, max(1, trunc(measureBaseXp(kind, m))))
                 # difficulty는 무시 (배율 항상 1.0)
flat 퀘스트 추가 시: quest.xp = max(1, trunc(base_xp × C.difficultyMultiplier[difficulty] ?? 1.0))
                     # Easy 0.7 / Normal 1.0 / Hard 1.5 — 레거시 adj_xp 그대로
```
- **난이도 배율은 flat 퀘스트에만** 적용한다 (사용자 결정 2026-11-25). 측정형은 측정치가 이미 양·강도를 담고 있으므로 Hard를 골라도 1.5배가 되지 않는다 → "항상 Hard" 악용 방지.
- flat 예: 30 Easy → 21, 30 Hard → 45, 3 Easy → 2 (레거시와 같음).
- 측정형 예: 근력 6400kg 볼륨 → 96 (Easy·Hard 모두 96). 수영 6000m → 240 → 상한 200.
- 측정형 퀘스트의 `difficulty` 필드는 표시·필터용으로만 남는다. `rawXp` 시그니처는 그대로 유지한다.

### 3.4 완료 1회의 XP 계산 순서
```
1. raw            (§3.3)
2. + C.prBonusXp(20)   측정치가 기록(record_key)에 연결돼 있고 PR을 세웠으면 (§7.3)
3. eff  = diminish(tree, rawToday[tree], raw)      (§4.1)
4. eff *= repeatMultiplier(countToday[tree])       (§4.2)
5. (MVP 이후) eff *= fatigueMultiplier(F), 휴식일 보너스   (§10.2)
6. eff *= 1 + streakBonus(streak)                  (§8)
7. xp = round(eff)   → tree.xp += xp, today_xp += xp
8. rawToday[tree] += raw, countToday[tree] += 1   (3·4단계에서 쓴 값은 더하기 전 값)
9. 스탯 상승 (§6)
```
`rawToday`, `countToday`는 트리별 오늘 누적치로 **영속 저장**해야 한다 (앱을 껐다 켜도 같은 날이면 유지, 날짜가 바뀌면 0).

---

## 4. 체감 감소와 일일 상한 (R2)

### 4.1 누적 구간 감쇠
트리 t의 구간 목록 `bands = C.treeDiminishingBands[t] ?? C.defaultDiminishingBands`. 오늘 이미 쌓인 원시 XP `a = rawToday[t]`, 새로 더할 `raw`, `b = a + raw`:
```
diminish(t, a, raw) = Σ_band  max(0, min(b, band.upTo) − max(a, 이전 band.upTo)) × band.rate
                      (마지막 band.upTo 이상은 0배 = 일일 상한)
```
| 트리 | 구간 | 하루 효과 XP 최대 |
|---|---|---|
| 기본 (swim·mobility·study·social) | 0–80 ×1.0, 80–200 ×0.25 | 80 + 30 = **110** |
| physical | 0–100 ×1.0, 100–200 ×0.25 | 100 + 25 = **125** |
| recovery, routine | 0–60 ×1.0, 60–100 ×0.5 | 60 + 20 = **80** |

### 4.2 반복 감쇠
같은 날 같은 트리의 n번째 완료(1부터): `repeatMultiplier(n) = max(C.repeatDecayFloor=0.4, C.repeatDecay^(n−1))` → 1.0, 0.7, 0.49, 0.4, 0.4…
(PLAN R2 "같은 날 같은 트리 반복 시 감쇠". 큰 세션 하나를 잘게 쪼개 기록하는 것보다 실제로 한 번 하는 것이 낫게 만든다.)

### 4.3 예시
- 성실: 근력 1세션 raw 96 → physical 0→96, 전부 1.0배 → 96. 손실 0.
- 몰아치기: 근력 2세션 (볼륨 8000kg, raw 120씩)
  - 1회차: 0→120 = 100×1.0 + 20×0.25 = 105, ×1.0 → 105
  - 2회차: 120→240 = [120,200] 80×0.25 = 20, ×0.7 → 14
  - 합 119 / 원시 240 (50%)
- 몰아치기: 수영 2000m 2회 (80씩): 80 + ([80,160] 80×0.25)×0.7 = 80 + 14 = 94 / 160 (59%)
- 수면 8h + 낮잠 같은 recovery 2회 (40 + 40): 40 + (20×1.0 + 20×0.5)×0.7 = 61 / 80

---

## 5. 레벨 (R7 로그형 곡선)

### 5.1 트리 레벨
```
need(L)      = round(C.treeLevelBaseXp=200 × C.treeLevelGrowth=1.15^(L−1))     # L → L+1 필요 XP
cumXp(L)     = Σ_{l=1}^{L−1} need(l)                                           # L 도달 누적 XP
level(total) = 1에서 시작해 left ≥ need(level)인 동안 left −= need, level++   (최대 C.treeLevelMax=99)
xp_in_level  = left,  xp_next = need(level)                                    # 레거시 필드명 유지
```
누적 XP가 지수로 늘어 **레벨 ≈ log₁.₁₅(1 + 0.15·XP/200)** — 초반 빠르고 후반 완만. Lv2 = 200 XP (레거시와 같음).

| Lv | need | 누적 | | Lv | need | 누적 |
|---|---|---|---|---|---|---|
| 1 | 200 | 0 | | 12 | 930 | 4870 |
| 2 | 230 | 200 | | 15 | 1415 | 8101 |
| 3 | 264 | 430 | | 20 | 2846 | 17642 |
| 5 | 350 | 998 | | 25 | 5725 | 36832 |
| 8 | 532 | 2213 | | 30 | 11515 | 75432 |
| 10 | 704 | 3357 | | | | |

트리 하루 최대 효과 XP가 110~125(+스트릭 10%)이므로 매일 상한을 채워도 한 트리 Lv20은 약 4.3개월, Lv25는 약 9개월 걸린다.

### 5.2 메인 레벨
```
main_level = 1 + Σ_t (level_t − 1)
```
- 레거시 `max(1, Σ level)`은 트리가 1개일 때 이 식과 같다 (트리 1개 Lv5 → 메인 5). 트리 7개가 전부 Lv1이면 메인 1.
- 여러 트리를 고르게 키울수록 메인 레벨이 빨리 오른다 (각 트리 초반 레벨이 싸기 때문) → "균형 잡힌 자기계발"을 보상.
- 예: physical 11, swim 6, mobility 6, recovery 10, study 9, social 3, routine 9 → 1 + (10+5+5+9+8+2+8) = 48.

### 5.3 레거시 레벨/XP 변환
레거시 곡선 `need_old(L) = 200 + 80(L−1)` (SPEC_v1 §3.3). 임포트할 때 트리마다:
```
(L_old, in_old, next_old) = legacyLevel(xp_old)
xp_preserve = cumXp(L_old) + floor(in_old / next_old × need(L_old))    # 같은 레벨·같은 진행률
xp_new      = max(xp_old, xp_preserve)
```
- **레벨도 XP도 줄지 않는다.** 새 곡선이 Lv25까지는 더 싸서 대부분 XP를 그대로 쓰고 레벨이 조금 오른다. 아주 높은 레벨(≈Lv26 이상)만 XP를 늘려서 레벨을 지킨다.

| 레거시 XP | 레거시 레벨 | 새 XP | 새 레벨 |
|---|---|---|---|
| 200 | Lv2 (0/280) | 200 | Lv2 (0/230) |
| 1280 | Lv5 (0/520) | 1280 | Lv5 (282/350) |
| 4680 | Lv10 (0/920) | 4680 | Lv11 (619/809) |
| 10000 | Lv14 (1160/1240) | 10000 | Lv16 (484/1627) |
| 30000 | Lv26 (1000/2200) | 45549 | Lv26 (2992/6584) |

- 저장된 `level/xp_in_level/xp_next`는 믿지 않고 `xp`로 다시 계산한다 (레거시도 physical은 매번 재계산).
- `trees`에 physical 외 트리가 있으면: 키가 `C.treeKeys`에 있으면 같은 규칙으로 변환, 없으면 버리고 로그에 남긴다 (레거시에서 갱신 안 되던 유령 레벨 → 메인 레벨이 레거시보다 낮아질 수 있음, 임포트 요약에 표시).
- 나머지 6개 트리는 xp 0으로 만든다. `main_level`은 저장값을 버리고 §5.2로 다시 계산한다.
- `today_xp/today_date`: 임포트 날짜가 `today_date`와 같으면 그대로, 다르면 0. `rawToday/countToday`는 0으로 시작.

---

## 6. 스탯 성장

### 6.1 자동 성장 (명시 보상이 없는 퀘스트)
```
soft(cur) = C.statSoftK / (C.statSoftK + max(0, cur − C.defaultStatValue))     # K=40
delta_s   = xp × C.statGainPerXp(0.01) × weight[category][s] × soft(cur_s)
(new, applied) = clampToCap(cur_s, delta_s, cap_s)                            # 레거시 clamp_to_cap
stats[s] = round(new, 3)
```
예: 근력 xp 101(스트릭 +5%) → 힘 10에서 +101×0.01×0.6×1.0 = **+0.606**, 힘 30에서 soft=40/60 → **+0.404**, 힘이 상한 30이면 +0 (돌파 필요).

### 6.2 명시 보상 (레거시 rewards)
- 퀘스트에 `rewards`(스탯별 수치)가 하나라도 0이 아니면 자동 성장 대신 **명시 보상만** 적용한다 (레거시 퀘스트 호환).
- 명시 보상에도 R2를 적용한다: `delta_s = rewards[s] × (eff₄ / raw)` (eff₄ = §3.4의 4단계 값, 트리 없는 `Other`는 비율 1). 음수 보상은 레거시처럼 그대로 허용(비율 적용 안 함).
- `cur > cap`일 때 양수 보상이 cap으로 끌어내리는 레거시 동작은 **고친다**: 새 앱은 `cur ≥ cap`이면 양수 delta를 무시하고 값을 유지한다 (임포트 데이터에만 생길 수 있는 상태).

### 6.3 상한
스탯은 상한(cap)을 넘지 않는다. 상한은 **돌파(§7)로만** 오른다. 신규 3스탯은 10/30에서 시작.

---

## 7. 돌파 = PR 갱신 (R5)

### 7.1 기록(Record)
- 기록 키 `record_key`(사용자 정의 문자열, 예: `"스쿼트 1RM(kg)"`, `"1500m 수영(초)"`), 방향 `higher`/`lower`, 연결 스탯 하나.
- 측정치가 있는 완료마다 해당 기록의 값(예: 최고 무게, 거리, 기록 시간)을 남길 수 있다. `best`는 방향에 맞는 역대 최고값.

### 7.2 PR 판정
```
best == null          → PR 아님 (기준 기록 등록만), 단 돌파 퀘스트에 target이 있으면 value가 target 달성 시 PR
higher:  value ≥ best × (1 + C.prMinImprovementRatio)      # 1% 이상 개선
lower:   value ≤ best × (1 − C.prMinImprovementRatio)
```
예: 스쿼트 best 80kg → 80×1.01 = 80.8kg 이상만 PR (80.7 ✗, 80.8 ✓). 1500m 600초 → 600×0.99 = 594초 이하만 PR (594.1 ✗, 594 ✓). best가 없고 target도 없으면 기록만 등록되고 PR이 아니다 (시뮬 `isPr(value, null)` = false, 시뮬은 모든 스탯의 기준 기록을 100으로 미리 등록해 두므로 이 분기를 타지 않는다).

### 7.3 돌파 퀘스트
- type/category = `"돌파"` (레거시 문자열), 필드: `unlock_stat`, `unlock_to`(요청 상한, 기본 cap+20 — 레거시 폼과 같음), 신규 `record_key`, `record_direction`, `target`(선택).
- 완료 시 측정값 입력이 **필수**. 성공 조건 = 그 값이 PR (§7.2). 성공하면:
```
maxStep = max(C.breakthroughMinStep=20, cap × C.breakthroughMaxStepRatio=0.5)
new_cap = min(unlock_to, cap + maxStep)     # unlock_to > cap 이어야 추가 가능 (레거시 검증)
```
  예: 힘 cap 30, unlock_to 50 → 50 (C등급). cap 50, unlock_to 100 → min(100, 75) = 75. cap 200, unlock_to 300 → 300.
- 실패해도 퀘스트는 DONE(레거시 동일), 기록은 저장(best보다 좋으면 best 갱신은 PR일 때만).
- 돌파 퀘스트는 트리 XP·스탯 보상이 없다 (레거시 동일). 일반 퀘스트가 PR을 세우면 원시 XP +`C.prBonusXp`(20).
- **레거시에서 가져온 ACTIVE 돌파 퀘스트**(record_key 없음): 완료 시 값 입력 없이 레거시 규칙(unlock_to > cap이면 성공)을 쓰되 `maxStep` 제한은 적용한다 (결정 §13-3). R5의 유일한 예외이며 새로 만드는 돌파 퀘스트에는 적용하지 않는다.

---

## 8. 스트릭 (MVP: 단순 스트릭)

- 활동일 = 그 날 퀘스트를 하나라도 완료(돌파 포함)한 날. 첫 완료 시점에 갱신:
```
last_active == 오늘      → 변화 없음
last_active == 어제      → streak += 1
그 밖(null 포함)          → streak = 1
last_active = 오늘
```
- 날짜 변경(dailyRollover) 때 `last_active < 어제`이면 `streak = 0` (표시용).
- 보너스 (**MVP 포함 확정**): `streakBonus = min(C.streakBonusMax=0.10, streak × C.streakBonusPerDay=0.01)`, §3.4 6단계에 곱한다. 예: 스트릭 5 → ×1.05, 30 → ×1.10.
- 레거시 `streak_days`/`last_active_date`는 쓰인 적이 없어 0/null → 임포트 후 0에서 시작.
- 유예일·감소형 리셋(R6)은 MVP 이후 (§10.3).

---

## 9. 업적

### 9.1 판정 시점·방식
- 완료 직후, 날짜 변경 직후(스트릭), 임포트 직후 1회 판정. 해금은 되돌리지 않는다. 데이터 정의는 `C.achievements` (id/name/desc/icon/kind/threshold).
- 판정 종류(`kind`): `completions`(누적 완료 수), `main_level`, `breakthrough_success`(돌파 성공 누적), `stat_at_cap`, `grade`(threshold = `C.gradeOrder` 인덱스, 어느 스탯 상한이든 그 등급 이상), `streak`, `tree_level`, `all_trees_level`, `pr_count`.

### 9.2 레거시 8종 — 개선 사항
| id | 이름 | 레거시 조건 (SPEC §4.7) | 새 조건 |
|---|---|---|---|
| first_quest | 첫 발걸음 | 현재 DONE 수 ≥ 1 | **누적 완료 수** ≥ 1 |
| first_levelup | 각성 | main_level ≥ 2 | 같음 (새 메인 레벨 식) |
| quest_10 | 모험가 | 현재 DONE 수 ≥ 10 (Daily 리셋·삭제로 줄어드는 버그) | **누적 완료 수** ≥ 10 (Daily 반복 완료도 매번 1) |
| quest_50 | 영웅 | 현재 DONE 수 ≥ 50 | **누적 완료 수** ≥ 50 |
| first_breakthrough | 한계 돌파 | DONE 돌파 퀘스트 존재 (실패해도 해금) | **돌파 성공** ≥ 1. desc "첫 돌파에 성공했다!" |
| stat_max_d | D랭크 달성 → **한계 도달** | 아무 스탯 값 ≥ 상한 | 같음. 이름만 실제 의미대로 바꿈 (id 유지) |
| level_5 | 숙련자 | main_level ≥ 5 | 같음 |
| level_10 | 전문가 | main_level ≥ 10 | 같음 |

- 누적 완료 수 `total_completions`는 프로필 카운터(완료마다 +1, 삭제해도 안 줄어듦). 임포트 초기값 = `max(현재 DONE 수, log.json의 "퀘스트 완료: " 이벤트 수)`.
- 레거시 `achievements.json`의 `unlocked`는 그대로 유지 (새 조건으로 다시 잠그지 않음).

### 9.3 신규 16종
| id | 이름 | 조건 |
|---|---|---|
| quest_100 / quest_500 | 베테랑 / 전설 | 누적 완료 100 / 500 |
| level_25 / level_50 | 달인 / 그랜드마스터 | 메인 Lv 25 / 50 |
| rank_c / rank_b / rank_a / rank_s | C~S랭크 달성 | 아무 스탯 상한 등급 C / B / A / S |
| breakthrough_5 | 벽 깨기 | 돌파 성공 5회 |
| streak_7 / streak_30 / streak_100 | 일주일 연속 / 한 달 연속 / 백일 | 스트릭 7 / 30 / 100 |
| tree_10 | 한 우물 | 트리 하나 Lv10 |
| all_rounder | 만능 | 모든 트리 Lv5 이상 |
| pr_1 / pr_20 | 신기록 / 기록 사냥꾼 | 누적 PR 1 / 20 |

시뮬 기준 성실 유저 90일 = 24종 중 15~16종, 게으름 4종, 몰아치기 12종.

---

## 10. MVP 이후 공식 초안 (config에 상수 있음, `--post-mvp`로 시뮬)

### 10.1 R3 디트레이닝
```
스탯 s가 마지막으로 오른 날 last_gain_s, 역대 최고 peak_s
floor_s = max(C.defaultStatValue, peak_s × C.detrainFloorRatio=0.85)
매일 rollover: (오늘 − last_gain_s) > C.detrainGraceDays=7 이고 cur > floor 이면
    cur ← cur − C.detrainDailyRate(0.02) × (cur − floor)
```
- 바닥으로 지수 접근 → 완만하고, 최고치의 85% 밑으로는 안 떨어진다. 상한(cap)은 내려가지 않는다.
- 예: 힘 40(peak 40) → floor 34. 8일째부터 40 → 39.88 → 39.76…, 30일 감소 후 34 + 6×0.98³⁰ ≈ **37.3**, 무한히 쉬어도 34.

### 10.2 R4 피로도 / 회복
```
rollover:  F ← F × C.fatigueDailyRetain(0.6)
완료:      F += xp × C.fatigueLoadPerXp[tree]   (physical 0.25, swim 0.2, mobility 0.02)
           수면 7~9h 기록 → F −= C.fatigueSleepRelief(15)
           그 밖 recovery 완료 → F −= xp × C.fatigueRecoveryReliefPerXp(0.3)
           F = clamp(F, 0, 100)
XP 배율:   fatigueMultiplier(F) = 1 − 0.4 × clamp((F − 40) / (100 − 40), 0, 1)
휴식일:    오늘 고강도(Gym/Swim) 완료가 아직 없으면 recovery·mobility XP × C.restDayRecoveryBonus(1.2)
```
- 예: 근력 2세션(xp ≈119) + 수영 2회(≈94) → F = 29.75 + 18.8 ≈ 48.5 → 다음 완료 배율 1 − 0.4×8.5/60 = **0.943**. 다음날 48.5×0.6 ≈ 29.
- 매일 같은 고강도(하루 +48.5)를 쉬지 않고 하면 정상상태 F = 48.5/0.4 → 100 (배율 0.6). 좋은 수면(−15)을 같이 하면 F ≈ 84 (배율 0.71).

### 10.3 R6 관대한 스트릭
```
첫 완료 시 gap = 오늘 − last_active
gap == 1                                  → streak += 1
gap == 2 이고 빠진 날이 속한 주(월~일)에 유예 미사용 → 유예 사용, streak += 1   (C.streakGraceDaysPerWeek=1)
그 밖                                       → streak = floor(streak × C.streakBreakRetainRatio=0.5) + 1
```
- 예: 스트릭 20에서 하루 빠짐(그 주 유예 남음) → 21. 이틀 빠짐 → floor(20×0.5)+1 = **11**.
- 시뮬에서 성실 유저 최대 스트릭 53 → 88 (8% 결석이 전부 유예로 흡수).

---

## 11. 밸런스 목표와 시뮬레이션 리포트

### 11.1 목표 (`tool/sim/main.dart`가 PASS/FAIL 판정)
| # | 목표 | 의도 |
|---|---|---|
| G1 | 성실 유저 90일 메인 Lv 40~55 | 3개월 꾸준히 하면 "레벨 40대" 체감 |
| G2 | 몰아치기: 원시 XP가 성실 이상인데 총 XP ≤ 성실×0.7, 메인 Lv ≤ 성실×0.8 | 같은 양을 몰아서 하면 확실히 손해 |
| G3 | R2 효율(효과/원시) 몰아치기 ≤ 70%, 성실 ≥ 95% | 체감 감소는 성실 유저를 건드리지 않는다 |
| G4 | 게으름 메인 Lv 3~12, 총 XP ≤ 성실×0.15 | 조금만 해도 진전은 보이되 격차는 크다 |
| G5 | 성실 유저 90일 안에 돌파 ≥ 1, 상한 C등급 이상 | 3개월 안에 첫 상한 돌파 경험 |
| G6 | 성실 유저 트리 최고 Lv ≤ 15 | 로그 곡선 — 한 트리가 폭주하지 않는다 |

### 11.2 페르소나와 가정
- **성실**: 매일(8% 결석) 수면 7~8h, 루틴 체크(flat 30), 가동성 15분, 근력 월·수·금(16세트×10회×무게), 수영 화·토 1500m, 학업 평일 4뽀모, 소셜 수·토 2회. 주간 원시 XP ≈ 1,290.
- **게으름**: 하루 30% 확률로 수면 6h·근력 절반·2뽀모·가동성 10분·루틴 중 1~2개.
- **몰아치기**: 토·일만. 수면 9h, 루틴, 근력 2세션(성실 세션의 1.25배 볼륨), 수영 2000m×2, 5뽀모×2, 가동성 60분, 소셜 5회. 주간 원시 XP ≈ 1,390 (성실보다 많음).
- 돌파 모델(시뮬 전용 가정): 스탯별 "실제 능력"이 그 스탯이 오른 **날**마다 0.6% 성장(같은 날 여러 번 해도 1회), 상한에 닿은 스탯은 주 1회 돌파 시도(unlock_to = cap+20), 능력이 지난 성공 기록보다 1% 이상 높으면 성공.
- seed 42 고정, 결정적.

### 11.3 결과 (MVP 모드, `dart run tool/sim/main.dart --md`, 측정형 난이도 배율 1.0 반영)
##### 시점별 요약
| 페르소나 | 일 | 메인Lv | 총XP | 원시XP | R2효율 | 스탯합 | 최고 스탯 | 최대 상한 | 돌파 | 스트릭(최대) | 업적 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 성실 | 7 | 5 | 1330 | 1284 | 100% | 82.9 | 정신력 13.7 | 30.0 | 0 | 7(7) | 5 |
| 성실 | 14 | 11 | 2743 | 2572 | 100% | 95.9 | 정신력 17.3 | 30.0 | 0 | 14(14) | 7 |
| 성실 | 30 | 20 | 5795 | 5358 | 100% | 121.6 | 정신력 24.2 | 30.0 | 0 | 1(28) | 8 |
| 성실 | 60 | 35 | 11588 | 10815 | 99% | 164.6 | 정신력 35.2 | 50.0 | 2 | 23(28) | 13 |
| 성실 | 90 | 48 | 17796 | 16589 | 99% | 204.9 | 정신력 45.3 | 50.0 | 4 | 53(53) | 15 |
| 게으름 | 7 | 1 | 188 | 184 | 100% | 71.9 | 힘 10.6 | 30.0 | 0 | 4(4) | 1 |
| 게으름 | 14 | 1 | 402 | 394 | 100% | 74.0 | 정신력 11.2 | 30.0 | 0 | 3(4) | 2 |
| 게으름 | 30 | 2 | 708 | 697 | 100% | 77.0 | 힘 12.0 | 30.0 | 0 | 1(4) | 3 |
| 게으름 | 60 | 5 | 1098 | 1083 | 100% | 80.7 | 힘 12.9 | 30.0 | 0 | 1(4) | 4 |
| 게으름 | 90 | 5 | 1490 | 1471 | 100% | 84.4 | 정신력 13.9 | 30.0 | 0 | 2(4) | 4 |
| 몰아치기 | 7 | 2 | 962 | 1400 | 68% | 79.5 | 지구력 12.2 | 30.0 | 0 | 2(2) | 3 |
| 몰아치기 | 14 | 7 | 1925 | 2806 | 68% | 88.6 | 지구력 14.3 | 30.0 | 0 | 2(2) | 4 |
| 몰아치기 | 30 | 14 | 3851 | 5634 | 67% | 106.0 | 지구력 18.1 | 30.0 | 0 | 2(2) | 6 |
| 몰아치기 | 60 | 26 | 7706 | 11362 | 67% | 137.8 | 지구력 25.1 | 30.0 | 0 | 2(2) | 8 |
| 몰아치기 | 90 | 38 | 12044 | 17928 | 66% | 169.6 | 지구력 31.5 | 50.0 | 2 | 1(2) | 12 |

##### 90일차 트리 레벨
| 페르소나 | Physical | Swim | Mobility | Recovery | Study | Social | Routine |
|---|---|---|---|---|---|---|---|
| 성실 | 11 | 6 | 6 | 10 | 9 | 3 | 9 |
| 게으름 | 3 | 1 | 1 | 2 | 1 | 1 | 2 |
| 몰아치기 | 9 | 8 | 6 | 5 | 7 | 5 | 4 |

##### 90일차 스탯 (값/상한)
| 페르소나 | 힘 | 민첩 | 정신력 | 지구력 | 매력 | 집중 | 커뮤니케이션 |
|---|---|---|---|---|---|---|---|
| 성실 | 30.0/50 | 21.8/30 | 45.3/50 | 36.2/50 | 19.7/30 | 38.7/50 | 13.3/30 |
| 게으름 | 13.8/30 | 10.5/30 | 13.9/30 | 13.0/30 | 10.9/30 | 12.4/30 | 10.0/30 |
| 몰아치기 | 25.4/30 | 23.3/30 | 30.0/50 | 31.5/50 | 16.8/30 | 25.6/30 | 17.1/30 |

##### 메인 레벨 추이 (10일 간격)
| 페르소나 | D10 | D20 | D30 | D40 | D50 | D60 | D70 | D80 | D90 |
|---|---|---|---|---|---|---|---|---|---|
| 성실 | 6 | 14 | 20 | 26 | 31 | 35 | 40 | 45 | 48 |
| 게으름 | 1 | 1 | 2 | 3 | 5 | 5 | 5 | 5 | 5 |
| 몰아치기 | 2 | 9 | 14 | 17 | 23 | 26 | 32 | 33 | 38 |

##### 목표 판정
- [PASS] G1 성실 메인Lv 40~55 (실제 48)
- [PASS] G2 몰아치기: 원시XP ≥ 성실인데 총XP ≤ 성실×0.7, 메인Lv ≤ 성실×0.8 (원시 17928 vs 16589, XP 68%, Lv 38 vs 48)
- [PASS] G3 R2효율 몰아치기 ≤ 70% (실제 66%), 성실 ≥ 95% (실제 99%)
- [PASS] G4 게으름 메인Lv 3~12, 총XP ≤ 성실×0.15 (실제 Lv 5, XP 8%)
- [PASS] G5 성실 돌파 ≥ 1, 최대 상한 C등급 이상 (실제 돌파 4, 상한 50.0)
- [PASS] G6 성실 트리 최고 Lv ≤ 15 (실제 11)

##### MVP 이후 모드 (`--post-mvp`, R3+R4+R6) 90일차
| 페르소나 | 메인Lv | 총XP | 원시XP | R2효율 | 스탯합 | 최대 상한 | 돌파 | 스트릭(최대) | 업적 |
|---|---|---|---|---|---|---|---|---|---|
| 성실 | 50 | 19025 | 16589 | 99% | 211.6 | 50 | 4 | 88(88) | 16 |
| 게으름 | 5 | 1604 | 1471 | 100% | 83.3 | 30 | 0 | 3(7) | 5 |
| 몰아치기 | 38 | 11729 | 17928 | 66% | 166.9 | 50 | 2 | 2(3) | 12 |

G1~G6 모두 PASS (몰아치기 총 XP 성실 대비 62%).

### 11.4 해석
- **성실**: 90일 메인 Lv 48, 트리 Lv 3~11, 4개 스탯이 첫 돌파로 C등급(상한 50). 체감 감소 손실 1% — 성실 유저는 R2를 거의 느끼지 않는다. 스트릭 보너스(+10%)로 원시보다 총 XP가 7% 많다.
- **몰아치기**: 원시 XP를 성실보다 8% **더** 쌓았지만 총 XP 68%, 메인 Lv 38 (성실의 79%). 손실의 대부분은 physical(근력 2세션 → 50% 효율)과 같은 트리 반복. 스트릭이 2를 넘지 못해 보너스도 거의 없다. 돌파는 2회 — 능력 성장이 "훈련한 날 수"에 묶여 있기 때문.
- **게으름**: 메인 Lv 5, 총 XP 성실의 8%. 진전은 보이지만(첫 레벨업·업적 4개) 격차가 크다.
- 메인 레벨 격차(79%)가 XP 격차(68%)보다 작은 것은 로그 곡선(R7)의 의도된 압축이다. 몰아치기를 더 불리하게 하려면 레벨이 아니라 R2 구간(`defaultDiminishingBands`의 0.25)이나 `repeatDecay`를 조정한다.
- 시뮬레이터에 없는 것: 명시 보상(rewards), 일반 퀘스트 PR 보너스, Other 카테고리. P3에서 실제 사용 패턴으로 다시 맞춘다.

### 11.5 튜닝 이력
| 단계 | 변경 | 결과 |
|---|---|---|
| 1 | 구간 100×1.0/250×0.4, 반복 감쇠 없음, need = 150×1.13^(L−1) | 성실 Lv61, 몰아치기 Lv52 (85%), 몰아치기 효율 77% → G1·G2·G3 실패 |
| 2 | 기본 구간 80/200 ×0.3, physical 100/200, 반복 감쇠 0.7 추가 | 몰아치기 효율 65%, XP 67% |
| 3 | 레벨 base 200(레거시 Lv2 = 200과 일치), growth 1.15 | 성실 Lv48, 몰아치기 Lv37 → 전부 PASS |
| 4 | (사용자 결정 7) 측정형 퀘스트 난이도 배율 제거. 몰아치기 페르소나의 Hard를 "1.25배 볼륨·수영 2000m×2"로 바꿔 원시 XP를 성실 이상으로 유지. 2구간 배율 0.3 → 0.25 | 성실 Lv48, 몰아치기 Lv38 (XP 68%, R2효율 66%) → 전부 PASS |

---

## 12. 구현 메모 (INTERFACES.md 반영용)

엔진(A3)·데이터(A4)가 저장·계산해야 하는 상태:

| 위치 | 필드 | 용도 |
|---|---|---|
| Profile | `stats`, `stat_caps` (7키) | §1, §6 |
| Profile | `trees.<t>.xp` (7트리, level/xp_in_level/xp_next는 파생값) | §5 |
| Profile | `today_date`, `today_xp`, **`raw_today[t]`, `count_today[t]`** | §3.4, §4 — 같은 날 앱 재시작해도 유지 |
| Profile | `streak_days`, `last_active_date` (레거시 키 재사용), (R6) `grace_week_used` | §8, §10.3 |
| Profile | **`total_completions`**, **`breakthrough_success_count`**, **`pr_count`** | §9 |
| Profile | (R3) `stat_peak[s]`, `stat_last_gain_date[s]` / (R4) `fatigue` | §10 — MVP에서 컬럼만 만들어 두면 이후 마이그레이션 불필요 |
| Quest | `measure_kind` (기본 `flat`), 신규 카테고리 키 | §3 |
| Quest(돌파) | `unlock_stat`, `unlock_to` + `record_key`, `record_direction`, `target` | §7 |
| Completion(신규) | quest_id, ts, 측정값 map, raw, eff, xp, tree, stat 변화, PR 여부 | 로그·통계·되돌리기 근거 |
| Record(신규) | record_key, direction, stat, best, 이력(값, ts, completion_id) | §7 |

- 엔진 함수 제안: `rawXp(kind, measure, difficulty, flatXp)`, `diminish(tree, rawToday, raw)`, `repeatMultiplier(n)`, `levelFromXp(total)`, `mainLevel(levels)`, `convertLegacyTreeXp(xp)`, `statSoftFactor(cur)`, `clampToCap`, `isPr(value, best, direction)`, `breakthroughNewCap(cap, unlockTo)`, `streakBonus(streak)`. 시뮬 구현(`tool/sim/sim_engine.dart`)과 이름·결과를 맞추면 시뮬을 회귀 테스트 기준으로 쓸 수 있다.
- 키 문자열(스탯·트리·카테고리·측정치·업적 kind)은 `GameConfig`의 리스트가 정본. enum을 만들면 `name`/`key`가 이 문자열과 같아야 한다.

---

## 13. 결정 사항 (사용자 결정, 2026-11-25)

이전 미결 7건은 모두 결정됐다.

| # | 항목 | 결정 | 반영 위치 |
|---|---|---|---|
| 1 | 레거시 Swim/Mobility/Recovery 카테고리 | 각자 새 트리로 재배치. 기존 physical XP는 physical에 그대로 둔다 | §2.2 |
| 2 | 레거시 레벨 변환 | max 규칙 (레벨·XP 둘 다 줄지 않음) | §5.3 |
| 3 | 가져온 ACTIVE 돌파 퀘스트 | 레거시 규칙으로 완료 허용 (unlock_to > cap이면 성공), maxStep 제한 적용 | §7.3 |
| 4 | 옛 영문 7스탯 값 | 버리고 신규 3스탯은 기본값 10. `C.legacyEnglishStatAliases`는 **미사용**(참고용) | §1.1, config 주석 |
| 5 | 업적 변경 | 누적 완료 수 기준, first_breakthrough는 성공 시만, stat_max_d 이름 "한계 도달" | §9.2 |
| 6 | 스트릭 XP 보너스 | MVP에 포함 (+1%/일, 최대 +10%) | §8 |
| 7 | 측정형 퀘스트 난이도 배율 | **적용하지 않음 (항상 1.0)**. 난이도 배율은 flat 퀘스트에만 | §3.3, `rawXp` |
