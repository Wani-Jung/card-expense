import 'dart:convert';

import 'package:card_expense/budget.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/flavor.dart';
import 'package:card_expense/lab_screen.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-49: 잔여 보정은 합계 잔여 ≥ 0 일 때만, 팝업 문구, 숫자 끝자리 0 생략, 스토어판 정비법 퀴즈 숨김.
/// 이 파일은 CI 에서 스토어 채널 define 으로도 돈다 (C 의 기대값이 채널마다 갈림).
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

  /// 만원 단위 (소수 가능) → 원
  int w(num manwon) => (manwon * 10000).round();

  group('B 숫자 표시: 소수 끝자리 0 생략', () {
    test('35, 8.5, 33.95, 0, 초과 8.2, 1.05', () {
      expect(manwon(w(35)), '35');
      expect(manwon(w(8.5)), '8.5');
      expect(manwon(w(33.95)), '33.95');
      expect(manwon(0), '0');
      expect(remainingText(-w(8.2)), '초과 8.2');
      expect(manwon(w(1.05)), '1.05');
      expect(manwon(w(100)), '100');
      expect(manwon(w(100.5)), '100.5');
      expect(manwon(w(10.1)), '10.1');
      expect(manwon(w(-0.001)), '0'); // 반올림하면 0
      expect(manwonOrDash(null), '-');
      // 저장·계산은 원 단위 그대로, 입력은 소수 둘째 자리까지
      expect(parseManwon('34.25'), 342500);
      expect(parseManwon('35'), 350000);
    });
  });

  group('A 차량비 잔여 보정 (합계 잔여 ≥ 0 일 때만)', () {
    MonthBudget budget(num total, num car) => MonthBudget(total: w(total), car: w(car));
    MonthUsage use(num car, num ops) => MonthUsage(w(car), w(ops));

    test('경계: 합계 잔여 0 이면 보정, 같으면 안 함, 합계 음수면 안 함', () {
      // 합계 잔여 0, 차량 잔여 30 → 0 으로 보정
      var r = carRemainShown(budget(100, 40), use(10, 90));
      expect((r.shown, r.original, r.adjusted), (0, w(30), true));
      // 같음 (합계 잔여 30 = 차량 잔여 30)
      r = carRemainShown(budget(100, 40), use(10, 60));
      expect((r.shown, r.adjusted), (w(30), false));
      // 합계 잔여 -1원 → 보정 안 함
      r = carRemainShown(budget(100, 40), use(10, 90.0001));
      expect((r.shown, r.adjusted), (w(30), false));
    });

    test('7월 예시: 수립 합계 70·차량비 54, 사용 합계 78.2·차량비 60.9 → 합계 초과 8.2, 차량비 초과 6.9', () {
      final b = budget(70, 54);
      final u = use(60.9, 78.2 - 60.9);
      expect(remainingText(remaining(b.total, u.total)), '초과 8.2');
      final r = carRemainShown(b, u);
      expect(r.adjusted, isFalse);
      expect(remainingText(r.shown), '초과 6.9');
    });

    test('팝업 문구: 줄바꿈 그대로, 끝자리 0 없는 숫자 + 만원', () {
      expect(carRemainAdjustedMessage(w(8.5)), '잔여 총액이 잔여 차량비보다 적어서,\n잔여 총액으로 표시했어요.\n(원래 차량비 잔여: 8.5만원)');
      expect(carRemainAdjustedMessage(w(30)), endsWith('(원래 차량비 잔여: 30만원)'));
    });

    Future<void> pumpMonth(
      WidgetTester tester, {
      required num total,
      required num car,
      required num usedCar,
      required num usedOps,
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
        'expenses_v1': jsonEncode([item('a', kCar, w(usedCar)), item('b', kOps, w(usedOps))]),
      });
      final store = await Store.open();
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.pumpAndSettle();
    }

    testWidgets('메인 표 7월 예시: 두 칸 숫자가 다르고 경고 아이콘 없음, 수립·사용도 끝자리 0 없음', (tester) async {
      await pumpMonth(tester, total: 70, car: 54, usedCar: 60.9, usedOps: 17.3);
      expect(find.text('초과 8.2'), findsOneWidget);
      expect(find.text('초과 6.9'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.text('70'), findsOneWidget);
      expect(find.text('54'), findsOneWidget);
      expect(find.text('78.2'), findsOneWidget);
      expect(find.text('60.9'), findsOneWidget);
      expect(find.text('16'), findsOneWidget); // 운영비 수립 = 70 − 54
    });

    testWidgets('메인 표 보정: 합계 잔여 ≥ 0 이고 차량비 잔여가 더 크면 경고 아이콘 → 팝업', (tester) async {
      // 합계 100·차량 40, 사용 차량 31.5·운영 64.2 → 합계 잔여 4.3, 차량 잔여 8.5 → 차량비 칸도 4.3 으로 보정
      await pumpMonth(tester, total: 100, car: 40, usedCar: 31.5, usedOps: 64.2);
      expect(find.text('4.3'), findsNWidgets(2));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.warning_amber_rounded));
      await tester.pumpAndSettle();
      expect(find.text('잔여 총액이 잔여 차량비보다 적어서,\n잔여 총액으로 표시했어요.\n(원래 차량비 잔여: 8.5만원)'), findsOneWidget);
      expect(find.text('확인'), findsOneWidget);
    });
  });

  group('C 농어촌정비법 퀴즈 노출', () {
    testWidgets('스토어판은 숨김, 깃허브판은 보임 (실험실 메뉴는 유지)', (tester) async {
      phone(tester);
      Future<void> noop() async {}
      await tester.pumpWidget(
        MaterialApp(
          home: LabScreen(quizSummary: () => '', ruralSummary: () => '', onQuiz: noop, onRural: noop),
        ),
      );
      expect(find.text('안전 OX Quiz'), findsOneWidget);
      expect(find.text('농어촌정비법 퀴즈'), isStoreChannel ? findsNothing : findsOneWidget);
      expect(kShowRuralQuiz, !isStoreChannel || kRuralQuizInStore);
      expect(kRuralQuizInStore, isFalse); // 검토가 끝나면 true 로
    });

    testWidgets('메뉴 실험실 설명도 채널에 맞게', (tester) async {
      phone(tester);
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'card_digits': '0000',
        'sender_number': '1588-1600',
        'update_checked_at': now.millisecondsSinceEpoch,
        'quiz_last_day_v1': quizDay(now),
        'notif_asked_v1': true,
      });
      final store = await Store.open();
      await tester.pumpWidget(CardExpenseApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('메뉴'));
      await tester.pumpAndSettle();
      expect(find.text('실험실'), findsOneWidget);
      expect(find.text(isStoreChannel ? '안전 OX Quiz' : '안전 OX Quiz · 농어촌정비법 퀴즈'), findsOneWidget);
    });
  });
}
