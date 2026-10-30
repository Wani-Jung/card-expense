import 'package:card_expense/challenge_card.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/quiz_category_picker.dart';
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

  testWidgets('챌린지: 문항 수 비활성, 10문제 진행 → 결과·최고 기록, 지난 문제에 회차 1줄', (tester) async {
    phone(tester);
    final bank = _bank(25);
    await tester.pumpWidget(
      MaterialApp(
        home: QuizHomeScreen(store: store, bank: () async => bank),
      ),
    );
    await tester.tap(find.text('안전 OX 챌린지'));
    await tester.pumpAndSettle();

    // 활성 25문항: 10·20 만 고를 수 있음 → 10문제로 진행 (검증 내용은 20문제 때와 같음)
    ButtonStyleButton btn(String n) =>
        tester.widget<ButtonStyleButton>(find.ancestor(of: find.text(n), matching: find.byType(OutlinedButton)));
    expect(btn('20').onPressed, isNotNull);
    expect(btn('30').onPressed, isNull);
    expect(btn('50').onPressed, isNull);
    expect(btn('10').onPressed, isNotNull);
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 10'), findsOneWidget);

    // ✕ → 확인 창, [계속하기] 면 그대로
    await tester.tap(find.byTooltip('그만두기'));
    await tester.pumpAndSettle();
    expect(find.text('챌린지를 그만둘까요? 기록은 남지 않아요'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text('O'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('챌린지 결과'), findsOneWidget);
    expect(find.textContaining('/ 10 정답'), findsOneWidget);
    expect(find.text('최고 기록!'), findsOneWidget); // 첫 회차는 최고 기록
    expect(find.text('문항당'), findsOneWidget);
    expect(find.text('결과 이미지 공유'), findsOneWidget);
    expect(store.runs, hasLength(1));
    expect(store.records.where((r) => r.src == kQuizChallenge), hasLength(10));

    // 문제 전체 보기: 기본은 [전체] (10문제 모두), [틀린 문제만] 으로 거르기
    await tester.tap(find.text('문제 전체 보기'));
    await tester.pumpAndSettle();
    final all = tester.widget<QuizSelectChip>(find.widgetWithText(QuizSelectChip, '전체'));
    expect(all.selected, isTrue);
    await tester.tap(find.text('틀린 문제만'));
    await tester.pumpAndSettle();
    // 모두 O 로 답했으므로 틀린 건 정답이 X 인 문제(짝수 번호)뿐
    expect(find.textContaining('내 답 O → 정답 X'), findsWidgets);
    expect(find.textContaining('내 답 O → 정답 O'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 지난 문제 다시 보기: 챌린지는 회차 1줄, 누르면 그 회차 문제
    await tester.tap(find.text('지난 문제 다시 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('챌린지 10문제 · 정답률 '), findsOneWidget);
    expect(find.textContaining('내 답 '), findsNothing);
    await tester.tap(find.textContaining('챌린지 10문제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('내 답 '), findsWidgets);
    // 펼친 회차 안에도 [전체] [틀린 문제만] (기본 전체) — 위쪽 화면 칩 + 회차 칩 두 벌
    expect(find.text('틀린 문제만'), findsNWidgets(2));
    expect(tester.widget<QuizSelectChip>(find.widgetWithText(QuizSelectChip, '전체').last).selected, isTrue);
    await tester.tap(find.text('틀린 문제만').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('내 답 O → 정답 O'), findsNothing);
    await tester.tap(find.text('틀린 문제만').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('챌린지 10문제'), findsOneWidget);
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

  group('결과 카드', () {
    Future<void> pumpCard(WidgetTester tester, {required bool best, String? name}) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ChallengeResultCard(
                  run: const ChallengeRun(id: 'c1', at: 0, n: 20, correct: 17, ms: 134000),
                  name: name,
                  date: DateTime(2026, 10, 29),
                  newBest: best,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('최고 기록이면 띠, 이름·날짜, 등급·통계', (tester) async {
      await pumpCard(tester, best: true, name: '홍길동');
      expect(find.text('최고 기록!'), findsOneWidget);
      expect(find.text('홍길동 · 2026.10.29'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('17 / 20 정답'), findsOneWidget);
      expect(find.text('🦺 안전 베테랑'), findsOneWidget);
      expect(find.text('2분 14초'), findsOneWidget);
      expect(find.text('6.7초'), findsOneWidget);
      expect(find.text('Made by wani'), findsOneWidget);
      expect(find.text('한국농어촌공사 현장 안전 OX'), findsOneWidget);
      // 세로 2:3
      final size = tester.getSize(find.byType(ChallengeResultCard));
      expect(size.height / size.width, closeTo(1.5, 0.01));
    });

    testWidgets('최고 기록이 아니면 띠 없음, 이름이 비면 날짜만', (tester) async {
      await pumpCard(tester, best: false, name: '');
      expect(find.text('최고 기록!'), findsNothing);
      expect(find.text('2026.10.29'), findsOneWidget);
      await pumpCard(tester, best: false, name: null);
      expect(find.text('2026.10.29'), findsOneWidget);
    });
  });

  testWidgets('점수 기록 지우기: 확인 후 정답률 -, 지난 문제는 정답만·틀린 문제만 칩 숨김', (tester) async {
    phone(tester);
    final today = quizDay(DateTime.now());
    await store.record(QuizRecord(today, 'q1', true, true));
    await store.record(QuizRecord(today, 'q2', true, false, src: kQuizExtra));
    await tester.pumpWidget(
      MaterialApp(
        home: QuizHomeScreen(store: store, bank: () async => _bank(3)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);
    await tester.tap(find.text('점수 기록 지우기'));
    await tester.pumpAndSettle();
    expect(find.text(kClearScoresMessage), findsOneWidget);
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsNothing);
    expect(find.text('-'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // 푼 문제 수는 남음

    await tester.tap(find.text('지난 문제 다시 보기'));
    await tester.pumpAndSettle();
    expect(find.text('틀린 문제만'), findsNothing);
    expect(find.textContaining('내 답'), findsNothing);
    expect(find.text('정답 O'), findsOneWidget);
    expect(find.text('정답 X'), findsOneWidget);
  });
}
