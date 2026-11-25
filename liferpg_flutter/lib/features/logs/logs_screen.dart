import 'package:flutter/material.dart';

/// 로그 — 이벤트 히스토리. (A5가 구현)
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그')),
      body: const Center(child: Text('로그가 없습니다')),
    );
  }
}
