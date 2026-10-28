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

  testWidgets('메뉴 내역 관리 3개 항목·건수 배지, 각 화면 열기', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    for (final t in ['미분류 내역', '확인 필요 내역', '무시한 내역']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('0건'), findsNWidgets(3));
    // 설정은 카드 문자 설정 하나 (저장된 값 표시), 앱 정보 맨 아래 제작자
    expect(find.text('카드번호 변경'), findsNothing);
    expect(find.text('발신번호 변경'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('카드 0000 · 발신 1588-1600'), findsOneWidget);
    expect(find.text('제작자'), findsOneWidget);
    expect(find.text('wani'), findsOneWidget);
    await tester.tap(find.text('카드 문자 설정'));
    await tester.pumpAndSettle();
    expect(find.text('기본값으로'), findsOneWidget);
    expect(find.textContaining('제작자'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
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
  });
}
