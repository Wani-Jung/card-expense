import 'dart:convert';

import 'package:card_expense/expense.dart';
import 'package:card_expense/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 메인 화면이 그려지는지 (표·월 진행 표시줄·◀ ▶), 넘김·표시줄 터치가 동작하는지.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 네이티브 채널은 빈 응답
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('card_expense/native'), (_) async => null);
    SharedPreferences.setMockInitialValues({
      'card_digits': '0000',
      'sender_number': '1588-1600',
      // 업데이트 확인(네트워크) 건너뛰기
      'update_checked_at': DateTime.now().millisecondsSinceEpoch,
    });
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    // 하단 3버튼 내비게이션 바(48dp)
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
    final store = await Store.open();
    await tester.pumpWidget(CardExpenseApp(store: store));
    await tester.pumpAndSettle();
  }

  testWidgets('월 진행 표시줄 1~12, ◀ ▶ 위치 고정, 표시줄 터치로 이동', (tester) async {
    await pumpHome(tester);
    final now = DateTime.now();
    expect(find.text('${now.year}년 ${now.month}월'), findsOneWidget);
    for (var m = 1; m <= 12; m++) {
      expect(find.text('$m'), findsWidgets);
    }

    final prev = tester.getTopLeft(find.byTooltip('이전'));
    final next = tester.getTopLeft(find.byTooltip('다음'));

    // 홀짝으로 바꾸고 합산 화면까지 넘겨도 화살표 위치 그대로
    await tester.tap(find.text('1개월 ▾'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('홀짝 ('));
    await tester.pumpAndSettle();
    expect(find.text('홀짝 ▾'), findsOneWidget);
    var sawCombined = false;
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('다음'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byTooltip('이전')), prev);
      expect(tester.getTopLeft(find.byTooltip('다음')), next);
      if (find.textContaining('월 합산').evaluate().isNotEmpty) sawCombined = true;
    }
    expect(sawCombined, isTrue);

    // 표시줄 숫자 터치 → 그 달 월 화면
    // (넘기다 보면 해가 바뀔 수 있으니 연도는 보지 않음)
    await tester.tap(find.text('7').first);
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^\d{4}년 7월$')), findsOneWidget);
  });

  testWidgets('요약표 좌우 스와이프 = ◀ ▶, 짧게 밀면 그대로', (tester) async {
    await pumpHome(tester);
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1);
    final prev = DateTime(now.year, now.month - 1);
    String t(DateTime d) => '${d.year}년 ${d.month}월';

    // 짧게(30px) 밀면 안 넘어감
    await tester.drag(find.text('수립'), const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(find.text(t(now)), findsOneWidget);
    // 세로로 더 크게 움직이면 안 넘어감
    await tester.drag(find.text('수립'), const Offset(-80, 120));
    await tester.pumpAndSettle();
    expect(find.text(t(now)), findsOneWidget);

    // 왼쪽으로 밀기 → 다음 달, 오른쪽 두 번 → 이전 달
    await tester.drag(find.text('수립'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text(t(next)), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.drag(find.text('수립'), const Offset(200, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text(t(prev)), findsOneWidget);
  });

  testWidgets('메뉴: 섹션 없이 7개 한 화면, 내역 관리·결제내역 입력 펼침, 권한 설정', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    const titles = ['결제내역 입력', '내역 관리', '등록 업체·추천 키워드', '카드 문자 설정', '권한 설정', '업데이트 확인', '제작자'];
    for (final t in titles) {
      expect(find.text(t), findsOneWidget);
    }
    for (final gone in ['내역 넣기', '정산', '업체 관리', '설정', '앱 정보', '이번 달 내역 복사', '현재 버전', '알림 접근 설정']) {
      expect(find.text(gone), findsNothing);
    }
    // 스크롤 없이 마지막 항목이 하단 바(48dp) 위에 보임
    expect(tester.getBottomLeft(find.text('wani')).dy, lessThan(780 - 48));
    expect(find.text('카드 0000 · 발신 1588-1600'), findsOneWidget);
    expect(find.text('알림 감지 권한 필요'), findsOneWidget);

    // 확인 필요 0건이면 내역 관리는 접힌 채 시작
    expect(find.text('미분류 내역'), findsNothing);
    await tester.tap(find.text('내역 관리'));
    await tester.pumpAndSettle();
    expect(find.text('0건'), findsNWidgets(4)); // 합계 + 하위 3개
    await tester.tap(find.text('결제내역 입력'));
    await tester.pumpAndSettle();
    expect(find.text('문자 붙여넣기'), findsOneWidget);
    expect(find.text('문자 캡처화면 업로드'), findsOneWidget);

    for (final (t, empty) in [
      ('미분류 내역', '미분류 내역이 없어요'),
      ('확인 필요 내역', '확인이 필요한 내역이 없어요'),
      ('무시한 내역', '무시한 내역이 없어요'),
    ]) {
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
      expect(find.text(empty), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('카드 문자 설정'));
    await tester.pumpAndSettle();
    expect(find.text('기본값으로'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 권한 설정: 스위치를 끄면 기기에 저장되고 메뉴 설명도 바뀜
    await tester.tap(find.text('권한 설정'));
    await tester.pumpAndSettle();
    expect(find.text('알림 감지'), findsOneWidget);
    expect(find.text('꺼짐'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getBool('use_listener_v1'), isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('알림 감지 꺼짐'), findsOneWidget);
  });

  testWidgets('무시한 내역에서 차량비 고르면 같은 업체 무시·대기 건 일괄 정리, 되돌리기', (tester) async {
    Map<String, Object?> item(String id, String merchant, String? cat, int day, [String? reason]) => {
          'id': id,
          'amount': 10000,
          'dateTime': DateTime(DateTime.now().year, DateTime.now().month, day, 12).toIso8601String(),
          'merchant': merchant,
          'isCancel': false,
          'raw': '',
          'category': cat,
          'ignoreReason': ?reason,
        };
    SharedPreferences.setMockInitialValues({
      'card_digits': '0000',
      'sender_number': '1588-1600',
      'update_checked_at': DateTime.now().millisecondsSinceEpoch,
      'expenses_v1': jsonEncode([
        item('a', '고야커피', 'ignored', 1),
        item('b', '고야커피', 'ignored', 2),
        item('c', '고야커피', null, 3),
        item('d', '고야커피', 'ignored', 4, 'duplicate'),
      ]),
    });
    await pumpHome(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내역 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('무시한 내역'));
    await tester.pumpAndSettle();
    expect(find.text('직접 무시 (2건)'), findsOneWidget);

    await tester.tap(find.text('차량비').first);
    await tester.pumpAndSettle();
    expect(find.text("'고야커피' 무시·대기 내역 2건도 차량비로 정리할까요?"), findsOneWidget);
    await tester.tap(find.text('모두 정리'));
    await tester.pumpAndSettle();
    // 직접 무시 2건 + 대기 1건이 차량비로, 중복으로 무시한 건은 그대로
    expect(find.text('직접 무시 (2건)'), findsNothing);
    expect(find.text('중복으로 무시 (1건)'), findsOneWidget);
    Map<String, String?> cats() => {
          for (final e in jsonDecode(prefs.getString('expenses_v1')!) as List)
            (e as Map)['id'] as String: e['category'] as String?,
        };
    expect(cats(), {'a': 'car', 'b': 'car', 'c': 'car', 'd': 'ignored'});

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('직접 무시 (2건)'), findsOneWidget);
    expect(cats(), {'a': 'ignored', 'b': 'ignored', 'c': null, 'd': 'ignored'});
  });
}
