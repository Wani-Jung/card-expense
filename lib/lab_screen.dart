import 'package:flutter/material.dart';

import 'flavor.dart';
import 'law_notice.dart';
import 'layout.dart';
import 'menu_screen.dart';
import 'rural_quiz.dart';

/// 메뉴 > 실험실 (REQ-47·51): 안전 OX Quiz, 법령 Quiz 4종([kLawQuizzes] 순서). 항목을 누르면 그 화면, 돌아오면 설명을 다시 읽는다.
/// 법령 Quiz 는 부제 없이 제목만(2.0.3). `kShowRuralQuiz` 일 때만 (REQ-62 부터 스토어판에도), 맨 아래에 출처·고지 `LawSourceNotice`.
class LabScreen extends StatefulWidget {
  final String Function() quizSummary;
  final Future<void> Function() onQuiz;
  final Future<void> Function(LawQuiz) onLaw;
  const LabScreen({
    super.key,
    required this.quizSummary,
    required this.onQuiz,
    required this.onLaw,
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
        if (kShowRuralQuiz)
          for (final law in kLawQuizzes) ...[
            const Divider(height: 1, thickness: 0.5),
            ListTile(
              leading: Icon(law.icon),
              title: Text(law.title), // 부제 없이 제목만 (2.0.3), ListTile 이 줄 가운데에 맞춘다
              trailing: const Icon(Icons.chevron_right),
              onTap: _then(() => widget.onLaw(law)),
            ),
          ],
        if (kShowRuralQuiz) const LawSourceNotice(),
      ],
    ),
  );
}
