import 'package:flutter/material.dart';

import 'layout.dart';
import 'quiz.dart';

/// 메뉴 > 설정. 지금은 '매일 OX 퀴즈' 스위치 하나 (기본 꺼짐).
/// 꺼져 있으면 앱을 열 때 자동으로 뜨는 오늘의 퀴즈만 안 나오고, 안전 OX Quiz 메뉴의 연습·챌린지는 그대로 쓸 수 있다.
class AppSettingsScreen extends StatefulWidget {
  final QuizStore quiz;
  const AppSettingsScreen({super.key, required this.quiz});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('설정')),
    body: ListView(
      padding: EdgeInsets.only(top: 4, bottom: listBottomPad(context)),
      children: [
        SwitchListTile(
          title: const Text('매일 OX 퀴즈'),
          subtitle: const Text('켜면 앱을 열 때 하루 한 번 안전 OX 퀴즈가 나옵니다.', style: TextStyle(fontSize: 12)),
          value: widget.quiz.dailyOn,
          onChanged: (v) async {
            await widget.quiz.setDailyOn(v);
            if (mounted) setState(() {});
          },
        ),
      ],
    ),
  );
}
