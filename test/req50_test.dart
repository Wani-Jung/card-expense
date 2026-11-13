import 'dart:convert';

import 'package:card_expense/budget.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/rural_quiz.dart';
import 'package:card_expense/rural_quiz_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-50: 차량비 잔여 보정 철회, 요약표 단위 선택(만원·천원·원), 정비법 점수 기록 지우기.
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

  int w(num manwon) => (manwon * 10000).round();

  /// 이번 달 수립·사용을 넣고 메인을 띄운다
  Future<Store> pumpMonth(
    WidgetTester tester, {
    required num total,
    required num car,
    required int usedCar,
    required int usedOps,
    Map<String, Object> extra = const {},
  }) async {
    phone(tester);
    final now = DateTime.now();
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
        Budgets.keyOf(now): {'total': w(total), 'car': w(car)},
      }),
      'expenses_v1': jsonEncode([item('a', kCar, usedCar), item('b', kOps, usedOps)]),
      ...extra,
    });
    final store = await Store.open();
    await tester.pumpWidget(CardExpenseApp(store: store));
    await tester.pumpAndSettle();
    return store;
  }

  group('A 잔여 보정 철회: 차량비 잔여는 언제나 자기 값', () {
    testWidgets('합계 잔여가 양수이고 차량비 잔여가 더 커도 그대로, 경고 아이콘 없음', (tester) async {
      // 합계 100·차량 40, 사용 차량 31.5·운영 64.2 → 합계 잔여 4.3, 차량 잔여 8.5
      await pumpMonth(tester, total: 100, car: 40, usedCar: w(31.5), usedOps: w(64.2));
      expect(find.text('4.3'), findsOneWidget);
      expect(find.text('8.5'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('합계 잔여가 음수여도 차량비는 자기 값 (7월 예시: 초과 8.2 / 초과 6.9)', (tester) async {
      await pumpMonth(tester, total: 70, car: 54, usedCar: w(60.9), usedOps: w(17.3));
      expect(find.text('초과 8.2'), findsOneWidget);
      expect(find.text('초과 6.9'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('B 단위 선택', () {
    test('만원 / 천원 / 원 표기 (반올림·쉼표·0·초과)', () {
      expect(money(342500, MoneyUnit.man), '34.25');
      expect(money(350000, MoneyUnit.man), '35');
      expect(money(85000, MoneyUnit.man), '8.5');
      expect(money(342500, MoneyUnit.thousand), '343');
      expect(money(342499, MoneyUnit.thousand), '342'); // 반올림 경계
      expect(money(350000, MoneyUnit.thousand), '350');
      expect(money(1234000, MoneyUnit.thousand), '1,234');
      expect(money(342500, MoneyUnit.won), '342,500');
      expect(money(1234560, MoneyUnit.won), '1,234,560');
      for (final u in MoneyUnit.values) {
        expect(money(0, u), '0', reason: u.name);
      }
      expect(remainingIn(-82000, MoneyUnit.man), '초과 8.2');
      expect(remainingIn(-82000, MoneyUnit.thousand), '초과 82');
      expect(remainingIn(-82000, MoneyUnit.won), '초과 82,000');
      expect(remainingIn(-1500, MoneyUnit.thousand), '초과 2'); // 1.5 → 2 (반올림)
      expect(remainingIn(null, MoneyUnit.won), '-');
      expect(moneyOrDash(null, MoneyUnit.thousand), '-');
      expect(groupDigits(-1234567), '-1,234,567');
    });

    test('입력 변환: 만원 소수 둘째 자리, 천원·원 정수만 (원 단위로 저장)', () {
      expect(parseMoney('34.25', MoneyUnit.man), 342500);
      expect(parseMoney('343', MoneyUnit.thousand), 343000);
      expect(parseMoney('1,234', MoneyUnit.thousand), 1234000);
      expect(parseMoney('342500', MoneyUnit.won), 342500);
      expect(parseMoney('', MoneyUnit.won), isNull);
      expect(() => parseMoney('34.5', MoneyUnit.thousand), throwsFormatException);
      expect(() => parseMoney('1.5', MoneyUnit.won), throwsFormatException);
      expect(moneyInputText(1234000, MoneyUnit.thousand), '1234');
      expect(moneyInputText(342500, MoneyUnit.man), '34.25');
      expect(MoneyUnit.byName(null), MoneyUnit.man);
      expect(MoneyUnit.byName('won'), MoneyUnit.won);
    });

    testWidgets('드롭다운으로 바꾸면 표가 그 단위로, 기기에 저장, 다시 열어도 유지', (tester) async {
      final store = await pumpMonth(tester, total: 123.456, car: 40, usedCar: 342500, usedOps: 0);
      expect(find.text('단위: 만원 ▾'), findsOneWidget);
      expect(find.text('34.25'), findsWidgets);
      await tester.tap(find.text('단위: 만원 ▾'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('원').last);
      await tester.pumpAndSettle();
      expect(find.text('단위: 원 ▾'), findsOneWidget);
      expect(store.moneyUnit, MoneyUnit.won);
      expect(find.text('342,500'), findsWidgets);
      expect(find.text('1,234,560'), findsOneWidget); // 7자리: 합계 수립
      // 칸 안에 들어감 (넘침 오류 없음)
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('단위: 원 ▾'), findsOneWidget);
      // 천원
      await tester.tap(find.text('단위: 원 ▾'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('천원').last);
      await tester.pumpAndSettle();
      expect(find.text('343'), findsWidgets);
      expect(find.text('1,235'), findsOneWidget);
    });

    testWidgets('수립 편집 시트: 천원 단위로 입력 → 원으로 저장', (tester) async {
      final store = await pumpMonth(
        tester,
        total: 100,
        car: 40,
        usedCar: 0,
        usedOps: 0,
        extra: {'money_unit_v1': 'thousand'},
      );
      await tester.tap(find.text('1,000').first); // 수립 칸 (잔여 칸도 1,000)
      await tester.pumpAndSettle();
      expect(find.text('천원'), findsWidgets); // 입력칸 단위
      expect(find.widgetWithText(TextField, '1000'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '343');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(store.loadBudgets().forMonth(DateTime.now()).total, 343000);
      expect(find.text('343'), findsWidgets);
    });

    testWidgets('사전입력사항 1단계도 고른 단위', (tester) async {
      await pumpMonth(tester, total: 100, car: 40, usedCar: 0, usedOps: 0, extra: {'money_unit_v1': 'won'});
      await tester.tap(find.byTooltip('메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사전입력사항'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '1000000'), findsOneWidget);
      expect(find.text('원'), findsWidgets);
    });
  });

  group('C 정비법 점수 기록 지우기', () {
    testWidgets('확인 → 정답률 -·푼 문제 수 유지·최고 기록 없음, [되돌리기], 안전 OX 기록 그대로', (tester) async {
      phone(tester);
      final safe = jsonEncode({'day': '2026-11-13', 'id': 'w001', 'choice': true, 'correct': true});
      SharedPreferences.setMockInitialValues({
        'quiz_log_v1': [safe],
      });
      final prefs = await SharedPreferences.getInstance();
      final store = RuralStore(prefs);
      await store.record(const RuralRecord('2026-11-13', 'r001', 1, true));
      await store.saveRun(const ChallengeRun(id: 'c1', at: 0, n: 10, correct: 7, ms: 60000), [
        const RuralRecord('2026-11-13', 'r002', 2, false, src: kQuizChallenge, run: 'c1'),
      ]);
      expect(store.best(10), isNotNull);
      final bank = RuralBank.parse(
        '''{"version":1,"updated":"","groups":[],"questions":[
        {"id":"r001","group":"농어촌정비법","category":"벌칙","type":"ox","question":"문제1","answer":true,"explain":"","basis":"","active":true},
        {"id":"r002","group":"농어촌정비법","category":"벌칙","type":"choice","question":"문제2","choices":["가","나","다","라"],"answer":3,"explain":"","basis":"","active":true}]}''',
      )!;
      await tester.pumpWidget(
        MaterialApp(
          home: RuralQuizHomeScreen(store: store, bank: () async => bank),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      await tester.tap(find.text('점수 기록 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('점수 기록을 지울까요?'), findsOneWidget);
      for (final s in ['푼 문제 수', '챌린지 정답률·걸린 시간·최고 기록', '지난 문제 다시 보기 목록', '안전 OX Quiz 기록']) {
        expect(find.textContaining(keepWords(s)), findsOneWidget, reason: s);
      }
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(find.text('-'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 푼 문제 수
      expect(store.percent, isNull);
      expect(store.solvedCount, 2);
      expect(store.best(10), isNull);
      expect(store.runs.single.n, 10);
      expect(prefs.getStringList('quiz_log_v1'), [safe]); // 안전 OX 그대로

      // 지운 기록: 지난 문제에는 정답만, 회차는 '챌린지 · 10문제'
      await tester.tap(find.text('지난 문제 다시 보기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('내 답'), findsNothing);
      expect(find.text('정답 O'), findsOneWidget);
      expect(find.text('챌린지 · 10문제'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 되돌리기
      await tester.tap(find.text('점수 기록 지우기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(find.text('되돌리기'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      // 두 번째 지우기 직전(이미 지운 상태)으로 돌아감. 지우기 전 그대로 복원되는지는 아래 단위 테스트
      expect(store.percent, isNull);
      expect(store.solvedCount, 2);
    });

    test('스냅숏 복원은 지우기 전 그대로', () async {
      SharedPreferences.setMockInitialValues({});
      final store = RuralStore(await SharedPreferences.getInstance());
      await store.record(const RuralRecord('d', 'r001', 1, true));
      final snap = store.snapshotScores();
      await store.clearScores();
      expect(store.records.single.correct, isNull);
      await store.restoreScores(snap);
      expect(store.records.single.correct, isTrue);
      expect(store.percent, 100);
    });
  });
}
