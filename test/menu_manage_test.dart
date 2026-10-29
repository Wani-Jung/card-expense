import 'dart:convert';

import 'package:card_expense/expense.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-38: 메뉴 펼침 하나만, 메뉴 위 화면·돌아오면 배지 갱신, 배지 색, 확인한 내역, 무시한 내역 되살리기 → 미분류
void main() {
  final now = DateTime.now();
  DateTime at(int monthsAgo, int day, [int hour = 12]) => DateTime(now.year, now.month - monthsAgo, day, hour);

  Map<String, Object?> item(
    String id,
    String merchant,
    String? cat,
    DateTime t, {
    int amount = 10000,
    bool cancel = false,
    String? reason,
    String? dupOf,
    String? from,
  }) => {
    'id': id,
    'amount': amount,
    'dateTime': t.toIso8601String(),
    'merchant': merchant,
    'isCancel': cancel,
    'raw': 'NH기업0000승인',
    'category': cat,
    'ignoreReason': ?reason,
    'dupOf': ?dupOf,
    'ignoredFrom': ?from,
  };

  late SharedPreferences prefs;

  Future<void> pumpHome(WidgetTester tester, List<Map<String, Object?>> items) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('card_expense/native'),
      (_) async => null,
    );
    SharedPreferences.setMockInitialValues({
      'card_digits': '0000',
      'sender_number': '1588-1600',
      'update_checked_at': DateTime.now().millisecondsSinceEpoch,
      'quiz_last_day_v1': quizDay(DateTime.now()),
      'expenses_v1': jsonEncode(items),
    });
    prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
    final store = await Store.open();
    await tester.pumpWidget(CardExpenseApp(store: store));
    await tester.pumpAndSettle();
  }

  Map<String, Map> stored() => {
    for (final e in jsonDecode(prefs.getString('expenses_v1')!) as List) (e as Map)['id'] as String: e,
  };

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
  }

  /// 내역 관리 펼치기 (확인 필요가 있으면 이미 펼친 채 시작)
  Future<void> openManage(WidgetTester tester) async {
    if (find.text('미분류 내역').evaluate().isNotEmpty) return;
    await tester.tap(find.text('내역 관리'));
    await tester.pumpAndSettle();
  }

  Color? badgeColor(WidgetTester tester, Finder row, String text) {
    final c = tester.widget<Container>(
      find.ancestor(of: find.descendant(of: row, matching: find.text(text)), matching: find.byType(Container)).first,
    );
    return (c.decoration as BoxDecoration).color;
  }

  testWidgets('펼침은 하나만, 메뉴 위 화면 → 뒤로가기 하면 메뉴(펼침 유지·배지 갱신), 배지 색', (tester) async {
    await pumpHome(tester, [
      item('p1', '새가게', null, at(0, 1)),
      item('i1', '무시가게', kIgnored, at(0, 2)),
      item('c1', '분류가게', kCar, at(0, 3)),
    ]);
    await openMenu(tester);
    // 확인 필요 0건 → 접힌 채 시작
    expect(find.text('미분류 내역'), findsNothing);
    await tester.tap(find.text('내역 관리'));
    await tester.pumpAndSettle();
    expect(find.text('미분류 내역'), findsOneWidget);
    expect(find.text('확인한 내역'), findsOneWidget);
    // 결제내역 입력을 펼치면 내역 관리는 접힘
    await tester.tap(find.text('결제내역 입력'));
    await tester.pumpAndSettle();
    expect(find.text('문자 붙여넣기'), findsOneWidget);
    expect(find.text('미분류 내역'), findsNothing);
    await tester.tap(find.text('내역 관리'));
    await tester.pumpAndSettle();
    expect(find.text('문자 붙여넣기'), findsNothing);

    // 배지 색: 미분류 1 → 빨강, 확인 필요 0 → 회색, 무시 1·확인한 1 → 검정, 내역 관리 합계 1 → 빨강
    const red = Color(0xFFD93025), black = Color(0xFF1F1F1F), grey = Color(0xFFF1F3F4);
    ListTile tile(String t) => tester.widget<ListTile>(find.ancestor(of: find.text(t), matching: find.byType(ListTile)));
    Finder row(String t) => find.ancestor(of: find.text(t), matching: find.byType(ListTile));
    expect(tile('미분류 내역').trailing, isNotNull);
    expect(badgeColor(tester, row('미분류 내역'), '1건'), red);
    expect(badgeColor(tester, row('확인 필요 내역'), '0건'), grey);
    expect(badgeColor(tester, row('무시한 내역'), '1건'), black);
    expect(badgeColor(tester, row('확인한 내역'), '1건'), black);
    expect(badgeColor(tester, row('내역 관리'), '1건'), red);

    // 미분류 내역에서 분류 → 뒤로가기 → 메뉴, 펼침 유지, 배지 갱신
    await tester.tap(find.text('미분류 내역'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('운영비').first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('메뉴'), findsOneWidget);
    expect(find.text('미분류 내역'), findsOneWidget); // 펼침 그대로
    expect(badgeColor(tester, row('미분류 내역'), '0건'), grey);
    expect(badgeColor(tester, row('확인한 내역'), '2건'), black);

    // 문자 붙여넣기도 메뉴 위에 → 뒤로가기 하면 메뉴
    await tester.tap(find.text('결제내역 입력'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('문자 붙여넣기'));
    await tester.pumpAndSettle();
    expect(find.text('메뉴'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('메뉴'), findsOneWidget);
    expect(find.text('문자 붙여넣기'), findsOneWidget);

    // 등록 업체·추천 키워드도
    await tester.tap(find.text('등록 업체·추천 키워드'));
    await tester.pumpAndSettle();
    expect(find.text('업체 관리'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('메뉴'), findsOneWidget);
  });

  testWidgets('확인한 내역: 분류된 건만, 칩·월별 합계(취소 차감)·검색, 편집 시트로 변경·되돌리기', (tester) async {
    await pumpHome(tester, [
      item('a', '홍성주유소', kCar, at(0, 2), amount: 50000),
      item('b', '홍성주유소', kCar, at(0, 3), amount: 20000, cancel: true),
      item('c', '김밥나라', kOps, at(0, 4), amount: 8000),
      item('d', '지난달식당', kOps, at(1, 5), amount: 12000),
      item('p', '대기가게', null, at(0, 6)),
      item('x', '무시가게', kIgnored, at(0, 7)),
    ]);
    await openMenu(tester);
    await openManage(tester);
    await tester.tap(find.text('확인한 내역'));
    await tester.pumpAndSettle();
    expect(find.text('확인한 내역 (4건)'), findsOneWidget);
    expect(find.text('대기가게'), findsNothing);
    expect(find.text('무시가게'), findsNothing);
    final m0 = '${at(0, 1).year}년 ${at(0, 1).month}월';
    final m1 = '${at(1, 1).year}년 ${at(1, 1).month}월';
    expect(find.text('$m0 · 3건 · 합계 38,000원'), findsOneWidget); // 50,000 − 20,000 + 8,000
    expect(find.text('$m1 · 1건 · 합계 12,000원'), findsOneWidget);
    expect(find.text('-20,000원'), findsOneWidget);

    await tester.tap(find.text('차량비'));
    await tester.pumpAndSettle();
    expect(find.text('$m0 · 2건 · 합계 30,000원'), findsOneWidget);
    expect(find.text('김밥나라'), findsNothing);
    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '김밥');
    await tester.pumpAndSettle();
    expect(find.text('김밥나라'), findsOneWidget);
    expect(find.text('홍성주유소'), findsNothing);

    // 편집 시트로 차량비로 변경 → 스낵바 [되돌리기]
    await tester.tap(find.text('김밥나라'));
    await tester.pumpAndSettle();
    expect(find.text('미분류로 되돌리기'), findsOneWidget);
    expect(find.text('무시'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, '차량비'));
    await tester.pumpAndSettle();
    expect(stored()['c']!['category'], kCar);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(stored()['c']!['category'], kOps);
  });

  testWidgets('확인한 내역이 없으면 안내', (tester) async {
    await pumpHome(tester, [item('p', '대기가게', null, at(0, 6))]);
    await openMenu(tester);
    await openManage(tester);
    await tester.tap(find.text('확인한 내역'));
    await tester.pumpAndSettle();
    expect(find.text('확인한 내역이 없어요'), findsOneWidget);
  });

  testWidgets('무시한 내역 되살리기 3종 → 미분류, 사유 필드 삭제, [되돌리기] 복구, 재표시 방지 기억', (tester) async {
    await pumpHome(tester, [
      item('m', '직접가게', kIgnored, at(0, 2), reason: kIgnoreManual),
      item('o1', '중복가게', kCar, at(0, 3, 9)),
      item('o2', '중복가게', kIgnored, at(0, 3, 10), reason: kIgnoreDuplicate, dupOf: 'o1'),
      item('s1', '취소가게', kIgnored, at(0, 4, 9), amount: 30000, reason: kIgnoreOffset, from: kOps),
      item('s2', '취소가게', kIgnored, at(0, 4, 10), amount: 30000, cancel: true, reason: kIgnoreOffset, from: kOps),
    ]);
    await openMenu(tester);
    await openManage(tester);
    await tester.tap(find.text('무시한 내역'));
    await tester.pumpAndSettle();

    // 1) 직접 무시 [대기로 되돌리기]
    await tester.tap(find.text('대기로 되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('미분류 내역으로 옮겼어요'), findsOneWidget);
    expect(find.text('보기'), findsOneWidget);
    expect(stored()['m']!['category'], isNull);
    expect(stored()['m']!.containsKey('ignoreReason'), isFalse);
    // [되돌리기] → 원래 무시 상태·사유 그대로
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(stored()['m']!['category'], kIgnored);
    expect(stored()['m']!['ignoreReason'], kIgnoreManual);

    // 2) 중복 아님 · 되살리기 → 미분류, dupOf 삭제, 쌍 기억
    await tester.tap(find.text('중복 아님 · 되살리기'));
    await tester.pumpAndSettle();
    expect(stored()['o2']!['category'], isNull);
    expect(stored()['o2']!.containsKey('dupOf'), isFalse);
    final ok = prefs.getStringList('check_ok_v1')!;
    expect(ok.any((k) => k.startsWith('dup|')), isTrue);
    // [되돌리기] 해도 기억은 남음
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(stored()['o2']!['ignoreReason'], kIgnoreDuplicate);
    expect(stored()['o2']!['dupOf'], 'o1');
    expect(prefs.getStringList('check_ok_v1')!.any((k) => k.startsWith('dup|')), isTrue);

    // 3) 승인 후 취소 [되살리기] → 두 건 모두 미분류 (무시 전 분류로 돌리지 않음), ignoredFrom 삭제, 묶음 기억
    await tester.tap(find.text('되살리기'));
    await tester.pumpAndSettle();
    expect(find.text('2건을 미분류 내역으로 옮겼어요'), findsOneWidget);
    for (final id in ['s1', 's2']) {
      expect(stored()[id]!['category'], isNull);
      expect(stored()[id]!.containsKey('ignoredFrom'), isFalse);
      expect(stored()[id]!.containsKey('ignoreReason'), isFalse);
    }
    expect(prefs.getStringList('check_ok_v1')!.any((k) => k.startsWith('cancelled|')), isTrue);

    // [보기] → 미분류 내역 화면
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('미분류 내역 ('), findsOneWidget);
    expect(find.textContaining('취소가게'), findsNWidgets(2));
  });
}
