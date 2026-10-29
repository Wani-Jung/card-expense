import 'package:card_expense/category_badge.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/ignored_screen.dart';
import 'package:card_expense/vendor.dart';
import 'package:card_expense/vendor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _e(String id, String merchant, String? cat, DateTime at,
        {String? reason, String? dupOf}) =>
    Expense(
      id: id,
      amount: 10000,
      dateTime: at,
      merchant: merchant,
      isCancel: false,
      raw: '',
      category: cat,
      ignoreReason: reason,
      dupOf: dupOf,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  tester.view.viewPadding = const FakeViewPadding(bottom: 144);
  addTearDown(tester.view.reset);
}

Widget _small(String label, VoidCallback onPressed) =>
    SizedBox(height: 30, child: ElevatedButton(onPressed: onPressed, child: Text(label)));

void main() {
  group('무시 사유 저장', () {
    test('저장·불러오기, 예전 데이터는 직접 무시', () {
      final dup = _e('b', '편의점', kIgnored, DateTime(2026, 10, 1), reason: kIgnoreDuplicate, dupOf: 'a');
      final back = Expense.fromJson(dup.toJson());
      expect(back.ignoreReason, kIgnoreDuplicate);
      expect(back.dupOf, 'a');
      expect(back.ignoredAsDuplicate, isTrue);

      final old = Expense.fromJson({
        'id': 'x',
        'amount': 1000,
        'dateTime': DateTime(2026, 10, 1).toIso8601String(),
        'category': kIgnored,
      });
      expect(old.ignoreReason, isNull);
      expect(old.ignoredAsDuplicate, isFalse);
      // 무시 아닌 건은 사유 필드 자체를 저장 안 함
      expect(_e('c', '가게', kCar, DateTime(2026, 10, 1)).toJson().containsKey('ignoreReason'), isFalse);
    });
  });

  testWidgets('무시한 내역: 사유별 묶음, 중복 건은 원본 표시 + 되살리기만', (tester) async {
    _phone(tester);
    final orig = _e('a', '편의점', kCar, DateTime(2026, 12, 8, 13, 23));
    final dup = _e('b', '편의점', kIgnored, DateTime(2026, 12, 8, 13, 25), reason: kIgnoreDuplicate, dupOf: 'a');
    final manual = _e('c', '빵집', kIgnored, DateTime(2026, 12, 1));
    final items = [orig, dup, manual];
    Expense? revived;
    await tester.pumpWidget(MaterialApp(
      home: IgnoredScreen(
        items: items,
        recommend: (_) => null,
        changes: ValueNotifier(0),
        onChange: (e, cat) async => e.category = cat,
        onReviveOffset: (_) async {},
        onReviveDuplicate: (e) async {
          revived = e;
          e
            ..category = null
            ..ignoreReason = null
            ..dupOf = null;
        },
        carButton: (rec, p) => _small('차량비', p),
        opsButton: (rec, p) => _small('운영비', p),
      ),
    ));
    expect(find.text('직접 무시 (1건)'), findsOneWidget);
    expect(find.text('중복으로 무시 (1건)'), findsOneWidget);
    expect(find.text('중복이라 무시함 · 원본 12.08 13:23 (차량비)'), findsOneWidget);
    // 차량비/운영비 버튼은 직접 무시 건에만
    expect(find.text('차량비'), findsOneWidget);
    expect(find.text('대기로 되돌리기'), findsOneWidget);

    await tester.tap(find.text('중복 아님 · 되살리기'));
    await tester.pumpAndSettle();
    expect(revived, dup);
    expect(find.text('중복으로 무시 (1건)'), findsNothing);
    expect(find.text('직접 무시 (1건)'), findsOneWidget);
  });

  group('업체 관리', () {
    VendorBook book() {
      final b = VendorBook({}, []);
      for (var i = 0; i < 30; i++) {
        b.learn('업체${i.toString().padLeft(2, '0')}', i.isEven ? kCar : kOps);
      }
      return b;
    }

    testWidgets('고정 배지, 마지막 항목이 + 추가 버튼에 안 가림', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(home: VendorScreen(book: book(), onChanged: () async {})));
      expect(find.byType(CategoryBadge), findsWidgets);
      expect(find.byType(ActionChip), findsNothing);

      await tester.dragUntilVisible(find.text('업체29'), find.byType(ListView), const Offset(0, -500));
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      final lastBottom = tester.getBottomLeft(find.ancestor(of: find.text('업체29'), matching: find.byType(ListTile))).dy;
      final fabTop = tester.getTopLeft(find.byType(FloatingActionButton)).dy;
      expect(lastBottom, lessThanOrEqualTo(fabTop));
    });

    testWidgets('행 눌러 바텀시트에서 변경, 삭제는 이름 넣어 확인', (tester) async {
      _phone(tester);
      final b = VendorBook({}, [])..learn('고야커피', kOps);
      await tester.pumpWidget(MaterialApp(home: VendorScreen(book: b, onChanged: () async {})));

      await tester.tap(find.text('고야커피'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('차량비'));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(b.learned.values.single.category, kCar);

      await tester.tap(find.byTooltip('삭제'));
      await tester.pumpAndSettle();
      expect(find.text("'고야커피'를 목록에서 뺄까요?"), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(b.learned, hasLength(1));
      await tester.tap(find.byTooltip('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('빼기'));
      await tester.pumpAndSettle();
      expect(b.learned, isEmpty);
    });
  });
}
