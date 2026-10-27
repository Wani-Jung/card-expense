import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'budget.dart';
import 'flavor.dart';
import 'sms_parser.dart';
import 'vendor.dart';

/// 분류: null 이면 분류 대기.
const kCar = 'car';
const kOps = 'ops';
const kIgnored = 'ignored';

class Expense {
  final String id;
  final int amount;
  final DateTime dateTime;
  final String merchant;
  final bool isCancel;
  final String raw;
  String? category;

  Expense({
    required this.id,
    required this.amount,
    required this.dateTime,
    required this.merchant,
    required this.isCancel,
    required this.raw,
    this.category,
  });

  factory Expense.fromParsed(ParsedSms p) => Expense(
        id: p.id,
        amount: p.amount,
        dateTime: p.dateTime,
        merchant: p.merchant,
        isCancel: p.isCancel,
        raw: p.raw,
      );

  /// 합계에 더할 값. 승인취소는 음수.
  int get signedAmount => isCancel ? -amount : amount;

  bool inMonth(DateTime month) =>
      dateTime.year == month.year && dateTime.month == month.month;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'dateTime': dateTime.toIso8601String(),
        'merchant': merchant,
        'isCancel': isCancel,
        'raw': raw,
        'category': category,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        amount: j['amount'] as int,
        dateTime: DateTime.parse(j['dateTime'] as String),
        merchant: j['merchant'] as String? ?? '',
        isCancel: j['isCancel'] as bool? ?? false,
        raw: j['raw'] as String? ?? '',
        category: j['category'] as String?,
      );
}

/// v1.5.1 1회 정리: RCS JSON 본문 때문에 가맹점에 붙은 "\r\n", "}}}} 같은 찌꺼기를 지우고
/// 본문을 실제 텍스트로 바꾼다. 분류(차량비·운영비·대기·무시)는 그대로 둔다.
/// 정리 후 같은 승인 건(같은 id)이 둘 이상이면 하나만 남긴다 (분류된 것 > 대기 > 무시 순).
List<Expense> cleanupStoredItems(List<Expense> items) {
  int rank(String? c) => c == kCar || c == kOps ? 0 : (c == null ? 1 : 2);
  final byId = <String, Expense>{};
  for (final e in items) {
    // JSON·리터럴 줄바꿈이 든 본문만 다시 읽는다. 나머지는 가맹점만 정리
    // (캡처 확인 화면에서 손으로 고친 금액·날짜를 덮어쓰지 않도록).
    final dirty = e.raw.trimLeft().startsWith('{') || e.raw.contains(r'\n') || e.raw.contains(r'\r');
    final raw = dirty ? normalizeBody(e.raw) : e.raw;
    // 원래 시각을 기준으로 다시 읽어서 연도는 그대로 유지한다
    final p = dirty ? parseSms(raw, cardDigits: '', receivedAt: e.dateTime, requireCard: false) : null;
    final fixed = Expense(
      id: p?.id ?? e.id,
      amount: p?.amount ?? e.amount,
      dateTime: p?.dateTime ?? e.dateTime,
      merchant: p?.merchant ?? cleanMerchant(e.merchant),
      isCancel: p?.isCancel ?? e.isCancel,
      raw: raw,
      category: e.category,
    );
    final prev = byId[fixed.id];
    if (prev == null || rank(fixed.category) < rank(prev.category)) byId[fixed.id] = fixed;
  }
  return byId.values.toList();
}

class Store {
  static const _kItems = 'expenses_v1';
  static const _kDigits = 'card_digits';
  static const _kSender = 'sender_number';
  static const _kBudgets = 'budgets_v1';
  static const _kAutoImported = 'auto_import_done';
  static const _kUpdateChecked = 'update_checked_at';
  static const _kUpdateSkipped = 'update_skipped_tag';

  final SharedPreferences _prefs;
  Store._(this._prefs);

  static Future<Store> open() async => Store._(await SharedPreferences.getInstance());

  String? get cardDigits => _prefs.getString(_kDigits);
  String? get senderNumber => _prefs.getString(_kSender);

  /// 카드번호·발신번호 저장. 하나라도 바뀌면 (전용판) 1년치 자동 불러오기를 다시 하게 한다.
  Future<void> setSettings(String digits, String sender) async {
    if (digits != cardDigits || sender != senderNumber) await _prefs.remove(_kAutoImported);
    await _prefs.setString(_kDigits, digits);
    await _prefs.setString(_kSender, sender);
  }

