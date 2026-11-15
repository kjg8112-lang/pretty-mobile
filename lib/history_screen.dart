import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'transcript.dart';

/// 세션(명령 + 출력) 목록. 카드 안의 글자를 길게 눌러 전체 선택/복사 가능
class HistoryScreen extends StatelessWidget {
  final Transcript transcript;
  const HistoryScreen({super.key, required this.transcript});

  @override
  Widget build(BuildContext context) {
    final blocks = transcript.blocks.where((b) => b.text.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('세션 기록'),
        actions: [
          IconButton(
            tooltip: '전체 복사',
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: transcript.fullText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('전체 기록을 복사했습니다.')),
              );
            },
          ),
        ],
      ),
      body: blocks.isEmpty
          ? const Center(child: Text('아직 기록이 없습니다.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: blocks.length,
              itemBuilder: (context, i) {
                final b = blocks[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.command.isEmpty ? '(시작)' : '\$ ${b.command}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '이 세션 복사',
                              icon: const Icon(Icons.content_copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: b.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('세션을 복사했습니다.'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        // SelectableText: 길게 눌러 단어 선택, 메뉴에서 "전체 선택"/"복사"
                        SelectableText(
                          b.output.toString().trimRight(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
