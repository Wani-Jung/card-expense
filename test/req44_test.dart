import 'package:card_expense/menu_screen.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/quiz_category_picker.dart';
import 'package:card_expense/quiz_screens.dart';
import 'package:card_expense/quiz_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-44: 개인정보처리방침 확인 팝업, 매일 OX 스위치 이동, 점수 기록 지우기 문구·되돌리기,
/// 선택 칩 색, 지난 문제 묶음·꼬리표 없음·[해설] 말풍선.
QuizBank _bank(int n) => QuizBank(1, '2026-10-31', [
  for (var i = 1; i <= n; i++)
    QuizQuestion(id: 'q$i', category: '분야', question: '문제 $i', answer: i.isOdd, explain: '해설 $i', basis: '근거 $i'),
]);

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('B3 개인정보처리방침 확인 팝업', () {
    late List<MethodCall> launches;
    setUp(() {
      launches = [];
      // 호스트 테스트에서 url_launcher 는 기본 MethodChannel 구현을 쓴다
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launches.add(call);
          return true;
        },
      );
    });

    Future<void> pumpMenu(WidgetTester tester) async {
      phone(tester);
      Future<void> noop() async {}
      await tester.pumpWidget(
        MaterialApp(
          home: MenuScreen(
            onImport: noop,
            onPaste: noop,
            onOcr: noop,
            onVendors: noop,
            onUpdate: noop,
            importEnabled: () => true,
            onSettings: noop,
            cardSummary: () => '카드 0000',
            onPermissions: noop,
            permSummary: () => '',
            quizSummary: () => '연속 3일',
            onQuiz: noop,
            counts: () => (pending: 0, check: 0, ignored: 0, confirmed: 0),
            onUnclassified: noop,
            onCheck: noop,
            onIgnored: noop,
            onConfirmed: noop,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('[취소]면 링크를 열지 않음, [열기]면 열림', (tester) async {
      await pumpMenu(tester);
      await tester.tap(find.text('개인정보처리방침'));
      await tester.pumpAndSettle();
      expect(find.text('개인정보처리방침 페이지(GitHub)를 인터넷 브라우저로 엽니다.'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(launches.where((c) => c.method == 'launch'), isEmpty);

      await tester.tap(find.text('개인정보처리방침'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final launch = launches.where((c) => c.method == 'launch').toList();
      expect(launch, hasLength(1));
      expect((launch.single.arguments as Map)['url'], 'https://github.com/Wani-Jung/card-expense/blob/main/PRIVACY.md');
    });
  });

  group('안전 OX Quiz 화면', () {
    Future<QuizStore> pumpQuiz(WidgetTester tester, Map<String, Object> prefs, {QuizBank? bank}) async {
      phone(tester);
      SharedPreferences.setMockInitialValues(prefs);
      final store = QuizStore(await SharedPreferences.getInstance());
      return store;
    }

    for (final saved in [null, true, false]) {
      testWidgets('C1 매일 OX 퀴즈 스위치: 저장값 $saved → ${saved ?? false}, 점수 기록 지우기 위', (tester) async {
        final store = await pumpQuiz(tester, {'quiz_daily_on_v1': ?saved});
        await tester.pumpWidget(MaterialApp(home: QuizHomeScreen(store: store, bank: () async => _bank(3))));
        await tester.pumpAndSettle();
        final sw = find.widgetWithText(SwitchListTile, '매일 OX 퀴즈');
        expect(tester.widget<SwitchListTile>(sw).value, saved ?? false);
        expect(find.text('켜면 앱을 열 때 하루 한 번 안전 OX 퀴즈가 나옵니다.'), findsOneWidget);
        expect(tester.getTopLeft(sw).dy, lessThan(tester.getTopLeft(find.text('점수 기록 지우기')).dy));
        // 챌린지 설명은 10~50
        expect(find.text('10~50문제, 시간과 정답률로 기록에 도전'), findsOneWidget);
        expect(find.textContaining('20~50'), findsNothing);
      });
    }

    testWidgets('C2 점수 기록 지우기: 문구, 푼 문제 수 유지·정답률 -, [되돌리기]로 복구', (tester) async {
      final store = await pumpQuiz(tester, {});
      final today = quizDay(DateTime.now());
      await store.record(QuizRecord(today, 'q1', true, true));
      await store.record(QuizRecord(today, 'q2', true, false, src: kQuizExtra));
      await tester.pumpWidget(MaterialApp(home: QuizHomeScreen(store: store, bank: () async => _bank(3))));
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      await tester.tap(find.text('점수 기록 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('점수 기록을 지울까요?'), findsOneWidget);
      for (final s in ['푼 문제 수', '연속 일수', '챌린지 정답률·걸린 시간·최고 기록', '지난 문제 다시 보기 목록']) {
        expect(find.textContaining(s), findsOneWidget, reason: s);
      }
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(find.text('-'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(store.solvedCount, 2);
      expect(store.percent, isNull);

      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(store.percent, 50);
      expect(find.text('50%'), findsOneWidget);
    });
  });

  group('지난 문제 다시 보기', () {
    late QuizStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = QuizStore(await SharedPreferences.getInstance());
      final today = quizDay(DateTime.now());
      final at = DateTime.now().millisecondsSinceEpoch;
      await store.record(QuizRecord(today, 'q1', true, true));
      await store.record(QuizRecord(today, 'q2', true, false, src: kQuizExtra));
      await store.record(QuizRecord(today, 'q3', true, true, src: kQuizExtra));
      await store.saveRun(ChallengeRun(id: 'r1', at: at, n: 2, correct: 1, ms: 30000), [
        QuizRecord(today, 'q4', true, false, src: kQuizChallenge, run: 'r1'),
        QuizRecord(today, 'q5', true, true, src: kQuizChallenge, run: 'r1'),
      ]);
    });

    Future<void> pumpHistory(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(home: QuizHistoryScreen(store: store, bank: () async => _bank(5))));
      await tester.pumpAndSettle();
    }

    testWidgets('E1·E2 같은 날 안에서 챌린지 카드 / 한 문제 더 풀기 / 매일 퀴즈 묶음, 꼬리표 없음', (tester) async {
      await pumpHistory(tester);
      expect(find.text('한 문제 더 풀기 · 2문제'), findsOneWidget);
      expect(find.text('매일 퀴즈 · 1문제'), findsOneWidget);
      final card = find.ancestor(of: find.textContaining('챌린지 2문제'), matching: find.byType(Card));
      expect(card, findsOneWidget);
      for (final tag in ['추가 문제', '오늘의 문제', '챌린지']) {
        expect(find.text(tag), findsNothing, reason: tag);
      }
      // 묶음 아래 문제들
      final extraY = tester.getTopLeft(find.text('한 문제 더 풀기 · 2문제')).dy;
      final dailyY = tester.getTopLeft(find.text('매일 퀴즈 · 1문제')).dy;
      // 묶음 순서 = 가장 최근 기록 순: 챌린지 카드 → 한 문제 더 풀기 → 매일 퀴즈
      expect(tester.getTopLeft(find.textContaining('챌린지 2문제')).dy, lessThan(extraY));
      expect(extraY, lessThan(dailyY));
      for (final q in ['문제 2', '문제 3']) {
        final y = tester.getTopLeft(find.text(q)).dy;
        expect(y, greaterThan(extraY));
        expect(y, lessThan(dailyY));
      }
      expect(tester.getTopLeft(find.text('문제 1')).dy, greaterThan(dailyY));

      // 챌린지 카드를 펼치면 그 회차 문제가 카드 안에, 골드 세로줄
      expect(find.text('문제 4'), findsNothing);
      await tester.tap(find.textContaining('챌린지 2문제'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: card, matching: find.text('문제 4')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('문제 5')), findsOneWidget);
      final bar = tester.widgetList<Container>(find.descendant(of: card, matching: find.byType(Container))).where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.border is Border && (d.border! as Border).left.color == kQuizGold;
      });
      expect(bar, hasLength(1));
    });

    testWidgets('E3 [해설] 버튼: 누르면 말풍선 펼침, 다시 누르면 접힘. 문제를 눌러서는 안 열림', (tester) async {
      await pumpHistory(tester);
      expect(find.text('해설 1'), findsNothing);
      await tester.tap(find.text('문제 1'));
      await tester.pumpAndSettle();
      expect(find.text('해설 1'), findsNothing);

      final row = find.ancestor(of: find.text('문제 1'), matching: find.byType(QuizRecordTile));
      final btn = find.descendant(of: row, matching: find.text('해설'));
      expect(btn, findsOneWidget);
      // [해설]은 '내 답 → 정답' 줄 오른쪽
      final answer = find.descendant(of: row, matching: find.textContaining('내 답 O → 정답 O'));
      expect(tester.getCenter(btn).dx, greaterThan(tester.getCenter(answer).dx));
      expect((tester.getCenter(btn).dy - tester.getCenter(answer).dy).abs(), lessThan(12));

      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.text('해설 1'), findsOneWidget);
      expect(find.text('근거: 근거 1'), findsOneWidget);
      expect(tester.getTopLeft(find.text('해설 1')).dy, greaterThan(tester.getBottomLeft(answer).dy));
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.text('해설 1'), findsNothing);
    });

    testWidgets('D1 [전체]/[틀린 문제만] 선택 = 네이비 채움·흰 글자, 비선택 = 흰 바탕·회색, 체크 없음, 크기 그대로', (tester) async {
      await pumpHistory(tester);
      Material mat(String label) => tester.widget<Material>(
        find.descendant(of: find.widgetWithText(QuizSelectChip, label).first, matching: find.byType(Material)),
      );
      Color textColor(String label) => tester
          .widget<Text>(find.descendant(of: find.widgetWithText(QuizSelectChip, label).first, matching: find.text(label)))
          .style!
          .color!;
      expect(mat('전체').color, kQuizNavy);
      expect(textColor('전체'), Colors.white);
      expect(mat('틀린 문제만').color, Colors.white);
      expect(textColor('틀린 문제만'), QuizSelectChip.textOff);
      expect(find.byIcon(Icons.check), findsNothing);
      final before = tester.getSize(find.widgetWithText(QuizSelectChip, '틀린 문제만').first);

      await tester.tap(find.text('틀린 문제만').first);
      await tester.pumpAndSettle();
      expect(mat('틀린 문제만').color, kQuizNavy);
      expect(textColor('틀린 문제만'), Colors.white);
      expect(mat('전체').color, Colors.white);
      expect(tester.getSize(find.widgetWithText(QuizSelectChip, '틀린 문제만').first), before);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });

  testWidgets('D1 분야 칩도 같은 선택 칩, 눌러서 선택·해제', (tester) async {
    phone(tester);
    final bank = QuizBank(1, '2026-10-31', [
      QuizQuestion(id: 'a', group: '현장 안전기준', category: '추락', question: 'A', answer: true, explain: '', basis: ''),
      QuizQuestion(id: 'b', group: '현장 안전기준', category: '화재', question: 'B', answer: false, explain: '', basis: ''),
    ]);
    var selected = <String>{'현장 안전기준|추락'};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => QuizCategoryPicker(
            bank: bank,
            selected: selected,
            onChanged: (v) => setState(() => selected = v),
          ),
        ),
      ),
    ));
    expect(find.byType(FilterChip), findsNothing);
    final chip = find.widgetWithText(QuizSelectChip, '화재 1');
    expect(tester.widget<QuizSelectChip>(chip).selected, isFalse);
    final size = tester.getSize(chip);
    await tester.tap(chip);
    await tester.pump();
    expect(selected, contains('현장 안전기준|화재'));
    expect(tester.widget<QuizSelectChip>(chip).selected, isTrue);
    expect(tester.getSize(chip), size);
  });
}
