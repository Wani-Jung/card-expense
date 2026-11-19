import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'budget.dart';
import 'expense.dart';
import 'quiz.dart';
import 'vendor.dart';

/// 스토어 스크린샷용 데모 데이터 모드 (REQ-53). `--dart-define=DEMO=true` 일 때만 켜진다.
/// 릴리스 빌드(define 없음)에서는 false 라 아래 코드는 쓰이지 않는다. 가맹점·카드번호는 모두 가짜.
const kDemo = bool.fromEnvironment('DEMO');

/// 데모 한 달 수립 (REQ-56): 총액 45만 · 차량비 30만 (운영비 15만)
const kDemoTotalBudget = 450000;
const kDemoCarBudget = 300000;

/// 데모 화면 구성
/// [pending] 분류 대기 카드(추천 배지)를 넣을지, [issues] 확인 필요 내역(중복 의심·분류 섞임)을 넣을지.
Future<void> seedDemo(SharedPreferences p, {DateTime? now, bool pending = true, bool issues = true}) async {
  final n = now ?? DateTime.now();
  final thisMonth = DateTime(n.year, n.month);
  final prevMonth = DateTime(n.year, n.month - 1);

  /// 이번 달 [daysAgo] 일 전 (1일보다 앞이면 1일, 시각은 [h]:[m])
  DateTime at(int daysAgo, int h, int m) {
    final d = (n.day - daysAgo).clamp(1, n.day);
    final t = DateTime(n.year, n.month, d, h, m);
    // 월초·이른 시각이라 미래가 되면 지금보다 조금 앞으로 (미래 날짜는 '확인 필요'로 잡힌다)
    return t.isAfter(n) ? n.subtract(Duration(minutes: 3 + daysAgo * 5 + m % 5)) : t;
  }

  var seq = 0;
  Map<String, Object?> item(DateTime t, String merchant, int amount, String? cat) => {
    'id': 'demo${seq++}',
    'amount': amount,
    'dateTime': t.toIso8601String(),
    'merchant': merchant,
    'isCancel': false,
    'raw': '[Web발신]\nNH기업카드 0000 승인\n$amount원 일시불\n$merchant',
    'category': cat,
    if (cat == null) 'pendingSince': t.toIso8601String(),
  };

  // REQ-56: 현실적인 규모 — 한 달 수립 총액 45만·차량비 30만(운영비 15만), 사용은 차량비 약 20만·운영비 약 10만.
  // 어느 장면에서도 사용이 수립을 넘지 않고, 차량비 잔여 경고(차량비 잔여 > 전체 잔여)가 생기지 않게 맞춘다.
  final items = <Map<String, Object?>>[
    // 지난달 (홀짝·짝홀 두 달 합산 화면용): 차량비 187,500 · 운영비 92,700
    item(DateTime(prevMonth.year, prevMonth.month, 4, 9, 12), 'OO주유소', 71000, kCar),
    item(DateTime(prevMonth.year, prevMonth.month, 9, 12, 30), 'BB식당', 13000, kOps),
    item(DateTime(prevMonth.year, prevMonth.month, 13, 8, 40), 'EE자동차정비', 52000, kCar),
    item(DateTime(prevMonth.year, prevMonth.month, 15, 12, 10), 'CC한식뷔페', 16000, kOps),
    item(DateTime(prevMonth.year, prevMonth.month, 18, 15, 20), 'DD문구', 11200, kOps),
    item(DateTime(prevMonth.year, prevMonth.month, 20, 12, 5), 'FF김밥', 8500, kOps),
    item(DateTime(prevMonth.year, prevMonth.month, 22, 18, 5), 'OO셀프주유소', 64500, kCar),
    item(DateTime(prevMonth.year, prevMonth.month, 24, 14, 30), 'MM커피', 11000, kOps),
    item(DateTime(prevMonth.year, prevMonth.month, 26, 12, 20), 'NN칼국수', 15000, kOps),
    item(DateTime(prevMonth.year, prevMonth.month, 27, 12, 0), 'II국밥', 18000, kOps),
    // 이번 달: 차량비 200,500 · 운영비 95,900
    item(at(17, 8, 55), 'OO주유소', 68000, kCar),
    item(at(15, 12, 20), 'BB식당', 14000, kOps),
    item(at(13, 10, 5), 'DD문구', 8400, kOps),
    item(at(11, 9, 30), 'EE자동차정비', 45000, kCar),
    item(at(10, 14, 40), 'MM커피', 12000, kOps),
    item(at(9, 12, 15), 'CC한식뷔페', 18000, kOps),
    item(at(7, 17, 40), 'OO셀프주유소', 72500, kCar),
    item(at(6, 12, 30), 'NN칼국수', 16000, kOps),
    item(at(5, 12, 5), 'FF김밥', 9500, kOps),
    item(at(4, 14, 10), 'GG카센터', 15000, kCar),
    item(at(2, 12, 25), 'II국밥', 18000, kOps),
    if (issues) ...[
      // c 같은 가맹점·금액 10분 이내 중복 의심
      item(at(15, 12, 24), 'BB식당', 14000, kOps),
      // a 같은 업체인데 분류가 섞임 (소수 쪽이 확인 필요)
      item(at(10, 11, 0), 'HH마트', 9800, kOps),
      item(at(6, 16, 30), 'HH마트', 7600, kOps),
      item(at(3, 10, 45), 'HH마트', 12900, kCar),
    ],
    if (pending) ...[
      item(at(1, 8, 20), 'KK주유소', 61000, null),
      item(at(1, 12, 35), 'LL분식', 9000, null),
      item(at(0, 9, 10), 'OO주유소', 55000, null),
    ],
  ];

  final budgets = {
    for (final m in [prevMonth, thisMonth, DateTime(n.year, n.month + 1)])
      Budgets.keyOf(m): {'total': kDemoTotalBudget, 'car': kDemoCarBudget},
  };

  final vendors = VendorBook.initial();
  for (final (name, cat) in [
    ('OO주유소', kCar),
    ('OO셀프주유소', kCar),
    ('EE자동차정비', kCar),
    ('BB식당', kOps),
    ('CC한식뷔페', kOps),
    ('DD문구', kOps),
  ]) {
    vendors.learn(name, cat);
  }

  // 안전 OX: 최근 며칠 오늘의 문제를 푼 기록 (요약 카드 숫자용)
  final log = [
    for (var i = 6; i >= 1; i--)
      jsonEncode({'d': quizDay(n.subtract(Duration(days: i))), 'id': 'w00$i', 'c': true, 'ok': i != 3}),
  ];

  await p.setString('card_digits', '0000');
  await p.setString('sender_number', '1588-1600');
  await p.setString('expenses_v1', jsonEncode(items));
  await p.setString('budgets_v1', jsonEncode(budgets));
  await p.setString('vendor_book_v1', jsonEncode(vendors.toJson()));
  await p.setStringList('quiz_log_v1', log);
  await p.setString('quiz_last_day_v1', quizDay(n));
  await p.setString('money_unit_v1', MoneyUnit.won.name);
  await p.setBool('notif_asked_v1', true);
  // 알림 감지 '앱에서 사용'을 꺼서 권한 배너가 안 뜨게 (에뮬레이터엔 알림 접근 권한이 없음)
  await p.setBool('use_listener_v1', false);
  await p.setInt('update_checked_at', n.millisecondsSinceEpoch);
}

/// 앱 시작 때 데모 모드면 데모 데이터로 시작한다. 이미 내역이 있으면(실제 데이터일 수 있음) 건드리지 않는다.
Future<void> seedDemoIfEmpty() async {
  if (!kDemo) return;
  final p = await SharedPreferences.getInstance();
  if (p.containsKey('expenses_v1') || p.containsKey('card_digits')) return;
  await seedDemo(p);
}
