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

  factory MonthBudget.fromJson(Map<String, dynamic> j) => MonthBudget(total: j['total'] as int?, car: j['car'] as int?);
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

/// 원 → 만원, 소수점 둘째 자리까지, 끝자리 0 은 생략 (REQ-49). 342500 → "34.25", 350000 → "35", 85000 → "8.5"
String manwon(int won) {
  final s = (won / 10000).toStringAsFixed(2);
  final t = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return t == '-0' ? '0' : t;
}

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

/// 잔여 값 기준 상태: 사용 = 수립 − 잔여 로 보고 [budgetLevel]
BudgetLevel remainLevel(int? plan, int? rem) =>
    plan == null || rem == null ? BudgetLevel.ok : budgetLevel(plan - rem, plan);

/// 잔여 표기 (만원). 비면 '-', 마이너스면 부호 대신 '초과 3.5'.
String remainingText(int? rem) => remainingIn(rem, MoneyUnit.man);

/// 요약표 단위 (REQ-50). 화면 표시만 바꾸고 계산·저장은 원 단위 그대로.
enum MoneyUnit {
  man('만원'),
  thousand('천원'),
  won('원');

  final String label;
  const MoneyUnit(this.label);

  /// 저장된 선택이 없으면 원 (REQ-52). 고른 적 있으면 그 값 그대로
  static MoneyUnit byName(String? n) => values.firstWhere((u) => u.name == n, orElse: () => won);
}

/// 차량비 잔여 경고 (REQ-52): 차량비 잔여 > 0 이고 차량비 잔여 > 합계 잔여일 때
/// (= 운영비를 수립보다 많이 써서 전체 남은 돈이 차량비 잔여보다 적음). 숫자는 바꾸지 않고 아이콘·안내만.
bool carRemainWarn(int? carRem, int? totalRem) =>
    carRem != null && totalRem != null && carRem > 0 && carRem > totalRem;

/// 차량비 잔여 경고 안내 문구. 금액은 지금 단위·규칙 + 단위 글자 (원·천원·만원 모두 받침 있음 → '이에요')
/// 줄은 직접 나눈다(REQ-55: 문장 중간에서 어색하게 끊기지 않게, 빈 줄로 두 문단).
String carRemainWarnMessage(int carRem, int totalRem, MoneyUnit u) {
  String amt(int w) => moneyWithUnit(w, u);
  return totalRem >= 0
      ? '차량비는 ${amt(carRem)} 남았지만,\n운영비가 초과돼서\n전체 남은 돈은 ${amt(totalRem)}이에요.\n\n'
            '차량비를 다 쓰면 총액을 넘으니\n유의하세요.'
      : '차량비는 ${amt(carRem)} 남았지만,\n운영비 초과로\n전체는 이미 ${amt(-totalRem)} 초과예요.\n\n'
            '차량비를 더 쓰면 초과 금액이 커지니\n유의하세요.';
}

/// 경고 팝업 제목
const kCarRemainWarnTitle = '차량비 잔여 주의';

/// 금액 + 단위 글자 ('101,000원', '10천원', '35만원')
String moneyWithUnit(int won, MoneyUnit u) => '${money(won, u)}${u.label}';

/// 경고 팝업 숫자 칸 값: 전체 잔여 (마이너스면 '초과 X')
String totalRemainWithUnit(int totalRem, MoneyUnit u) =>
    totalRem < 0 ? '초과 ${moneyWithUnit(-totalRem, u)}' : moneyWithUnit(totalRem, u);

/// 단위 옆 '(반올림)' 을 보일지 (만원·천원만, REQ-51)
bool showsRounding(MoneyUnit u) => u != MoneyUnit.won;

/// '(반올림)' 을 누르면 보이는 안내
const kRoundingNote = "칸마다 반올림해서\n합계와 1 정도 다를 수 있어요.\n\n정확한 금액은 '원' 단위로 보세요.";

/// '(반올림)' 안내 팝업 제목 (REQ-59)
const kRoundingTitle = '반올림해서 보여 줘요';

