import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/data.dart';
import 'package:liferpg/domain/domain.dart';

import 'repository_contract.dart';

void main() {
  runRepositoryContract(
      'InMemory', (clock) async => InMemoryGameRepository(clock: clock));

  test('초기 상태·이벤트 주입', () async {
    final now = DateTime(2026, 3, 2, 9);
    final init = GameState.initial(now).copyWith(nextQuestId: 42);
    final ev = LogEvent(ts: now, type: LogEvent.system, message: 'hi');
    final repo = InMemoryGameRepository(initial: init, events: [ev]);
    expect(await repo.load(), init);
    expect(await repo.recentEvents(), [ev]);
    await repo.commit(init.copyWith(nextQuestId: 43));
    expect(repo.commitCount, 1);
    expect((await repo.load()).nextQuestId, 43);
    await repo.close();
    expect(repo.load, throwsStateError);
  });
}
