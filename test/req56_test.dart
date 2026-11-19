import 'package:card_expense/budget.dart';
import 'package:card_expense/demo.dart';
import 'package:card_expense/expense.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REQ-56: 스토어 스크린샷 데모 데이터 규모 — 수립 총액 45만·차량비 30만, 어느 장면도 초과·차량비 잔여 경고 없음.
void main() {
  ({int car, int ops}) used(List<Expense> items, List<DateTime> months) {
    var car = 0, ops = 0;
    for (final e in items) {
      if (!months.any((m) => m.year == e.dateTime.year && m.month == e.dateTime.month)) continue;
      if (e.category == kCar) car += e.signedAmount;
      if (e.category == kOps) ops += e.signedAmount;
    }
    return (car: car, ops: ops);
  }

  for (final now in [DateTime(2026, 11, 19, 15), DateTime(2026, 12, 2, 8, 30), DateTime(2027, 1, 28, 18)]) {
    for (final (pending, issues) in [(false, false), (true, false), (false, true)]) {
      test('${now.month}월 ${now.day}일 · 대기 $pending · 확인 필요 $issues: 1개월·두 달 합산 모두 수립 안, 경고 없음', () async {
        SharedPreferences.setMockInitialValues({});
        await seedDemo(await SharedPreferences.getInstance(), now: now, pending: pending, issues: issues);
        final store = await Store.open();
        final items = store.loadItems();
        final budgets = store.loadBudgets();
        final month = DateTime(now.year, now.month);
        final prev = DateTime(now.year, now.month - 1);
        expect(budgets.forMonth(month).total, 450000);
        expect(budgets.forMonth(month).car, 300000);
        expect(budgets.forMonth(month).ops, 150000);

        for (final months in [
          [month],
          [prev],
          [prev, month],
        ]) {
          final u = used(items, months);
          final planTotal = 450000 * months.length, planCar = 300000 * months.length;
          final totalRem = planTotal - u.car - u.ops, carRem = planCar - u.car;
          final label = months.map((m) => m.month).join('+');
          expect(u.car, lessThanOrEqualTo(planCar), reason: '$label 차량비');
          expect(u.ops, lessThanOrEqualTo(planTotal - planCar), reason: '$label 운영비');
          expect(totalRem, greaterThan(0), reason: '$label 합계');
          expect(carRemainWarn(carRem, totalRem), isFalse, reason: '$label 경고 ($carRem > $totalRem)');
        }
        // 한 달 사용 규모: 차량비 약 18~22만, 운영비 약 9~11만 (분류된 기본 건 기준)
        if (!issues) {
          final u = used(items, [month]);
          expect(u.car, inInclusiveRange(180000, 220000));
          expect(u.ops, inInclusiveRange(90000, 110000));
        }
        // 개별 금액: 주유 5~8만, 식사 1~2만 원대
        for (final e in items) {
          if (e.merchant.contains('주유')) expect(e.amount, inInclusiveRange(50000, 80000), reason: e.merchant);
          if (RegExp('식당|국밥|칼국수|한식').hasMatch(e.merchant)) {
            expect(e.amount, inInclusiveRange(10000, 29999), reason: e.merchant);
          }
        }
      });
    }
  }
}
