import 'package:card_expense/check.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/vendor.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 28, 12);
var _seq = 0;

Expense _e(String merchant, String? cat, DateTime at, {int amount = 10000, bool cancel = false}) => Expense(
      id: '${at.toIso8601String()}|$amount|${cancel ? 'C' : 'A'}|${_seq++}',
      amount: amount,
      dateTime: at,
      merchant: merchant,
      isCancel: cancel,
      raw: '',
      category: cat,
    );

List<CheckIssue> _find(List<Expense> items, {VendorBook? vendors, Set<String> ok = const {}}) =>
    findIssues(items, vendors ?? VendorBook({}, []), now: _now, okKeys: ok);

List<CheckIssue> _of(List<CheckIssue> all, CheckRule r) => all.where((i) => i.rule == r).toList();

void main() {
  group('a. 같은 가맹점 분류 섞임', () {
    test('다수와 다른 쪽만, 이유에 평소 분류', () {
      final items = [
        for (var i = 0; i < 9; i++) _e('월산주유소', kCar, DateTime(2026, 10, 1 + i)),
        _e('(주)월산 주유소', kOps, DateTime(2026, 10, 20)),
      ];
      final a = _of(_find(items), CheckRule.mixedVendor);
      expect(a, hasLength(1));
      expect(a.single.e.category, kOps);
      expect(a.single.reason, contains('평소엔 차량비로 분류한 업체예요'));
      expect(a.single.reason, contains('10건 중 9건'));
    });

    test('반반이거나 한쪽만이면 표시 안 함, 대기·무시는 안 셈', () {
      expect(
          _of(_find([_e('가게', kCar, DateTime(2026, 10, 1)), _e('가게', kOps, DateTime(2026, 10, 2))]),
              CheckRule.mixedVendor),
          isEmpty);
      expect(
          _of(
              _find([
                _e('가게', kCar, DateTime(2026, 10, 1)),
                _e('가게', null, DateTime(2026, 10, 2)),
                _e('가게', kIgnored, DateTime(2026, 10, 3)),
              ]),
              CheckRule.mixedVendor),
          isEmpty);
    });
  });

  group('b. 추천·등록 업체와 반대', () {
    test('차량 추천 키워드인데 운영비', () {
      final b = _of(_find([_e('강남셀프주유소', kOps, DateTime(2026, 10, 1))], vendors: VendorBook.initial()),
          CheckRule.recommendMismatch);
      expect(b, hasLength(1));
      expect(b.single.reason, contains('차량비 추천 키워드'));
    });

    test('등록 업체와 반대로 분류', () {
      final v = VendorBook({}, [])..learn('홍성칼국수', kOps);
      final b = _of(_find([_e('홍성칼국수', kCar, DateTime(2026, 10, 1))], vendors: v), CheckRule.recommendMismatch);
      expect(b.single.reason, '등록 업체는 운영비인데 차량비로 분류했어요');
    });

    test('추천과 같으면 표시 안 함, a 에 걸린 건은 b 에 또 안 나옴', () {
      final v = VendorBook.initial();
      expect(_find([_e('강남셀프주유소', kCar, DateTime(2026, 10, 1))], vendors: v), isEmpty);
      final items = [
        _e('월산주유소', kCar, DateTime(2026, 10, 1)),
        _e('월산주유소', kCar, DateTime(2026, 10, 2)),
        _e('월산주유소', kOps, DateTime(2026, 10, 3)),
      ];
      final all = _find(items, vendors: v);
      expect(_of(all, CheckRule.mixedVendor), hasLength(1));
      expect(_of(all, CheckRule.recommendMismatch), isEmpty);
    });
  });

  group('c. 중복 의심', () {
    test('같은 가맹점·금액 10분 이내 2건 → 둘 다, 묶음 포함', () {
      final items = [
        _e('편의점', kOps, DateTime(2026, 10, 1, 9, 0)),
        _e('편의점', kOps, DateTime(2026, 10, 1, 9, 10)),
      ];
      final c = _of(_find(items), CheckRule.duplicate);
      expect(c, hasLength(2));
      expect(c.first.reason, contains('같은 결제가 두 번 들어온 것 같아요'));
      expect(c.first.group, hasLength(2));
    });

    test('10분 넘게 차이·금액 다름·무시한 건은 아님', () {
      expect(
          _of(
              _find([
                _e('편의점', kOps, DateTime(2026, 10, 1, 9, 0)),
                _e('편의점', kOps, DateTime(2026, 10, 1, 9, 11)),
                _e('편의점', kOps, DateTime(2026, 10, 1, 9, 12), amount: 5000),
                _e('편의점', kIgnored, DateTime(2026, 10, 1, 9, 13)),
              ]),
              CheckRule.duplicate),
          isEmpty);
    });
  });

  group('d. 승인취소 짝', () {
    test('원승인 없는 취소', () {
      final d = _of(_find([_e('빵집', kOps, DateTime(2026, 10, 2), cancel: true)]), CheckRule.cancelPair);
      expect(d.single.reason, contains('원래 승인 내역이 없는 취소'));
    });

    test('원승인과 분류가 다름 / 같으면 표시 안 함 / 원승인이 대기여도 짝은 있음', () {
      final orig = _e('빵집', kCar, DateTime(2026, 10, 1));
      final d = _of(_find([orig, _e('빵집', kOps, DateTime(2026, 10, 2), cancel: true)]), CheckRule.cancelPair);
      expect(d.single.reason, contains('차량비로 분류돼 있어요'));

      expect(_find([_e('빵집', kOps, DateTime(2026, 10, 1)), _e('빵집', kOps, DateTime(2026, 10, 2), cancel: true)]),
          isEmpty);
      expect(_find([_e('빵집', null, DateTime(2026, 10, 1)), _e('빵집', kOps, DateTime(2026, 10, 2), cancel: true)]),
          isEmpty);
    });
  });

  group('e. 날짜 이상', () {
    test('미래 날짜, 1년보다 오래된 날짜', () {
      final all = _of(
          _find([
            _e('가게A', kOps, _now.add(const Duration(days: 3))),
            _e('가게B', kOps, _now.subtract(const Duration(days: 400))),
            _e('가게C', kOps, _now.subtract(const Duration(days: 300))),
          ]),
          CheckRule.oddDate);
      expect(all.map((i) => i.e.merchant), unorderedEquals(['가게A', '가게B']));
      expect(all.firstWhere((i) => i.e.merchant == '가게A').reason, contains('미래 날짜'));
      expect(all.firstWhere((i) => i.e.merchant == '가게B').reason, contains('1년보다 오래된'));
    });
  });

  test('이대로 맞아요 한 건은 다시 안 나옴, 규칙 순서로 정렬', () {
    final future = _e('가게A', kOps, _now.add(const Duration(days: 3)));
    final cancel = _e('빵집', kOps, DateTime(2026, 10, 2), cancel: true);
    final all = _find([future, cancel]);
    expect(all.map((i) => i.rule), [CheckRule.cancelPair, CheckRule.oddDate]);
    expect(_find([future, cancel], ok: {all.last.key}).map((i) => i.rule), [CheckRule.cancelPair]);
  });
}
