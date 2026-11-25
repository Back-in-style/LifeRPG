import 'package:flutter/material.dart';

/// 퀘스트 — 필터 칩, Daily 그룹, 추가/상세/완료(측정치 입력). (A5가 구현)
class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('퀘스트')),
      body: const Center(child: Text('퀘스트 (구현 예정)')),
      floatingActionButton: FloatingActionButton(
        onPressed: null,
        child: const Icon(Icons.add),
      ),
    );
  }
}
