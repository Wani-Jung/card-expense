import 'dart:convert';

import 'package:card_expense/budget.dart';
import 'package:card_expense/category_badge.dart';
import 'package:card_expense/challenge_card.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/rural_quiz.dart';
import 'package:card_expense/rural_quiz_screens.dart';
import 'package:card_expense/vendor.dart';
import 'package:card_expense/vendor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-48: 사전입력사항 문구, 농어촌정비법 챌린지, 결과 카드 크레딧 삭제, 키워드 칩 켜기/끄기·길게 눌러 삭제,
/// 차량비 잔여 보정.
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

  group('A 사전입력사항', () {
    testWidgets('제목·메뉴 이름, 1·2단계 설명 줄 없음 (비워 두고 넘어가기는 그대로)', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({
        'update_checked_at': DateTime.now().millisecondsSinceEpoch,
        'quiz_last_day_v1': quizDay(DateTime.now()),
        'notif_asked_v1': true,
      });
      final store = await Store.open();
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('사전입력사항'), findsOneWidget);
      expect(find.text('사용법'), findsNothing);
      expect(find.textContaining(keepWords('한 달에 쓸 수 있는')), findsNothing);
      expect(find.textContaining(keepWords('비워 두면 나중에')), findsNothing);
      // 비워 둔 채 다음
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.textContaining(keepWords('이 번호로 온 문자 중')), findsNothing);
      expect(find.text(keepWords('승인 문자에 적힌 카드번호 네자리\n(예: "NH기업0000승인" 이면 0000)')), findsOneWidget);
      expect(store.loadBudgets().forMonth(DateTime.now()).total, isNull);
    });
  });

  group('C 결과 카드·크레딧', () {
    testWidgets('결과 카드에 Made by wani 없음, 정비법 제목·등급', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: ChallengeResultCard(
                  run: const ChallengeRun(id: 'c1', at: 0, n: 10, correct: 9, ms: 60000),
                  name: '',
                  date: DateTime(2026, 11, 12),
                  newBest: false,
                  title: kRuralChallengeTitle,
                  subtitle: kRuralCardSubtitle,
                  gradeTopic: '정비법',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Made by wani'), findsNothing);
      expect(find.text('농어촌정비법 챌린지'), findsOneWidget);
      expect(find.text('농어촌정비법 OX·객관식'), findsOneWidget);
      expect(find.text('🥇 정비법 달인'), findsOneWidget);
    });
  });

  group('D 키워드 칩', () {
    test('꺼 둔 키워드는 추천에 안 씀, 저장·읽기, 업데이트로 기본 키워드가 추가돼도 꺼진 채', () {
      final b = VendorBook.initial();
      expect(b.recommend('홍성주유소')!.category, kCar);
      b.toggleKeyword(b.keywords.firstWhere((k) => k.keyword == '주유'));
      expect(b.recommend('홍성주유소'), isNull);
      final back = VendorBook.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
      expect(back.keywords.firstWhere((k) => k.keyword == '주유').enabled, isFalse);
      expect(back.recommend('홍성주유소'), isNull);
      back
        ..defaultsVersion = 2
        ..upgradeDefaults();
      expect(back.keywords.firstWhere((k) => k.keyword == '주유').enabled, isFalse);
      back.toggleKeyword(back.keywords.firstWhere((k) => k.keyword == '주유'));
      expect(back.recommend('홍성주유소')!.category, kCar);
      // 켜진 키워드는 json 에 enabled 를 따로 안 남긴다 (예전 형식 그대로)
      expect(const KeywordRule('a', kCar).toJson().containsKey('enabled'), isFalse);
    });

    testWidgets('짧게 누르면 끄기/켜기(색), 길게 누르면 확인 후 지운 키워드로, 분류 바꾸는 창 없음', (tester) async {
      phone(tester);
      final b = VendorBook.initial();
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: VendorScreen(book: b, onChanged: () async => saved++),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('누르면 끄기/켜기 · 길게 누르면 삭제'), findsOneWidget);
      Material chipMat(String w) => tester.widget<Material>(
        find.descendant(of: find.widgetWithText(KeywordChip, w), matching: find.byType(Material)).first,
      );
      expect(chipMat('세차').color, kCarColor);
      expect(chipMat('카페').color, kOpsColor);
      expect(KeywordChip.colors(b.keywords.firstWhere((k) => k.keyword == '카페')).fg, kOpsText);

      await tester.tap(find.widgetWithText(KeywordChip, '세차'));
      await tester.pumpAndSettle();
      expect(b.keywords.firstWhere((k) => k.keyword == '세차').enabled, isFalse);
      expect(chipMat('세차').color, Colors.white);
      expect(find.byType(BottomSheet), findsNothing); // 분류 전환 창 없음
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(saved, 1);
      await tester.tap(find.widgetWithText(KeywordChip, '세차'));
      await tester.pumpAndSettle();
      expect(b.keywords.firstWhere((k) => k.keyword == '세차').enabled, isTrue);

      await tester.longPress(find.widgetWithText(KeywordChip, '세차'));
      await tester.pumpAndSettle();
      expect(find.text("'세차'를 목록에서 뺄까요?"), findsOneWidget);
      await tester.tap(find.text('빼기'));
      await tester.pumpAndSettle();
      expect(b.keywords.map((k) => k.keyword), isNot(contains('세차')));
      expect(b.removedKeywords.map((k) => k.keyword), contains('세차'));
      expect(find.text('되돌리기'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(b.keywords.map((k) => k.keyword), contains('세차'));
    });

    test('꺼 둔 키워드를 지우면 지운 목록에는 켜진 채로 (다시 넣으면 바로 추천)', () {
      final b = VendorBook.initial();
      final k = b.keywords.firstWhere((k) => k.keyword == '세차');
      b.toggleKeyword(k);
      b.removeKeyword(b.keywords.firstWhere((k) => k.keyword == '세차'));
      b.restoreRemoved(b.removedKeywords.where((k) => k.keyword == '세차'));
      expect(b.recommend('손세차장')!.category, kCar);
    });
  });

  group('E 차량비 잔여 보정', () {
    MonthBudget budget(int total, int car) => MonthBudget(total: total * 10000, car: car * 10000);
    MonthUsage use(int car, int ops) => MonthUsage(car * 10000, ops * 10000);

    test('차량비 잔여 > 합계 잔여면 합계 잔여로, 같거나 작으면 그대로, 수립 없으면 그대로', () {
      // 합계 100 · 차량 40, 차량 10 · 운영 80 사용 → 합계 잔여 10, 차량 잔여 30 → 10 으로
      var r = carRemainShown(budget(100, 40), use(10, 80));
      expect((r.shown, r.original, r.adjusted), (100000, 300000, true));
      // 같을 때(합계 잔여 30 = 차량 잔여 30)는 보정 안 함
      r = carRemainShown(budget(100, 40), use(10, 60));
      expect((r.shown, r.adjusted), (300000, false));
      // 차량 잔여가 더 작으면 그대로
      r = carRemainShown(budget(100, 40), use(35, 10));
      expect((r.shown, r.adjusted), (50000, false));
      // 합계가 마이너스면 차량비도 같은 값(초과)
      r = carRemainShown(budget(100, 40), use(10, 100));
      expect((r.shown, r.adjusted), (-100000, true));
      expect(remainLevel(400000, r.shown), BudgetLevel.over);
      expect(remainingText(r.shown), '초과 10.00');
      // 수립 없음
      r = carRemainShown(const MonthBudget(total: 1000000), use(10, 80));
      expect((r.shown, r.adjusted), (null, false));
    });

    test('색 규칙은 보정 값 기준 (차량비 수립 대비): 20% 이하 남으면 주의', () {
      expect(remainLevel(400000, 100000), BudgetLevel.ok); // 25% 남음
      expect(remainLevel(400000, 80000), BudgetLevel.warn); // 20% 남음
      expect(remainLevel(400000, 0), BudgetLevel.warn);
      expect(remainLevel(400000, -1), BudgetLevel.over);
    });

    test('팝업 문구', () {
      expect(
        carRemainAdjustedMessage(300000),
        '운영비를 초과해 써서, 실제로 남은 차량비는 합계 잔여만큼이에요. 그래서 합계 잔여 값으로 표시했어요. (원래 차량비 잔여 30.00)',
      );
    });

    testWidgets('메인 표: 보정 칸에 경고 아이콘, 누르면 팝업', (tester) async {
      phone(tester);
      final now = DateTime.now();
      final key = Budgets.keyOf(now);
      Map<String, Object?> item(String id, String cat, int amount) => {
        'id': id,
        'amount': amount,
        'dateTime': DateTime(now.year, now.month, 1, 12).toIso8601String(),
        'merchant': '가게$id',
        'isCancel': false,
        'raw': '',
        'category': cat,
      };
      SharedPreferences.setMockInitialValues({
        'card_digits': '0000',
        'sender_number': '1588-1600',
        'update_checked_at': now.millisecondsSinceEpoch,
        'quiz_last_day_v1': quizDay(now),
        'notif_asked_v1': true,
        'budgets_v1': jsonEncode({
          key: {'total': 1000000, 'car': 400000},
        }),
        'expenses_v1': jsonEncode([item('a', kCar, 50000), item('b', kOps, 800000)]),
      });
      final store = await Store.open();
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.pumpAndSettle();
      // 합계 잔여 15.00, 차량비 칸도 15.00 (원래 35.00)
      expect(find.text('15.00'), findsNWidgets(2));
      expect(find.text('35.00'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.warning_amber_rounded));
      await tester.pumpAndSettle();
      expect(find.text(keepWords(carRemainAdjustedMessage(350000))), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      // 저장된 수립은 그대로
      expect(store.loadBudgets().forMonth(now).car, 400000);
    });
  });

  group('B 농어촌정비법 챌린지', () {
    const json = '''{"version":1,"updated":"","groups":[{"name":"농어촌정비법","categories":["벌칙","총칙"]}],
      "questions":[
      {"id":"r001","group":"농어촌정비법","category":"벌칙","type":"choice","question":"문제1","choices":["가","나","다","라"],"answer":3,"explain":"","basis":"","active":true},
      {"id":"r002","group":"농어촌정비법","category":"벌칙","type":"ox","question":"문제2","answer":true,"explain":"","basis":"","active":true},
      {"id":"r003","group":"농어촌정비법","category":"총칙","type":"ox","question":"문제3","answer":false,"explain":"","basis":"","active":true},
      {"id":"r004","group":"농어촌정비법","category":"총칙","type":"choice","question":"문제4","choices":["가","나","다","라"],"answer":1,"explain":"","basis":"","active":true},
      {"id":"r005","group":"농어촌정비법","category":"총칙","type":"ox","question":"문제5","answer":true,"explain":"","basis":"","active":true},
      {"id":"r006","group":"농어촌정비법","category":"총칙","type":"ox","question":"문제6","answer":true,"explain":"","basis":"","active":true},
      {"id":"r007","group":"농어촌정비법","category":"총칙","type":"ox","question":"문제7","answer":true,"explain":"","basis":"","active":true},
      {"id":"r008","group":"농어촌정비법","category":"총칙","type":"ox","question":"문제8","answer":true,"explain":"","basis":"","active":true},
      {"id":"r009","group":"농어촌정비법","category":"총칙","type":"ox","question":"문제9","answer":true,"explain":"","basis":"","active":true},
      {"id":"r010","group":"농어촌정비법","category":"총칙","type":"ox","question":"문제10","answer":true,"explain":"","basis":"","active":true},
      {"id":"r011","group":"농어촌정비법","category":"총칙","type":"ox","question":"문제11","answer":true,"explain":"","basis":"","active":true}
      ]}''';

    testWidgets('10문제 진행(OX·객관식) → 결과·최고 기록, 기록은 정비법 쪽에만, 지난 문제에 회차 카드', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({'quiz_name_v1': ''});
      final prefs = await SharedPreferences.getInstance();
      final store = RuralStore(prefs);
      final bank = RuralBank.parse(json)!;
      await tester.pumpWidget(MaterialApp(home: RuralQuizHomeScreen(store: store, bank: () async => bank)));
      await tester.pumpAndSettle();
      // 항목 순서: 챌린지 → 한 문제 더 → 지난 문제
      final order = ['농어촌정비법 챌린지', '한 문제 더 풀기', '지난 문제 다시 보기'];
      final ys = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));

      await tester.tap(find.text('농어촌정비법 챌린지'));
      await tester.pumpAndSettle();
      // 활성 11문항: 10 만 가능
      ButtonStyleButton size(String n) =>
          tester.widget<ButtonStyleButton>(find.ancestor(of: find.text(n), matching: find.byType(OutlinedButton)));
      expect(size('10').onPressed, isNotNull);
      expect(size('20').onPressed, isNull);
      await tester.tap(find.text('시작'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        // OX 면 O, 객관식이면 1번
        final o = find.text('O');
        await tester.tap(o.evaluate().isNotEmpty ? o : find.text('1'));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('챌린지 결과'), findsOneWidget);
      expect(find.text('농어촌정비법 챌린지'), findsOneWidget);
      expect(find.text('최고 기록!'), findsOneWidget);
      expect(find.text('Made by wani'), findsNothing);
      expect(store.runs, hasLength(1));
      expect(store.records.where((r) => r.src == kQuizChallenge && r.run == store.runs.single.id), hasLength(10));
      expect(store.best(10), isNotNull);
      // 안전 OX 쪽 기록은 그대로
      expect(prefs.getStringList('quiz_log_v1'), isNull);
      expect(prefs.getStringList('quiz_runs_v1'), isNull);

      await tester.tap(find.text('문제 전체 보기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('내 답 '), findsNWidgets(10));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('지난 문제 다시 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(RuralRunTile), findsOneWidget);
      expect(find.textContaining('챌린지 10문제 · 정답률 '), findsOneWidget);
      expect(find.textContaining('내 답 '), findsNothing);
      await tester.tap(find.textContaining('챌린지 10문제'));
      await tester.pumpAndSettle();
      expect(find.textContaining('내 답 '), findsWidgets);
    });

    test('기록 형식: 한 문제 더는 예전 형식 그대로, 챌린지는 출처·회차', () {
      expect(const RuralRecord('d', 'r1', 1, true).toJson(), {'d': 'd', 'q': 'r1', 'p': 1, 'ok': true});
      final c = RuralRecord.fromJson(const RuralRecord('d', 'r1', 2, false, src: kQuizChallenge, run: 'c1').toJson());
      expect((c.src, c.run, c.pick), (kQuizChallenge, 'c1', 2));
      expect(RuralRecord.fromJson({'d': 'd', 'q': 'r', 'p': 1, 'ok': true}).src, kQuizExtra);
    });
  });
}
