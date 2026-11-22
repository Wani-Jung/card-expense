import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'layout.dart';
import 'rural_quiz.dart';

/// 법령 Quiz 출처·고지 (REQ-62, Google Play '정부 정보를 전달하는 앱' 정책).
/// 실험실(법령 고르는 곳)과 법령 Quiz 첫 화면 맨 아래에 작게. 출처를 누르면 국가법령정보센터를 브라우저로 연다.
const kLawSourceUrl = 'https://www.law.go.kr';
const kLawSourceLine = '법령 원문 출처: 국가법령정보센터(law.go.kr)';
const kLawDisclaimer = '이 앱은 정부·공공기관과 관련 없는 개인 앱이며, 문제는 학습용으로 법적 효력이 없어요.';

/// 'yyyy-mm-dd' → 'yyyy.mm.dd' (형식이 다르면 그대로)
String lawBaseDateText(String updated) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(updated) ? updated.replaceAll('-', '.') : updated;

Future<String>? _baseDate;

/// 내장 문제 파일(`quiz/rural_questions.json`)의 기준일(updated). 못 읽으면 빈 문자열
Future<String> lawQuizBaseDate() => _baseDate ??= rootBundle
    .loadString(kRuralAsset)
    .then((t) => lawBaseDateText(((jsonDecode(t) as Map<String, dynamic>)['updated'] as String?) ?? ''))
    .catchError((_) => '');

class LawSourceNotice extends StatelessWidget {
  /// 테스트용. 없으면 문제 파일에서 읽는다
  final Future<String>? baseDate;
  final Future<void> Function(Uri)? open;
  const LawSourceNotice({super.key, this.baseDate, this.open});

  static const _grey = Color(0xFF80868B);

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: baseDate ?? lawQuizBaseDate(),
    builder: (context, snap) {
      final date = snap.data ?? '';
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => (open ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(Uri.parse(kLawSourceUrl)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  kLawSourceLine,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1F3A68),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            Text(
              keepWords([kLawDisclaimer, if (date.isNotEmpty) '기준일: $date'].join(' ')),
              style: const TextStyle(fontSize: 11, height: 1.5, color: _grey),
            ),
          ],
        ),
      );
    },
  );
}
