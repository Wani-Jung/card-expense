import 'package:card_expense/budget.dart';
import 'package:card_expense/expense.dart';
import 'package:card_expense/sms_parser.dart';
import 'package:card_expense/update_check.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _e(int amount, String cat, DateTime at, {bool cancel = false}) => Expense(
      id: '${at.toIso8601String()}|$amount|${cancel ? 'C' : 'A'}',
      amount: amount,
      dateTime: at,
      merchant: '가맹점',
      isCancel: cancel,
      raw: '',
      category: cat,
    );

void main() {
  group('만원 변환', () {
    test('원 → 만원 소수점 둘째 자리', () {
      expect(manwon(342500), '34.25');
      expect(manwon(96000), '9.60');
      expect(manwon(0), '0.00');
      expect(manwon(-96000), '-9.60');
      expect(manwonOrDash(null), '-');
    });

    test('만원 입력 → 원', () {
      expect(parseManwon('34.25'), 342500);
      expect(parseManwon('50'), 500000);
      expect(parseManwon(' 1,234.5 '), 12345000);
      expect(parseManwon('0.01'), 100);
      expect(parseManwon(''), isNull); // 비우면 지우기
      expect(() => parseManwon('abc'), throwsFormatException);
      expect(() => parseManwon('-3'), throwsFormatException);
    });
  });

  group('운영비 수립 자동 계산', () {
    test('합계 − 차량비', () {
      const b = MonthBudget(total: 500000, car: 200000);
      expect(b.ops, 300000);
      expect(b.opsInvalid, isFalse);
    });

    test('차량비가 합계보다 크면 음수 = 입력 오류', () {
      const b = MonthBudget(total: 100000, car: 150000);
      expect(b.ops, -50000);
      expect(b.opsInvalid, isTrue);
    });

    test('둘 중 하나라도 비면 계산하지 않음', () {
      expect(const MonthBudget(total: 100000).ops, isNull);
      expect(const MonthBudget(car: 100000).ops, isNull);
      expect(const MonthBudget().opsInvalid, isFalse);
    });
  });

  group('초과 판정', () {
    test('사용 > 수립이면 초과', () {
      expect(isOverBudget(500001, 500000), isTrue);
      expect(isOverBudget(500000, 500000), isFalse);
      expect(isOverBudget(10, 500000), isFalse);
    });

    test('수립이 비어 있으면 판정 안 함', () {
      expect(isOverBudget(999999999, null), isFalse);
    });
  });

  group('월별 수립', () {
    test('새 달은 직전에 수립한 달 값을 그대로 쓰고, 바꾸면 그 달만 바뀜', () {
      final b = Budgets({});
      final jul = DateTime(2026, 7), aug = DateTime(2026, 8), sep = DateTime(2026, 9);
      b.setTotal(jul, 500000);
      b.setCar(jul, 200000);
      expect(b.forMonth(sep).total, 500000);
      expect(b.forMonth(sep).car, 200000);

      b.setCar(aug, 300000); // 8월만 차량비 변경, 합계는 7월 값 물려받음
      expect(b.forMonth(aug).total, 500000);
      expect(b.forMonth(aug).car, 300000);
      expect(b.forMonth(jul).car, 200000);
      expect(b.forMonth(sep).car, 300000); // 9월은 이제 8월 값을 물려받음
      expect(b.forMonth(DateTime(2026, 6)).total, isNull); // 이전 달은 영향 없음
    });

    test('저장했다 불러와도 같음', () {
      final b = Budgets({})..setTotal(DateTime(2026, 7), 342500);
      final back = Budgets.fromJson(b.toJson());
      expect(back.forMonth(DateTime(2026, 7)).total, 342500);
    });
  });

  test('사용 금액: 분류별 합계, 승인취소 차감, 다른 달·무시·대기는 제외', () {
    final m = DateTime(2026, 7);
    final items = [
      _e(96000, kCar, DateTime(2026, 7, 28)),
      _e(96000, kCar, DateTime(2026, 7, 29), cancel: true),
      _e(50000, kCar, DateTime(2026, 7, 30)),
      _e(12000, kOps, DateTime(2026, 7, 20)),
      _e(99999, kIgnored, DateTime(2026, 7, 20)),
      _e(77777, kOps, DateTime(2026, 8, 1)),
    ];
    final u = MonthUsage.of(items, m);
    expect(u.car, 50000);
    expect(u.ops, 12000);
    expect(u.total, 62000);
  });

  test('정산 텍스트에 수립/사용 포함', () {
    final m = DateTime(2026, 7);
    final t = settlementText([_e(342500, kCar, DateTime(2026, 7, 2))], m, '0000',
        const MonthBudget(total: 500000, car: 300000));
    expect(t, contains('수립/사용 (단위: 만원)'));
    expect(t, contains('합계: 수립 50.00 / 사용 34.25 / 잔여 15.75'));
    expect(t, contains('차량비: 수립 30.00 / 사용 34.25 / 초과 4.25'));
    expect(t, contains('운영비: 수립 20.00 / 사용 0.00\n'));
    expect(t, isNot(contains('운영비 계획')));
  });

  group('업데이트 버전 비교', () {
    test('태그와 앱 버전 비교', () {
      expect(isNewerVersion('v1.4.0', '1.3.0'), isTrue);
      expect(isNewerVersion('v1.10.0', '1.9.9'), isTrue);
      expect(isNewerVersion('v2.0.0', '1.99.99'), isTrue);
      expect(isNewerVersion('v1.4.0', '1.4.0'), isFalse);
      expect(isNewerVersion('v1.3.9', '1.4.0'), isFalse);
      expect(isNewerVersion('v1.4.1', '1.4.0+12'), isTrue);
    });

    test('형식이 이상하면 새 버전 아님', () {
      expect(isNewerVersion('dev', '1.0.0'), isFalse);
      expect(isNewerVersion('', '1.0.0'), isFalse);
      expect(parseVersion('v1.4'), isNull);
      expect(parseVersion('v1.4.0'), [1, 4, 0]);
    });
  });

  group('여러 건 붙여넣기 쪼개기', () {
    test('[Web발신] 없이 이어 붙은 문자도 카드번호+승인 단위로 나눈다', () {
      const pasted = 'NH기업0000승인\n공용카드\n96,000원 체크\n07/28 16:26\n(주)월산주유소\n'
          'NH기업0000승인\n공용카드\n12,000원 체크\n07/29 12:01\n김밥천국\n'
          'NH기업0000승인취소\n공용카드\n12,000원 체크\n07/29 12:30\n김밥천국';
      final parts = splitMessages(pasted);
      expect(parts, hasLength(3));
      final parsed = [
        for (final p in parts) parseSms(p, cardDigits: '0000', receivedAt: DateTime(2026, 8, 1))!,
      ];
      expect(parsed.map((p) => p.amount), [96000, 12000, 12000]);
      expect(parsed.map((p) => p.merchant), ['(주)월산주유소', '김밥천국', '김밥천국']);
      expect(parsed.map((p) => p.isCancel), [false, false, true]);
    });

    test('[Web발신] 과 섞여 있어도 한 건씩', () {
      const pasted = '[Web발신]\nNH기업0000승인 5,000원 07/28 09:00 편의점\n'
          '[Web발신]\nNH기업0000승인 6,000원 07/28 10:00 빵집 NH기업0000승인 7,000원 07/28 11:00 꽃집';
      expect(splitMessages(pasted), hasLength(3));
    });
  });

  group('잔여·초과', () {
    test('잔여 = 수립 − 사용, 수립이 비면 null', () {
      expect(remaining(500000, 342500), 157500);
      expect(remaining(null, 342500), isNull);
      expect(remaining(300000, 342500), -42500);
    });

    test('표기: 비면 -, 마이너스면 초과', () {
      expect(remainingText(null), '-');
      expect(remainingText(157500), '15.75');
      expect(remainingText(0), '0.00');
      expect(remainingText(-35000), '초과 3.50');
    });

    test('정산 텍스트: 수립이 없으면 잔여 -, 운영비는 잔여 생략', () {
      final t = settlementText([_e(10000, kOps, DateTime(2026, 7, 2))], DateTime(2026, 7), '0000');
      expect(t, contains('합계: 수립 - / 사용 1.00 / 잔여 -'));
      expect(t, contains('운영비: 수립 - / 사용 1.00\n'));
    });

    test('정산 텍스트: 운영비 계획 초과, 차량비 잔여 > 합계 잔여 참고', () {
      final m = DateTime(2026, 7);
      // 합계 50 / 차량비 30 → 운영비 20. 운영비 25 사용, 차량비 5 사용
      final t = settlementText([
        _e(250000, kOps, DateTime(2026, 7, 2)),
        _e(50000, kCar, DateTime(2026, 7, 3)),
      ], m, '0000', const MonthBudget(total: 500000, car: 300000));
      expect(t, contains('운영비 계획 +5.00'));
      expect(t, contains('차량비: 수립 30.00 / 사용 5.00 / 잔여 25.00 (합계 잔여 20.00)'));
    });

    test('정산 텍스트: 두 달 합산 보기면 합산 표도', () {
      final budgets = Budgets({})
        ..setTotal(DateTime(2026, 9), 500000)
        ..setCar(DateTime(2026, 9), 300000);
      final items = [_e(100000, kCar, DateTime(2026, 9, 2)), _e(200000, kCar, DateTime(2026, 10, 2))];
      final p = PeriodSummary.of(budgets, items, periodMonths(DateTime(2026, 10), PeriodMode.oddEven));
      final t = settlementText(items, DateTime(2026, 10), '0000', budgets.forMonth(DateTime(2026, 10)), p);
      expect(t, contains('■ 9~10월 합산 수립/사용 (단위: 만원)'));
      expect(t, contains('차량비: 수립 60.00 / 사용 30.00 / 잔여 30.00'));
    });
  });

  group('합계·차량비 상태 3단계', () {
    test('경계값 80% / 100%', () {
      expect(budgetLevel(799999, 1000000), BudgetLevel.ok);
      expect(budgetLevel(800000, 1000000), BudgetLevel.warn);
      expect(budgetLevel(1000000, 1000000), BudgetLevel.warn);
      expect(budgetLevel(1000001, 1000000), BudgetLevel.over);
      expect(budgetLevel(5000000, null), BudgetLevel.ok);
    });

    test('차량비 잔여가 합계 잔여보다 클 때만 참고 문구', () {
      expect(carRemainHint(200000, 250000), '합계 잔여 20.00');
      expect(carRemainHint(-10000, 50000), '합계 초과 상태');
      expect(carRemainHint(300000, 250000), isNull);
      expect(carRemainHint(null, 250000), isNull);
    });

    test('운영비는 계획보다 더 썼을 때만 계획 +X.XX', () {
      expect(opsOverText(200000, 250000), '계획 +5.00');
      expect(opsOverText(200000, 200000), isNull);
      expect(opsOverText(null, 250000), isNull);
    });
  });

  group('보기 기간 묶음', () {
    List<String> ms(int y, int m, PeriodMode mode) =>
        periodMonths(DateTime(y, m), mode).map((d) => '${d.year}-${d.month}').toList();

    test('1개월', () {
      expect(ms(2026, 9, PeriodMode.single), ['2026-9']);
      expect(periodButtonLabel(DateTime(2026, 9), PeriodMode.single), '1개월');
    });

    test('홀짝: (1·2)(3·4)…(11·12)', () {
      expect(ms(2026, 9, PeriodMode.oddEven), ['2026-9', '2026-10']);
      expect(ms(2026, 10, PeriodMode.oddEven), ['2026-9', '2026-10']);
      expect(ms(2026, 1, PeriodMode.oddEven), ['2026-1', '2026-2']);
      expect(ms(2026, 12, PeriodMode.oddEven), ['2026-11', '2026-12']);
      expect(periodButtonLabel(DateTime(2026, 10), PeriodMode.oddEven), '9~10월 합산');
    });

    test('짝홀: (2·3)…(12·1), 연도 넘김', () {
      expect(ms(2026, 10, PeriodMode.evenOdd), ['2026-10', '2026-11']);
      expect(ms(2026, 11, PeriodMode.evenOdd), ['2026-10', '2026-11']);
      expect(ms(2026, 12, PeriodMode.evenOdd), ['2026-12', '2027-1']);
      expect(ms(2027, 1, PeriodMode.evenOdd), ['2026-12', '2027-1']);
      expect(periodButtonLabel(DateTime(2027, 1), PeriodMode.evenOdd), '12~1월 합산');
    });

    test('합산: 수립·사용 더하기, 한 달이라도 수립이 비면 -', () {
      final budgets = Budgets({})..setTotal(DateTime(2026, 12), 500000);
      final items = [
        _e(100000, kCar, DateTime(2026, 12, 5)),
        _e(30000, kOps, DateTime(2027, 1, 3)),
        _e(70000, kCar, DateTime(2026, 11, 3)), // 묶음 밖
      ];
      final p = PeriodSummary.of(budgets, items, periodMonths(DateTime(2026, 12), PeriodMode.evenOdd));
      expect(p.budget.total, 1000000); // 1월은 12월 수립을 물려받음
      expect(p.budget.car, isNull); // 차량비 수립은 비어 있음
      expect(p.usage.car, 100000);
      expect(p.usage.ops, 30000);
      expect(remainingText(remaining(p.budget.car, p.usage.car)), '-');

      final p2 = PeriodSummary.of(Budgets({}), items, periodMonths(DateTime(2026, 12), PeriodMode.evenOdd));
      expect(p2.budget.total, isNull);
    });
  });
}
