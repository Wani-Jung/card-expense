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

/// REQ-49: 숫자 끝자리 0 생략, 스토어판 정비법 퀴즈 숨김. (잔여 보정은 REQ-50 에서 철회)
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

  // 차량비 잔여 보정 테스트는 REQ-50 에서 기능을 철회하면서 뺐다 (test/req50_test.dart 가 '차량비는 언제나 자기 값'을 확인)

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
