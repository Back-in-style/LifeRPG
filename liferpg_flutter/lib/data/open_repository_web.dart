import 'game_repository.dart';
import 'in_memory_game_repository.dart';

/// 웹 미리보기용: 메모리 저장소 (새로고침하면 초기화).
Future<GameRepository> openGameRepository() async => InMemoryGameRepository();
