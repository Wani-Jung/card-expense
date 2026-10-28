import 'expense.dart';

/// 월별 수립(예산). 금액은 원 단위로 저장하고 화면에는 만원으로 보여준다.
/// 운영비 수립은 따로 입력받지 않고 합계 − 차량비로 계산한다.
class MonthBudget {
  final int? total;
  final int? car;
  const MonthBudget({this.total, this.car});

  int? get ops => total == null || car == null ? null : total! - car!;

  /// 차량비 수립이 합계보다 커서 운영비가 음수가 되는 입력 오류.
  bool get opsInvalid => (ops ?? 0) < 0;

  Map<String, dynamic> toJson() => {'total': total, 'car': car};

  factory MonthBudget.fromJson(Map<String, dynamic> j) =>
      MonthBudget(total: j['total'] as int?, car: j['car'] as int?);
}

/// 월별 수립 모음. 수립이 없는 달은 직전에 수립한 달의 값을 그대로 쓴다.
class Budgets {
  final Map<String, MonthBudget> byMonth;
  Budgets(this.byMonth);

  static String keyOf(DateTime month) => '${month.year}-${two(month.month)}';

  MonthBudget forMonth(DateTime month) {
    final key = keyOf(month);
    final own = byMonth[key];
    if (own != null) return own;
    final earlier = byMonth.keys.where((k) => k.compareTo(key) < 0).toList()..sort();
    return earlier.isEmpty ? const MonthBudget() : byMonth[earlier.last]!;
  }

  /// 그 달만 바꾼다. 물려받던 다른 칸 값은 그 달에 그대로 복사해 둔다.
  void setTotal(DateTime month, int? won) {
    byMonth[keyOf(month)] = MonthBudget(total: won, car: forMonth(month).car);
  }

  void setCar(DateTime month, int? won) {
    byMonth[keyOf(month)] = MonthBudget(total: forMonth(month).total, car: won);
  }

  Map<String, dynamic> toJson() => byMonth.map((k, v) => MapEntry(k, v.toJson()));

  factory Budgets.fromJson(Map<String, dynamic> j) =>
      Budgets(j.map((k, v) => MapEntry(k, MonthBudget.fromJson(v as Map<String, dynamic>))));
}

/// 그 달 분류된 내역의 사용 금액. 승인취소는 차감된다.
class MonthUsage {
  final int car;
  final int ops;
  const MonthUsage(this.car, this.ops);
  int get total => car + ops;

  factory MonthUsage.of(Iterable<Expense> items, DateTime month) {
    var car = 0, ops = 0;
    for (final e in items.where((e) => e.inMonth(month))) {
      if (e.category == kCar) car += e.signedAmount;
      if (e.category == kOps) ops += e.signedAmount;
    }
    return MonthUsage(car, ops);
  }
}

/// 원 → 만원, 소수점 둘째 자리. 342500 → "34.25"
String manwon(int won) => (won / 10000).toStringAsFixed(2);

String manwonOrDash(int? won) => won == null ? '-' : manwon(won);

/// 만원 입력 → 원. "34.25" → 342500. 빈칸은 null(지우기), 숫자가 아니거나 음수면 throw.
int? parseManwon(String input) {
  final t = input.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v < 0) throw const FormatException('만원 단위 숫자를 입력해주세요');
  return (v * 10000).round();
}

/// 사용이 수립을 넘었는지. 수립이 비어 있으면 판정하지 않는다.
bool isOverBudget(int used, int? budget) => budget != null && used > budget;

/// 잔여 = 수립 − 사용 (원). 수립이 비면 null.
int? remaining(int? plan, int used) => plan == null ? null : plan - used;

/// 잔여 표기 (만원). 비면 '-', 마이너스면 부호 대신 '초과 3.50'.
String remainingText(int? rem) => rem == null ? '-' : (rem < 0 ? '초과 ${manwon(-rem)}' : manwon(rem));

/// 합계·차량비 상태. 여유: 사용 < 수립의 80% / 주의: 80% 이상 ~ 100% 이하 / 초과: 100% 초과.
enum BudgetLevel { ok, warn, over }

BudgetLevel budgetLevel(int used, int? plan) {
  if (plan == null) return BudgetLevel.ok;
  if (used > plan) return BudgetLevel.over;
  if (plan > 0 && used * 10 >= plan * 8) return BudgetLevel.warn;
  return BudgetLevel.ok;
}

/// 차량비 잔여가 합계 잔여보다 크면 차량비 칸 아래에 붙이는 참고 문구. 아니면 null.
String? carRemainHint(int? totalRem, int? carRem) {
  if (totalRem == null || carRem == null || carRem <= totalRem) return null;
  return totalRem < 0 ? '합계 초과 상태' : '합계 잔여 ${manwon(totalRem)}';
}

/// 운영비는 잔여를 보여주지 않고, 사용이 수립을 넘을 때만 '계획 +X.XX'. 아니면 null.
String? opsOverText(int? opsPlan, int used) =>
    opsPlan == null || opsPlan < 0 || used <= opsPlan ? null : '계획 +${manwon(used - opsPlan)}';

/// 요약표 보기 기간. 앱을 켤 때마다 [single] 로 시작한다 (저장 안 함).
enum PeriodMode { single, oddEven, evenOdd }

String periodModeLabel(PeriodMode m) => switch (m) {
      PeriodMode.single => '1개월',
      PeriodMode.oddEven => '홀짝 (1·2월, 3·4월 …)',
      PeriodMode.evenOdd => '짝홀 (2·3월, 4·5월 …)',
    };

/// [month] 가 들어 있는 묶음의 달들. 홀짝은 (1·2)(3·4)…(11·12), 짝홀은 (2·3)…(12·1) — 12·1 은 연도를 넘긴다.
List<DateTime> periodMonths(DateTime month, PeriodMode mode) {
  final m = DateTime(month.year, month.month);
  if (mode == PeriodMode.single) return [m];
  final odd = m.month.isOdd;
  final startsHere = mode == PeriodMode.oddEven ? odd : !odd;
  // DateTime 은 13월·0월을 다음 해 1월·전년 12월로 넘겨 준다.
  return startsHere
      ? [m, DateTime(m.year, m.month + 1)]
      : [DateTime(m.year, m.month - 1), m];
}

/// 버튼 글씨. "1개월" / "9~10월 합산" / "12~1월 합산"
String periodButtonLabel(DateTime month, PeriodMode mode) {
  if (mode == PeriodMode.single) return '1개월';
  final ms = periodMonths(month, mode);
  return '${ms.first.month}~${ms.last.month}월 합산';
}

/// 여러 달 합산 표. 한 달이라도 수립이 비어 있으면 그 칸은 null('-').
class PeriodSummary {
  final List<DateTime> months;
  final MonthBudget budget;
  final MonthUsage usage;
  const PeriodSummary(this.months, this.budget, this.usage);

  factory PeriodSummary.of(Budgets budgets, Iterable<Expense> items, List<DateTime> months) {
    int? sum(int? Function(MonthBudget) f) {
      var s = 0;
      for (final m in months) {
        final v = f(budgets.forMonth(m));
        if (v == null) return null;
        s += v;
      }
      return s;
    }

    var car = 0, ops = 0;
    for (final m in months) {
      final u = MonthUsage.of(items, m);
      car += u.car;
      ops += u.ops;
    }
    return PeriodSummary(months, MonthBudget(total: sum((b) => b.total), car: sum((b) => b.car)), MonthUsage(car, ops));
  }

  String get label =>
      months.length == 1 ? '${months.first.month}월' : '${months.first.month}~${months.last.month}월 합산';
}
