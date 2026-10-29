import 'package:card_expense/quiz.dart';
import 'package:card_expense/quiz_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuizBank _bank(int n) => QuizBank(1, '2026-10-31', [
  for (var i = 1; i <= n; i++)
    QuizQuestion(id: 'q$i', category: '분야', question: '문제 $i', answer: i.isOdd, explain: '해설 $i', basis: '근거 $i'),
]);

void main() {
  late QuizStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = QuizStore(await SharedPreferences.getInstance());
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('챌린지: 문항 수 비활성, 20문제 진행 → 결과·최고 기록, 지난 문제에 회차 1줄', (tester) async {
    phone(tester);
    final bank = _bank(25);
    await tester.pumpWidget(
      MaterialApp(
        home: QuizHomeScreen(store: store, bank: () async => bank),
      ),
    );
    await tester.tap(find.text('안전 OX 챌린지'));
    await tester.pumpAndSettle();

    // 활성 25문항: 20 만 고를 수 있음
    ButtonStyleButton btn(String n) =>
        tester.widget<ButtonStyleButton>(find.ancestor(of: find.text(n), matching: find.byType(OutlinedButton)));
    expect(btn('20').onPressed, isNotNull);
    expect(btn('30').onPressed, isNull);
    expect(btn('50').onPressed, isNull);

    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 20'), findsOneWidget);

    // ✕ → 확인 창, [계속하기] 면 그대로
    await tester.tap(find.byTooltip('그만두기'));
    await tester.pumpAndSettle();
    expect(find.text('챌린지를 그만둘까요? 기록은 남지 않아요'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.text('O'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('챌린지 결과'), findsOneWidget);
    expect(find.textContaining('/20 정답'), findsOneWidget);
    expect(find.text('최고 기록 달성!'), findsOneWidget);
    expect(find.textContaining('문항당 평균'), findsOneWidget);
    expect(store.runs, hasLength(1));
    expect(store.records.where((r) => r.src == kQuizChallenge), hasLength(20));

    await tester.tap(find.text('틀린 문제 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('해설 '), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 지난 문제 다시 보기: 챌린지는 회차 1줄, 누르면 그 회차 문제
    await tester.tap(find.text('지난 문제 다시 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('챌린지 20문제 · 정답률 '), findsOneWidget);
    expect(find.textContaining('내 답 '), findsNothing);
    await tester.tap(find.textContaining('챌린지 20문제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('내 답 '), findsWidgets);
    await tester.tap(find.text('틀린 문제만'));
    await tester.pumpAndSettle();
    expect(find.textContaining('챌린지 20문제'), findsOneWidget);
  });

  testWidgets('중간에 그만두면 기록이 남지 않음', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ChallengeStartScreen(store: store, bank: () async => _bank(25)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('O'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byTooltip('그만두기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('그만두기'));
    await tester.pumpAndSettle();
    expect(find.text('몇 문제에 도전할까요?'), findsOneWidget);
    expect(store.runs, isEmpty);
    expect(store.records, isEmpty);
  });

  testWidgets('한 문제 더 풀기: 오늘 다 풀면 소진 안내', (tester) async {
    phone(tester);
    final today = quizDay(DateTime.now());
    await store.record(QuizRecord(today, 'q1', true, true));
    await tester.pumpWidget(
      MaterialApp(
        home: QuizPracticeScreen(store: store, bank: () async => _bank(2)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('문제 2'), findsOneWidget);
    await tester.tap(find.text('O'));
    await tester.pumpAndSettle();
    expect(find.textContaining('정답은'), findsOneWidget);
    expect(store.records.last.src, kQuizExtra);
    await tester.tap(find.text('다음 문제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('오늘 준비된 문제를 모두 풀었어요!'), findsOneWidget);
  });
}
