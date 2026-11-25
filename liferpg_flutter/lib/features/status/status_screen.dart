import 'package:flutter/material.dart';

/// 상태창 — 메인 레벨, 스탯 카드, 스킬 트리. (A5가 구현)
class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LifeRPG')),
      body: const Center(child: Text('상태창 (구현 예정)')),
    );
  }
}
