import 'package:card_expense/budget.dart';
import 'package:card_expense/cancel_link.dart';
import 'package:card_expense/check.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/vendor.dart';
import 'package:flutter_test/flutter_test.dart';

var _seq = 0;

Expense _e(String? cat, DateTime at, {bool cancel = false, int amount = 94000, String merchant = '(주)월산주유소'}) =>
    Expense(
      id: '${at.toIso8601String()}|$amount|${cancel ? 'C' : 'A'}|${_seq++}',
      amount: amount,
      dateTime: at,
      merchant: merchant,
      isCancel: cancel,
      raw: '',
      category: cat,
    );

final _now = DateTime(2026, 12, 20);
List<CheckIssue> _issues(List<Expense> items, [Set<String> ok = const {}]) =>
    findIssues(items, VendorBook({}, []), now: _now, okKeys: ok);
List<CheckIssue> _of(List<CheckIssue> all, CheckRule r) => all.where((i) => i.rule == r).toList();

void main() {
  // 12/08 13:23 승인 → 13:24 승인취소 → 13:24 재승인 (같은 가맹점·금액)
  late Expense a1, c, a2;
  setUp(() {
    a1 = _e(kCar, DateTime(2026, 12, 8, 13, 23));
    c = _e(kCar, DateTime(2026, 12, 8, 13, 24), cancel: true);
    a2 = _e(kCar, DateTime(2026, 12, 8, 13, 24));
  });

  test('승인 → 취소 → 재승인: 원승인은 13:23, 합계 94,000, 중복 의심 0, 승인 후 취소 1', () {
    final items = [a2, c, a1];
    final links = linkCancels(items);
    expect(links[c.id]!.origin, a1);

    expect(MonthUsage.of(items, DateTime(2026, 12)).car, 94000);
    final all = _issues(items);
    expect(_of(all, CheckRule.duplicate), isEmpty);
    expect(_of(all, CheckRule.cancelPair), isEmpty);
    final cancelled = _of(all, CheckRule.cancelled);
    expect(cancelled, hasLength(1));
    expect(cancelled.single.group, [a1, c]);
    expect(cancelled.single.rebuy, a2);
  });

  test('확인했어요(취소로 상쇄) 하면 합계 그대로, 승인 후 취소에서 빠짐. 되살리기 기억 키로 다시 안 뜸', () {
    final items = [a1, c, a2];
    final issue = _of(_issues(items), CheckRule.cancelled).single;
    for (final t in issue.group) {
      t
        ..ignoredFrom = t.category
        ..category = kIgnored
        ..ignoreReason = kIgnoreOffset;
    }
    expect(MonthUsage.of(items, DateTime(2026, 12)).car, 94000);
    expect(_of(_issues(items), CheckRule.cancelled), isEmpty);
    expect(a1.ignoredAsOffset && c.ignoredAsOffset, isTrue);

    // 되살리기: 원래 분류로, 기억한 키로 다시 안 뜸
    for (final t in issue.group) {
      t
        ..category = t.ignoredFrom
        ..ignoreReason = null
        ..ignoredFrom = null;
    }
    expect(a1.category, kCar);
    expect(_of(_issues(items, {issue.key}), CheckRule.cancelled), isEmpty);
  });

  test('원승인 없는 취소는 취소 짝 불일치', () {
    final lone = _e(kOps, DateTime(2026, 12, 8, 9), cancel: true, merchant: '빵집');
    final all = _issues([lone]);
    expect(_of(all, CheckRule.cancelPair).single.reason, contains('원래 승인 내역이 없는 취소'));
    expect(_of(all, CheckRule.cancelled), isEmpty);
  });

  test('같은 날 같은 금액 정상 결제 2건(취소 없음)은 여전히 중복 의심', () {
    final x = _e(kOps, DateTime(2026, 12, 8, 12, 0), amount: 9000, merchant: '김밥천국');
    final y = _e(kOps, DateTime(2026, 12, 8, 12, 3), amount: 9000, merchant: '김밥천국');
    expect(_of(_issues([x, y]), CheckRule.duplicate), hasLength(1));
  });

  test('새 취소는 원승인 분류를 따라감 (원승인이 대기면 그대로)', () {
    final pending = _e(null, DateTime(2026, 12, 8, 13, 24), cancel: true);
    expect(followOrigins([a1, pending]), [pending]);
    expect(pending.category, kCar);

    final o = _e(null, DateTime(2026, 12, 9, 10));
    final cc = _e(null, DateTime(2026, 12, 9, 11), cancel: true);
    expect(followOrigins([o, cc]), isEmpty);
    expect(cc.category, isNull);
  });

  test('기존 데이터 바로잡기: 중복으로 무시된 재결제 되살림, 취소 분류 맞춤', () {
    // v1.13: 재승인을 [하나 무시] (원본 = 13:23), 취소는 운영비로 잘못
    a2
      ..category = kIgnored
      ..ignoreReason = kIgnoreDuplicate
      ..dupOf = a1.id;
    c.category = kOps;
    // 진짜 중복(사이에 취소 없음)은 그대로 둔다
    final d1 = _e(kOps, DateTime(2026, 12, 10, 9, 0), amount: 5000, merchant: '편의점');
    final d2 = _e(kIgnored, DateTime(2026, 12, 10, 9, 2), amount: 5000, merchant: '편의점')
      ..ignoreReason = kIgnoreDuplicate
      ..dupOf = d1.id;
    final items = [a1, c, a2, d1, d2];

    expect(fixCancelRebuys(items), 2);
    expect(a2.category, kCar);
    expect(a2.ignoreReason, isNull);
    expect(c.category, kCar);
    expect(d2.ignoredAsDuplicate, isTrue);
    expect(MonthUsage.of(items, DateTime(2026, 12)).car, 94000);
    expect(_of(_issues(items), CheckRule.cancelled), hasLength(1));
    expect(fixCancelRebuys(items), 0);
  });

  test('저장·불러오기: 취소로 상쇄 전 분류 유지', () {
    final e = _e(kIgnored, DateTime(2026, 12, 8))
      ..ignoreReason = kIgnoreOffset
      ..ignoredFrom = kCar;
    final back = Expense.fromJson(e.toJson());
    expect(back.ignoredAsOffset, isTrue);
    expect(back.ignoredFrom, kCar);
  });
}
