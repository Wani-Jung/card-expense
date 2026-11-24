import 'dart:convert';
import 'dart:io';

import 'package:card_expense/budget.dart';
import 'package:card_expense/import_screen.dart';
import 'package:card_expense/ingest.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/native.dart';
import 'package:card_expense/quiz_screens.dart';
import 'package:card_expense/rural_quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// REQ-66 (불러오기 결과 줄바꿈·닫기 버튼) + REQ-67 (법령 개정 표시 정확성, 화면 문구 정리)
void main() {
  group('REQ-67 1부 법령 Quiz 개정 표시', () {
    final j = jsonDecode(File('quiz/rural_questions.json').readAsStringSync()) as Map<String, dynamic>;
    final qs = (j['questions'] as List).cast<Map<String, dynamic>>();

    test("문제 파일 어디에도 '개정 없음'이 없음 (날짜를 모르면 근거 조문만)", () {
      expect(File('quiz/rural_questions.json').readAsStringSync().contains('개정 없음'), isFalse);
      final q = qs.firstWhere((q) => (q['question'] as String).contains('시·도지사에게만 신고할 수 있다'));
      expect(q['basis'], contains('제22조의3'));
      expect(q.containsKey('amended'), isFalse);
      expect(RuralQuestion.fromJson(q).basisLine, q['basis']); // '법 제22조의3' 만
    });

    test('건진법 제22조의3 해설 주어: 장관이 공정건설지원센터를 설치·운영', () {
      final q = qs.firstWhere((q) => (q['question'] as String).contains('시·도지사에게만 신고할 수 있다'));
      expect(q['explain'], contains('장관은 신고 처리를 위해 공정건설지원센터를 설치·운영할 수 있어요.'));
      expect(File('quiz/rural_questions.json').readAsStringSync().contains('공정건설지원센터를 둘 수 있어요'), isFalse);
    });

    test("도구도 '이후 개정 없음'을 만들지 않음", () {
      for (final f in ['tools/law_quiz/amend.py', 'tools/law_quiz/xl.py']) {
        expect(File(f).readAsStringSync().contains("'제정(전부개정) 이후 개정 없음'"), isFalse, reason: f);
        expect(File(f).readAsStringSync().contains("' 이후 개정 없음'"), isFalse, reason: f);
      }
    });
  });

  group('REQ-66 C 줄 나열·버튼', () {
    test('resultLines: 항목별 한 줄, 0건은 뺌', () {
      expect(resultLines(fresh: 0, dup: 5, ignored: 4), ['이미 있는 문자 5건', '무시했던 문자 4건']);
      expect(resultLines(fresh: 2, dup: 0, done: true), ['새로 넣은 문자 2건']);
      expect(resultLines(fresh: 2, dup: 1), ['새로 넣을 문자 2건', '이미 있는 문자 1건']);
      expect(resultLines(fresh: 0, dup: 0, rejected: 1, done: true), ['승인 문자 아님 1건']);
    });

    testWidgets("미리보기: 넣을 게 없으면 '닫기' (결과 팝업 없이), 제목 길게 누르면 진단", (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var closed = 0;
      ImportPreview? confirmed;
      final p = const ImportPreview(InboxScan([], ['im/chat: 15881600']), IngestReport(fresh: [], dup: 5, ignoredHits: [], rejected: []), unique: 5, bySender: 5);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ImportRangePanel(
              preview: (_, _) async => p,
              clock: () => DateTime(2026, 11, 22),
              onConfirm: (r) => confirmed = r,
              onNothing: () => closed++,
            ),
          ]),
        ),
      ));
      await tester.tap(find.text('이 기간 문자 확인'));
      await tester.pumpAndSettle();
      expect(find.text('이미 있는 문자 5건'), findsOneWidget);
      expect(find.text('불러오기'), findsNothing);
      await tester.longPress(find.text('이 기간 승인 문자 5건'));
      await tester.pumpAndSettle();
      expect(find.text('불러오기 진단'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '닫기'));
      expect(closed, 1);
      expect(confirmed, isNull);
    });
  });

  group('REQ-67 2부', () {
    test('단위 메뉴 순서: 원 / 천원 / 만원 (저장은 이름이라 그대로 읽힘)', () {
      expect(MoneyUnit.values.map((u) => u.label), ['원', '천원', '만원']);
      expect(MoneyUnit.byName('man'), MoneyUnit.man);
      expect(MoneyUnit.byName(null), MoneyUnit.won);
    });

    test('반올림 안내 문구', () {
      expect(kRoundingNote.split('\n').take(2), ['칸마다 따로 반올림해서', '더한 값과 합계가 1 정도 다를 수 있어요.']);
    });

    test("가맹점 이름: 띄어쓰기 기준 줄바꿈 + 최대 2줄 말줄임", () {
      final t = merchantText('좋은아침페스츄리 홍성내포점') as Text;
      expect(t.data, keepWords('좋은아침페스츄리 홍성내포점'));
      expect(t.maxLines, 2);
      expect(t.overflow, TextOverflow.ellipsis);
      expect((merchantText('') as Text).data, keepWords('(가맹점 미상)'));
    });

    testWidgets('분야별 정답률: 큰 분야는 소제목으로 한 번만', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: categoryScoreRows([
            (label: '서류·절차 · 안전관리체제', correct: 1, n: 2),
            (label: '현장 안전기준 · 전기작업', correct: 1, n: 1),
            (label: '서류·절차 · 위험성평가', correct: 2, n: 2),
          ])),
        ),
      ));
      expect(find.text('서류·절차'), findsOneWidget);
      expect(find.text('현장 안전기준'), findsOneWidget);
      expect(find.text('안전관리체제'), findsOneWidget);
      expect(find.text('위험성평가'), findsOneWidget);
      expect(find.textContaining('서류·절차 · '), findsNothing);
    });
  });
}
