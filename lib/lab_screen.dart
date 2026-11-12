import 'package:flutter/material.dart';

import 'flavor.dart';
import 'layout.dart';
import 'menu_screen.dart';

/// 메뉴 > 실험실 (REQ-47): 안전 OX Quiz, 농어촌정비법 퀴즈. 항목을 누르면 그 화면, 돌아오면 설명을 다시 읽는다.
/// 농어촌정비법 퀴즈는 스토어판에서 숨긴다 (`kShowRuralQuiz`, REQ-49).
class LabScreen extends StatefulWidget {
  final String Function() quizSummary, ruralSummary;
  final Future<void> Function() onQuiz, onRural;
  const LabScreen({
    super.key,
    required this.quizSummary,
    required this.ruralSummary,
    required this.onQuiz,
    required this.onRural,
  });

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  VoidCallback _then(Future<void> Function() f) => () async {
    await f();
    if (mounted) setState(() {});
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('실험실')),
    body: ListView(
      padding: EdgeInsets.only(bottom: listBottomPad(context)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            keepWords('카드 관리 말고 업무에 도움이 될 만한 기능을 시험해 보는 곳이에요.'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
          ),
        ),
        ListTile(
          leading: const QuizIcon(),
          title: const Text('안전 OX Quiz'),
          subtitle: Text(widget.quizSummary(), style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _then(widget.onQuiz),
        ),
        if (kShowRuralQuiz) ...[
          const Divider(height: 1, thickness: 0.5),
          ListTile(
            leading: const Icon(Icons.agriculture_outlined),
            title: const Text('농어촌정비법 퀴즈'),
            subtitle: Text(widget.ruralSummary(), style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _then(widget.onRural),
          ),
        ],
      ],
    ),
  );
}