  /// (전용판) 현재 설정으로 1년치 자동 불러오기를 했는지.
  bool get autoImported => _prefs.getBool(_kAutoImported) ?? false;
  Future<void> setAutoImported() => _prefs.setBool(_kAutoImported, true);

  static const _kVendors = 'vendor_book_v1';

  /// 업체 관리. 처음이면 기본 키워드가 들어간 상태로 시작한다.
  VendorBook loadVendors() {
    final s = _prefs.getString(_kVendors);
    return s == null ? VendorBook.initial() : VendorBook.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> saveVendors(VendorBook v) => _prefs.setString(_kVendors, jsonEncode(v.toJson()));

  Budgets loadBudgets() {
    final s = _prefs.getString(_kBudgets);
    return s == null ? Budgets({}) : Budgets.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> saveBudgets(Budgets b) => _prefs.setString(_kBudgets, jsonEncode(b.toJson()));

  /// 업데이트 자동 확인은 하루 한 번.
  DateTime? get updateCheckedAt {
    final ms = _prefs.getInt(_kUpdateChecked);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setUpdateCheckedAt(DateTime t) => _prefs.setInt(_kUpdateChecked, t.millisecondsSinceEpoch);

  /// '나중에'를 누른 버전. 자동 확인에서는 다시 띄우지 않는다.
  String? get updateSkippedTag => _prefs.getString(_kUpdateSkipped);
  Future<void> setUpdateSkippedTag(String tag) => _prefs.setString(_kUpdateSkipped, tag);

  static const _kCleanedV1 = 'merchant_cleanup_v1';

  List<Expense> loadItems() {
    final s = _prefs.getString(_kItems);
    if (s == null) return [];
    return (jsonDecode(s) as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 앱 시작 시 1회: 저장된 내역의 가맹점·본문 찌꺼기 정리 ([cleanupStoredItems]).
  Future<void> migrate() async {
    if (_prefs.getBool(_kCleanedV1) ?? false) return;
    final items = loadItems();
    if (items.isNotEmpty) await saveItems(cleanupStoredItems(items));
    await _prefs.setBool(_kCleanedV1, true);
  }

  Future<void> saveItems(List<Expense> items) =>
      _prefs.setString(_kItems, jsonEncode(items.map((e) => e.toJson()).toList()));
}

String won(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b원';
}

String two(int n) => n.toString().padLeft(2, '0');

String fmtDateTime(DateTime d) =>
    '${d.year}.${two(d.month)}.${two(d.day)} ${two(d.hour)}:${two(d.minute)}';

/// 정산용 텍스트. 화면에서 보고 있는 달 기준. 맨 위에 수립/사용 표를 붙인다.
String settlementText(List<Expense> items, DateTime month, String digits,
    [MonthBudget budget = const MonthBudget()]) {
  final inMonth = items.where((e) => e.inMonth(month)).toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final b = StringBuffer('[${month.year}년 ${month.month}월 $kAppName] 카드 $digits\n');
  final usage = MonthUsage.of(inMonth, month);
  // 메신저에 붙여넣으면 칸이 안 맞으므로 줄 단위로 쓴다.
  String row(String label, int? plan, int used) =>
      ' $label: 수립 ${manwonOrDash(plan)} / 사용 ${manwon(used)}';
  b.writeln();
  b.writeln('■ 수립/사용 (단위: 만원)');
  b.writeln(row('합계', budget.total, usage.total));
  b.writeln(row('차량비', budget.car, usage.car));
  b.writeln(row('운영비', budget.ops, usage.ops));
  var total = 0;
  for (final (cat, label) in [(kCar, '차량비'), (kOps, '운영비')]) {
    final list = inMonth.where((e) => e.category == cat).toList();
    final sum = list.fold<int>(0, (s, e) => s + e.signedAmount);
    total += sum;
    b.writeln();
    b.writeln('■ $label ${list.length}건 / ${won(sum)}');
    for (final e in list) {
      final d = e.dateTime;
      b.writeln(' ${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)} '
          '${e.merchant}${e.isCancel ? ' (승인취소)' : ''} ${won(e.signedAmount)}');
    }
  }
  b.writeln();
  b.writeln('■ 합계 ${won(total)}');
  final pending = inMonth.where((e) => e.category == null).length;
  if (pending > 0) b.writeln('※ 미분류 $pending건 있음');
  return b.toString();
}