/// 천 단위 쉼표. 1234560 → "1,234,560"
String groupDigits(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// 원 → 단위 표기. 만원 = 소수 둘째 자리 반올림·끝자리 0 생략, 천원 = 반올림·정수·쉼표, 원 = 쉼표
/// 화면 표시 (REQ-51): 만원·천원 = 그 단위로 반올림한 정수 + 천 단위 쉼표 (342,500 → 34 / 343), 원 = 쉼표.
/// 칸마다 원 단위 값을 반올림하므로 칸의 합과 합계가 1 정도 다를 수 있다 (보정하지 않음, '(반올림)' 안내)
String money(int won, MoneyUnit u) => switch (u) {
  MoneyUnit.man => groupDigits((won / 10000).round()),
  MoneyUnit.thousand => groupDigits((won / 1000).round()),
  MoneyUnit.won => groupDigits(won),
};

String moneyOrDash(int? won, MoneyUnit u) => won == null ? '-' : money(won, u);

/// 잔여 표기 (단위). 비면 '-', 마이너스면 부호 대신 '초과 X' (같은 단위·규칙)
String remainingIn(int? rem, MoneyUnit u) => rem == null ? '-' : (rem < 0 ? '초과 ${money(-rem, u)}' : money(rem, u));

/// 단위 입력 → 원. 만원은 소수 둘째 자리까지, 천원·원은 정수만 (쉼표 무시). 빈칸은 null, 잘못되면 throw.
int? parseMoney(String input, MoneyUnit u) {
  if (u == MoneyUnit.man) return parseManwon(input);
  final t = input.trim().replaceAll(',', '');
  if (t.isEmpty) return null;
  final v = int.tryParse(t);
  if (v == null || v < 0) throw FormatException('${u.label} 단위 정수를 입력해주세요');
  return u == MoneyUnit.thousand ? v * 1000 : v;
}

/// 입력칸에서 받는 글자 (만원은 소수점 허용)
RegExp moneyInputChars(MoneyUnit u) => u == MoneyUnit.man ? RegExp(r'[0-9.]') : RegExp(r'[0-9,]');

/// 입력칸 처음 값 (쉼표 없이)
/// 편집칸에 미리 채우는 값: 만원은 반올림하지 않은 원래 값(끝자리 0 생략, 34.25), 천원·원은 쉼표 없이
String moneyInputText(int won, MoneyUnit u) => u == MoneyUnit.man ? manwon(won) : money(won, u).replaceAll(',', '');

/// 합계·차량비 상태. 여유: 사용 < 수립의 80% / 주의: 80% 이상 ~ 100% 이하 / 초과: 100% 초과.
enum BudgetLevel { ok, warn, over }

BudgetLevel budgetLevel(int used, int? plan) {
  if (plan == null) return BudgetLevel.ok;
  if (used > plan) return BudgetLevel.over;
  if (plan > 0 && used * 10 >= plan * 8) return BudgetLevel.warn;
  return BudgetLevel.ok;
}

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
  return startsHere ? [m, DateTime(m.year, m.month + 1)] : [DateTime(m.year, m.month - 1), m];
}

/// 버튼 글씨는 모드 이름만. 어느 기간인지는 위쪽 제목에서 보인다.
String periodModeShort(PeriodMode m) => switch (m) {
  PeriodMode.single => '1개월',
  PeriodMode.oddEven => '홀짝',
  PeriodMode.evenOdd => '짝홀',
};

/// 메인 화면이 보고 있는 단계. 월 화면이면 그 달, 합산 화면이면 묶음의 첫째 달 + [combined].
class PeriodView {
  final DateTime month;
  final bool combined;
  PeriodView(DateTime month, {this.combined = false}) : month = DateTime(month.year, month.month);

  /// 표·내역에 쓰는 달들 (합산이면 두 달)
  List<DateTime> months(PeriodMode mode) => combined ? periodMonths(month, mode) : [month];

  /// 위쪽 제목. "2026년 3월" / "2026년 3~4월 합산" / "2026년 12월~2027년 1월 합산"
  String title(PeriodMode mode) {
    final ms = months(mode);
    if (ms.length == 1) return '${month.year}년 ${month.month}월';
    final a = ms.first, b = ms.last;
    return a.year == b.year
        ? '${a.year}년 ${a.month}~${b.month}월 합산'
        : '${a.year}년 ${a.month}월~${b.year}년 ${b.month}월 합산';
  }

  @override
  bool operator ==(Object other) => other is PeriodView && other.month == month && other.combined == combined;
  @override
  int get hashCode => Object.hash(month, combined);
  @override
  String toString() => '${month.year}-${month.month}${combined ? '합산' : ''}';
}

/// ◀(-1) ▶(+1) 한 번 넘기기.
/// 1개월: 한 달씩. 홀짝·짝홀: 묶음마다 [첫째 달] → [둘째 달] → [두 달 합산] → 다음 묶음 첫째 달, ◀는 정확히 역순.
PeriodView stepView(PeriodView v, PeriodMode mode, int dir) {
  final m = v.month;
  if (mode == PeriodMode.single) return PeriodView(DateTime(m.year, m.month + dir));
  final pair = periodMonths(m, mode);
  final idx = v.combined ? 2 : (m == pair.first ? 0 : 1);
  final next = idx + dir;
  if (next == 0 || next == 1) return PeriodView(pair[next]);
  if (next == 2) return PeriodView(pair.first, combined: true);
  if (next == 3) return PeriodView(DateTime(pair.last.year, pair.last.month + 1)); // 다음 묶음 첫째 달
  // next == -1: 이전 묶음 합산
  final prev = periodMonths(DateTime(pair.first.year, pair.first.month - 1), mode);
  return PeriodView(prev.first, combined: true);
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
}
