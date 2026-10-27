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
