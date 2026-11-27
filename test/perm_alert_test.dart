import 'package:card_expense/expense.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/notice_dialog.dart';
import 'package:card_expense/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2.1.1: 문자 권한이 없으면 메뉴 '권한 설정' 오른쪽과 권한 설정 화면 '문자 읽기' 제목 옆에 노란 느낌표
void main() {
  Future<void> pumpHome(WidgetTester tester, {required bool smsGranted, bool useSms = true}) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('card_expense/native'),
      (call) async => call.method == 'permissionStatus'
          ? {'listener': true, 'sms': smsGranted, 'smsBlocked': false}
          : null,
    );
    SharedPreferences.setMockInitialValues({
      'card_digits': '0000',
      'sender_number': '1588-1600',
      'update_checked_at': DateTime.now().millisecondsSinceEpoch,
      'quiz_last_day_v1': quizDay(DateTime.now()),
      'use_sms_v1': useSms,
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = await Store.open();
    await tester.pumpWidget(CardExpenseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
  }

  Finder rowOf(String title) => find.ancestor(of: find.text(title), matching: find.byType(ListTile)).first;

  testWidgets('문자 권한 없음: 메뉴 권한 설정에 노란 ! → 들어가면 문자 읽기에 노란 !', (tester) async {
    await pumpHome(tester, smsGranted: false);
    final badge = find.descendant(of: rowOf('권한 설정'), matching: find.byType(PermAlertBadge));
    expect(badge, findsOneWidget);
    final w = tester.widget<WarnBadge>(find.descendant(of: badge, matching: find.byType(WarnBadge)));
    expect(w.color, kPermAlert);
    // 다른 메뉴 항목에는 없음
    expect(find.byType(PermAlertBadge), findsOneWidget);

    await tester.tap(find.text('권한 설정'));
    await tester.pumpAndSettle();
    final sms = find.text('문자 읽기');
    expect(sms, findsOneWidget);
    final card = find.ancestor(of: sms, matching: find.byType(Card)).first;
    expect(find.descendant(of: card, matching: find.byType(PermAlertBadge)), findsOneWidget);
    // 알림 감지 카드엔 없음
    final listener = find.ancestor(of: find.text('알림 감지'), matching: find.byType(Card)).first;
    expect(find.descendant(of: listener, matching: find.byType(PermAlertBadge)), findsNothing);
    // 제목 바로 옆(오른쪽)
    expect(tester.getCenter(find.descendant(of: card, matching: find.byType(PermAlertBadge))).dx,
        greaterThan(tester.getCenter(sms).dx));
  });

  testWidgets('문자 권한 있음: 표시 없음', (tester) async {
    await pumpHome(tester, smsGranted: true);
    expect(find.byType(PermAlertBadge), findsNothing);
    await tester.tap(find.text('권한 설정'));
    await tester.pumpAndSettle();
    expect(find.byType(PermAlertBadge), findsNothing);
  });

  testWidgets('문자 읽기를 앱에서 꺼 둔 경우(사용자 선택): 표시 없음', (tester) async {
    await pumpHome(tester, smsGranted: false, useSms: false);
    expect(find.byType(PermAlertBadge), findsNothing);
  });
}
