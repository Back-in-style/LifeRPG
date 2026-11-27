// 플랫폼별 저장소 열기: 네이티브는 Drift(SQLite), 웹은 메모리(새로고침하면 초기화).
export 'open_repository_native.dart'
    if (dart.library.js_interop) 'open_repository_web.dart';
