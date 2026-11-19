import 'dart:convert';

import 'package:card_expense/budget.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/layout.dart';
import 'package:card_expense/main.dart';
import 'package:card_expense/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-52: 요약표 단위 기본 원, 차량비 잔여 경고 아이콘·안내, 홀짝·짝홀을 고르면 두 달 합산 화면부터.
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

  /// 이번 달 수립·사용(원)을 넣고 메인을 띄운다
  Future<Store> pumpMonth(
    WidgetTester tester, {
    int? total,
    int? car,
    int usedCar = 0,
    int usedOps = 0,
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
        Budgets.keyOf(now): {'total': ?total, 'car': ?car},
      }),
      'expenses_v1': jsonEncode([if (usedCar > 0) item('a', kCar, usedCar), if (usedOps > 0) item('b', kOps, usedOps)]),
      ...extra,
    });
    final store = await Store.open();
    await tester.pumpWidget(CardExpenseApp(store: store));
    await tester.pumpAndSettle();
    return store;
  }

  final warn = find.byKey(const ValueKey('car_remain_warn'));
  final warnIcon = find.byIcon(Icons.error);

  group('A 단위 기본값 원', () {
    test('저장값 없음 → 원, 저장값 있으면 그대로', () async {
      expect(MoneyUnit.byName(null), MoneyUnit.won);
      for (final u in MoneyUnit.values) {
        SharedPreferences.setMockInitialValues({'money_unit_v1': u.name});
        expect((await Store.open()).moneyUnit, u);
      }
      SharedPreferences.setMockInitialValues({});
      expect((await Store.open()).moneyUnit, MoneyUnit.won);
    });

    testWidgets('처음 설치: 표는 원, (반올림) 없음', (tester) async {
      await pumpMonth(tester, total: 1000000, car: 400000, usedCar: 342500);
      expect(find.text('단위: 원 ▾'), findsOneWidget);
      expect(find.text('342,500'), findsWidgets);
      expect(find.text('(반올림)'), findsNothing);
    });

    testWidgets('예전에 만원을 고른 사용자는 만원 그대로', (tester) async {
      await pumpMonth(tester, total: 1000000, car: 400000, usedCar: 342500, extra: {'money_unit_v1': 'man'});
      expect(find.text('단위: 만원 ▾'), findsOneWidget);
      expect(find.text('34'), findsWidgets);
    });
  });

  group('B 차량비 잔여 경고', () {
    test('조건 경계', () {
      expect(carRemainWarn(100000, 60000), isTrue);
      expect(carRemainWarn(100000, 99999), isTrue); // 1원 차이
      expect(carRemainWarn(100000, 100000), isFalse); // 같으면 표시 안 함
      expect(carRemainWarn(100000, -50000), isTrue);
      expect(carRemainWarn(0, -50000), isFalse); // 차량비 잔여 0
      expect(carRemainWarn(-1000, -50000), isFalse); // 차량비 초과
      expect(carRemainWarn(null, 1000), isFalse);
      expect(carRemainWarn(1000, null), isFalse);
    });

    test('문구: 합계 양수/음수, 단위별 금액', () {
      expect(
        carRemainWarnMessage(101000, 64000, MoneyUnit.won),
        '차량비는 101,000원 남았지만, 운영비가 초과돼서 전체 남은 돈은 64,000원이에요.\n차량비를 다 쓰면 총액을 넘으니 유의하세요.',
      );
      expect(
        carRemainWarnMessage(101000, -50000, MoneyUnit.won),
        '차량비는 101,000원 남았지만, 운영비 초과로 전체는 이미 50,000원 초과예요.\n차량비를 더 쓰면 초과 금액이 커지니 유의하세요.',
      );
      expect(carRemainWarnMessage(101000, 64000, MoneyUnit.thousand), startsWith('차량비는 101천원 남았지만'));
      expect(carRemainWarnMessage(101000, 64000, MoneyUnit.thousand), contains('전체 남은 돈은 64천원이에요'));
      expect(carRemainWarnMessage(345000, 64000, MoneyUnit.man), startsWith('차량비는 35만원 남았지만'));
      expect(carRemainWarnMessage(345000, 64000, MoneyUnit.man), contains('전체 남은 돈은 6만원이에요'));
      expect(carRemainWarnMessage(345000, 0, MoneyUnit.man), contains('전체 남은 돈은 0만원이에요'));
    });

    testWidgets('운영비 초과로 합계 잔여 < 차량비 잔여 → 아이콘, 숫자는 자기 값, 칸 탭으로 안내', (tester) async {
      // 합계 100만·차량 40만, 사용 차량 30만·운영 64만 → 차량 잔여 10만, 합계 잔여 6만
      await pumpMonth(tester, total: 1000000, car: 400000, usedCar: 300000, usedOps: 640000);
      expect(warn, findsOneWidget);
      expect(warnIcon, findsOneWidget);
      final icon = tester.widget<Icon>(warnIcon);
      expect(icon.color, kCarWarn);
      expect(icon.size, inInclusiveRange(18, 20));
      expect(find.text('100,000'), findsOneWidget); // 차량비 잔여 숫자 그대로
      // 칸 왼쪽 아래(아이콘과 먼 곳)를 눌러도 안내
      final cell = tester.getRect(warn);
      await tester.tapAt(cell.bottomLeft + const Offset(6, -6));
      await tester.pumpAndSettle();
      expect(
        find.text(keepWords('차량비는 100,000원 남았지만, 운영비가 초과돼서 전체 남은 돈은 60,000원이에요.\n차량비를 다 쓰면 총액을 넘으니 유의하세요.')),
        findsOneWidget,
      );
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      // 아이콘 자체를 눌러도
      await tester.tap(warnIcon);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('아이콘은 오른쪽 위, 누르는 범위 40×40 이상, 7자리 숫자와 안 겹침', (tester) async {
      // 차량 잔여 1,234,560 · 합계 잔여 1,134,560
      await pumpMonth(tester, total: 2000000, car: 1500000, usedCar: 265440, usedOps: 600000);
      expect(warn, findsOneWidget);
      final cell = tester.getRect(warn);
      final ic = tester.getRect(warnIcon);
      expect(ic.right, closeTo(cell.right, 4));
      expect(ic.top, closeTo(cell.top, 4));
      expect(cell.width, greaterThanOrEqualTo(40));
      expect(cell.height, greaterThanOrEqualTo(40));
      final num = tester.getRect(find.text('1,234,560'));
      expect(num.overlaps(ic), isFalse, reason: 'num $num icon $ic');
      expect(tester.takeException(), isNull);
    });

    testWidgets('합계 잔여가 음수면 초과 문구', (tester) async {
      await pumpMonth(tester, total: 1000000, car: 400000, usedCar: 300000, usedOps: 750000);
      await tester.tap(warn);
      await tester.pumpAndSettle();
      expect(find.textContaining(keepWords('전체는 이미 50,000원 초과예요')), findsOneWidget);
    });

    testWidgets('표시 안 함: 같을 때·차량비 잔여 0·차량비 초과·운영비 여유', (tester) async {
      for (final (car, ops) in [(300000, 600000), (400000, 700000), (450000, 600000), (300000, 500000)]) {
        await pumpMonth(tester, total: 1000000, car: 400000, usedCar: car, usedOps: ops);
        expect(warn, findsNothing, reason: '$car/$ops');
        expect(warnIcon, findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
      // 1원 차이는 표시
      await pumpMonth(tester, total: 1000000, car: 400000, usedCar: 300000, usedOps: 600001);
      expect(warn, findsOneWidget);
    });
  });

  group('B-2 홀짝·짝홀은 합산 화면부터', () {
    String title(DateTime m, PeriodMode mode, {bool combined = false}) =>
        PeriodView(combined ? periodMonths(m, mode).first : m, combined: combined).title(mode);

    Future<void> pickMode(WidgetTester tester, String current, String label) async {
      await tester.tap(find.text('$current ▾'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('홀짝 → 합산, 짝홀 → 합산, 1개월 → 보던 달, 앱 시작은 1개월', (tester) async {
      await pumpMonth(tester, total: 1000000, car: 400000);
      final now = DateTime(DateTime.now().year, DateTime.now().month);
      expect(find.text(title(now, PeriodMode.single)), findsOneWidget); // 보기는 저장 안 함 → 시작은 1개월
      await pickMode(tester, '1개월', periodModeLabel(PeriodMode.oddEven));
      expect(find.text(title(now, PeriodMode.oddEven, combined: true)), findsOneWidget);
      await pickMode(tester, '홀짝', periodModeLabel(PeriodMode.evenOdd));
      expect(find.text(title(now, PeriodMode.evenOdd, combined: true)), findsOneWidget);
      await pickMode(tester, '짝홀', periodModeLabel(PeriodMode.single));
      // 합산 화면에서 1개월로 → 묶음 첫째 달 월 화면
      expect(find.text(title(periodMonths(now, PeriodMode.evenOdd).first, PeriodMode.single)), findsOneWidget);
    });

    testWidgets('연말 묶음: 12월에서 짝홀 → 12월~다음 해 1월 합산, 월 숫자를 누르면 그 달 월 화면', (tester) async {
      await pumpMonth(tester, total: 1000000, car: 400000);
      final y = DateTime.now().year;
      await tester.tap(find.text('12').first);
      await tester.pumpAndSettle();
      expect(find.text('$y년 12월'), findsOneWidget);
      await pickMode(tester, '1개월', periodModeLabel(PeriodMode.evenOdd));
      expect(find.text('$y년 12월~${y + 1}년 1월 합산'), findsOneWidget);
      // ◀ 순서는 그대로: 합산 → 둘째 달 (1월)
      await tester.tap(find.byTooltip('이전'));
      await tester.pumpAndSettle();
      expect(find.text('${y + 1}년 1월'), findsOneWidget);
    });

    testWidgets('합산 화면에서도 같은 경고 규칙', (tester) async {
      // 묶음 두 달 모두 합계 100만·차량 40만, 이번 달 사용 차량 30만·운영 130만
      // → 두 달 합산: 차량 잔여 50만 > 합계 잔여 40만
      final now = DateTime.now();
      final pair = periodMonths(now, PeriodMode.oddEven);
      await pumpMonth(
        tester,
        usedCar: 300000,
        usedOps: 1300000,
        extra: {
          'budgets_v1': jsonEncode({
            for (final m in pair) Budgets.keyOf(m): {'total': 1000000, 'car': 400000},
          }),
        },
      );
      await pickMode(tester, '1개월', periodModeLabel(PeriodMode.oddEven));
      expect(find.text(title(now, PeriodMode.oddEven, combined: true)), findsOneWidget);
      expect(warn, findsOneWidget);
      await tester.tap(warn);
      await tester.pumpAndSettle();
      expect(
        find.text(keepWords('차량비는 500,000원 남았지만, 운영비가 초과돼서 전체 남은 돈은 400,000원이에요.\n차량비를 다 쓰면 총액을 넘으니 유의하세요.')),
        findsOneWidget,
      );
    });
  });
}
