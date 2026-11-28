import 'dart:convert';

import 'package:card_expense/budget.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/quiz.dart';
import 'package:card_expense/review_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2.0.3: 메인 '분류 대기' 카드는 보고 있는 기간(1개월 = 그 달, 합산 = 두 달) 것만,
/// 다른 달 미분류는 '다른 달 미분류 n건 ›' 한 줄 → 미분류 내역 화면
void main() {
  final now = DateTime.now();
  DateTime at(int monthsAgo, int day) => DateTime(now.year, now.month - monthsAgo, day, 12);

  Map<String, Object?> item(String id, String merchant, DateTime t, [String? cat]) => {
    'id': id,
    'amount': 10000,
    'dateTime': t.toIso8601String(),
    'merchant': merchant,
    'isCancel': false,
    'raw': 'NH기업0000승인',
    'category': cat,
  };

  // 이번 달 대기 2 · 지난달 대기 1 · 석 달 전 대기 1 · 이번 달 분류된 1 (대기 아님)
  final items = [
    item('a', '가식당', at(0, 1)),
    item('b', '나식당', at(0, 2)),
    item('c', '다식당', at(1, 10)),
    item('d', '라식당', at(3, 10)),
    item('e', '마주유소', at(0, 1), 'car'),
  ];

  test('pendingInView: 그 기간 대기만 최신순, 나머지는 개수', () {
    final list = [for (final m in items) Expense.fromJson(m)];
    final r = pendingInView(list, [DateTime(now.year, now.month)]);
    expect(r.here.map((e) => e.id), ['b', 'a']);
    expect(r.others, 2);
    final two = pendingInView(list, [DateTime(now.year, now.month - 1), DateTime(now.year, now.month)]);
    expect(two.here.map((e) => e.id), ['b', 'a', 'c']);
    expect(two.others, 1);
    expect(pendingInView(list, [DateTime(now.year, now.month - 6)]).others, 4);
  });

  Future<void> pumpHome(WidgetTester tester, [List<Map<String, Object?>>? seed]) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('card_expense/native'),
      (_) async => null,
    );
    SharedPreferences.setMockInitialValues({
      'card_digits': '0000',
      'sender_number': '1588-1600',
      'update_checked_at': DateTime.now().millisecondsSinceEpoch,
      'quiz_last_day_v1': quizDay(DateTime.now()),
      'expenses_v1': jsonEncode(seed ?? items),
    });
    tester.view.physicalSize = const Size(1080, 4680);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
    final store = await Store.open();
    await tester.pumpWidget(CardExpenseApp(store: store));
    await tester.pumpAndSettle();
  }

  Finder other(int n) => find.text('다른 달 미분류 $n건 ›');

  testWidgets('월 이동·보기 전환 때 분류 대기 카드가 그 기간 것으로, 다른 달 n건 숫자', (tester) async {
    await pumpHome(tester);
    // 이번 달 (1개월)
    expect(find.text('분류 대기 2건'), findsOneWidget);
    expect(find.text(keepWords('가식당')), findsOneWidget);
    expect(find.text(keepWords('다식당')), findsNothing);
    expect(other(2), findsOneWidget);

    // ◀ 지난달
    await tester.tap(find.byTooltip('이전'));
    await tester.pumpAndSettle();
    expect(find.text('분류 대기 1건'), findsOneWidget);
    expect(find.text(keepWords('다식당')), findsOneWidget);
    expect(find.text(keepWords('가식당')), findsNothing);
    expect(other(3), findsOneWidget);

    // ◀ 두 달 전: 그 달 대기 없음 → 카드 자리에 한 줄만
    await tester.tap(find.byTooltip('이전'));
    await tester.pumpAndSettle();
    expect(find.textContaining('분류 대기'), findsNothing);
    expect(other(4), findsOneWidget);

    // 보기 전환: 홀짝 → 보던 달이 속한 두 달 합산 화면
    await tester.tap(find.text('1개월 ▾'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('홀짝 ('));
    await tester.pumpAndSettle();
    final months = periodMonths(DateTime(now.year, now.month - 2), PeriodMode.oddEven);
    final list = [for (final m in items) Expense.fromJson(m)];
    final want = pendingInView(list, months);
    if (want.here.isEmpty) {
      expect(find.textContaining('분류 대기'), findsNothing);
    } else {
      expect(find.text('분류 대기 ${want.here.length}건'), findsOneWidget);
    }
    expect(other(want.others), findsOneWidget);

    // 한 줄을 누르면 미분류 내역 화면 (모든 달 4건)
    await tester.tap(other(want.others));
    await tester.pumpAndSettle();
    expect(find.text('미분류 내역 (4건)'), findsOneWidget);
  });

  testWidgets('2.1.1 한 줄 카드: 문자 원문 없이 가맹점·금액 + [차량비][운영비][무시], 높이 작게', (tester) async {
    await pumpHome(tester, [items[0]]);
    expect(find.text('분류 대기 1건'), findsOneWidget);
    expect(find.textContaining('NH기업0000승인'), findsNothing); // 원문은 메인에 안 보임
    final name = find.text(keepWords('가식당'));
    expect(name, findsOneWidget);
    final card = find.ancestor(of: name, matching: find.byType(Card)).first;
    expect(tester.getSize(card).height, lessThan(90));
    for (final t in ['차량비', '운영비', '무시']) {
      final b = find.descendant(of: card, matching: find.text(t));
      expect(b, findsOneWidget, reason: t);
      // 버튼이 가맹점 이름과 같은 줄(오른쪽)에 있다
      expect(tester.getCenter(b).dx, greaterThan(tester.getCenter(name).dx), reason: t);
      expect((tester.getCenter(b).dy - tester.getCenter(card).dy).abs(), lessThan(20), reason: t);
    }
    // 차량비 → 운영비 → 무시 순서
    final xs = [for (final t in ['차량비', '운영비', '무시']) tester.getCenter(find.descendant(of: card, matching: find.text(t))).dx];
    expect(xs[0] < xs[1] && xs[1] < xs[2], isTrue);
  });

  testWidgets('2.1.1 권한이 꺼져 있어도 메인에 권한 안내 배너가 안 뜸', (tester) async {
    await pumpHome(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('card_expense/native'),
      (call) async => call.method == 'permissionStatus' ? {'listener': false, 'sms': false, 'smsBlocked': false} : null,
    );
    await tester.pumpWidget(const SizedBox());
    final store = await Store.open();
    await tester.pumpWidget(CardExpenseApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('분류 대기 2건'), findsOneWidget);
    expect(find.textContaining('승인 문자 자동 감지'), findsNothing);
    expect(find.text('문자 권한'), findsNothing);
    expect(find.text('알림 접근 켜기'), findsNothing);
  });

  testWidgets('다른 달 미분류가 없으면 한 줄 없음', (tester) async {
    await pumpHome(tester, [items[0], items[1], items[4]]);
    expect(find.text('분류 대기 2건'), findsOneWidget);
    expect(find.textContaining('다른 달 미분류'), findsNothing);
  });

  testWidgets('2.1.1 그 기간에 미분류가 있으면 요약표 대신 안내, 다 분류하면 표', (tester) async {
    await pumpHome(tester);
    // 이번 달 대기 2건 → 안내가 덮고 표는 숨김(자리는 유지)
    expect(find.byType(PendingCover), findsOneWidget);
    expect(find.text(kPendingCoverText), findsOneWidget);
    expect(find.text('수립').hitTestable(), findsNothing);
    // 단위·보기 기간 줄은 그대로 누를 수 있음
    expect(find.text('1개월 ▾').hitTestable(), findsOneWidget);
    // 미분류가 없는 달(두 달 전)은 표
    await tester.tap(find.byTooltip('이전'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이전'));
    await tester.pumpAndSettle();
    expect(find.byType(PendingCover), findsNothing);
    expect(find.text('수립').hitTestable(), findsOneWidget);
  });

  testWidgets('2.1.1 다른 달에만 미분류가 있으면 이번 달 표는 보임', (tester) async {
    await pumpHome(tester, [items[2], items[4]]);
    expect(find.byType(PendingCover), findsNothing);
    expect(find.text('수립').hitTestable(), findsOneWidget);
  });

  testWidgets('2.1.2 미분류 내역 화면도 메인과 같은 한 줄 카드(버튼이 가맹점과 같은 줄, 오른쪽)', (tester) async {
    await pumpHome(tester);
    await tester.tap(other(2));
    await tester.pumpAndSettle();
    final name = find.text(keepWords('다식당'));
    expect(name, findsOneWidget);
    final card = find.ancestor(of: name, matching: find.byType(Card)).first;
    final car = find.descendant(of: card, matching: find.text('차량비'));
    final ignore = find.descendant(of: card, matching: find.text('무시'));
    expect(car, findsOneWidget);
    expect(ignore, findsOneWidget);
    // 버튼은 가맹점 오른쪽, 카드 세로 가운데 근처 (예전엔 가맹점 줄 아래에 따로)
    expect(tester.getCenter(car).dx, greaterThan(tester.getCenter(name).dx));
    expect((tester.getCenter(car).dy - tester.getCenter(card).dy).abs(), lessThan(12));
    expect(tester.getCenter(ignore).dx, greaterThan(tester.getCenter(car).dx));
  });

  testWidgets('2.1.2 분류 대기 카드 왼쪽을 누르면 세 줄(가맹점/금액/날짜)로 펼침, 다시 누르면 접힘', (tester) async {
    // item() 은 금액 10000 고정이라 금액만 바꿈
    final long = {...item('z', '아주아주긴이름의홍성현대셀프주유소본점', DateTime(now.year, now.month, 1, 13, 24)), 'amount': 94000};
    await pumpHome(tester, [long]);
    final info = find.byKey(const ValueKey('pending_info_z'));
    expect(info, findsOneWidget);
    final closedH = tester.getSize(info).height;
    // 접힘: 금액·날짜가 한 줄
    expect(find.textContaining('94,000원'), findsOneWidget);
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending_open')), findsOneWidget);
    expect(find.text('94,000원'), findsOneWidget); // 금액 줄 따로
    expect(find.text(fmtShortDateTime(DateTime(now.year, now.month, 1, 13, 24))), findsOneWidget); // 날짜 줄 따로
    expect(find.text('아주아주긴이름의홍성현대셀프주유소본점'), findsOneWidget); // 가맹점 전체
    expect(tester.getSize(info).height, greaterThan(closedH));
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending_open')), findsNothing);
    expect(tester.getSize(info).height, closeTo(closedH, 0.5));
  });
}
