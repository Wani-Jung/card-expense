import 'dart:convert';
import 'dart:io';

import 'package:card_expense/budget.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/lab_screen.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/notice_dialog.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/rural_quiz.dart';
import 'package:card_expense/rural_quiz_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-51: 요약표 만원 정수 표시 + '(반올림)' 안내, 법령 Quiz 4종(2027 기준), 문제 아래 '근거 · 개정 시점' 한 줄.
/// 이 파일은 CI 에서 스토어 채널 define 으로도 돈다 (실험실 노출 기대값이 채널마다 갈림).
void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('card_expense/native'),
      (_) async => null,
    );
  });

  group('D 만원 정수 표시', () {
    test('예시·0·초과·반올림 경계, 천원·원은 그대로', () {
      const m = MoneyUnit.man;
      expect(money(342500, m), '34');
      expect(money(345000, m), '35');
      expect(money(344999, m), '34'); // 경계
      expect(money(85000, m), '9');
      expect(money(12345000, m), '1,235');
      expect(money(0, m), '0');
      expect(money(4999, m), '0');
      expect(remainingIn(-82000, m), '초과 8');
      expect(remainingIn(-345000, m), '초과 35');
      expect(remainingIn(null, m), '-');
      // 칸마다 반올림, 합계 보정 없음: 4.5 / 4.5 / 9 → 5 / 5 / 9
      expect([money(45000, m), money(45000, m), money(90000, m)], ['5', '5', '9']);
      // 천원·원은 REQ-50 그대로
      expect(money(342500, MoneyUnit.thousand), '343');
      expect(money(342500, MoneyUnit.won), '342,500');
      // 입력·미리 채움은 반올림하지 않은 원래 값
      expect(moneyInputText(342500, m), '34.25');
      expect(moneyInputText(350000, m), '35');
      expect(parseMoney('34.25', m), 342500);
      expect(showsRounding(MoneyUnit.man), isTrue);
      expect(showsRounding(MoneyUnit.thousand), isTrue);
      expect(showsRounding(MoneyUnit.won), isFalse);
    });

    Future<Store> pumpMonth(WidgetTester tester, {String unit = 'man'}) async {
      phone(tester);
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'card_digits': '0000',
        'sender_number': '1588-1600',
        'update_checked_at': now.millisecondsSinceEpoch,
        'quiz_last_day_v1': quizDay(now),
        'notif_asked_v1': true,
        'money_unit_v1': unit,
        'budgets_v1': jsonEncode({
          Budgets.keyOf(now): {'total': 1234500, 'car': 342500},
        }),
      });
      final store = await Store.open();
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('표는 정수, 편집 시트는 원래 값(34.25)으로 미리 채움', (tester) async {
      final store = await pumpMonth(tester);
      expect(find.text('123'), findsWidgets); // 합계 수립 123.45 → 123
      expect(find.text('34'), findsWidgets); // 차량비 수립 34.25 → 34
      expect(find.text('34.25'), findsNothing);
      await tester.tap(find.text('34').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '34.25'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '34.56');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(store.loadBudgets().forMonth(DateTime.now()).car, 345600);
      expect(find.text('35'), findsWidgets);
    });

    testWidgets("'(반올림)' 은 만원·천원에서만, 누르면 안내 (확인 버튼 하나)", (tester) async {
      await pumpMonth(tester);
      expect(find.byTooltip(kRoundingTooltip), findsOneWidget);
      await tester.tap(find.byTooltip(kRoundingTooltip));
      await tester.pumpAndSettle();
      expect(find.text(keepWords(kRoundingNote)), findsOneWidget);
      expect(find.descendant(of: find.byType(NoticeDialog), matching: find.byType(FilledButton)), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text(keepWords(kRoundingNote)), findsNothing);

      for (final (label, shown) in [('천원', true), ('원', false), ('만원', true)]) {
        await tester.tap(find.textContaining('단위: '));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(find.byTooltip(kRoundingTooltip), shown ? findsOneWidget : findsNothing, reason: label);
      }
    });
  });

  group('A 문제 파일 (2027 기준 4개 법령)', () {
    final raw = File('quiz/rural_questions.json').readAsStringSync();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final bank = RuralBank.parse(raw)!;

    test('그룹별 문항 수·id 접두어·amended', () {
      expect(j['version'], greaterThanOrEqualTo(2));
      expect(bank.groups.map((g) => g.name), ['농어촌정비법', '건설기술 진흥법', '국가계약법', '건축법']);
      final expected = {'농어촌정비법': ('r', 200), '건설기술 진흥법': ('c', 92), '국가계약법': ('k', 115), '건축법': ('b', 127)};
      for (final MapEntry(key: g, value: (p, n)) in expected.entries) {
        final qs = bank.questions.where((q) => q.group == g).toList();
        expect(qs, hasLength(n), reason: g);
        expect(qs.every((q) => q.id.startsWith(p)), isTrue, reason: g);
        expect(qs.where((q) => q.amended.isNotEmpty), isNotEmpty, reason: g);
        expect(bank.only(g)!.questions, hasLength(n));
        expect(bank.only(g)!.groups.single.name, g);
      }
      expect(bank.questions.map((q) => q.id).toSet(), hasLength(534));
      // '조 개정 이력'·법령 원문은 넣지 않음
      final q0 = (j['questions'] as List).first as Map<String, dynamic>;
      expect(q0.keys, isNot(contains('history')));
      expect(raw.contains('조 개정 이력'), isFalse);
      // 시행 전 개정 예시가 있음
      expect(bank.questions.any((q) => q.amended.contains('시행')), isTrue);
    });

    test('fromJson: amended 있음 / 없음', () {
      final a = RuralQuestion.fromJson({
        'id': 'r1',
        'group': '농어촌정비법',
        'category': '총칙',
        'type': 'ox',
        'question': 'Q',
        'answer': true,
        'explain': '',
        'basis': '법 제2조제3호',
        'amended': '2024.1.2 개정(해당 항)',
      });
      expect(a.amended, '2024.1.2 개정(해당 항)');
      expect(a.basisLine, '법 제2조제3호 · 2024.1.2 개정(해당 항)');
      final b = RuralQuestion.fromJson({
        'id': 'r2',
        'group': '농어촌정비법',
        'category': '총칙',
        'type': 'ox',
        'question': 'Q',
        'answer': false,
        'explain': '',
        'basis': '법 제3조',
      });
      expect(b.amended, '');
      expect(b.basisLine, '법 제3조');
      final c = RuralQuestion.fromJson({
        'id': 'r3',
        'group': '농어촌정비법',
        'category': '총칙',
        'type': 'ox',
        'question': 'Q',
        'answer': false,
      });
      expect(c.basisLine, '');
    });
  });

  group('B 문제 화면 근거·개정 한 줄', () {
    RuralQuestion q({String basis = '', String amended = '', bool choice = false}) => RuralQuestion(
      id: 'r1',
      group: '농어촌정비법',
      category: '총칙',
      question: '문제 문장',
      choices: choice ? const ['가', '나', '다', '라'] : const [],
      answer: choice ? 2 : 1,
      explain: '해설',
      basis: basis,
      amended: amended,
    );

    Future<void> pumpCard(WidgetTester tester, RuralQuestion question) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [RuralQuestionCard(question: question, onAnswer: (_) async {}, onNext: () {}, onStop: () {})],
            ),
          ),
        ),
      );
    }

    testWidgets('문제와 O/X 사이, 아이콘·13·회색', (tester) async {
      await pumpCard(tester, q(basis: '법 제90조', amended: '2026.10.27 개정 · 2027.10.28 시행'));
      final line = find.text(keepWords('법 제90조 · 2026.10.27 개정 · 2027.10.28 시행'));
      expect(line, findsOneWidget);
      expect(find.byIcon(Icons.event_note), findsOneWidget);
      final t = tester.widget<Text>(line);
      expect(t.style!.fontSize, 13);
      expect(t.style!.fontWeight, anyOf(isNull, FontWeight.normal));
      final qy = tester.getBottomLeft(find.text(keepWords('문제 문장'))).dy;
      final ly = tester.getTopLeft(line).dy;
      final oy = tester.getTopLeft(find.text('O')).dy;
      expect(ly, greaterThan(qy));
      expect(oy, greaterThan(tester.getBottomLeft(line).dy));
    });

    testWidgets('객관식도 보기 위, amended 가 비면 근거만', (tester) async {
      await pumpCard(tester, q(basis: '법 제2조제3호', choice: true));
      final line = find.text(keepWords('법 제2조제3호'));
      expect(line, findsOneWidget);
      expect(tester.getTopLeft(find.text(keepWords('가'))).dy, greaterThan(tester.getBottomLeft(line).dy));
    });

    testWidgets('근거·개정 둘 다 비면 줄 숨김', (tester) async {
      await pumpCard(tester, q());
      expect(find.byIcon(Icons.event_note), findsNothing);
      expect(find.byType(RuralBasisLine), findsOneWidget); // 위젯은 있지만 빈 칸
    });

    testWidgets('답한 뒤 해설 아래 근거: 줄은 그대로, 지난 문제에도 한 줄', (tester) async {
      final question = q(basis: '법 제3조', amended: '1995.1.5 제정 이후 개정 없음');
      await pumpCard(tester, question);
      await tester.tap(find.text('O'));
      await tester.pumpAndSettle();
      expect(find.text('근거: 법 제3조'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RuralRecordTile(record: const RuralRecord('2026-11-16', 'r1', 1, true), question: question),
          ),
        ),
      );
      final line = find.text(keepWords('법 제3조 · 1995.1.5 제정 이후 개정 없음'));
      expect(line, findsOneWidget);
      expect(tester.getTopLeft(line).dy, greaterThan(tester.getBottomLeft(find.text(keepWords('문제 문장'))).dy));
    });
  });

  group('C 그룹별 기록', () {
    test('기록 분리, 정비법은 예전 rural_* 키 그대로, 점수 지우기는 그 그룹만', () async {
      final old = jsonEncode(const RuralRecord('2026-11-10', 'r002', 1, true).toJson());
      SharedPreferences.setMockInitialValues({
        'rural_log_v1': [old],
        'rural_challenge_size_v1': 30,
      });
      final prefs = await SharedPreferences.getInstance();
      final laws = {for (final l in kLawQuizzes) l.group: RuralStore(prefs, l)};
      final rural = laws['농어촌정비법']!;
      expect(identical(rural.quiz, kRuralLaw), isTrue);
      expect(rural.kLog, 'rural_log_v1');
      expect(rural.solvedCount, 1); // 예전 기록 그대로 읽힘
      expect(rural.challengeSize, 30);
      expect(RuralStore(prefs).solvedCount, 1); // 기본값도 정비법

      final ctech = laws['건설기술 진흥법']!;
      expect(ctech.solvedCount, 0);
      expect(ctech.challengeSize, kChallengeDefaultSize);
      await ctech.record(const RuralRecord('2026-11-16', 'c001', 0, false));
      await laws['건축법']!.record(const RuralRecord('2026-11-16', 'b001', 1, true));
      expect(ctech.percent, 0);
      expect(laws['건축법']!.percent, 100);
      expect(rural.solvedCount, 1);
      expect(laws['국가계약법']!.solvedCount, 0);
      expect({for (final l in laws.values) l.kLog}, hasLength(4));

      await ctech.clearScores();
      expect(ctech.percent, isNull);
      expect(ctech.solvedCount, 1);
      expect(rural.percent, 100);
      expect(laws['건축법']!.percent, 100);
      expect(prefs.getStringList('rural_log_v1'), [old]);
    });

    test('문제 고르기는 그 법령 문항만 (가방도 따로)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bank = RuralBank.parse(File('quiz/rural_questions.json').readAsStringSync())!;
      for (final l in kLawQuizzes) {
        final b = bank.only(l.group)!;
        final s = RuralStore(prefs, l);
        for (var i = 0; i < 5; i++) {
          expect((await s.next(b))!.group, l.group);
        }
        expect(RuralStore.challengeSet(b, 10).every((q) => q.group == l.group), isTrue);
      }
    });

    testWidgets("실험실: 법령 Quiz 4개 '… Quiz' (스토어판은 4개 다 숨김)", (tester) async {
      phone(tester);
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: LabScreen(
            quizSummary: () => '',
            lawSummary: (l) => '${l.group} 요약',
            onQuiz: () async {},
            onLaw: (l) async => opened.add(l.group),
          ),
        ),
      );
      final names = ['농어촌정비법 Quiz', '건설기술 진흥법 Quiz', '국가계약법 Quiz', '건축법 Quiz'];
      expect(find.text('안전 OX Quiz'), findsOneWidget);
      for (final n in names) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text('농어촌정비법 퀴즈'), findsNothing);
      // REQ-62: 스토어판에도 보임
      for (var i = 1; i < names.length; i++) {
        expect(tester.getTopLeft(find.text(names[i])).dy, greaterThan(tester.getTopLeft(find.text(names[i - 1])).dy));
      }
      await tester.tap(find.text('국가계약법 Quiz'));
      await tester.pumpAndSettle();
      expect(opened, ['국가계약법']);
    });

    testWidgets('법령 화면 제목·챌린지 이름·결과 카드 제목은 그룹 이름', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final law = kLawQuizzes[1];
      final bank = RuralBank.parse(File('quiz/rural_questions.json').readAsStringSync())!.only(law.group)!;
      await tester.pumpWidget(
        MaterialApp(
          home: RuralQuizHomeScreen(store: RuralStore(prefs, law), bank: () async => bank),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('건설기술 진흥법 Quiz'), findsOneWidget);
      expect(find.text('건설기술 진흥법 챌린지'), findsOneWidget);
      expect(law.title, '건설기술 진흥법 Quiz');
      expect(
        ruralShareText(law, const ChallengeRun(id: 'c', at: 0, n: 10, correct: 8, ms: 1)),
        startsWith('건설기술 진흥법 Quiz 80%'),
      );
    });
  });
}
